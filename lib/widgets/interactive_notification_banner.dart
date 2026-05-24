import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InteractiveNotificationBanner extends StatefulWidget {
  const InteractiveNotificationBanner({
    super.key,
    required this.title,
    required this.message,
    required this.logoAsset,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final String logoAsset;
  final VoidCallback onDismiss;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String logoAsset = 'assets/brand/meledata-icon.png',
  }) {
    // Generate tactile feedback to simulate native notification arrival
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.mediumImpact();
    });

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => InteractiveNotificationBanner(
        title: title,
        message: message,
        logoAsset: logoAsset,
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<InteractiveNotificationBanner> createState() => _InteractiveNotificationBannerState();
}

class _InteractiveNotificationBannerState extends State<InteractiveNotificationBanner> {
  bool _visible = false;
  Timer? _dismissTimer;

  @override
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });

    _dismissTimer = Timer(const Duration(milliseconds: 4200), () {
      _hideAndDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _hideAndDismiss() {
    if (!mounted) return;
    setState(() {
      _visible = false;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      top: _visible ? topPadding + 10 : -140,
      left: 14,
      right: 14,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! < -4) {
            _hideAndDismiss();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155).withValues(alpha: 0.4)
                          : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Circular Premium Icon Container
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Image.asset(
                              widget.logoAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => Icon(
                                Icons.notifications_active_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text Contents
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  'now',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3.5),
                            Text(
                              widget.message,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
