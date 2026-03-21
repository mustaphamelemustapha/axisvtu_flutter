import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/theme_toggle_button.dart';
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.7);
    final hint = onSurface.withValues(alpha: 0.5);
    final fill = Theme.of(context).colorScheme.surface;
    return Scaffold(
      body: AuthBackdrop(
        overlay: const Positioned(
          top: 16,
          right: 16,
          child: ThemeToggleButton(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 520),
            Text(
              'Enter email or phone',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Continue to sign in or create an account automatically.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: muted),
                hintText: 'you@email.com or 08012345678',
                hintStyle: TextStyle(color: hint),
                filled: true,
                fillColor: fill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _GradientButton(label: 'Continue', onTap: _continue),
            const SizedBox(height: 10),
            Text(
              'By continuing, you agree to use AxisVTU responsibly.',
              style: TextStyle(color: onSurface.withValues(alpha: 0.5), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: const [
                _GhostChip(label: 'Trusted by 100,000+ users'),
                _GhostChip(label: 'Instant delivery'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AxisPalette.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostChip extends StatelessWidget {
  const _GhostChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
    );
  }
}
