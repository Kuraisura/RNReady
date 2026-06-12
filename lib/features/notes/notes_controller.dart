import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single note / journal entry.
class Note {
  final String id;
  final String title;
  final String body;
  final int updatedAt; // epoch ms

  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  Note copyWith({String? title, String? body, int? updatedAt}) => Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'body': body, 'updatedAt': updatedAt};

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Persists notes locally (shared_preferences) and exposes them as Riverpod
/// state. All writes save immediately so nothing is lost on close.
class NotesController extends StateNotifier<List<Note>> {
  NotesController() : super([]) {
    _load();
  }

  static const _key = 'notes_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      final notes = [
        for (final n in list) Note.fromJson(n as Map<String, dynamic>),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = notes;
    } catch (_) {
      // leave empty
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final n in state) n.toJson()]));
    } catch (_) {
      // best-effort
    }
  }

  /// Creates a note and returns its id.
  String add({required String title, required String body}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final note = Note(
      id: 'n$now',
      title: title.trim(),
      body: body.trim(),
      updatedAt: now,
    );
    state = [note, ...state];
    _save();
    return note.id;
  }

  void update(String id, {required String title, required String body}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = [
      for (final n in state)
        if (n.id == id)
          n.copyWith(title: title.trim(), body: body.trim(), updatedAt: now)
        else
          n,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _save();
  }

  void remove(String id) {
    state = [for (final n in state) if (n.id != id) n];
    _save();
  }
}

final notesProvider =
    StateNotifierProvider<NotesController, List<Note>>((_) => NotesController());
