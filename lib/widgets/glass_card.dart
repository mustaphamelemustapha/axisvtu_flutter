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
        color: isDark ? const Color(0xFF0E1624) : const Color(0xFFFEFFFF),
        borderRadius: BorderRadius.circular(AxisRadii.lg),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
