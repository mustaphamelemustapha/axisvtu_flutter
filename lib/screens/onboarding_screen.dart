import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/axis_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
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
      MaterialPageRoute(builder: (_) => WelcomeScreen(initialIsLogin: isLogin)),
    );
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _pageController.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _markAndGo(false); // Go to Sign up by default when finishing onboarding
  }

  Widget _dot(int index, ThemeData theme) {
    final active = _page == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Background gradient colors based on the current page
    final bgGradients = [
      [theme.colorScheme.primary.withValues(alpha: 0.8), const Color(0xFF6366F1)], // Slide 1
      [const Color(0xFFF97316), const Color(0xFFF59E0B)], // Slide 2
      [const Color(0xFF10B981), const Color(0xFF059669)], // Slide 3
    ];

    final slideData = [
      {
        'title': 'Instant Top-ups',
        'body': 'Buy data, airtime, and pay bills in seconds. Experience lightning-fast transactions anytime, anywhere.',
        'icon': Icons.bolt_rounded,
      },
      {
        'title': 'Secure & Reliable',
        'body': 'Your funds are protected with bank-grade security. Track every transaction with complete transparency.',
        'icon': Icons.shield_rounded,
      },
      {
        'title': 'Epic Rewards',
        'body': 'Earn cashback and referral bonuses on your transactions. The more you use, the more you save.',
        'icon': Icons.stars_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1A) : Colors.white,
      body: Stack(
        children: [
          // Animated Background Gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradients[_page],
              ),
            ),
          ),
          
          // Pattern Overlay
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          
          SafeArea(
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
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset('assets/brand/meledata-icon.png'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'MELE DATA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _markAndGo(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                
                // Icons Carousel
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _page = idx),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Center(
                        child: AnimatedScale(
                          scale: _page == index ? 1.0 : 0.8,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Icon(
                              slideData[index]['icon'] as IconData,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Bottom Content Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151C2C) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Text Content
                      SizedBox(
                        height: 100,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Column(
                            key: ValueKey<int>(_page),
                            children: [
                              Text(
                                slideData[_page]['title'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
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
                      const SizedBox(height: 32),
                      
                      // Button
                      PrimaryButton(
                        label: _page == 2 ? 'Get Started' : 'Next',
                        icon: _page == 2 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                        onPressed: _next,
                      ),
                      
                      const SizedBox(height: 16),
                      if (_page == 2)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _markAndGo(true),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(height: 20), // Placeholder to keep height consistent
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
