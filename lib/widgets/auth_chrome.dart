import 'package:flutter/material.dart';

import 'theme_toggle_button.dart';

class AuthTopBar extends StatelessWidget {
  const AuthTopBar({
    super.key,
    this.onBack,
    this.showBack = true,
    this.trailing,
    this.trailingSize = 46,
  });

  final VoidCallback? onBack;
  final bool showBack;
  final Widget? trailing;
  final double trailingSize;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final compact = shortestSide < 390;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 8, 16, compact ? 8 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showBack)
            _HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 46, height: 46),
          trailing ?? ThemeToggleButton(size: trailingSize),
        ],
      ),
    );
  }
}

class AuthHeroBlock extends StatelessWidget {
  const AuthHeroBlock({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoSize = 86,
    this.titleSize = 30,
    this.subtitleAlign = TextAlign.center,
    this.titleAlign = TextAlign.center,
    this.tight = false,
    this.maxWidth = 440,
  });

  final String title;
  final String subtitle;
  final double logoSize;
  final double titleSize;
  final TextAlign subtitleAlign;
  final TextAlign titleAlign;
  final bool tight;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final compact = tight || size.height < 760 || size.width < 390;
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.72)
        : const Color(0xFF475569);
    final brandColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            compact ? 0 : 8,
            24,
            compact ? 12 : 24,
          ),
          child: Column(
            children: [
              Container(
                width: compact ? logoSize * 0.8 : logoSize,
                height: compact ? logoSize * 0.8 : logoSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(compact ? 24 : 28),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x3D60A5FA)
                        : const Color(0x1F2563EB),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.22 : 0.1,),
                      blurRadius: compact ? 16 : 22,
                      offset: Offset(0, compact ? 8 : 12),
                    ),
                  ],
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(compact ? 22 : 26),
                    child: Image.asset(
                      'assets/brand/axisvtu-icon.png',
                      width: compact ? logoSize * 0.8 : logoSize,
                      height: compact ? logoSize * 0.8 : logoSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 16 : 24),
              Text(
                title,
                textAlign: titleAlign,
                style: TextStyle(
                  fontSize: compact ? titleSize * 0.9 : titleSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  color: brandColor,
                  height: 1.1,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                subtitle,
                textAlign: subtitleAlign,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.5,
                  letterSpacing: -0.1,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF151F34)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withOpacity(0.24),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
