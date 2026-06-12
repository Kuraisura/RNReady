import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../features/mcq_quiz/mcq_models.dart';
import '../../features/module_slides/slide_models.dart';
import '../models/module_structure.dart';

/// Loads the pre-generated, source-grounded study content bundled as JSON
/// assets: per-page key-point highlight anchors and per-topic quiz banks.
///
/// Both files are produced offline from the actual module text (see
/// `assets/study/`), so this is a precise replacement for the old statistical
/// summarizer and the hardcoded demo questions. Results are parsed once and
/// cached for the session.
class StudyContentService {
  StudyContentService._();
  static final StudyContentService instance = StudyContentService._();

  static const highlightsAsset = 'assets/study/ackp_highlights.json';
  static const quizzesAsset = 'assets/study/ackp_quizzes.json';
  static const structureAsset = 'assets/study/module_structure.json';
  static const subtopicTextAsset = 'assets/study/subtopic_text.json';
  // One JSON file per subtopic deck (keyed by start page) — loaded on demand so
  // the app never holds all ~385 decks in memory at once.
  static const slidesDir = 'assets/study/slides';

  Map<int, List<String>>? _highlights;
  List<QuizBank>? _banks;
  List<ModuleSection>? _sections;
  Map<String, String>? _subtopicText;
  final Map<int, SlideDeck?> _slideCache = {};

  /// Pre-extracted plain text for a subtopic, keyed by its start page.
  /// Used to ground AI-generated quizzes/cases. '' if unavailable.
  Future<String> subtopicText(int startPage) async {
    if (_subtopicText == null) {
      try {
        final raw = await rootBundle.loadString(subtopicTextAsset);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final map = (json['text'] as Map<String, dynamic>?) ?? const {};
        _subtopicText = {
          for (final e in map.entries) e.key: e.value as String,
        };
      } catch (_) {
        _subtopicText = {};
      }
    }
    return _subtopicText![startPage.toString()] ?? '';
  }

  /// The generated slide deck for a subtopic (by its start page), or null when
  /// its file hasn't been authored yet. Each deck is its own asset
  /// (`assets/study/slides/<startPage>.json`) loaded and cached on demand.
  Future<SlideDeck?> slideDeck(int startPage) async {
    if (_slideCache.containsKey(startPage)) return _slideCache[startPage];
    SlideDeck? deck;
    try {
      final raw = await rootBundle.loadString('$slidesDir/$startPage.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      deck = SlideDeck.fromJson(startPage, json);
      if (deck.isEmpty) deck = null;
    } catch (_) {
      deck = null;
    }
    _slideCache[startPage] = deck;
    return deck;
  }

  /// The section -> subtopic -> page-range outline extracted from the PDF.
  Future<List<ModuleSection>> loadSections() async {
    if (_sections != null) return _sections!;
    try {
      final raw = await rootBundle.loadString(structureAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _sections = [
        for (final s in (json['sections'] as List? ?? const []))
          ModuleSection.fromJson(s as Map<String, dynamic>),
      ];
    } catch (_) {
      _sections = [];
    }
    return _sections!;
  }

  Future<Map<int, List<String>>> _loadHighlights() async {
    if (_highlights != null) return _highlights!;
    try {
      final raw = await rootBundle.loadString(highlightsAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final pages = (json['pages'] as Map<String, dynamic>?) ?? const {};
      _highlights = {
        for (final e in pages.entries)
          int.parse(e.key): [for (final a in (e.value as List)) a as String],
      };
    } catch (_) {
      // Asset missing or malformed: behave as "no curated highlights".
      _highlights = {};
    }
    return _highlights!;
  }

  /// Curated highlight anchors for [page], or null if the page is not in the
  /// curated set (callers may then fall back to the local summarizer).
  /// An empty list means "curated, but nothing worth highlighting here".
  Future<List<String>?> anchorsForPage(int page) async {
    final map = await _loadHighlights();
    return map[page];
  }

  /// Flat list of every subtopic title across all sections (for seeding
  /// AI-generated clinical cases / quizzes). Empty if structure unavailable.
  Future<List<String>> allSubtopicTitles() async {
    final sections = await loadSections();
    return [
      for (final s in sections)
        for (final sub in s.subtopics) sub.title,
    ];
  }

  /// All per-topic quiz banks, grounded in the module. Empty if unavailable.
  Future<List<QuizBank>> loadQuizBanks() async {
    if (_banks != null) return _banks!;
    try {
      final raw = await rootBundle.loadString(quizzesAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final banks = (json['banks'] as List?) ?? const [];
      _banks = [
        for (final b in banks) QuizBank.fromJson(b as Map<String, dynamic>),
      ];
    } catch (_) {
      _banks = [];
    }
    return _banks!;
  }
}
