import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final isDark = theme.isDark;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.read<ThemeController>().toggle();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                key: ValueKey(isDark),
                color: isDark ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
