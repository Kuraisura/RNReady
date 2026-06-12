import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import '../../data/services/llm_service.dart';
import '../../data/services/study_content_service.dart';
import 'mcq_models.dart';

/// Generates board-style quiz questions for a subtopic from its bundled text
/// via the AI, parses them into [QuizQuestion]s, and caches the result on disk
/// so each subtopic is only generated once (and works offline thereafter).
class QuizGeneratorService {
  QuizGeneratorService(this._llm);
  final LlmService _llm;
  final _rng = Random();

  /// Returns the cached question pool for [startPage] if present, else null.
  Future<List<QuizQuestion>?> cached(int startPage) async {
    try {
      final f = await _file(startPage);
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString()) as List;
      return [
        for (final q in raw)
          QuizQuestion.fromJson(q as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Whether a subtopic already has a saved (offline-ready) quiz pool.
  Future<bool> hasCache(int startPage) async {
    try {
      return await (await _file(startPage)).exists();
    } catch (_) {
      return false;
    }
  }

  /// Generates a fresh batch of questions for a subtopic, MERGES it into the
  /// on-disk pool (so offline retakes accumulate variety), and returns the new
  /// batch. Throws [OfflineException] when offline.
  ///
  /// [types] restricts the formats produced (empty = a mix of all four).
  /// When [count] is null the target scales with the subtopic's length so the
  /// quiz aims to cover EVERY key concept in the notes (see [coverageCount]).
  Future<List<QuizQuestion>> generate({
    required String title,
    required int startPage,
    Set<QuizType> types = const {},
    int? count,
  }) async {
    final source = await StudyContentService.instance.subtopicText(startPage);
    final target = count ?? coverageCount(source);
    // A nonce nudges the model to produce different items each call.
    final nonce = _rng.nextInt(1 << 32).toRadixString(16);
    final reply = await _llm.chat(
      temperature: 0.85,
      [
        {'role': 'system', 'content': _buildSystem(types)},
        {
          'role': 'user',
          'content': 'TOPIC: $title\n\nSOURCE NOTES:\n$source\n\n'
              'Generate about $target questions that COMPREHENSIVELY cover every '
              'key concept, definition, value and fact in the SOURCE NOTES — do '
              'not stop short. (variation id: $nonce). Vary the wording and '
              'focus so retakes feel fresh.'
        },
      ],
    );

    // Keep only raw maps that successfully construct a question.
    final freshMaps = _validMaps(reply);
    if (freshMaps.isNotEmpty) {
      await _mergeIntoPool(startPage, freshMaps);
    }
    return [
      for (final m in freshMaps) QuizQuestion.fromJson(m),
    ];
  }

  /// A content-scaled target question count: roughly one question per ~90 words
  /// of source notes, so longer subtopics get more questions and the quiz can
  /// cover the whole topic. Clamped to a sane range to respect free-AI limits.
  static int coverageCount(String source) {
    final words =
        source.trim().isEmpty ? 0 : source.trim().split(RegExp(r'\s+')).length;
    final scaled = (words / 90).round();
    return scaled.clamp(10, 45);
  }

  // ── parsing ───────────────────────────────────────────────────────────────

  /// Raw question maps from a reply that each parse cleanly into a question.
  List<Map<String, dynamic>> _validMaps(String reply) {
    final jsonStr = _extractJsonArray(reply);
    if (jsonStr == null) return [];
    final List decoded;
    try {
      decoded = jsonDecode(jsonStr) as List;
    } catch (_) {
      return [];
    }
    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try {
        QuizQuestion.fromJson(item); // validate
        out.add(item);
      } catch (_) {
        // skip malformed item
      }
    }
    return out;
  }

  // ── parsing ───────────────────────────────────────────────────────────────

  /// Pulls the first top-level JSON array out of a model reply that may be
  /// wrapped in prose or ```json fences.
  String? _extractJsonArray(String s) {
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start < 0 || end <= start) return null;
    return s.substring(start, end + 1);
  }

  // ── disk cache (a growing pool per subtopic) ──────────────────────────────

  static const _poolCap = 60; // keep the newest N questions per subtopic

  Future<File> _file(int startPage) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/quizzes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/sub_$startPage.json');
  }

