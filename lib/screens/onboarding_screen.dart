import 'package:flutter/material.dart';
import '../utils/fast_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/concentric_circles_bg.dart';
import '../widgets/primary_button.dart';
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

  Future<void> _markAndGo(bool isLogin) async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      FastRoute(page: WelcomeScreen(initialIsLogin: isLogin)),
    );
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _pageController.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _markAndGo(false);
  }

  Widget _dot(int index, ThemeData theme) {
    final active = _page == index;
    final primary = theme.colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? primary : primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        boxShadow: active
            ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final slideData = [
      {
        'title': 'Instant Top-ups',
        'body': 'Buy data, airtime, and pay bills in seconds. Experience lightning-fast transactions anytime.',
        'icon': Icons.bolt_rounded,
      },
      {
        'title': 'Secure & Reliable',
        'body': 'Your funds are protected with bank-grade security. Track every transaction effortlessly.',
        'icon': Icons.shield_rounded,
      },
      {
        'title': 'Epic Rewards',
        'body': 'Earn cashback and referral bonuses on your transactions. The more you use, the more you save.',
        'icon': Icons.stars_rounded,
      },
    ];

    return Scaffold(
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset('assets/brand/meledata-icon.png'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'MELE DATA',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _markAndGo(true),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ],
                ),
              ),
              
              // Icons Carousel (Glassmorphic)
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _page = idx),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Center(
                      child: AnimatedScale(
                        scale: _page == index ? 1.0 : 0.85,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _page == index ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              slideData[index]['icon'] as IconData,
                              size: 90,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Bottom Floating Card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Text Content (Animated)
                      SizedBox(
                        height: 110,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            key: ValueKey<int>(_page),
                            children: [
                              Text(
                                slideData[_page]['title'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slideData[_page]['body'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) => _dot(index, theme)),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Next / Get Started Button
                      PrimaryButton(
                        label: _page == 2 ? 'Get Started' : 'Next',
                        icon: _page == 2 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                        isPremium: true,
                        onPressed: _next,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Sign In Link
                      AnimatedOpacity(
                        opacity: _page == 2 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _page == 2 ? _markAndGo(true) : null,
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
