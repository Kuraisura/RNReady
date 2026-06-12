import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Premium "Clinical Tech" themes (Material 3) for RN Ready.
///
/// Two coordinated schemes — see [AppPalette]. Feature widgets pull their
/// colors from `Theme.of(context).colorScheme` and fonts from `textTheme`, so
/// flipping [ThemeMode] restyles the whole app instantly.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppPalette.dark, AppPalette.darkBg);
  static ThemeData get light => _build(AppPalette.light, AppPalette.lightBg);

  static ThemeData _build(ColorScheme scheme, Color scaffoldBg) {
    final text = AppTypography.textTheme(scheme.brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: text,
      // Organic page transitions everywhere by default.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        barrierColor: AppPalette.navy900.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surface,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: scheme.outline,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.35)
              : null,
        ),
      ),
    );
  }
}

/// ── Back-compat aliases ────────────────────────────────────────────────────
/// Existing feature files were written against `AppColors`. These keep them
/// compiling while each screen is migrated to `Theme.of(context).colorScheme`.
/// New code should NOT use these — prefer the theme.
class AppColors {
  AppColors._();
  static const primary = AppPalette.navy900;
  static const accent = AppPalette.mint;
  static const highlight = AppPalette.highlightInk;
  static const cardBorder = Color(0xFF2C3A57);
  static const bg = AppPalette.darkBg;
}
