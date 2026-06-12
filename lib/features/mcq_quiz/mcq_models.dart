/// Quiz question model family.
///
/// One quiz bank can mix four formats: multiple-choice, identification,
/// enumeration, and matching. Every type is graded **on-device** (no AI, no
/// network), so quizzes stay free and work offline.
///
/// JSON back-compat: a question with no `"type"` field is treated as
/// multiple-choice, so the original 5 banks keep parsing unchanged.
library;

import 'dart:math';

/// Strips a leading option label like "A. " / "b) " so options can be safely
/// reordered without the letters going out of sequence.
String stripOptionLabel(String s) =>
    s.replaceFirst(RegExp(r'^\s*[A-Da-d][\.\)]\s*'), '').trim();

/// Returns a play-ready copy of [questions]: the question order is shuffled,
/// and each multiple-choice question's options are shuffled (with the correct
/// index remapped). Other types are returned unchanged. Pass [max] to cap how
/// many questions are taken. Call this on every attempt so a cached quiz still
/// feels fresh.
List<QuizQuestion> prepareForPlay(
  List<QuizQuestion> questions, {
  int? max,
  Random? random,
}) {
  final r = random ?? Random();
  final list = [...questions]..shuffle(r);
  final taken =
      (max != null && max < list.length) ? list.sublist(0, max) : list;
  return [
    for (final q in taken)
      if (q is McqQuestion) q.shuffledOptions(r) else q,
  ];
}

/// Shared, forgiving text comparison for free-text answers:
/// lowercase, trim, collapse whitespace, drop surrounding punctuation.
/// Lets "St. Elevation" match "st elevation" and "Marasmus." match "marasmus".
String normalizeAnswer(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

enum QuizType { multipleChoice, identification, enumeration, matching }

QuizType _typeFromString(String? raw) {
  switch (raw) {
    case 'identification':
      return QuizType.identification;
    case 'enumeration':
      return QuizType.enumeration;
    case 'matching':
      return QuizType.matching;
    case 'mcq':
    case 'multipleChoice':
    case null:
      return QuizType.multipleChoice;
    default:
      return QuizType.multipleChoice;
  }
}

/// Base class for every quiz question. Holds the fields common to all formats
/// and the grading contract.
sealed class QuizQuestion {
  final QuizType type;
  final String prompt;
  final int points;
  final String? rationale;
  final String? topic;

  const QuizQuestion({
    required this.type,
    required this.prompt,
    required this.points,
    this.rationale,
    this.topic,
  });

  /// Earned points for [response] (0..points), allowing partial credit.
  /// [response] shape depends on the concrete type — see each subclass.
  double grade(Object? response);

  /// True when [response] is "complete enough" to advance (used to gate Next).
  bool isAnswered(Object? response);

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    final type = _typeFromString(j['type'] as String?);
    switch (type) {
      case QuizType.multipleChoice:
        return McqQuestion.fromJson(j);
      case QuizType.identification:
        return IdentificationQuestion.fromJson(j);
      case QuizType.enumeration:
        return EnumerationQuestion.fromJson(j);
      case QuizType.matching:
        return MatchingQuestion.fromJson(j);
    }
  }
}

/// Multiple-choice: pick one option. [response] is an `int?` option index.
class McqQuestion extends QuizQuestion {
  final List<String> options;
  final int correctIndex;

  const McqQuestion({
    required super.prompt,
    required this.options,
    required this.correctIndex,
    super.points = 1,
    super.rationale,
    super.topic,
  }) : super(type: QuizType.multipleChoice);

  @override
  double grade(Object? response) =>
      (response is int && response == correctIndex) ? points.toDouble() : 0;

  @override
  bool isAnswered(Object? response) => response is int;

  /// A copy with options reordered (labels stripped) and [correctIndex]
  /// remapped — so repeated plays don't always have the answer in slot A.
  McqQuestion shuffledOptions(Random r) {
    final order = List<int>.generate(options.length, (i) => i)..shuffle(r);
    return McqQuestion(
      prompt: prompt,
      options: [for (final i in order) stripOptionLabel(options[i])],
      correctIndex: order.indexOf(correctIndex),
      points: points,
      rationale: rationale,
      topic: topic,
    );
  }

  factory McqQuestion.fromJson(Map<String, dynamic> j) => McqQuestion(
        prompt: j['prompt'] as String,
        options: [for (final o in (j['options'] as List)) o as String],
        correctIndex: (j['correctIndex'] as num).toInt(),
        points: (j['points'] as num?)?.toInt() ?? 1,
        rationale: j['rationale'] as String?,
        topic: j['topic'] as String?,
      );
}

/// Identification: type the one correct term. Any entry in [accepted] (e.g.
/// synonyms / spellings) counts. [response] is a `String`.
class IdentificationQuestion extends QuizQuestion {
  /// First entry is treated as the canonical answer for display.
  final List<String> accepted;

  const IdentificationQuestion({
    required super.prompt,
    required this.accepted,
    super.points = 1,
    super.rationale,
    super.topic,
  }) : super(type: QuizType.identification);

  String get canonical => accepted.isEmpty ? '' : accepted.first;

  @override
  double grade(Object? response) {
    if (response is! String) return 0;
    final got = normalizeAnswer(response);
    if (got.isEmpty) return 0;
    for (final a in accepted) {
      if (normalizeAnswer(a) == got) return points.toDouble();
    }
    return 0;
  }

