import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/axis_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import 'register_screen.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static const String route = '/onboarding';
  static const String seenKey = 'axisvtu_onboarding_seen_v1';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markAndGo(Widget page) async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _next() async {
    if (_page == 0) {
      await _pageController.animateToPage(
        1,
        duration: AxisDurations.normal,
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _markAndGo(const WelcomeScreen());
  }

  Widget _dot(bool active, ThemeData theme) {
    return AnimatedContainer(
      duration: AxisDurations.normal,
      curve: Curves.easeOut,
      width: active ? 18 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary
            : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A3A52)
                : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _slide(BuildContext context, {
    required String title,
    required String body,
    required IconData icon,
    required String badge,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111A2B) : Colors.white;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.68);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _miniPill(context, Icons.account_balance_wallet_outlined, 'Wallet'),
                  const Spacer(),
                  _miniPill(context, Icons.receipt_long_rounded, badge),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF17233B) : const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: theme.colorScheme.primary, size: 30),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ) ??
                          const TextStyle(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                            height: 1.45,
                          ) ??
                          const TextStyle(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniPill(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF090E17) : const Color(0xFFF5F8FD);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.68);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF101A2B) : Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.14),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.asset('assets/brand/meledata-icon.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MELE DATA',
                        style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.35,
                            ) ??
                            const TextStyle(),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const ThemeToggleButton(size: 42),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _page = index),
                  children: [
                    _slide(
                      context,
                      title: 'Buy Data. Pay Bills. Instantly.',
                      body: 'Fast, reliable data, airtime, and bill payments - all in one place.',
                      icon: Icons.flash_on_rounded,
                      badge: 'Payments',
                    ),
                    _slide(
                      context,
                      title: 'Simple. Secure. Always Clear.',
                      body: 'Track every transaction, fund your wallet easily, and stay in control.',
                      icon: Icons.verified_user_rounded,
                      badge: 'Trust',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(_page == 0, theme),
                  const SizedBox(width: 8),
                  _dot(_page == 1, theme),
                ],
              ),
              const SizedBox(height: 16),
              if (_page == 0) ...[
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _next,
                ),
              ] else ...[
                PrimaryButton(
                  label: 'Create account',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () => _markAndGo(const RegisterScreen()),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _markAndGo(const WelcomeScreen()),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: const Text('Sign in'),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _markAndGo(const WelcomeScreen()),
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                ),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
