import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_route.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialIdentifier});
  static const String route = '/login';

  final String? initialIdentifier;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentifier != null &&
        widget.initialIdentifier!.isNotEmpty) {
      _emailCtrl.text = widget.initialIdentifier!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final session = context.read<SessionController>();
    final ok = await session.login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final canPop = Navigator.of(context).canPop();
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
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canPop)
                          _HeaderIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          )
                        else
                          const SizedBox(width: 46, height: 46),
                        const ThemeToggleButton(size: 46),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
                    child: Column(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            gradient: AxisPalette.warmGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 28,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/brand/axisvtu-icon.png',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to continue your AxisVTU experience.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.72)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
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
                          _SectionLabel(text: 'Account'),
                          const SizedBox(height: 8),
                          _AuthInput(
                            controller: _emailCtrl,
                            hint: 'Email address',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _AuthInput(
                            controller: _passwordCtrl,
                            hint: 'Password',
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
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _emailCtrl.text.trim().isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        AuthRoute(
                                          page: ForgotPasswordScreen(
                                            identifier: _emailCtrl.text.trim(),
                                          ),
                                        ),
                                      );
                                    },
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          if (session.error != null) ...[
                            Text(
                              session.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 2),
                          PrimaryButton(
                            label: session.isLoading
                                ? 'Signing in...'
                                : 'Login',
                            loading: session.isLoading,
                            icon: Icons.login_rounded,
                            onPressed: session.isLoading ? null : _submit,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'No account yet?',
                                  style: TextStyle(color: muted),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    AuthRoute(page: const RegisterScreen()),
                                  ),
                                  child: const Text('Create one'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ChipTag(label: 'Fast login'),
                              _ChipTag(label: 'Secure sessions'),
                              _ChipTag(label: 'Quick recharge'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
