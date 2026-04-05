import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({
    super.key,
    required this.child,
    this.overlay,
    this.showBrandText = true,
  });

  final Widget child;
  final Widget? overlay;
  final bool showBrandText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0A1020), Color(0xFF111D37)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [Color(0xFFEAF2FF), Color(0xFFF6FAFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -30,
              left: 20,
              child: _StaticBlob(
                width: 120,
                height: 56,
                color: isDark
                    ? const Color(0xFF1F3D79)
                    : const Color(0xFFC9DCFF),
              ),
            ),
            Positioned(
              top: -12,
              right: 26,
              child: _StaticBlob(
                width: 86,
                height: 40,
                color: isDark
                    ? const Color(0xFF3154A2)
                    : const Color(0xFFDEE9FF),
              ),
            ),
            Positioned(
              top: 112,
              left: 20,
              child: _CasualTag(
                icon: Icons.wifi_rounded,
                label: 'Data in seconds',
                color: const Color(0xFF1E88E5),
              ),
            ),
            Positioned(
              top: 112,
              right: 20,
              child: _CasualTag(
                icon: Icons.bolt_rounded,
                label: 'Airtime fast',
                color: const Color(0xFFFF7A59),
              ),
            ),
            Positioned(
              top: 168,
              left: 20,
              right: 20,
              child: _CasualTag(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Wallet funding made easy',
                color: const Color(0xFF0FB5AE),
                fullWidth: true,
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 238),
                child: Column(
                  children: [
                    Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                        gradient: AxisPalette.warmGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Hero(
                          tag: 'axis-logo',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/brand/axisvtu-icon.png',
                              width: 66,
                              height: 66,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showBrandText) ...[
                      const SizedBox(height: 14),
                      Text(
                        'AxisVTU',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: brandColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (overlay case final Widget overlayWidget) overlayWidget,
            Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticBlob extends StatelessWidget {
  const _StaticBlob({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _CasualTag extends StatelessWidget {
  const _CasualTag({
    required this.icon,
    required this.label,
    required this.color,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16233D) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.92)
                  : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
