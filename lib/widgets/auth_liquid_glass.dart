import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/axis_tokens.dart';

/// A reusable liquid-glass container adhering to the design specification:
/// - 10-18% translucent white fill
/// - 20-30px background blur (with fallback for Reduce Transparency)
/// - 1px edge highlight border
/// - Smooth rounded corners and soft diffuse shadow
class LiquidGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? borderColor;

  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.blur = 24.0,
    this.opacity = 0.12,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final reduceTransparency = media.accessibleNavigation;

    final bgColor = isDark
        ? (reduceTransparency
            ? const Color(0xFF131D2F)
            : Colors.white.withValues(alpha: opacity))
        : (reduceTransparency
            ? Colors.white
            : Colors.white.withValues(alpha: 0.85));

    final edgeBorderColor = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFE2E8F0));

    final content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AxisSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: edgeBorderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : const Color(0xFF94A3B8).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (reduceTransparency) {
      return content;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );
  }
}

/// Floating data plan card for ambient background animation
class FloatingDataPlanCard extends StatelessWidget {
  final String network;
  final String plan;
  final String price;
  final String badge;
  final Color networkColor;

  const FloatingDataPlanCard({
    super.key,
    required this.network,
    required this.plan,
    required this.price,
    required this.badge,
    required this.networkColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.68)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: networkColor.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: networkColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: networkColor.withValues(alpha: isDark ? 0.6 : 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$network $plan',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: networkColor.withValues(alpha: isDark ? 0.22 : 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: networkColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.75)
                      : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// Phone pill displaying locked phone number with a Change button
class PhonePill extends StatelessWidget {
  final String phone;
  final VoidCallback onChange;

  const PhonePill({
    super.key,
    required this.phone,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.phone_rounded,
            size: 20,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Text(
            'Phone: ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              phone,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onChange();
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: const Text(
                'Change',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shake animation widget for displaying inline validation errors
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double deltaX;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
    this.deltaX = 12.0,
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    HapticFeedback.vibrate();
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        // 3 gentle oscillations damped out
        final offset =
            progress == 0 || progress == 1
                ? 0.0
                : (1.0 - progress) * widget.deltaX *
                    (progress * 12.0).sin();
        return Transform.translate(
          offset: Offset(offset, 0),
          child: widget.child,
        );
      },
    );
  }
}

extension on double {
  double sin() => (this * 3.141592653589793 / 2).clamp(-1.0, 1.0);
}
