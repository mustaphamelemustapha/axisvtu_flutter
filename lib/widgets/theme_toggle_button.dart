import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final isDark = theme.isDark;
    final colorScheme = Theme.of(context).colorScheme;
    final label = isDark ? 'Dark' : 'Light';
    final bgColor = isDark ? const Color(0xFF101A2A) : const Color(0xFFF9FBFF);
    final borderColor = isDark
        ? const Color(0xFF2A3A52)
        : colorScheme.outline.withValues(alpha: 0.92);

    return LayoutBuilder(
      builder: (context, constraints) {
        final requestedWidth = size * 1.82;
        final compact =
            constraints.maxWidth.isFinite &&
            constraints.maxWidth < requestedWidth;
        final width = compact ? constraints.maxWidth : requestedWidth;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<ThemeController>().toggle();
            },
            borderRadius: BorderRadius.circular(AxisRadii.xl),
            child: Ink(
              width: width,
              height: size,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AxisRadii.xl),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    AnimatedContainer(
                      duration: AxisDurations.normal,
                      curve: Curves.easeOut,
                      width: size * 0.62,
                      height: size * 0.62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isDark ? null : AxisPalette.gradient,
                        color: isDark ? const Color(0xFF17233B) : null,
                      ),
                      child: AnimatedSwitcher(
                        duration: AxisDurations.normal,
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: Tween<double>(begin: 0.75, end: 1).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          key: ValueKey(isDark),
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: AxisDurations.normal,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0.08, 0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                child: child,
                              ),
                            );
                          },
                          child: FittedBox(
                            key: ValueKey(label),
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
