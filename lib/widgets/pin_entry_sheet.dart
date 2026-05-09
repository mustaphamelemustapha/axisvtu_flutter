import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/axis_tokens.dart';

class PinEntrySheet {
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String confirmLabel = 'Continue',
    int pinLength = 4,
    bool autoSubmit = true,
    VoidCallback? onForgotPin,
    Future<String?> Function(String pin)? onSubmit,
  }) {
    final normalizedLength = pinLength == 6 ? 6 : 4;
    return showGeneralDialog<String>(
      context: context,
      barrierLabel: 'PIN',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => _PinPadDialog(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        pinLength: normalizedLength,
        autoSubmit: autoSubmit,
        onForgotPin: onForgotPin,
        onSubmit: onSubmit,
      ),
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
}

class _PinPadDialog extends StatefulWidget {
  const _PinPadDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.pinLength,
    required this.autoSubmit,
    this.onForgotPin,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final int pinLength;
  final bool autoSubmit;
  final VoidCallback? onForgotPin;
  final Future<String?> Function(String pin)? onSubmit;

  @override
  State<_PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends State<_PinPadDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _submitting = false;
  Timer? _autoSubmitTimer;
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _append(String digit) {
    if (_submitting || _pin.length >= widget.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = '$_pin$digit';
      _error = null;
    });
    if (widget.autoSubmit && _pin.length == widget.pinLength) {
      _autoSubmitTimer?.cancel();
      _autoSubmitTimer = Timer(const Duration(milliseconds: 100), _confirm);
    }
  }

  void _backspace() {
    if (_submitting || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _setError(String message) {
    setState(() => _error = message);
    _shakeController.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    if (!RegExp(r'^\d+$').hasMatch(_pin) || _pin.length != widget.pinLength) {
      _setError('PIN must be exactly ${widget.pinLength} digits.');
      return;
    }
    final pin = _pin;
    if (widget.onSubmit != null) {
      setState(() {
        _submitting = true;
        _error = null;
      });
      final message = await widget.onSubmit!(pin);
      if (!mounted) return;
      if (message == null) {
        Navigator.of(context).pop(pin);
        return;
      }
      setState(() {
        _submitting = false;
        _error = message;
        _pin = '';
      });
      _shakeController.forward(from: 0);
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(pin);
  }

  Widget _pinDot(int index) {
    final filled = index < _pin.length;
    return AnimatedContainer(
      duration: AxisDurations.fast,
      width: widget.pinLength == 6 ? 14 : 16,
      height: widget.pinLength == 6 ? 14 : 16,
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
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0E1A33), Color(0xFF0A1022)],
                    )
                  : null,
              color: isDark ? null : surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : theme.colorScheme.outline.withValues(alpha: 0.16),
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
                          color: isDark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.86)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final t = _shakeController.value;
                    final offset = math.sin(t * math.pi * 8) * 6;
                    return Transform.translate(
                      offset: Offset(_error != null ? offset : 0, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.pinLength,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _pinDot(i),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: AxisDurations.fast,
                  child: _error == null
                      ? const SizedBox(height: 18)
                      : Padding(
                          key: ValueKey(_error),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    _keyButton(child: const Text('1'), onTap: () => _append('1')),
                    _keyButton(child: const Text('2'), onTap: () => _append('2')),
                    _keyButton(child: const Text('3'), onTap: () => _append('3')),
                    _keyButton(child: const Text('4'), onTap: () => _append('4')),
                    _keyButton(child: const Text('5'), onTap: () => _append('5')),
                    _keyButton(child: const Text('6'), onTap: () => _append('6')),
                    _keyButton(child: const Text('7'), onTap: () => _append('7')),
                    _keyButton(child: const Text('8'), onTap: () => _append('8')),
                    _keyButton(child: const Text('9'), onTap: () => _append('9')),
                    _keyButton(
                      child: Icon(
                        Icons.backspace_outlined,
                        size: 20,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      onTap: _backspace,
                      enabled: _pin.isNotEmpty,
                    ),
                    _keyButton(child: const Text('0'), onTap: () => _append('0')),
                    _keyButton(
                    child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      onTap: _submitting ? () {} : _confirm,
                      enabled: _pin.length == widget.pinLength && !_submitting,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: _pin.length == widget.pinLength && !_submitting ? _confirm : null,
                  child: AnimatedSwitcher(
                    duration: AxisDurations.fast,
                    child: _submitting
                        ? SizedBox(
                            key: const ValueKey('submitting'),
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                            ),
                          )
                        : Text(
                            widget.confirmLabel,
                            key: const ValueKey('confirm'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                            ),
                          ),
                  ),
                ),
                if (widget.onForgotPin != null) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onForgotPin!();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot PIN?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : theme.colorScheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
