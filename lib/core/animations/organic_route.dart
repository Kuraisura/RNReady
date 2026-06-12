import 'package:flutter/material.dart';

/// Fluid, organic page transition: the incoming screen rises slightly from
/// below while fading and easing up to full scale. Tuned with `easeOutCubic`
/// for a soft, premium "settle" rather than a mechanical slide.
///
/// Use this for dashboard → module / quiz pushes that are NOT driven by a Hero
/// (for Hero-paired card expansion, keep `FadeScaleRoute` so the shared element
/// owns the motion).
class OrganicRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  OrganicRoute(this.page)
      : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06), // rise from just below
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
}
