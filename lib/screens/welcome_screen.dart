import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/auth_route.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'shell_screen.dart';
import '../services/biometric_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.initialIdentifier});
  static const String route = '/welcome';

  final String? initialIdentifier;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _localError;
  bool _focusPasswordPending = false;
  bool _biometricAvailable = false;
  bool _biometricLoading = false;

  @override
  void initState() {
    super.initState();
    final initialIdentifier = widget.initialIdentifier;
    if (initialIdentifier != null && initialIdentifier.isNotEmpty) {
      _identifierCtrl.text = initialIdentifier;
      _focusPasswordPending = true;
    } else {
      _restoreSavedIdentifier();
    }
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(SessionController.lastIdentifierKey);
    if (!mounted || saved == null || saved.trim().isEmpty) return;
    setState(() {
      if (_identifierCtrl.text.trim().isEmpty) {
        _identifierCtrl.text = saved.trim();
        _focusPasswordPending = true;
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final enabled = await BiometricService.isAppLockEnabled;
    if (!enabled) return;
    final availability = await BiometricService.getAvailability();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = availability.ready;
    });
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _biometricLoading = true;
      _localError = null;
    });
    final success = await BiometricService.authenticate(
      reason: 'Sign in to AxisVTU',
    );
    if (!mounted) return;
    if (!success) {
      setState(() {
        _biometricLoading = false;
        _localError =
            'Biometric authentication was not completed. Try signing in with your password.';
      });
      return;
    }
    // Restore session from saved biometric token
    final session = context.read<SessionController>();
    final ok = await session.loginWithBiometrics();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    } else {
      setState(() {
        _biometricLoading = false;
        _localError =
            'Please sign in once with your password to enable biometric quick sign-in.';
      });
    }
  }

  String? _initialEmail(String identifier) {
    final trimmed = identifier.trim();
    return trimmed.contains('@') ? trimmed : null;
  }

  String? _initialPhone(String identifier) {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty || trimmed.contains('@')) return null;
    return trimmed;
  }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(
        () => _localError = 'Enter your email or phone number and password.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _localError = null;
    });

    final session = context.read<SessionController>();
    final ok = await session.login(identifier, password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
      return;
    }
    setState(() {
      _localError =
          session.error ?? 'Sign in failed. Check your details and try again.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.66);
    final authError = _localError ?? session.error;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AuthBackdrop(
          showBrandText: false,
          child: Column(
            children: [
              AuthTopBar(
                showBack: false,
                trailing: const ThemeToggleButton(size: 40),
                trailingSize: 40,
              ),
              AuthHeroBlock(
                title: 'Welcome back',
                subtitle:
                    'Access your data, airtime, and bill services in seconds.',
                logoSize: 84,
                titleSize: 28,
                tight: true,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_focusPasswordPending)
                      Builder(
                        builder: (context) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || !_focusPasswordPending) return;
                            _focusPasswordPending = false;
                            FocusScope.of(context).requestFocus(_passwordFocus);
                          });
                          return const SizedBox.shrink();
                        },
                      ),
                    _AuthInput(
                      controller: _identifierCtrl,
                      hint: 'Email address or phone number',
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _passwordCtrl,
                      focusNode: _passwordFocus,
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                      ),
                    ),
                    if (authError != null) ...[
                      const SizedBox(height: 12),
                      _AuthInfoCard(
                        message: authError,
                        isWarning: authError.contains('password') ||
                            authError.contains('details'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  AuthRoute(
                                    page: ForgotPasswordScreen(
                                      identifier: _identifierCtrl.text.trim(),
                                    ),
                                  ),
                                );
                              },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: session.isLoading || _loading
                          ? 'Signing in...'
                          : 'Continue',
                      loading: session.isLoading || _loading,
                      icon: Icons.login_rounded,
                      onPressed: (session.isLoading || _loading) ? null : _login,
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 14),
                      _BiometricSignInButton(
                        loading: _biometricLoading,
                        onPressed: (session.isLoading ||
                                _loading ||
                                _biometricLoading)
                            ? null
                            : _loginWithBiometrics,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'New to AxisVTU?',
                            style: TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              AuthRoute(
                                page: RegisterScreen(
                                  initialEmail: _initialEmail(
                                    _identifierCtrl.text,
                                  ),
                                  initialPhone: _initialPhone(
                                    _identifierCtrl.text,
                                  ),
                                ),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            child: const Text(
                              'Create account',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _TrustFooter(),
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

class _AuthInfoCard extends StatelessWidget {
  const _AuthInfoCard({required this.message, this.isWarning = false});
  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isWarning
        ? (isDark ? Colors.orangeAccent : Colors.orange.shade800)
        : (isDark ? Colors.blueAccent : Colors.blue.shade800);
    final bg = color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.info_outline_rounded : Icons.fingerprint_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: muted),
            const SizedBox(width: 6),
            Text(
              'Secure access • Fast services',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () {
            // Support logic
          },
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: muted,
          ),
          child: const Text(
            'Need help? Contact support',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AuthInput extends StatelessWidget {
  const _AuthInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF151E31) : const Color(0xFFF7FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}

class _BiometricSignInButton extends StatelessWidget {
  const _BiometricSignInButton({this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: primary.withValues(alpha: 0.25), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark
              ? primary.withValues(alpha: 0.08)
              : primary.withValues(alpha: 0.05),
          foregroundColor: primary,
        ),
        icon: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              )
            : const Icon(Icons.fingerprint_rounded, size: 22),
        label: Text(
          loading ? 'Authenticating…' : 'Sign in with Biometric',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}