  /// Adds [fresh] maps to the saved pool, de-duplicating by prompt and capping
  /// the total — so offline retakes keep growing in variety without unbounded
  /// disk use.
  Future<void> _mergeIntoPool(
      int startPage, List<Map<String, dynamic>> fresh) async {
    try {
      final f = await _file(startPage);
      final existing = <Map<String, dynamic>>[];
      if (await f.exists()) {
        try {
          for (final e in jsonDecode(await f.readAsString()) as List) {
            if (e is Map<String, dynamic>) existing.add(e);
          }
        } catch (_) {/* corrupt cache → start fresh */}
      }
      // Newest first; dedupe by normalized prompt.
      final merged = <Map<String, dynamic>>[...fresh, ...existing];
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final m in merged) {
        final key = (m['prompt'] as String? ?? '').trim().toLowerCase();
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        deduped.add(m);
        if (deduped.length >= _poolCap) break;
      }
      await f.writeAsString(jsonEncode(deduped));
    } catch (_) {
      // best-effort cache
    }
  }

  // ── prompt building ───────────────────────────────────────────────────────

  static const _schemaMcq = '''
Multiple choice:
{"type":"mcq","prompt":"...","options":["A. ...","B. ...","C. ...","D. ..."],
 "correctIndex":0,"points":1,"rationale":"why correct, grounded in the notes"}''';

  static const _schemaIdentification = '''
Identification:
{"type":"identification","prompt":"...","answer":"Canonical term",
 "accepted":["synonym1","synonym2"],"points":1,"rationale":"..."}''';

  static const _schemaEnumeration = '''
Enumeration:
{"type":"enumeration","prompt":"...","items":[["item1","syn"],["item2"],["item3"]],
 "count":3,"points":3,"rationale":"..."}''';

  static const _schemaMatching = '''
Matching:
{"type":"matching","prompt":"...",
 "pairs":[{"left":"A","right":"matches A"},{"left":"B","right":"matches B"}],
 "points":2,"rationale":"..."}''';

  static String _schemaFor(QuizType t) => switch (t) {
        QuizType.multipleChoice => _schemaMcq,
        QuizType.identification => _schemaIdentification,
        QuizType.enumeration => _schemaEnumeration,
        QuizType.matching => _schemaMatching,
      };

  /// Builds the system prompt. With no [types] the model mixes all four formats
  /// (favoring MCQ); otherwise it emits ONLY the requested formats.
  static String _buildSystem(Set<QuizType> types) {
    final selected = types.isEmpty ? QuizType.values.toSet() : types;
    final schemas = [
      for (final t in QuizType.values)
        if (selected.contains(t)) _schemaFor(t),
    ].join('\n\n');

    final mixRule = types.isEmpty
        ? '- Favor multiple choice (~60%), with a few of each other type.'
        : (selected.length == 1
            ? '- Use ONLY the format shown above for every question.'
            : '- Use ONLY the formats shown above, spread roughly evenly across them.');

    return '''
You are an item writer for the Philippine Nurse Licensure Exam (PNLE/NCLEX).
From the SOURCE NOTES, write board-style questions that test understanding,
prioritization, and safety — not trivial recall.

Return ONLY a JSON array (no prose, no markdown fences). Use these formats:

$schemas

Rules:
- Ground every question and rationale strictly in the SOURCE NOTES. Never invent
  facts not supported by the notes.
- Aim to cover EVERY distinct key concept in the notes — breadth over repetition.
$mixRule
- Keep prompts concise and unambiguous; exactly one defensible answer for mcq.
- Output must be valid JSON parseable as a single array.''';
  }
}
