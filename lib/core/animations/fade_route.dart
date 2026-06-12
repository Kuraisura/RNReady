import 'package:flutter/material.dart';

/// Smooth fade+scale route for module/quiz navigation.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  FadeScaleRoute(this.page)
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, _, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}