  @override
  bool isAnswered(Object? response) =>
      response is String && response.trim().isNotEmpty;

  factory IdentificationQuestion.fromJson(Map<String, dynamic> j) {
    // Accept either `"accepted": [...]` or a single `"answer": "..."`.
    final accepted = <String>[
      if (j['answer'] != null) j['answer'] as String,
      for (final a in (j['accepted'] as List? ?? const [])) a as String,
    ];
    return IdentificationQuestion(
      prompt: j['prompt'] as String,
      accepted: accepted,
      points: (j['points'] as num?)?.toInt() ?? 1,
      rationale: j['rationale'] as String?,
      topic: j['topic'] as String?,
    );
  }
}

/// Enumeration: list several required items in any order. Partial credit is
/// awarded per correct, non-duplicate item. [response] is a `List<String>`.
class EnumerationQuestion extends QuizQuestion {
  /// Each accepted item is itself a list of acceptable variants/synonyms.
  final List<List<String>> items;

  /// How many blanks to show. Defaults to the number of items.
  final int count;

  const EnumerationQuestion({
    required super.prompt,
    required this.items,
    required this.count,
    super.points = 1,
    super.rationale,
    super.topic,
  }) : super(type: QuizType.enumeration);

  /// Canonical (first-variant) label for each required item, for review.
  List<String> get canonicalItems =>
      [for (final variants in items) variants.isEmpty ? '' : variants.first];

  @override
  double grade(Object? response) {
    if (response is! List || items.isEmpty) return 0;
    final given = <String>{
      for (final r in response)
        if (r is String && normalizeAnswer(r).isNotEmpty) normalizeAnswer(r),
    };
    var matched = 0;
    final used = <int>{};
    for (final g in given) {
      for (var i = 0; i < items.length; i++) {
        if (used.contains(i)) continue;
        if (items[i].any((v) => normalizeAnswer(v) == g)) {
          used.add(i);
          matched++;
          break;
        }
      }
    }
    // Proportional partial credit across the full point value.
    return points * (matched / items.length);
  }

  @override
  bool isAnswered(Object? response) =>
      response is List &&
      response.any((r) => r is String && r.trim().isNotEmpty);

  factory EnumerationQuestion.fromJson(Map<String, dynamic> j) {
    final items = <List<String>>[
      for (final item in (j['items'] as List? ?? const []))
        if (item is String)
          [item]
        else
          [for (final v in (item as List)) v as String],
    ];
    return EnumerationQuestion(
      prompt: j['prompt'] as String,
      items: items,
      count: (j['count'] as num?)?.toInt() ?? items.length,
      points: (j['points'] as num?)?.toInt() ?? items.length,
      rationale: j['rationale'] as String?,
      topic: j['topic'] as String?,
    );
  }
}

/// Matching: pair each left prompt with the correct right option. Partial
/// credit per correct pair. [response] is a `Map<int,int>` (leftIndex →
/// rightIndex into [rights]).
class MatchingQuestion extends QuizQuestion {
  final List<String> lefts;
  final List<String> rights;

  /// correctPairs[i] = index into [rights] that matches lefts[i].
  final List<int> correctPairs;

  const MatchingQuestion({
    required super.prompt,
    required this.lefts,
    required this.rights,
    required this.correctPairs,
    super.points = 1,
    super.rationale,
    super.topic,
  }) : super(type: QuizType.matching);

  @override
  double grade(Object? response) {
    if (response is! Map || lefts.isEmpty) return 0;
    var correct = 0;
    for (var i = 0; i < lefts.length; i++) {
      final chosen = response[i];
      if (chosen is int && i < correctPairs.length && chosen == correctPairs[i]) {
        correct++;
      }
    }
    return points * (correct / lefts.length);
  }

  @override
  bool isAnswered(Object? response) =>
      response is Map && response.length == lefts.length;

  factory MatchingQuestion.fromJson(Map<String, dynamic> j) {
    final pairs = (j['pairs'] as List).cast<Map<String, dynamic>>();
    final lefts = [for (final p in pairs) p['left'] as String];
    final rights = [for (final p in pairs) p['right'] as String];
    // Default correct pairing is identity (left i ↔ right i); the UI shuffles
    // the right column for display, so storage order stays aligned.
    final correctPairs = [
      for (var i = 0; i < pairs.length; i++)
        (pairs[i]['match'] as num?)?.toInt() ?? i
    ];
    return MatchingQuestion(
      prompt: j['prompt'] as String,
      lefts: lefts,
      rights: rights,
      correctPairs: correctPairs,
      points: (j['points'] as num?)?.toInt() ?? pairs.length,
      rationale: j['rationale'] as String?,
      topic: j['topic'] as String?,
    );
  }
}

/// A per-topic collection of questions drawn from one area of the module.
class QuizBank {
  final String id;
  final String title;
  final List<QuizQuestion> questions;
  QuizBank({required this.id, required this.title, required this.questions});

  factory QuizBank.fromJson(Map<String, dynamic> j) => QuizBank(
        id: j['id'] as String,
        title: j['title'] as String,
        questions: [
          for (final q in (j['questions'] as List))
            QuizQuestion.fromJson(q as Map<String, dynamic>),
        ],
      );
}
