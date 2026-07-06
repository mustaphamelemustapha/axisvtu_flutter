import 'package:flutter/material.dart';

class FastRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FastRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 100), // Ultra fast 100ms
          reverseTransitionDuration: const Duration(milliseconds: 100),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Very snappy fade and slight slide
            return FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
              child: SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(0.02, 0.0), // very subtle
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: child,
              ),
            );
          },
        );
}
