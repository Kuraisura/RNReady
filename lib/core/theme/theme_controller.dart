import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the app-wide [ThemeMode].
///
/// The dashboard's toggle calls [ThemeController.toggle]; `main.dart` watches
/// [themeModeProvider] and feeds it to `MaterialApp`. Choice survives restarts
/// via `shared_preferences` (already a project dependency).
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(super.initial);

  static const _prefsKey = 'theme_mode'; // 'dark' | 'light'

  /// Reads the persisted preference. Defaults to dark — the signature look.
  static Future<ThemeMode> loadInitial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsKey) == 'light'
          ? ThemeMode.light
          : ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, state == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {
      // Persistence is best-effort; never block the UI on a write failure.
    }
  }
}

/// Overridden in `main.dart` with the persisted initial value (see
/// [ThemeController.loadInitial]) so the first frame already has the right mode.
final themeModeProvider =
    StateNotifierProvider<ThemeController, ThemeMode>(
  (ref) => ThemeController(ThemeMode.dark),
);
