import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

class AuthBackdrop extends StatefulWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop> with SingleTickerProviderStateMixin {
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
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: widget.child,
              ),
            ),
          ],
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
