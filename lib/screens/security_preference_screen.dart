import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import 'shell_screen.dart';

class SlateColors {
  static const Color slate = Color(0xFF64748B);
  static const Color shade50 = Color(0xFFF8FAFC);
  static const Color shade100 = Color(0xFFF1F5F9);
  static const Color shade200 = Color(0xFFE2E8F0);
  static const Color shade300 = Color(0xFFCBD5E1);
  static const Color shade400 = Color(0xFF94A3B8);
  static const Color shade500 = Color(0xFF64748B);
  static const Color shade600 = Color(0xFF475569);
  static const Color shade700 = Color(0xFF334155);
  static const Color shade900 = Color(0xFF0F172A);
}

class SecurityPreferenceScreen extends StatefulWidget {
  const SecurityPreferenceScreen({super.key});
  static const String route = '/security-preference';

  @override
  State<SecurityPreferenceScreen> createState() => _SecurityPreferenceScreenState();
}

class _SecurityPreferenceScreenState extends State<SecurityPreferenceScreen> {
  String _selected = 'smart'; // Default to 'smart' (Smart Security) as recommended

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070B12) : const Color(0xFFF8FAFC),
      body: AuthBackdrop(
        showBrandText: false,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 20),
              
              // Top Pagination Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Dot(active: false),
                  const SizedBox(width: 8),
                  _Dot(active: true, color: const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _Dot(active: false),
                ],
              ),
              const SizedBox(height: 48),
              
              // Beautiful Glowing Lock Icon Badge
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF1E293B).withValues(alpha: 0.8),
                            const Color(0xFF0F172A).withValues(alpha: 0.9),
                          ]
                        : [
                            Colors.white,
                            Colors.blue.shade50,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.blue.shade100,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 32,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              
              // Titles
              Text(
                'Secure Your Experience',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.6,
                  color: isDark ? Colors.white : SlateColors.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Choose how you\'d like to protect your MELE DATA account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? SlateColors.shade400 : SlateColors.shade600,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Security Preference Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    // Maximum Security Card
                    _SecurityOption(
                      title: 'Maximum Security',
                      subtitle: 'Require PIN every time you open the app',
                      iconWidget: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : SlateColors.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: _selected == 'max' ? const Color(0xFF3B82F6) : SlateColors.slate,
                          size: 24,
                        ),
                      ),
                      selected: _selected == 'max',
                      onTap: () => setState(() => _selected = 'max'),
                    ),
                    const SizedBox(height: 16),
                    
                    // Smart Security Card
                    _SecurityOption(
                      title: 'Smart Security',
                      subtitle: 'PIN required only for transactions',
                      recommended: true,
                      iconWidget: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _selected == 'smart'
                                ? [
                                    const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                    const Color(0xFFF97316).withValues(alpha: 0.2),
                                  ]
                                : [
                                    Colors.grey.withValues(alpha: 0.1),
                                    Colors.grey.withValues(alpha: 0.1),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: _selected == 'smart' ? const Color(0xFF3B82F6) : SlateColors.slate,
                          size: 24,
                        ),
                      ),
                      selected: _selected == 'smart',
                      onTap: () => setState(() => _selected = 'smart'),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Gradient Continue Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3B82F6), // Royal Blue
                        Color(0xFFF97316), // Sunset Coral
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      final session = context.read<SessionController>();
                      await session.setSecurityPreference(_selected);
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed(ShellScreen.route);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Caption Bottom Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: isDark ? SlateColors.shade500 : SlateColors.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'You can change this anytime in Settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? SlateColors.shade500 : SlateColors.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
         ),
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
      width: active ? 22 : 8,
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
    required this.iconWidget,
    this.recommended = false,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget iconWidget;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF3B82F6);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? primary : (isDark ? Colors.white.withValues(alpha: 0.05) : SlateColors.shade200),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : SlateColors.shade900,
                        ),
                      ),
                      if (recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? SlateColors.shade400 : SlateColors.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3B82F6),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? SlateColors.shade700 : SlateColors.shade300,
                    width: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
