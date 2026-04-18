import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/pin_entry_sheet.dart';
import 'api_client.dart';
import 'transaction_pin_service.dart';

class PurchaseAuthService {
  static Future<bool> authorizePin({
    required BuildContext context,
    String reason = 'purchase',
  }) async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return false;

    final service = TransactionPinService(token: token);

    try {
      final status = await service.statusOrNull();
      if (!context.mounted) return false;

      if (status == null) {
        _showSnack(
          context,
          'Transaction PIN service is updating. Please try again in a moment.',
        );
        return false;
      }

      if (!status.isSet) {
        return _setupFlow(context: context, service: service, reason: reason);
      }

      if (status.isLocked) {
        _showSnack(
          context,
          'Transaction PIN is temporarily locked. Try again later.',
        );
        return false;
      }

      return _verifyFlow(context: context, service: service, reason: reason);
    } on ApiException catch (e) {
      _showSnack(context, _friendlyError(e.message));
      return false;
    } catch (e) {
      _showSnack(context, _friendlyError(e.toString()));
      return false;
    }
  }

  static Future<bool> _setupFlow({
    required BuildContext context,
    required TransactionPinService service,
    required String reason,
  }) async {
    final first = await _requestPinInput(
      context: context,
      title: 'Create Transaction PIN',
      subtitle: 'Set your 4-digit PIN for $reason.',
      confirmLabel: 'Continue',
    );
    if (first == null || !context.mounted) return false;

    final second = await _requestPinInput(
      context: context,
      title: 'Confirm Transaction PIN',
      subtitle: 'Re-enter your 4-digit PIN.',
      confirmLabel: 'Save PIN',
    );
    if (second == null || !context.mounted) return false;
    if (first != second) {
      _showSnack(context, 'PIN mismatch. Please try again.');
      return false;
    }

    try {
      await service.setup(pin: first, confirmPin: second);
      if (!context.mounted) return false;
      _showSnack(context, 'Transaction PIN created successfully.');
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Another device/session may have already set it. Re-run verification.
        return _verifyFlow(context: context, service: service, reason: reason);
      }
      _showSnack(context, _friendlyError(e.message));
      return false;
    } catch (e) {
      _showSnack(context, _friendlyError(e.toString()));
      return false;
    }
  }

  static Future<bool> _verifyFlow({
    required BuildContext context,
    required TransactionPinService service,
    required String reason,
  }) async {
    final pin = await _requestPinInput(
      context: context,
      title: 'Enter Transaction PIN',
      subtitle: 'Authorize this $reason with your 4-digit PIN.',
      confirmLabel: 'Verify',
    );
    if (pin == null || !context.mounted) return false;

    try {
      await service.verify(pin);
      return true;
    } on ApiException catch (e) {
      _showSnack(context, _friendlyError(e.message));
      return false;
    } catch (e) {
      _showSnack(context, _friendlyError(e.toString()));
      return false;
    }
  }

  static Future<String?> _requestPinInput({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) {
    return PinEntrySheet.show(
      context,
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
    );
  }

  static void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _friendlyError(String message) {
    final raw = message.trim();
    if (raw.startsWith('ApiException(')) {
      final idx = raw.indexOf(':');
      if (idx != -1 && idx + 1 < raw.length) {
        return raw.substring(idx + 1).trim();
      }
    }
    if (raw.isEmpty) return 'Something went wrong. Please try again.';
    return raw;
  }
}
