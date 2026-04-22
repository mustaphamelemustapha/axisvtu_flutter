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
      setState(() => _localError = 'Enter your email or phone number and password.');
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
      _localError = session.error ?? 'Login failed. Check your details and try again.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.66);

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
                subtitle: 'Sign in to buy data, top up airtime, pay bills, and manage your wallet in one place.',
                logoSize: 80,
                titleSize: 27,
                tight: true,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    if (_localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _localError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (session.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        session.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: session.isLoading || _loading ? 'Signing in...' : 'Continue',
                      loading: session.isLoading || _loading,
                      icon: Icons.login_rounded,
                      onPressed: (session.isLoading || _loading) ? null : _login,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'New to AxisVTU?',
                            style: TextStyle(color: muted),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              AuthRoute(
                                page: RegisterScreen(
                                  initialEmail: _initialEmail(_identifierCtrl.text),
                                  initialPhone: _initialPhone(_identifierCtrl.text),
                                ),
                              ),
                            ),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
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
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}
