import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_pin_service.dart';

class PurchaseAuthService {
  static Future<String?> _requestPinInput({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) async {
    return showGeneralDialog<String>(
      context: context,
      barrierLabel: 'PIN',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _PinPadDialog(title: title, subtitle: subtitle),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
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
        title: 'Create Transaction PIN',
        subtitle: 'Set your 4-digit PIN for $reason.',
      );
      if (first == null) return false;
      if (!context.mounted) return false;

      final second = await _requestPinInput(
        context: context,
        title: 'Confirm Transaction PIN',
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

    for (var attempt = 0; attempt < 3; attempt++) {
      final pin = await _requestPinInput(
        context: context,
        title: 'Enter Transaction PIN',
        subtitle: 'Authorize this $reason with your 4-digit PIN.',
      );
      if (!context.mounted) return false;
      if (pin == null) return false;

      final ok = await AppPinService.verifyPin(pin);
      if (!context.mounted) return false;
      if (ok) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong PIN entered, try again.')),
      );
    }
    return false;
  }
}

class _PinPadDialog extends StatefulWidget {
  const _PinPadDialog({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends State<_PinPadDialog> {
  String _pin = '';
  String? _error;

  void _append(String digit) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = '$_pin$digit';
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _confirm() {
    if (!RegExp(r'^\d{4}$').hasMatch(_pin)) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    Navigator.of(context).pop(_pin);
  }

  Widget _pinDot(int index) {
    final filled = index < _pin.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? const Color(0xFF4C8DFF) : Colors.transparent,
        border: Border.all(
          color: filled
              ? const Color(0xFF4C8DFF)
              : Colors.white.withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
    );
  }

  Widget _keyButton({
    required Widget child,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: enabled
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E1A33), Color(0xFF0A1022)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _pinDot(i),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 14,
                  children: [
                    for (var n = 1; n <= 9; n++)
                      _keyButton(
                        child: Text(
                          '$n',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => _append('$n'),
                      ),
                    _keyButton(
                      child: const Icon(
                        Icons.backspace_outlined,
                        color: Colors.white,
                        size: 25,
                      ),
                      onTap: _backspace,
                      enabled: _pin.isNotEmpty,
                    ),
                    _keyButton(
                      child: const Text(
                        '0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _append('0'),
                    ),
                    _keyButton(
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onTap: _confirm,
                      enabled: _pin.length == 4,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
