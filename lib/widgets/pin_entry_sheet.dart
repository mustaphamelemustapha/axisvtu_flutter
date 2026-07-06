import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/axis_tokens.dart';
import '../services/biometric_service.dart';

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
    return Navigator.of(context).push<String>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _PinPadScreen(
          title: title,
          subtitle: subtitle,
          confirmLabel: confirmLabel,
          pinLength: normalizedLength,
          autoSubmit: autoSubmit,
          onForgotPin: onForgotPin,
          onSubmit: onSubmit,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

class _PinPadScreen extends StatefulWidget {
  const _PinPadScreen({
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
  State<_PinPadScreen> createState() => _PinPadScreenState();
}

class _PinPadScreenState extends State<_PinPadScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _submitting = false;
  Timer? _autoSubmitTimer;
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  bool _showBiometricButton = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final enabled = await BiometricService.isAppLockEnabled;
    final availability = await BiometricService.getAvailability();
    final savedPin = await BiometricService.getPin();
    if (enabled &&
        availability.ready &&
        savedPin != null &&
        savedPin.length == widget.pinLength) {
      if (mounted) {
        setState(() {
          _showBiometricButton = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithBiometrics();
        });
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_submitting) return;
    final success = await BiometricService.authenticate(
      reason: 'Verify with biometrics to continue',
    );
    if (success && mounted) {
      final savedPin = await BiometricService.getPin();
      if (savedPin != null && savedPin.length == widget.pinLength) {
        setState(() {
          _pin = savedPin;
        });
        await _confirm();
      }
    }
  }

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _append(String digit) {
    if (_submitting || _pin.length >= widget.pinLength) return;
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _setError(String message) {
    setState(() => _error = message);
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
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
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(pin);
  }

  Widget _buildPinBox(int index, bool isDark) {
    final filled = index < _pin.length;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: widget.pinLength == 6 ? 42 : 52,
      height: widget.pinLength == 6 ? 42 : 52,
      decoration: BoxDecoration(
        color: isDark 
            ? (filled ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
            : (filled ? Colors.white : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filled 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          width: filled ? 1.5 : 1,
        ),
        boxShadow: filled ? [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: filled ? 14 : 0,
          height: filled ? 14 : 0,
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: filled ? [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 6,
                spreadRadius: 1,
              )
            ] : [],
          ),
        ),
      ),
    );
  }

  Widget _keyButton({
    required Widget child,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 76,
      height: 76,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isDark) {
    final textStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : Colors.black87,
    );

    return Wrap(
      spacing: 28,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: [
        _keyButton(child: Text('1', style: textStyle), onTap: () => _append('1')),
        _keyButton(child: Text('2', style: textStyle), onTap: () => _append('2')),
        _keyButton(child: Text('3', style: textStyle), onTap: () => _append('3')),
        _keyButton(child: Text('4', style: textStyle), onTap: () => _append('4')),
        _keyButton(child: Text('5', style: textStyle), onTap: () => _append('5')),
        _keyButton(child: Text('6', style: textStyle), onTap: () => _append('6')),
        _keyButton(child: Text('7', style: textStyle), onTap: () => _append('7')),
        _keyButton(child: Text('8', style: textStyle), onTap: () => _append('8')),
        _keyButton(child: Text('9', style: textStyle), onTap: () => _append('9')),
        _showBiometricButton
            ? _keyButton(
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 32,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onTap: _authenticateWithBiometrics,
                enabled: !_submitting,
              )
            : SizedBox(width: 76, height: 76),
        _keyButton(child: Text('0', style: textStyle), onTap: () => _append('0')),
        _keyButton(
          child: Icon(
            Icons.backspace_rounded,
            size: 26,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
          onTap: _backspace,
          enabled: _pin.isNotEmpty && !_submitting,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Authorize Payment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // PIN Boxes Container
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 20,
                                spreadRadius: -5,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
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
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                widget.pinLength,
                                (i) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: _buildPinBox(i, isDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Error Text
                      AnimatedSwitcher(
                        duration: AxisDurations.fast,
                        child: _error == null
                            ? const SizedBox(height: 24)
                            : Padding(
                                key: ValueKey(_error),
                                padding: const EdgeInsets.only(top: 16, bottom: 8),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFFFF6B6B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Keypad
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildKeypad(isDark),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Submit/Loading state if not auto submit
                      if (!widget.autoSubmit || _submitting)
                        SizedBox(
                          height: 48,
                          child: _submitting
                            ? Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : (!widget.autoSubmit
                              ? TextButton(
                                  onPressed: _pin.length == widget.pinLength ? _confirm : null,
                                  child: Text(
                                    widget.confirmLabel,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _pin.length == widget.pinLength 
                                          ? theme.colorScheme.primary 
                                          : theme.colorScheme.primary.withValues(alpha: 0.5),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink()
                            ),
                        ),
                        
                      // Forgot PIN
                      if (widget.onForgotPin != null && !_submitting) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onForgotPin!();
                          },
                          child: Text(
                            'Forgot PIN?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
