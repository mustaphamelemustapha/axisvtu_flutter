import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class PurchaseLoadingOverlay {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    String title = 'Processing request',
  }) {
    hide();
    FocusManager.instance.primaryFocus?.unfocus();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(builder: (_) => _PurchaseLoadingView(title: title));
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _PurchaseLoadingView extends StatefulWidget {
  const _PurchaseLoadingView({required this.title});

  final String title;

  @override
  State<_PurchaseLoadingView> createState() => _PurchaseLoadingViewState();
}

class _PurchaseLoadingViewState extends State<_PurchaseLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.26),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 0.9,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) =>
                Transform.scale(scale: _pulseAnim.value, child: child),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.52,),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.26),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PremiumSpinner(),
                      const SizedBox(height: 14),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const _DynamicLoadingText(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumSpinner extends StatefulWidget {
  const _PremiumSpinner();

  @override
  State<_PremiumSpinner> createState() => _PremiumSpinnerState();
}

class _PremiumSpinnerState extends State<_PremiumSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0E1625)
        : Colors.white;
    return SizedBox(
      height: 66,
      width: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spinCtrl,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFF1E88E5),
                    Color(0xFF0FB5AE),
                    Color(0xFF9C27B0),
                    Color(0xFF1E88E5),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5.5),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
                ),
              ),
            ),
          ),
          Container(
            height: 11,
            width: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.38),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicLoadingText extends StatefulWidget {
  const _DynamicLoadingText();

  @override
  State<_DynamicLoadingText> createState() => _DynamicLoadingTextState();
}

class _DynamicLoadingTextState extends State<_DynamicLoadingText> {
  static const List<String> _messages = [
    'Validating request',
    'Connecting to provider',
    'Completing transaction',
  ];

  Timer? _timer;
  int _messageIndex = 0;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount % 3) + 1;
        if (_dotCount == 1) {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = List.filled(_dotCount, '.').join();
    return Text(
      '${_messages[_messageIndex]}$dots',
      key: ValueKey('$_messageIndex-$_dotCount'),
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
    );
  }
}
