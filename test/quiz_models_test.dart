import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rn_ready/features/mcq_quiz/mcq_models.dart';

void main() {
  test('all bundled quiz banks parse without throwing', () {
    final raw = File('assets/study/ackp_quizzes.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final banks = [
      for (final b in (json['banks'] as List))
        QuizBank.fromJson(b as Map<String, dynamic>),
    ];
    expect(banks.length, greaterThanOrEqualTo(6));
    // Every question must construct and expose a non-empty prompt.
    for (final bank in banks) {
      for (final q in bank.questions) {
        expect(q.prompt.trim(), isNotEmpty);
        expect(q.points, greaterThan(0));
      }
    }
  });

  test('legacy MCQ (no type field) still parses + grades', () {
    final q = QuizQuestion.fromJson({
      'prompt': 'Pick A',
      'options': ['A. one', 'B. two'],
      'correctIndex': 0,
    });
    expect(q, isA<McqQuestion>());
    expect(q.grade(0), 1.0);
    expect(q.grade(1), 0.0);
    expect(q.isAnswered(null), isFalse);
  });

  test('identification grades case/punctuation-insensitively', () {
    final q = QuizQuestion.fromJson({
      'type': 'identification',
      'answer': 'Kwashiorkor',
      'accepted': ['kwashiorkor'],
      'prompt': 'name it',
    }) as IdentificationQuestion;
    expect(q.grade('  KWASHIORKOR. '), 1.0);
    expect(q.grade('marasmus'), 0.0);
  });

  test('enumeration awards proportional partial credit', () {
    final q = QuizQuestion.fromJson({
      'type': 'enumeration',
      'prompt': 'list 3',
      'items': [
        ['Varicella', 'Chickenpox'],
        ['OPV'],
        ['MMR'],
      ],
      'count': 3,
      'points': 3,
    }) as EnumerationQuestion;
    expect(q.grade(['chickenpox', 'opv', 'mmr']), 3.0); // synonym + all
    expect(q.grade(['varicella', 'wrong', 'opv']), closeTo(2.0, 0.001));
    expect(q.grade(['opv', 'opv', 'opv']), closeTo(1.0, 0.001)); // no double
  });

  test('matching awards per-correct-pair credit', () {
    final q = QuizQuestion.fromJson({
      'type': 'matching',
      'prompt': 'match',
      'pairs': [
        {'left': 'Primary', 'right': 'Immunization'},
        {'left': 'Secondary', 'right': 'Early treatment'},
      ],
      'points': 2,
    }) as MatchingQuestion;
    expect(q.grade({0: 0, 1: 1}), 2.0); // both right (diagonal)
    expect(q.grade({0: 1, 1: 0}), 0.0); // both swapped
    expect(q.grade({0: 0, 1: 0}), closeTo(1.0, 0.001)); // one right
  });

  test('shuffling MCQ options keeps the correct answer correct', () {
    final q = McqQuestion(
      prompt: 'pick',
      options: ['A. right', 'B. wrong1', 'C. wrong2', 'D. wrong3'],
      correctIndex: 0,
    );
    // Try many seeds: the option text labelled "right" must always be the
    // one at the (remapped) correctIndex, and labels are stripped.
    for (var seed = 0; seed < 50; seed++) {
      final s = q.shuffledOptions(Random(seed));
      expect(s.options[s.correctIndex], 'right');
      expect(s.options.every((o) => !o.startsWith('A.')), isTrue);
      expect(s.grade(s.correctIndex), 1.0);
    }
  });

  test('prepareForPlay caps and preserves correctness', () {
    final qs = [
      for (var i = 0; i < 20; i++)
        McqQuestion(
          prompt: 'q$i',
          options: ['A. correct$i', 'B. x', 'C. y'],
          correctIndex: 0,
        ),
    ];
    final play = prepareForPlay(qs, max: 10, random: Random(1));
    expect(play.length, 10);
    for (final q in play) {
      expect((q as McqQuestion).grade(q.correctIndex), 1.0);
    }
  });
}
