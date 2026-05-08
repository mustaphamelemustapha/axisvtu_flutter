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
                      hint: 'Email or phone number',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _AuthInput(
                      controller: _passwordCtrl,
                      focusNode: _passwordFocus,
                      hint: 'Password',
                      icon: Icons.lock_person_outlined,
                      obscureText: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
                          ? 'Authenticating...'
                          : 'Sign In Securely',
                      loading: session.isLoading || _loading,
                      icon: Icons.lock_outline_rounded,
                      onPressed: (session.isLoading || _loading) ? null : _login,
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 18),
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'SECURE ACCESS • INSTANT DELIVERY • 24/7 TRUST',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            launchUrl(Uri.parse('mailto:mmtechglobe@gmail.com?subject=AxisVTU%20Support%20Request'));
          },
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: muted.withValues(alpha: 0.8),
          ),
          child: const Text(
            'Need any help? Contact Support',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AuthInput extends StatefulWidget {
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
  State<_AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<_AuthInput> {
  late FocusNode _effectiveFocus;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocus = widget.focusNode ?? FocusNode();
    _effectiveFocus.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _isFocused = _effectiveFocus.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _effectiveFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (_isFocused)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _effectiveFocus,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              widget.icon,
              size: 20,
              color: _isFocused ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: widget.suffix,
          filled: true,
          fillColor: isDark ? const Color(0xFF111827) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.06),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        ),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.08 : 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primary,
                          ),
                        )
                      : Icon(Icons.fingerprint_rounded, size: 22, color: primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Secure Access',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loading ? 'Authenticating...' : 'Use biometric access',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
