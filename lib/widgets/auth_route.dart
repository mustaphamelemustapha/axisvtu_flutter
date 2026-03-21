import 'dart:ui';

import 'package:flutter/material.dart';

class AuthRoute<T> extends PageRouteBuilder<T> {
  AuthRoute({required Widget page, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            final fade = Tween<double>(begin: 0, end: 1).animate(curved);
            final slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved);
            final scale = Tween<double>(begin: 0.98, end: 1).animate(curved);
            final blur = Tween<double>(begin: 8, end: 0).animate(curved);

            return AnimatedBuilder(
              animation: blur,
              builder: (context, _) {
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: slide,
                    child: ScaleTransition(
                      scale: scale,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: blur.value, sigmaY: blur.value),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
}
