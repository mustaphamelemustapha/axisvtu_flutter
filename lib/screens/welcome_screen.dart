import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/session.dart';
import '../widgets/auth_route.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/auth_segmented_control.dart';
import '../widgets/primary_button.dart';
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
  final _regConfirmPassCtrl = TextEditingController();
  
  bool _obscureLogin = true;
  bool _obscureReg = true;
  bool _obscureRegConfirm = true;
  bool _loading = false;
  String? _localError;
  bool _biometricAvailable = false;
  bool _biometricLoading = false;

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
    _regConfirmPassCtrl.dispose();
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
      _localError = null;
    });
    final success = await BiometricService.authenticate(reason: 'Sign in to MELE DATA');
    if (!mounted) return;
    if (!success) {
      setState(() {
        _biometricLoading = false;
        _localError = 'Biometric authentication failed. Try your password.';
      });
      return;
    }
    final session = context.read<SessionController>();
    final ok = await session.loginWithBiometrics();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    } else {
      setState(() {
        _biometricLoading = false;
        _localError = session.error ?? 'Authentication failed.';
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _localError = null;
    });

    final session = context.read<SessionController>();
    bool ok = false;

    if (_isLogin) {
      final identifier = _loginIdCtrl.text.trim();
      final password = _loginPassCtrl.text;
      if (identifier.isEmpty || password.isEmpty) {
        setState(() {
          _localError = 'Enter your email or phone number and password.';
          _loading = false;
        });
        return;
      }
      ok = await session.login(identifier, password);
    } else {
      final name = _regNameCtrl.text.trim();
      final email = _regEmailCtrl.text.trim();
      final phone = _regPhoneCtrl.text.trim();
      final password = _regPassCtrl.text;
      final confirmPassword = _regConfirmPassCtrl.text;

      if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
        setState(() {
          _localError = 'All fields are required.';
          _loading = false;
        });
        return;
      }
      if (password.length < 6) {
        setState(() {
          _localError = 'Password must be at least 6 characters.';
          _loading = false;
        });
        return;
      }
      if (password != confirmPassword) {
        setState(() {
          _localError = 'Passwords do not match.';
          _loading = false;
        });
        return;
      }
      ok = await session.register(name, email, phone, password);
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
      return;
    }
    setState(() {
      _localError = session.error ?? 'Request failed. Try again.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final session = context.watch<SessionController>();
    final authError = _localError ?? session.error;
    final isLoading = session.isLoading || _loading;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ConcentricCirclesBg(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [ThemeToggleButton(size: 40)],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Image.asset('assets/brand/meledata-icon.png'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      _isLogin ? 'Welcome Back' : 'Create Account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin ? 'Sign in to continue' : 'Join us to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Segmented Control
                    AuthSegmentedControl(
                      isLogin: _isLogin,
                      onChanged: (val) {
                        setState(() {
                          _isLogin = val;
                          _localError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Card with inputs
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF151C2C) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
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
                              const SizedBox(height: 16),
                              _Label('Password'),
                              _Input(
                                controller: _loginPassCtrl,
                                hint: 'Enter Password',
                                obscureText: _obscureLogin,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureLogin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                    style: TextStyle(fontWeight: FontWeight.w700),
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
                              const SizedBox(height: 16),
                              _Label('Email Address'),
                              _Input(
                                controller: _regEmailCtrl,
                                hint: 'example@mail.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _Label('Phone Number'),
                              _Input(
                                controller: _regPhoneCtrl,
                                hint: '080...',
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              _Label('Password'),
                              _Input(
                                controller: _regPassCtrl,
                                hint: 'Enter Password',
                                obscureText: _obscureReg,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureReg ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  onPressed: () => setState(() => _obscureReg = !_obscureReg),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Label('Confirm Password'),
                              _Input(
                                controller: _regConfirmPassCtrl,
                                hint: 'Re-enter Password',
                                obscureText: _obscureRegConfirm,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureRegConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  onPressed: () => setState(() => _obscureRegConfirm = !_obscureRegConfirm),
                                ),
                              ),
                            ],
                            
                            if (authError != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.error, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        authError,
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    PrimaryButton(
                      label: isLoading ? 'Please wait...' : 'Continue',
                      loading: isLoading,
                      onPressed: isLoading ? null : _submit,
                    ),

                    if (_isLogin && _biometricAvailable) ...[
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: _biometricLoading ? 'Authenticating...' : 'Sign In with Biometrics',
                        icon: Icons.fingerprint_rounded,
                        isPremium: false,
                        onPressed: _biometricLoading ? null : _loginWithBiometrics,
                      ),
                    ],

                    const SizedBox(height: 40),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
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
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        filled: true,
        fillColor: isDark ? const Color(0xFF0D131F) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
