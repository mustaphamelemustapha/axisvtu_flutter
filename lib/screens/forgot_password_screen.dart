import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../services/password_service.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String identifier;

  const ForgotPasswordScreen({super.key, required this.identifier});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0: OTP, 1: New Password
  
  // OTP Step
  final TextEditingController _otpCtrl = TextEditingController();
  final FocusNode _otpFocus = FocusNode();
  bool _loading = false;
  String? _error;
  int _countdown = 300; // 5 minutes
  Timer? _timer;

  // Password Step
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpCtrl.addListener(() {
      if (_otpCtrl.text.length > 6) {
        _otpCtrl.text = _otpCtrl.text.substring(0, 6);
        _otpCtrl.selection = TextSelection.collapsed(offset: 6);
      }
      setState(() {});
      if (_otpCtrl.text.length == 6 && !_loading && _step == 0) {
        _handleVerifyOTP();
      }
    });
    _passCtrl.addListener(() => setState(() {}));
    _confirmPassCtrl.addListener(() => setState(() {}));
    
    // Auto-focus OTP and request it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_step == 0) _otpFocus.requestFocus();
      _handleRequestOTP();
    });
  }

  Future<void> _handleRequestOTP() async {
    try {
      await PasswordService().requestReset(widget.identifier);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send code. Please tap Resend.', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _countdown = 300;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOTP() async {
    final otp = _otpCtrl.text;
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await PasswordService().verifyResetToken(
        identifier: widget.identifier,
        otp: otp,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _step = 1;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Invalid or expired code. Please try again.';
        });
      }
    }
  }

  Future<void> _handleUpdatePassword() async {
    final p1 = _passCtrl.text;
    final p2 = _confirmPassCtrl.text;

    if (p1.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await PasswordService().resetPassword(
        identifier: widget.identifier,
        otp: _otpCtrl.text,
        newPassword: p1,
      );
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password updated successfully', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(); // Go back to login
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Invalid code or failed to update. Please check and try again.';
        });
      }
    }
  }

  Future<void> _handleResend() async {
    if (_countdown > 0) return;
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await PasswordService().requestReset(widget.identifier);
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code resent', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code.', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String get _formattedTime {
    final m = (_countdown ~/ 60).toString().padLeft(2, '0');
    final s = (_countdown % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildOtpBoxes(bool isDark) {
    return Stack(
      children: [
        // Invisible text field
        Opacity(
          opacity: 0.0,
          child: TextField(
            controller: _otpCtrl,
            focusNode: _otpFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            autofocus: true,
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
        // Visual boxes
        GestureDetector(
          onTap: () => _otpFocus.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final text = _otpCtrl.text;
              final hasChar = index < text.length;
              final isActive = index == text.length || (index == 5 && text.length == 6);
              final char = hasChar ? text[index] : '';

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF2563EB)
                        : theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
                    width: isActive ? 2.0 : 1.0,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            blurRadius: 10,
                          )
                        ]
                      : [],
                ),
                child: Text(
                  char,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  late ThemeData theme;

  @override
  Widget build(BuildContext context) {
    theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Back
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Fake Hero / Logo to match Amigo screenshot
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131B2E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/brand/meledata-logo.png',
                            width: 44,
                            height: 44,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Main Title
                    Text(
                      'MELE DATA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Step Content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutQuint,
                      switchOutCurve: Curves.easeInQuint,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _step == 0 ? _buildOtpStep(isDark) : _buildPasswordStep(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpStep(bool isDark) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verify it's you
        Text(
          'Verify it\'s you',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code we sent to ${widget.identifier}.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        
        _buildOtpBoxes(isDark),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Verify',
          onPressed: _otpCtrl.text.length == 6 ? _handleVerifyOTP : null,
          loading: _loading,
          icon: Icons.check_rounded,
          isPremium: true,
        ),
        
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _handleResend,
              child: Text(
                _countdown > 0 ? 'Resend code in $_formattedTime' : 'Resend code',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _countdown > 0 ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                'Back to login',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordStep(bool isDark) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // New Password
        Text(
          'New password',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a new password for your account.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        // Pass 1
        _buildPasswordField(
          controller: _passCtrl,
          hint: 'New password',
          obscure: _obscure1,
          onToggle: () => setState(() => _obscure1 = !_obscure1),
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        // Pass 2
        _buildPasswordField(
          controller: _confirmPassCtrl,
          hint: 'Confirm new password',
          obscure: _obscure2,
          onToggle: () => setState(() => _obscure2 = !_obscure2),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Text(
          'Use at least 6 characters.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Update password',
          onPressed: _passCtrl.text.isNotEmpty && _confirmPassCtrl.text.isNotEmpty
              ? _handleUpdatePassword
              : null,
          loading: _loading,
          icon: Icons.check_rounded,
          isPremium: true,
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.lock_rounded,
            color: Color(0xFF2563EB),
            size: 18,
          ),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: const Color(0xFF64748B),
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
