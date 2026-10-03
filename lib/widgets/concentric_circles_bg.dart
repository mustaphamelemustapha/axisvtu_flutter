import 'package:flutter/material.dart';

/// Premium ambient mesh background with deep obsidian dark-mode tones and
/// soft diffused cyan/electric-blue light orbs (blur radius: 80+).
class ConcentricCirclesBg extends StatelessWidget {
  const ConcentricCirclesBg({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColors = isDark
        ? const [
            Color(0xFF0A0D14),
            Color(0xFF121826),
          ]
        : const [
            Color(0xFFF8FAFC),
            Color(0xFFEFF6FF),
          ];

    final orb1Color = isDark
        ? const Color(0xFF2563EB).withValues(alpha: 0.16)
        : const Color(0xFF3B82F6).withValues(alpha: 0.08);

    final orb2Color = isDark
        ? const Color(0xFF06B6D4).withValues(alpha: 0.11)
        : const Color(0xFF0EA5E9).withValues(alpha: 0.06);

    final orb3Color = isDark
        ? const Color(0xFF4F46E5).withValues(alpha: 0.13)
        : const Color(0xFF6366F1).withValues(alpha: 0.05);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bgColors,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Top-right electric blue orb
          Positioned(
            top: -60,
            right: -80,
            child: _DiffuseLightOrb(
              size: 280,
              color: orb1Color,
              blurRadius: 90,
              spreadRadius: 30,
            ),
          ),
          // Mid-left cyan orb
          Positioned(
            top: 220,
            left: -90,
            child: _DiffuseLightOrb(
              size: 240,
              color: orb2Color,
              blurRadius: 100,
              spreadRadius: 40,
            ),
          ),
          // Bottom-right indigo orb
          Positioned(
            bottom: -60,
            right: -70,
            child: _DiffuseLightOrb(
              size: 300,
              color: orb3Color,
              blurRadius: 100,
              spreadRadius: 35,
            ),
          ),
          // Foreground content
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _DiffuseLightOrb extends StatelessWidget {
  const _DiffuseLightOrb({
    required this.size,
    required this.color,
    required this.blurRadius,
    required this.spreadRadius,
  });

  final double size;
  final Color color;
  final double blurRadius;
  final double spreadRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ],
        ),
      ),
    );
  }
}
