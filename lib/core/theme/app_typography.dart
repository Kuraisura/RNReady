import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Dual-font typography system
///
///   • Playfair Display (serif)  → display / headline / title roles and
///     clinical scenario text. Sharp, editorial, high-contrast — gives the app
///     its premium "board-exam textbook" character.
///   • Inter (geometric sans)    → body, labels, buttons, navigation. Clean and
///     highly legible at UI sizes.
///
/// Both families are bundled offline (see pubspec.yaml `fonts:` + assets/fonts).
/// The family name strings here MUST match the `family:` values in pubspec.
/// If the .ttf assets are ever missing, Flutter falls back to the platform
/// default rather than crashing.
/// ──────────────────────────────────────────────────────────────────────────
class AppFonts {
  AppFonts._();
  static const serif = 'Playfair Display'; // headers + scenario prose
  static const sans = 'Inter'; // UI, body, labels
}

class AppTypography {
  AppTypography._();

  /// Builds the full [TextTheme] for a given [brightness]. One source of truth
  /// so light & dark stay perfectly in sync (only the ink color differs).
  static TextTheme textTheme(Brightness brightness) {
    final ink = brightness == Brightness.dark
        ? const Color(0xFFE6EAF2)
        : const Color(0xFF111827);
    final inkMuted = brightness == Brightness.dark
        ? const Color(0xFF9AA6BF)
        : const Color(0xFF5B6472);

    // Serif for large/expressive roles.
    TextStyle serif(double size, FontWeight w, {double h = 1.15, Color? c}) =>
        TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: size,
          fontWeight: w,
          height: h,
          color: c ?? ink,
          letterSpacing: -0.2,
        );

    // Sans for functional roles.
    TextStyle sans(double size, FontWeight w, {double h = 1.4, Color? c}) =>
        TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: size,
          fontWeight: w,
          height: h,
          color: c ?? ink,
        );

    return TextTheme(
      displayLarge: serif(40, FontWeight.w700),
      displayMedium: serif(34, FontWeight.w700),
      displaySmall: serif(28, FontWeight.w600),
      headlineMedium: serif(24, FontWeight.w600),
      headlineSmall: serif(20, FontWeight.w600),
      titleLarge: serif(19, FontWeight.w600),
      titleMedium: sans(16, FontWeight.w600),
      titleSmall: sans(14, FontWeight.w600, c: inkMuted),
      bodyLarge: sans(16, FontWeight.w400, h: 1.6),
      bodyMedium: sans(14, FontWeight.w400, h: 1.55),
      bodySmall: sans(12.5, FontWeight.w400, c: inkMuted),
      labelLarge: sans(15, FontWeight.w600),
      labelMedium: sans(13, FontWeight.w600),
      labelSmall: sans(11.5, FontWeight.w500, c: inkMuted),
    );
  }
}
