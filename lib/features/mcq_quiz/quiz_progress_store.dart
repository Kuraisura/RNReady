import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/module_structure.dart';

/// Best/last quiz score for one subtopic, keyed by its [page] (the subtopic's
/// start page — the same id used by the quiz cache). Drives the "6/8" badges on
/// the Practice Quizzes list and the "X/Y done" section counters.
class QuizProgress {
  final int page;
  final String title;

  /// Best attempt (highest by percentage).
  final int bestCorrect;
  final int bestTotal;

  /// Most recent attempt.
  final int lastCorrect;
  final int lastTotal;

  final int attempts;
  final int updatedAt; // epoch ms

  const QuizProgress({
    required this.page,
    required this.title,
    required this.bestCorrect,
    required this.bestTotal,
    required this.lastCorrect,
    required this.lastTotal,
    required this.attempts,
    required this.updatedAt,
  });

  double get bestPercent => bestTotal == 0 ? 0 : bestCorrect / bestTotal;

  Map<String, dynamic> toJson() => {
        'page': page,
        'title': title,
        'bestCorrect': bestCorrect,
        'bestTotal': bestTotal,
        'lastCorrect': lastCorrect,
        'lastTotal': lastTotal,
        'attempts': attempts,
        'updatedAt': updatedAt,
      };

  factory QuizProgress.fromJson(Map<String, dynamic> j) => QuizProgress(
        page: (j['page'] as num).toInt(),
        title: j['title'] as String? ?? '',
        bestCorrect: (j['bestCorrect'] as num?)?.toInt() ?? 0,
        bestTotal: (j['bestTotal'] as num?)?.toInt() ?? 0,
        lastCorrect: (j['lastCorrect'] as num?)?.toInt() ?? 0,
        lastTotal: (j['lastTotal'] as num?)?.toInt() ?? 0,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Persists per-subtopic quiz scores locally (shared_preferences) and exposes
/// them as Riverpod state, keyed by subtopic start page. Mirrors the approach
/// used by `NotesController`.
class QuizProgressController extends StateNotifier<Map<int, QuizProgress>> {
  QuizProgressController() : super({}) {
    _load();
  }

  static const _key = 'quiz_progress_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      final map = <int, QuizProgress>{};
      for (final e in list) {
        final p = QuizProgress.fromJson(e as Map<String, dynamic>);
        map[p.page] = p;
      }
      state = map;
    } catch (_) {
      // leave empty
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final p in state.values) p.toJson()]));
    } catch (_) {
      // best-effort
    }
  }

  /// Records a finished attempt for [page], updating the last attempt always and
  /// the best attempt only when this run scored a higher percentage.
  void record({
    required int page,
    required String title,
    required int correct,
    required int total,
  }) {
    if (total <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final prev = state[page];
    final prevBest = prev?.bestPercent ?? -1;
    final thisPct = correct / total;
    final keepPrevBest = prev != null && prevBest >= thisPct;

    final updated = QuizProgress(
      page: page,
      title: title,
      bestCorrect: keepPrevBest ? prev.bestCorrect : correct,
      bestTotal: keepPrevBest ? prev.bestTotal : total,
      lastCorrect: correct,
      lastTotal: total,
      attempts: (prev?.attempts ?? 0) + 1,
      updatedAt: now,
    );
    state = {...state, page: updated};
    _save();
  }
}

final quizProgressProvider =
    StateNotifierProvider<QuizProgressController, Map<int, QuizProgress>>(
        (_) => QuizProgressController());

/// How many subtopics of [section] have at least one recorded attempt, given the
/// current [progress] map. Used for the "X/Y done" counters.
int sectionDoneCount(ModuleSection section, Map<int, QuizProgress> progress) {
  var done = 0;
  for (final s in section.subtopics) {
    if (progress.containsKey(s.startPage)) done++;
  }
  return done;
}
