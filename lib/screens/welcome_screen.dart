import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/session.dart';
import '../widgets/auth_route.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/auth_segmented_control.dart';
import '../widgets/theme_toggle_button.dart';
import '../services/biometric_service.dart';
import 'forgot_password_screen.dart';
import 'shell_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.initialIdentifier, this.initialIsLogin = true});
  static const String route = '/welcome';

  final String? initialIdentifier;
  final bool initialIsLogin;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late bool _isLogin;
  
  // Login Controllers
  final _loginIdCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  
  // Register Controllers
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regReferralCtrl = TextEditingController();
  
  bool _obscureLogin = true;
  bool _obscureReg = true;
  bool _showReferralField = false;
  bool _loading = false;
  String? _toastMessage;
  Timer? _toastTimer;
  bool _biometricAvailable = false;
  bool _biometricLoading = false;

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    if (widget.initialIdentifier != null) {
      _loginIdCtrl.text = widget.initialIdentifier!;
      _regEmailCtrl.text = widget.initialIdentifier!;
    } else {
      _restoreSavedIdentifier();
    }
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    _regReferralCtrl.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSavedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(SessionController.lastIdentifierKey);
    if (!mounted || saved == null || saved.trim().isEmpty) return;
    setState(() {
      if (_loginIdCtrl.text.trim().isEmpty) _loginIdCtrl.text = saved.trim();
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final enabled = await BiometricService.isAppLockEnabled;
    if (!enabled) return;
    final availability = await BiometricService.getAvailability();
    if (!mounted) return;
    setState(() => _biometricAvailable = availability.ready);
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _biometricLoading = true;
    });
    final success = await BiometricService.authenticate(reason: 'Sign in to MELE DATA');
    if (!mounted) return;
    if (!success) {
      setState(() => _biometricLoading = false);
      _showToast('Biometric authentication failed. Try your password.');
      return;
    }
    final session = context.read<SessionController>();
    final ok = await session.loginWithBiometrics();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    } else {
      setState(() => _biometricLoading = false);
      _showToast(session.error ?? 'Authentication failed.');
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _toastMessage = null;
    });

    final session = context.read<SessionController>();
    bool ok = false;

    if (_isLogin) {
      final identifier = _loginIdCtrl.text.trim();
      final password = _loginPassCtrl.text;
      if (identifier.isEmpty || password.isEmpty) {
        setState(() => _loading = false);
        _showToast('Enter your email or phone number and password.');
        return;
      }
      ok = await session.login(identifier, password);
    } else {
      final name = _regNameCtrl.text.trim();
      final email = _regEmailCtrl.text.trim();
      final phone = _regPhoneCtrl.text.trim();
      final password = _regPassCtrl.text;
      final referralCode = _regReferralCtrl.text.trim();

      if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
        setState(() => _loading = false);
        _showToast('All fields are required.');
        return;
      }
      if (password.length < 6) {
        setState(() => _loading = false);
        _showToast('Password must be at least 6 characters.');
        return;
      }
      ok = await session.register(
        name, 
        email, 
        phone, 
        password,
        referralCode: referralCode.isEmpty ? null : referralCode,
      );
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
      return;
    }
    setState(() => _loading = false);
    _showToast(session.error ?? 'Request failed. Try again.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final session = context.watch<SessionController>();
    final isLoading = session.isLoading || _loading;

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ConcentricCirclesBg(
              child: Column(
                children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [ThemeToggleButton(size: 34)],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset('assets/brand/meledata-icon.png'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Title
                    Text(
                      _isLogin ? 'Welcome Back' : 'Create Account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLogin ? 'Sign in to continue' : 'Join us to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Segmented Control
                    AuthSegmentedControl(
                      isLogin: _isLogin,
                      onChanged: (val) {
                        setState(() {
                          _isLogin = val;
                          _toastMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Card with inputs
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // Directly rely on theme's card color so the new bright dark mode applies
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLogin) ...[
                              _Label('Email Address or Phone'),
                              _Input(
                                controller: _loginIdCtrl,
                                hint: 'example@mail.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              _Label('Password'),
                              _Input(
                                controller: _loginPassCtrl,
                                hint: 'Enter Password',
                                obscureText: _obscureLogin,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureLogin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      AuthRoute(
                                        page: ForgotPasswordScreen(
                                          identifier: _loginIdCtrl.text.trim(),
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.primary,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ),
                            ] else ...[
                              _Label('Full Name'),
                              _Input(
                                controller: _regNameCtrl,
                                hint: 'John Doe',
                                keyboardType: TextInputType.name,
                              ),
                              const SizedBox(height: 12),
                              _Label('Email Address'),
                              _Input(
                                controller: _regEmailCtrl,
                                hint: 'example@mail.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              _Label('Phone Number'),
                              _Input(
                                controller: _regPhoneCtrl,
                                hint: '080...',
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              _Label('Password'),
                              _Input(
                                controller: _regPassCtrl,
                                hint: 'Enter Password',
                                obscureText: _obscureReg,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureReg ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  onPressed: () => setState(() => _obscureReg = !_obscureReg),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Premium Referral Dropdown
                              if (!_showReferralField)
                                Center(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _showReferralField = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.local_offer_rounded, size: 14, color: theme.colorScheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Have a referral code?',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                _Label('Referral Code (Optional)'),
                                _Input(
                                  controller: _regReferralCtrl,
                                  hint: 'e.g. AXIS-1234',
                                  keyboardType: TextInputType.text,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Floating Bottom Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Side: Biometrics (if available and login)
                        if (_isLogin && _biometricAvailable)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: IconButton(
                              icon: _biometricLoading 
                                  ? const SizedBox(
                                      width: 20, height: 20, 
                                      child: CircularProgressIndicator(strokeWidth: 2)
                                    )
                                  : Icon(Icons.fingerprint_rounded, color: theme.colorScheme.primary),
                              onPressed: _biometricLoading ? null : _loginWithBiometrics,
                            ),
                          )
                        else
                          const SizedBox(width: 52), // Placeholder to keep spacing

                        // Right Side: Submit Button
                        GestureDetector(
                          onTap: isLoading ? null : _submit,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: isLoading ? theme.colorScheme.primary.withValues(alpha: 0.5) : theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                if (!isLoading)
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLoading)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Text(
                                    _isLogin ? 'Sign In' : 'Sign Up',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                if (!isLoading) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
          
          // Absolute Top Auto-Dismiss Error Toast
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            top: _toastMessage != null ? MediaQuery.of(context).padding.top + 16 : -150,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3F1921) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: isDark ? 0.4 : 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.error.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _toastMessage ?? '',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF991B1B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        // Rely on theme for input background to automatically match dark mode changes
        fillColor: theme.inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
