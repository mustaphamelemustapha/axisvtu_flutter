import 'package:flutter/material.dart';

import '../widgets/auth_backdrop.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/glass_card.dart';
import 'auth_password_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  static const String route = '/welcome';

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _idCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    final identifier = _idCtrl.text.trim();
    if (identifier.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthPasswordScreen(identifier: identifier),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.66);

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AuthBackdrop(
          overlay: const Positioned(
            top: 16,
            right: 16,
            child: ThemeToggleButton(),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to buy data, top up airtime, pay bills, and manage your wallet in one place.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _idCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Email address or phone number',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Secure wallet access, fast login, and instant purchases.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
