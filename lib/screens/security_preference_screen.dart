import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/primary_button.dart';
import 'shell_screen.dart';

class SecurityPreferenceScreen extends StatefulWidget {
  const SecurityPreferenceScreen({super.key});
  static const String route = '/security-preference';

  @override
  State<SecurityPreferenceScreen> createState() => _SecurityPreferenceScreenState();
}

class _SecurityPreferenceScreenState extends State<SecurityPreferenceScreen> {
  String _selected = 'smart'; // Default to 'smart' as recommended

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AuthBackdrop(
        showBrandText: false,
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dot(active: true, color: Colors.blueAccent),
                const SizedBox(width: 8),
                _Dot(active: false),
                const SizedBox(width: 8),
                _Dot(active: false),
              ],
            ),
            const SizedBox(height: 48),
            // Floating Lock Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Secure Your Experience',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Choose how you\'d like to protect your AxisVTU account',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Security Options
            _SecurityOption(
              title: 'Maximum Security',
              subtitle: 'Require PIN every time you open the app',
              icon: Icons.shield_rounded,
              selected: _selected == 'max',
              onTap: () => setState(() => _selected = 'max'),
            ),
            const SizedBox(height: 16),
            _SecurityOption(
              title: 'Smart Security',
              subtitle: 'PIN required only for transactions',
              icon: Icons.bolt_rounded,
              recommended: true,
              selected: _selected == 'smart',
              onTap: () => setState(() => _selected = 'smart'),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Continue',
              isPremium: true,
              onPressed: () async {
                final session = context.read<SessionController>();
                await session.setSecurityPreference(_selected);
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed(ShellScreen.route);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(width: 6),
                Text(
                  'You can change this anytime in Settings',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, this.color});
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: active ? (color ?? Colors.blueAccent) : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }
}

class _SecurityOption extends StatelessWidget {
  const _SecurityOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.recommended = false,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Colors.blueAccent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primary : Colors.white.withValues(alpha: 0.05),
            width: 2,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: primary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: selected ? primary : Colors.grey, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Colors.blueAccent)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
