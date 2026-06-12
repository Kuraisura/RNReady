import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anatomy_models.dart';

/// Persists hand-calibrated marker positions for anatomy diagrams.
///
/// The const [kAnatomyDiagrams] coordinates were tuned to the old vector art;
/// once a real illustration is bundled they need re-pinning. The calibrate
/// screen drags markers and saves the new (x, y) here, keyed by diagram id, so
/// the quiz reflects them instantly with no rebuild. Stored as a JSON array of
/// `{x, y}`, index-aligned to `diagram.parts`.
class AnatomyOverrides {
  static String _key(String id) => 'anat_coords_$id';

  /// Saved positions for [id] (index → Offset), or null if never calibrated.
  static Future<List<Offset>?> load(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(id));
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return [
        for (final p in list)
          Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String id, List<Offset> points) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode([
        for (final o in points) {'x': o.dx, 'y': o.dy},
      ]);
      await prefs.setString(_key(id), encoded);
    } catch (_) {
      // best-effort persistence
    }
  }

  static Future<void> clear(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(id));
    } catch (_) {}
  }
}

/// Returns [diagram]'s parts with any saved calibration applied. Falls back to
/// the const coordinates when nothing is saved (or counts don't line up).
Future<List<AnatomyPart>> effectiveParts(AnatomyDiagram diagram) async {
  final saved = await AnatomyOverrides.load(diagram.id);
  if (saved == null || saved.length != diagram.parts.length) {
    return diagram.parts;
  }
  return [
    for (var i = 0; i < diagram.parts.length; i++)
      AnatomyPart(
        diagram.parts[i].label,
        saved[i].dx,
        saved[i].dy,
        accepted: diagram.parts[i].accepted,
      ),
  ];
}
