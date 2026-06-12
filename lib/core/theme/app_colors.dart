import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// "Clinical Tech" palette
///
/// A bespoke design language for RN Ready. Two coordinated schemes share the
/// same accent identity (mint/teal interaction markers) but differ in surface:
///   • dark   → deep clinical navy, for the premium dashboard / quiz chrome
///   • light  → warm "paper", tuned for hours of long-form module reading
///
/// Feature widgets should prefer `Theme.of(context).colorScheme.*` so they
/// adapt automatically. The named constants below are for brand moments where
/// a fixed hue is intended regardless of scheme (gradients, highlight ink).
/// ──────────────────────────────────────────────────────────────────────────
class AppPalette {
  AppPalette._();

  // ── Brand anchors (scheme-independent) ────────────────────────────────────
  /// Deep clinical navy — primary dark surface.
  static const navy900 = Color(0xFF0B1220);
  /// Slightly lifted navy — cards / elevated dark surfaces.
  static const navy800 = Color(0xFF111A2E);
  static const navy700 = Color(0xFF1B2742);

  /// Soft mint — the signature success / interaction marker.
  static const mint = Color(0xFF5EEAD4);
  /// Emerald — stronger "correct / pass" state.
  static const emerald = Color(0xFF34D399);
  /// Slate — secondary accent for muted UI.
  static const slate = Color(0xFF94A3B8);

  /// Clinical alert red (wrong / unsafe).
  static const danger = Color(0xFFF87171);
  /// Amber highlight ink for the auto-highlighter (legible on paper & navy).
  static const highlightInk = Color(0xFFFFE38A);

  // ── Warm light "reading paper" surface ────────────────────────────────────
  static const paper = Color(0xFFFBFAF7);
  static const paperCard = Color(0xFFFFFFFF);
  static const inkDark = Color(0xFF111827);

  // ── ColorSchemes ──────────────────────────────────────────────────────────
  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: mint,
    onPrimary: navy900,
    secondary: emerald,
    onSecondary: navy900,
    surface: navy800,
    onSurface: Color(0xFFE6EAF2),
    surfaceContainerHighest: navy700,
    error: danger,
    onError: navy900,
    outline: Color(0xFF2C3A57),
  );

  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0E7C66), // deep teal — readable mint sibling on paper
    onPrimary: Colors.white,
    secondary: emerald,
    onSecondary: Colors.white,
    surface: paperCard,
    onSurface: inkDark,
    surfaceContainerHighest: Color(0xFFEFEDE6),
    error: Color(0xFFD14343),
    onError: Colors.white,
    outline: Color(0xFFE3E0D8),
  );

  /// Scaffold backgrounds (one notch behind the card surface).
  static const darkBg = navy900;
  static const lightBg = paper;
}

/// Glassmorphism design tokens — consumed by [GlassCard] and overlay surfaces.
class GlassTokens {
  GlassTokens._();

  /// Gaussian blur sigma behind frosted surfaces.
  static const double blurSigma = 18.0;

  /// Translucent fill applied over the blur, per brightness.
  static Color fill(Brightness b) => b == Brightness.dark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.55);

  /// Hairline border that catches light on the glass edge.
  static Color border(Brightness b) => b == Brightness.dark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.70);

  static const BorderRadius radius = BorderRadius.all(Radius.circular(20));
}
