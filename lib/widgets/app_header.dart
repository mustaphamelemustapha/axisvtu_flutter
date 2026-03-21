import 'package:flutter/material.dart';

import 'theme_toggle_button.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.showThemeToggle = true,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final bool showThemeToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          action!,
        ],
        if (action == null && showThemeToggle) ...[
          const SizedBox(width: 12),
          const ThemeToggleButton(),
        ],
      ],
    );
  }
}
