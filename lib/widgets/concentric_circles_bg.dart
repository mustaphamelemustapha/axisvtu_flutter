import 'package:flutter/material.dart';

class ConcentricCirclesBg extends StatelessWidget {
  const ConcentricCirclesBg({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    
    // Using the brand's primary color with very low opacity to create the soft circles
    final circleColor = primary.withValues(alpha: isDark ? 0.05 : 0.03);
    
    // Background color: Soft gradient based on brand colors
    final bgColors = isDark 
        ? [const Color(0xFF0A0F1A), const Color(0xFF0D1726)]
        : [primary.withValues(alpha: 0.05), primary.withValues(alpha: 0.02), Colors.white];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bgColors,
        ),
      ),
      child: Stack(
        children: [
          // Top Left Circles
          Positioned(
            top: -100,
            left: -100,
            child: _CirclesPattern(color: circleColor),
          ),
          // Top Right Circles
          Positioned(
            top: 50,
            right: -150,
            child: _CirclesPattern(color: circleColor),
          ),
          // Bottom Left Circles
          Positioned(
            bottom: -50,
            left: -120,
            child: _CirclesPattern(color: circleColor),
          ),
          // Foreground content
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _CirclesPattern extends StatelessWidget {
  const _CirclesPattern({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 40),
      ),
      child: Center(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 40),
          ),
          child: Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
