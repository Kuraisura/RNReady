import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the AI Tutor conversation so it survives app restarts.
///
/// Stored as a JSON array under one key in `shared_preferences` (already a
/// project dependency). Only real user/assistant turns are kept — transient
/// "offline" placeholders are never persisted.
class ChatStore {
  static const _key = 'ai_tutor_chat_v1';

  Future<List<({String text, bool isUser})>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return [
        for (final m in list)
          (
            text: (m as Map<String, dynamic>)['text'] as String,
            isUser: m['isUser'] as bool,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<({String text, bool isUser})> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode([
        for (final m in messages) {'text': m.text, 'isUser': m.isUser},
      ]);
      await prefs.setString(_key, encoded);
    } catch (_) {
      // best-effort persistence
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
