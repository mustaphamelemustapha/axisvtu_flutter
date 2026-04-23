import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/auth_route.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import 'shell_screen.dart';
import 'welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialPhone,
    this.initialEmail,
    this.initialReferralCode,
  });
  static const String route = '/register';

  final String? initialPhone;
  final String? initialEmail;
  final String? initialReferralCode;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phoneCtrl.text = widget.initialPhone!;
    }
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailCtrl.text = widget.initialEmail!;
    }
    if (widget.initialReferralCode != null && widget.initialReferralCode!.isNotEmpty) {
      _referralCtrl.text = widget.initialReferralCode!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _referralCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final referralCode = _referralCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(
        () => _localError = 'Full name, email, and password are required.',
      );
      return;
    }
    if (password.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }
    if (confirmPassword.isEmpty) {
      setState(() => _localError = 'Please confirm your password.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }

    setState(() => _localError = null);
    final session = context.read<SessionController>();
    final ok = await session.register(
      name,
      email,
      phone,
      password,
      referralCode: referralCode.isEmpty ? null : referralCode,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF070B12) : const Color(0xFFF2F6FF);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.66);

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AuthBackdrop(
          showBrandText: false,
          child: Column(
            children: [
              AuthTopBar(
                onBack: () => Navigator.of(context).pop(),
                trailing: const ThemeToggleButton(size: 40),
                trailingSize: 40,
              ),
              AuthHeroBlock(
                title: 'Create your account',
                subtitle: 'Open your VTU wallet and start transacting instantly.',
                logoSize: 80,
                titleSize: 27,
                tight: true,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  children: [
                    _AuthInput(
                      controller: _nameCtrl,
                      hint: 'Full name',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _emailCtrl,
                      hint: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _phoneCtrl,
                      hint: 'Phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _referralCtrl,
                      hint: 'Referral code (optional)',
                      icon: Icons.local_offer_outlined,
                    ),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _passwordCtrl,
                      hint: 'Create password',
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
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _confirmPasswordCtrl,
                      hint: 'Confirm password',
                      icon: Icons.lock_reset_rounded,
                      obscureText: _obscureConfirm,
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off : Icons.visibility,
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
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: session.isLoading ? 'Creating...' : 'Create account',
                      loading: session.isLoading,
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: session.isLoading ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already registered?',
                            style: TextStyle(color: muted),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              AuthRoute(
                                page: WelcomeScreen(
                                  initialIdentifier: _emailCtrl.text.trim().isEmpty
                                      ? null
                                      : _emailCtrl.text.trim(),
                                ),
                              ),
                            ),
                            child: const Text('Sign in'),
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
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
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
