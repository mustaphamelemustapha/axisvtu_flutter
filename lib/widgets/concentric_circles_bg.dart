import 'package:flutter/material.dart';

class ConcentricCirclesBg extends StatelessWidget {
  const ConcentricCirclesBg({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    
    // Increased visibility of circles
    final circleColor = primary.withValues(alpha: isDark ? 0.08 : 0.04);
    
    // Use the theme's background color directly to ensure it matches the lightened dark mode perfectly
    final bgColors = [
      theme.colorScheme.surface,
      theme.scaffoldBackgroundColor,
    ];

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 40),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 40),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
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
