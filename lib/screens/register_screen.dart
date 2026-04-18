import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/auth_route.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';
import 'shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.initialPhone, this.initialEmail});
  static const String route = '/register';

  final String? initialPhone;
  final String? initialEmail;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
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
    final ok = await session.register(name, email, phone, password);
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
    final sheetColor = isDark ? const Color(0xFF0F1626) : Colors.white;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.66);

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF080D18), Color(0xFF111A31)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFE8F0FF), Color(0xFFF8FAFF)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                ),
              ),
            ),
            Column(
                children: [
                  AuthTopBar(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  AuthHeroBlock(
                    title: 'Create Axis Account',
                    subtitle: 'Open your VTU wallet and start transacting instantly.',
                    logoSize: 82,
                    titleSize: 28,
                    tight: true,
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      decoration: BoxDecoration(
                        color: sheetColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(34),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.36 : 0.12,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: ListView(
                        children: [
                          _SectionLabel(text: 'Personal details'),
                          const SizedBox(height: 8),
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
                            controller: _passwordCtrl,
                            hint: 'Create password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                            label: session.isLoading
                                ? 'Creating...'
                                : 'Create account',
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
                                  onPressed: () =>
                                      Navigator.of(context).pushReplacement(
                                        AuthRoute(
                                          page: LoginScreen(
                                            initialIdentifier:
                                                _emailCtrl.text.trim().isEmpty
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
                          const SizedBox(height: 4),
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ChipTag(label: 'Dedicated account'),
                              _ChipTag(label: 'Auto receipts'),
                              _ChipTag(label: 'Simple dashboard'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF151F34)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.24),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
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

class _ChipTag extends StatelessWidget {
  const _ChipTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
