import 'package:flutter/material.dart';

import '../theme/axis_tokens.dart';
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
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF475569);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AxisPalette.softBackgroundGradient
            : AxisPalette.lightWashGradient,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -54,
              right: -48,
              child: _Orb(
                width: 180,
                height: 180,
                colors: [
                  const Color(0xFF2457F5).withValues(alpha: isDark ? 0.22 : 0.12),
                  const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.12 : 0.05),
                ],
              ),
            ),
            Positioned(
              bottom: -70,
              left: -56,
              child: _Orb(
                width: 190,
                height: 190,
                colors: [
                  const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.18 : 0.1),
                  const Color(0xFF2457F5).withValues(alpha: isDark ? 0.1 : 0.04),
                ],
              ),
            ),
            if (showBrandText) ...[
              Positioned(top: 16, left: 18, child: _BrandPill(isDark: isDark)),
              if (overlay case final Widget overlayWidget) overlayWidget,
              Positioned(
                top: 96,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    Container(
                      height: 94,
                      width: 94,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x3357A1FF)
                              : const Color(0x1F2457F5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.24 : 0.12,
                            ),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Hero(
                          tag: 'axis-logo',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/brand/axisvtu-icon.png',
                              width: 94,
                              height: 94,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'AxisVTU',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: brandColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fast VTU. Clean receipts. Wallet-first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _TrustChip(
                          icon: Icons.flash_on_rounded,
                          label: 'Fast delivery',
                        ),
                        _TrustChip(
                          icon: Icons.security_rounded,
                          label: 'Secure wallet',
                        ),
                        _TrustChip(
                          icon: Icons.receipt_long_rounded,
                          label: 'Instant receipts',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (overlay case final Widget overlayWidget) overlayWidget,
            Positioned.fill(
              child: Padding(
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

class _Orb extends StatelessWidget {
  const _Orb({required this.width, required this.height, required this.colors});

  final double width;
  final double height;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: colors, radius: 0.92),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1726)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/brand/axisvtu-icon.png', width: 18, height: 18),
          const SizedBox(width: 8),
          Text(
            'AxisVTU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B2C) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
