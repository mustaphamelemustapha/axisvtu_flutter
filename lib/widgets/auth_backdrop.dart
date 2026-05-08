import 'dart:ui' as ui;
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
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF475569);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFF),
      ),
      child: Stack(
        children: [
          // Ambient Glow Layer 1
          Positioned(
            top: -100,
            right: -80,
            child: _Orb(
              width: 320,
              height: 320,
              blur: 80,
              colors: [
                const Color(0xFF2457F5).withValues(alpha: isDark ? 0.15 : 0.08),
                const Color(0xFF14B8A6).withValues(alpha: 0.0),
              ],
            ),
          ),
          // Ambient Glow Layer 2
          Positioned(
            bottom: -120,
            left: -100,
            child: _Orb(
              width: 360,
              height: 360,
              blur: 100,
              colors: [
                const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.12 : 0.06),
                const Color(0xFF2457F5).withValues(alpha: 0.0),
              ],
            ),
          ),
          
          SafeArea(
            child: Stack(
              children: [
                if (showBrandText) ...[
                  Positioned(top: 16, left: 18, child: _BrandPill(isDark: isDark)),
                  if (overlay case final Widget overlayWidget) overlayWidget,
                  Positioned(
                    top: 86,
                    left: 24,
                    right: 24,
                    child: Column(
                      children: [
                        Container(
                          height: 98,
                          width: 98,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x3D57A1FF)
                                  : const Color(0x242457F5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.35 : 0.12,
                                ),
                                blurRadius: 32,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Hero(
                              tag: 'axis-logo',
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset(
                                    'assets/brand/axisvtu-icon.png',
                                    width: 98,
                                    height: 98,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'AxisVTU',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            color: brandColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fast services. Secure access. Trusted by thousands.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            letterSpacing: -0.1,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: const [
                            _TrustChip(
                              icon: Icons.verified_user_rounded,
                              label: 'Secure',
                            ),
                            _TrustChip(
                              icon: Icons.bolt_rounded,
                              label: 'Instant',
                            ),
                            _TrustChip(
                              icon: Icons.headset_mic_rounded,
                              label: '24/7 Support',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                Positioned.fill(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.width,
    required this.height,
    required this.colors,
    this.blur = 60,
  });

  final double width;
  final double height;
  final List<Color> colors;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: colors, radius: 0.8),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: const SizedBox.shrink(),
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
