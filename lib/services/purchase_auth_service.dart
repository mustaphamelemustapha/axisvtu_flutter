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
        return _setupFlow(
          context: context,
          service: service,
          reason: reason,
          pinLength: status.pinLength,
        );
      }

      return _verifyFlow(
        context: context,
        service: service,
        reason: reason,
        pinLength: status.pinLength,
      );
    } on ApiException catch (e) {
      _showSnack(context, _friendlyError(e.message, e.statusCode));
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
    required int pinLength,
  }) async {
    final first = await _requestPinInput(
      context: context,
      title: 'Create Transaction PIN',
      subtitle: 'Set your $pinLength-digit PIN for $reason.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (first == null || !context.mounted) return false;

    final second = await _requestPinInput(
      context: context,
      title: 'Confirm Transaction PIN',
      subtitle: 'Re-enter your $pinLength-digit PIN.',
      confirmLabel: 'Save PIN',
      pinLength: pinLength,
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
        return _verifyFlow(
          context: context,
          service: service,
          reason: reason,
          pinLength: pinLength,
        );
      }
      _showSnack(context, _friendlyError(e.message, e.statusCode));
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
    required int pinLength,
  }) async {
    final pin = await _requestPinInput(
      context: context,
      title: 'Enter Transaction PIN',
      subtitle: 'Authorize this $reason with your $pinLength-digit PIN.',
      confirmLabel: 'Verify',
      pinLength: pinLength,
      onSubmit: (value) async {
        try {
          await service.verify(value);
          return null;
        } on ApiException catch (e) {
          return _friendlyError(e.message, e.statusCode);
        } catch (e) {
          return _friendlyError(e.toString());
        }
      },
    );
    if (pin == null || !context.mounted) return false;
    return true;
  }

  static Future<String?> _requestPinInput({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String confirmLabel,
    required int pinLength,
    Future<String?> Function(String pin)? onSubmit,
  }) {
    return PinEntrySheet.show(
      context,
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      pinLength: pinLength,
      onSubmit: onSubmit,
    );
  }

  static void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _friendlyError(String message, [int? statusCode]) {
    final raw = message.trim();
    final lower = raw.toLowerCase();
    if (statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 423 ||
        statusCode == 429) {
      return 'Incorrect PIN, try again.';
    }
    if (lower.contains('incorrect') && lower.contains('pin')) {
      return 'Incorrect PIN, try again.';
    }
    if (lower.contains('locked') || lower.contains('attempt')) {
      return 'Incorrect PIN, try again.';
    }
    if (lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('try again later')) {
      return 'Incorrect PIN, try again.';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Check your connection and try again.';
    }
    if (raw.startsWith('ApiException(')) {
      final idx = raw.indexOf(':');
      if (idx != -1 && idx + 1 < raw.length) {
        final parsed = raw.substring(idx + 1).trim();
        if (parsed.toLowerCase().contains('incorrect') &&
            parsed.toLowerCase().contains('pin')) {
          return 'Incorrect PIN, try again.';
        }
        if (parsed.toLowerCase().contains('locked') ||
            parsed.toLowerCase().contains('attempt')) {
          return 'Incorrect PIN, try again.';
        }
        if (parsed.toLowerCase().contains('too many requests') ||
            parsed.toLowerCase().contains('rate limit') ||
            parsed.toLowerCase().contains('try again later')) {
          return 'Incorrect PIN, try again.';
        }
        return parsed;
      }
    }
    if (raw.isEmpty) return 'Something went wrong. Please try again.';
    return raw;
  }
}
