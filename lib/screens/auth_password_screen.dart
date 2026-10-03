import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:google_fonts/google_fonts.dart';
import '../services/biometric_service.dart';
import '../state/session.dart';
import '../widgets/auth_liquid_glass.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';
import '../widgets/state_select_sheet.dart';
import 'forgot_password_screen.dart';
import 'shell_screen.dart';
import 'welcome_screen.dart';

class AuthPasswordScreen extends StatefulWidget {
  const AuthPasswordScreen({
    super.key,
    required this.identifier,
    this.autoPromptBiometrics = true,
  });

  static const String route = '/auth-password';

  final String identifier;
  final bool autoPromptBiometrics;

  @override
  State<AuthPasswordScreen> createState() => _AuthPasswordScreenState();
}

class _AuthPasswordScreenState extends State<AuthPasswordScreen> {
  final TextEditingController _passwordCtrl = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  bool _obscurePassword = true;
  bool _loading = false;
  bool _biometricChecking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.autoPromptBiometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndTriggerBiometrics();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAndTriggerBiometrics() async {
    final enabled = await BiometricService.isAppLockEnabled;
    if (!enabled) {
      if (mounted) _passwordFocusNode.requestFocus();
      return;
    }

    final availability = await BiometricService.getAvailability();
    if (!availability.ready) {
      if (mounted) _passwordFocusNode.requestFocus();
      return;
    }

    setState(() => _biometricChecking = true);

    try {
      final success = await BiometricService.authenticate(
        reason: 'Sign in to MELE DATA',
      );

      if (!mounted) return;

      if (success) {
        final session = context.read<SessionController>();
        final ok = await session.loginWithBiometrics();
        if (!mounted) return;

        if (ok) {
          HapticFeedback.mediumImpact();
          await _onLoginSuccess();
          return;
        }
      }
    } catch (_) {
      // Biometric failure falls back to password field cleanly
    } finally {
      if (mounted) {
        setState(() => _biometricChecking = false);
        _passwordFocusNode.requestFocus();
      }
    }
  }

  Future<void> _handleLogin() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _errorMessage = 'Please enter your password');
      _shakeKey.currentState?.shake();
      return;
    }

    if (_loading) return;

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final session = context.read<SessionController>();
    final ok = await session.login(widget.identifier, password);

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      await _offerBiometricsIfAvailable();
      if (!mounted) return;
      await _onLoginSuccess();
      return;
    }

    // Login failed
    HapticFeedback.heavyImpact();
    String err = session.error ?? 'Invalid credentials. Please try again.';
    final lower = err.toLowerCase();
    if (lower.contains('locked') || lower.contains('too many')) {
      err = 'Account temporarily locked due to too many attempts. Please try again later or reset your password.';
    } else if (lower.contains('inactive')) {
      err = 'Account is inactive. Please contact support.';
    }

    setState(() {
      _loading = false;
      _errorMessage = err;
    });
    _shakeKey.currentState?.shake();
  }

  Future<void> _offerBiometricsIfAvailable() async {
    final enabled = await BiometricService.isAppLockEnabled;
    if (enabled) return;

    final availability = await BiometricService.getAvailability();
    if (!availability.supported || !availability.hasEnrolled) return;

    // Prompt user to enable biometrics
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: Color(0xFF2457F5), size: 28),
              SizedBox(width: 10),
              Text(
                'Enable Biometrics?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: const Text(
            'Would you like to use Face ID or Fingerprint for faster sign in next time?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Not now', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                await BiometricService.setAppLockEnabled(true);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2457F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onLoginSuccess() async {
    final session = context.read<SessionController>();

    // Rule 13: Check if state is null
    final user = session.user;
    final state = user?['state'];

    if (state == null || state.toString().trim().isEmpty) {
      if (!mounted) return;
      StateSelectBottomSheet.show(context, onCompleted: () {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(ShellScreen.route, (_) => false);
      });
      return;
    }

    // Proceed to Dashboard
    Navigator.of(context).pushNamedAndRemoveUntil(ShellScreen.route, (_) => false);
  }

  void _handleChangePhone() {
    HapticFeedback.lightImpact();
    // Return to Step 1 keeping phone prefilled, clearing password
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(initialPhone: widget.identifier),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ConcentricCirclesBg(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Back Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const SizedBox(height: 12),

                    // Header title
                    Text(
                      'Welcome back',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface,
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your password to sign in.',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Phone Pill with Change button
                    PhonePill(
                      phone: widget.identifier,
                      onChange: _handleChangePhone,
                    ),

                    const SizedBox(height: 36),

                    // Password Input Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label: Electric Blue uppercase bold
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                              'PASSWORD',
                              style: GoogleFonts.plusJakartaSans(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),

                          // Password Field
                          ShakeWidget(
                            key: _shakeKey,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _passwordFocusNode.hasFocus
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x1F2563EB),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: TextField(
                                controller: _passwordCtrl,
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleLogin(),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                                style: GoogleFonts.plusJakartaSans(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: const Color(0xFF2563EB),
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.35 : 0.4),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: _passwordFocusNode.hasFocus
                                        ? const Color(0xFF2563EB)
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                      size: 20,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _errorMessage != null
                                          ? theme.colorScheme.error
                                          : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _errorMessage != null ? theme.colorScheme.error : const Color(0xFF2563EB),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Error message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 15,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: theme.colorScheme.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Forgot password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      identifier: widget.identifier,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.plusJakartaSans(
                                  color: theme.colorScheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Login Button
                          _LoginButton(
                            loading: _loading || _biometricChecking,
                            onPressed: _handleLogin,
                          ),
                        ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.loading,
    required this.onPressed,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) {
        HapticFeedback.heavyImpact();
        setState(() => _pressed = true);
      },
      onTapUp: widget.loading ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.loading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF97316), // Premium Orange
                Color(0xFF3B82F6), // Premium Blue
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
