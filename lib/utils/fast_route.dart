import 'package:flutter/material.dart';

class FastRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FastRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 250), // Epic and smooth 250ms
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Elegant, realistic smooth slide and fade
            return FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
              child: SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(0.03, 0.0), // Subtle slide from the right
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
                ),
                child: child,
              ),
            );
          },
        );
}
