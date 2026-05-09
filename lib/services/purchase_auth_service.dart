import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/pin_entry_sheet.dart';
import 'api_client.dart';
import 'transaction_pin_service.dart';
import 'biometric_service.dart';

class PurchaseAuthService {
  // auto: chooser/fallback, pin: force pin sheet, biometric: try biometric first
  static const String methodAuto = 'auto';
  static const String methodPin = 'pin';
  static const String methodBiometric = 'biometric';

  static Future<bool> authorizePin({
    required BuildContext context,
    String reason = 'purchase',
    String preferredMethod = methodAuto,
  }) async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return false;

    final service = TransactionPinService(token: token);

    // Optimization: Show UI immediately for known PIN length (usually 4) 
    // or fetch status in parallel. For now, we fetch status but handle it gracefully.
    try {
      final status = await service.statusOrNull().timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (!context.mounted) return false;

      // If service is down or slow, default to a sensible state
      if (status == null) {
        return _verifyFlow(
          context: context,
          service: service,
          reason: reason,
          pinLength: 4, // Sensible default
          preferredMethod: preferredMethod,
        );
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
        preferredMethod: preferredMethod,
      );
    } catch (e) {
      // Fallback for any error during status fetch
      if (!context.mounted) return false;
      return _verifyFlow(
        context: context,
        service: service,
        reason: reason,
        pinLength: 4,
        preferredMethod: preferredMethod,
      );
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
      title: 'Create Purchase PIN',
      subtitle: 'Set your $pinLength-digit PIN for $reason.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (first == null || !context.mounted) return false;

    final second = await _requestPinInput(
      context: context,
      title: 'Confirm Purchase PIN',
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
      _showSnack(context, 'Purchase PIN created successfully.');
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Another device/session may have already set it. Re-run verification.
        return _verifyFlow(
          context: context,
          service: service,
          reason: reason,
          pinLength: pinLength,
          preferredMethod: methodAuto,
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
    required String preferredMethod,
  }) async {
    // 1. Check for Biometric Unlock
    final bioEnabled = await BiometricService.isAppLockEnabled;
    final savedPin = await BiometricService.getPin();
    final availability = await BiometricService.getAvailability();

    if (bioEnabled && availability.ready && context.mounted) {
      bool useBiometric = false;
      if (preferredMethod == methodBiometric) {
        useBiometric = true;
      } else if (preferredMethod == methodPin) {
        useBiometric = false;
      } else {
        final choice = await _askAuthMethod(context, reason);
        useBiometric = choice == true;
      }

      if (useBiometric) {
        final success = await BiometricService.authenticate(
          reason: 'Confirm your $reason via Biometrics',
        );
        if (success) {
          if (savedPin != null && savedPin.length == pinLength) {
            try {
              await service.verify(savedPin);
              return true;
            } catch (_) {
              // If saved PIN fails (maybe user changed it), delete it and fallback
              await BiometricService.deletePin();
            }
          }
          // If we reach here, biometric was successful but PIN is missing or invalid
          _showSnack(
            context,
            'Biometric verified. Enter your purchase PIN to sync.',
          );
        } else if (preferredMethod == methodBiometric) {
          // If biometric was explicitly requested but failed/cancelled, return false 
          // to avoid unexpected fallback to PIN sheet if they just wanted to cancel
          return false;
        }
      }
    }

    // 2. Manual PIN entry (Fallback or Primary)
    if (!context.mounted) return false;
    final pin = await _requestPinInput(
      context: context,
      title: 'Enter Purchase PIN',
      subtitle: 'Authorize this $reason with your $pinLength-digit PIN.',
      confirmLabel: 'Verify',
      pinLength: pinLength,
      onForgotPin: () async {
        try {
          await service.requestReset();
          _showSnack(
            context,
            'Reset link sent to your email. Open it to set a new PIN.',
          );
        } catch (e) {
          _showSnack(context, 'Unable to request PIN reset: $e');
        }
      },
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

    // 3. Sync PIN for future biometric use if enabled
    if (bioEnabled && availability.ready) {
      await BiometricService.savePin(pin);
    }
    
    return true;
  }

  static Future<bool?> _askAuthMethod(BuildContext context, String reason) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Authorize $reason',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Use biometrics for quick approval, or continue with your purchase PIN.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        icon: const Icon(Icons.pin_outlined),
                        label: const Text('Use PIN'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('Use fingerprint'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<String?> _requestPinInput({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String confirmLabel,
    required int pinLength,
    VoidCallback? onForgotPin,
    Future<String?> Function(String pin)? onSubmit,
  }) {
    return PinEntrySheet.show(
      context,
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      pinLength: pinLength,
      onForgotPin: onForgotPin,
      onSubmit: onSubmit,
    );
  }

  static void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
