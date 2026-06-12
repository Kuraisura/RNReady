import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable glassmorphism surface: a real Gaussian blur of whatever sits behind
/// it ([BackdropFilter]) under a translucent fill and a hairline light-catching
/// border. Adapts to the active [Brightness] via [GlassTokens].
///
/// Use for overlays, premium cards (exam banner, quiz scenario, AI feedback)
/// and frosted bars. Keep blurred regions modest in size — backdrop filters are
/// GPU-cheap per-pixel but not free over full screens.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = GlassTokens.radius,
    this.onTap,
    this.blurSigma = GlassTokens.blurSigma,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final double blurSigma;

  /// Optional accent wash laid over the neutral glass fill (e.g. mint for
  /// success surfaces). Kept subtle.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final glass = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint?.withValues(alpha: 0.14) ?? GlassTokens.fill(brightness),
            borderRadius: borderRadius,
            border: Border.all(color: GlassTokens.border(brightness), width: 1),
          ),
          child: child,
        ),
      ),
    );

    final lifted = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: (tint ?? AppPalette.navy900).withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: glass,
    );

    if (onTap == null) return lifted;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: lifted,
      ),
    );
  }
}
