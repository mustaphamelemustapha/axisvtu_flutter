import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  static const String route = '/welcome';

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _showAuthSheet() {
    final raw = _phoneCtrl.text.trim();
    final isEmail = raw.contains('@');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Text('Continue with AxisVTU', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Choose how you want to access your account.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            _GradientButton(
              label: 'Sign in',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(initialIdentifier: raw),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(
                      initialPhone: isEmail ? null : raw,
                      initialEmail: isEmail ? raw : null,
                    ),
                  ),
                );
              },
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0B1118),
              Color(0xFF101826),
              Color(0xFF0B1118),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _Floating(
                controller: _floatController,
                offset: const Offset(0, 6),
                phase: 0.0,
                child: const Positioned(
                  top: 120,
                  left: 16,
                  child: _MiniPlanCard(
                    label: 'MTN',
                    size: '1GB',
                    price: '₦409 • Monthly',
                  ),
                ),
              ),
              _Floating(
                controller: _floatController,
                offset: const Offset(0, -6),
                phase: 1.2,
                child: const Positioned(
                  top: 90,
                  right: 18,
                  child: _MiniPlanCard(
                    label: 'MTN',
                    size: '2GB',
                    price: '₦849 • Monthly',
                  ),
                ),
              ),
              _Floating(
                controller: _floatController,
                offset: const Offset(0, 8),
                phase: 2.1,
                child: const Positioned(
                  top: 170,
                  left: 150,
                  child: _MiniPlanCard(
                    label: 'MTN',
                    size: '5GB',
                    price: '₦1,799 • Monthly',
                    highlight: true,
                  ),
                ),
              ),
              _Floating(
                controller: _floatController,
                offset: const Offset(0, 4),
                phase: 2.8,
                child: const Positioned(
                  top: 230,
                  left: 24,
                  child: _Pill(label: 'Cashback on data', color: Color(0xFF13C26C)),
                ),
              ),
              _Floating(
                controller: _floatController,
                offset: const Offset(0, -4),
                phase: 1.8,
                child: const Positioned(
                  top: 240,
                  right: 24,
                  child: _Pill(label: 'Airtime → Cash', color: Color(0xFF3B82F6)),
                ),
              ),
              _Floating(
                controller: _floatController,
                offset: const Offset(0, 5),
                phase: 0.8,
                child: Positioned(
                  top: 210,
                  right: 14,
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.nightlight_round, color: Colors.white),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 260),
                  child: Column(
                    children: [
                      Container(
                        height: 92,
                        width: 92,
                        decoration: BoxDecoration(
                          gradient: AxisPalette.warmGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/brand/axisvtu-icon.svg',
                            width: 44,
                            height: 44,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'AxisVTU',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 520),
                      const Text(
                        'Enter email or phone',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Continue to sign in or create an account automatically.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                          hintText: 'you@email.com or 08012345678',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: const Color(0xFF111827),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _GradientButton(label: 'Continue', onTap: _showAuthSheet),
                      const SizedBox(height: 10),
                      Text(
                        'By continuing, you agree to use AxisVTU responsibly.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Floating extends StatelessWidget {
  const _Floating({
    required this.controller,
    required this.child,
    required this.offset,
    required this.phase,
  });

  final AnimationController controller;
  final Widget child;
  final Offset offset;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = sin((controller.value * 2 * pi) + phase);
        return Transform.translate(
          offset: Offset(offset.dx * value, offset.dy * value),
          child: child,
        );
      },
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

class _MiniPlanCard extends StatelessWidget {
  const _MiniPlanCard({
    required this.label,
    required this.size,
    required this.price,
    this.highlight = false,
  });

  final String label;
  final String size;
  final String price;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? const Color(0xFFFFB020) : const Color(0xFF2F3947),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Text(size, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(price, style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _GhostChip extends StatelessWidget {
  const _GhostChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
    );
  }
}
