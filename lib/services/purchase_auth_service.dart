import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_pin_service.dart';

class PurchaseAuthService {
  static Future<String?> _requestPinInput({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) async {
    String pinValue = '';
    String? errorText;

    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 4,
                    obscureText: true,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) {
                      pinValue = value.trim();
                      if (errorText != null) {
                        setStateDialog(() => errorText = null);
                      }
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: '4-digit PIN',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = pinValue;
                    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                      setStateDialog(
                        () => errorText = 'PIN must be exactly 4 digits.',
                      );
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
    return pin;
  }

  static Future<bool> authorizePin({
    required BuildContext context,
    String reason = 'purchase',
  }) async {
    final hasPin = await AppPinService.hasPin();
    if (!context.mounted) return false;

    if (!hasPin) {
      final first = await _requestPinInput(
        context: context,
        title: 'Create Purchase PIN',
        subtitle: 'Set your 4-digit PIN for $reason.',
      );
      if (first == null) return false;
      if (!context.mounted) return false;

      final second = await _requestPinInput(
        context: context,
        title: 'Confirm Purchase PIN',
        subtitle: 'Re-enter your 4-digit PIN.',
      );
      if (second == null) return false;
      if (first != second) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN mismatch. Please try again.')),
          );
        }
        return false;
      }

      await AppPinService.savePin(first);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN created successfully.')),
        );
      }
      return true;
    }

    final pin = await _requestPinInput(
      context: context,
      title: 'Enter Purchase PIN',
      subtitle: 'Authorize this $reason with your 4-digit PIN.',
    );
    if (pin == null) return false;

    final ok = await AppPinService.verifyPin(pin);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect PIN.')));
    }
    return ok;
  }
}
