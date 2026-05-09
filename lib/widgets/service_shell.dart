import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/axis_tokens.dart';
import 'theme_toggle_button.dart';

class ServiceShell extends StatelessWidget {
  const ServiceShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.footer,
    this.scrollController,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? footer;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 760 || size.width < 390;
    final bottomPadding = footer == null ? 24.0 : (compact ? 136.0 : 160.0);
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Container(color: Theme.of(context).scaffoldBackgroundColor),
            SafeArea(
              child: Stack(
                children: [
                  ListView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      compact ? 10 : 12,
                      16,
                      bottomPadding,
                    ),
                    children: [
                      Row(
                        children: [
                          _ActionBtn(
                            icon: Icons.arrow_back_rounded,
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              final nav = Navigator.of(context);
                              if (nav.canPop()) {
                                nav.pop();
                                return;
                              }
                              nav.pushNamedAndRemoveUntil('/app', (route) => false);
                            },
                          ),
                          const Spacer(),
                          const ThemeToggleButton(size: 44),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.15,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.62),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      child,
                    ],
                  ),
                  if (footer != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: footer!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceChoiceChip extends StatelessWidget {
  const ServiceChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: AxisDurations.normal,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.10)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceSectionCard extends StatelessWidget {
  const ServiceSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 760 || size.width < 390;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.40 : 0.72),
        ),
        boxShadow: AxisShadows.softGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: compact ? 3 : 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.64),
              ),
            ),
          ],
          SizedBox(height: compact ? 12 : 14),
          child,
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.95)),
        ),
        child: Icon(icon),
      ),
    );
  }
}
