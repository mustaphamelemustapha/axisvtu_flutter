import 'package:flutter/material.dart';

import '../theme/axis_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: padding ?? const EdgeInsets.all(AxisSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1624) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AxisRadii.md),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.10 : 0.08),
        ),
        boxShadow: AxisShadows.softGlow,
      ),
      child: child,
    );
  }
}
