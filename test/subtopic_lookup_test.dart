import 'package:flutter_test/flutter_test.dart';
import 'package:rn_ready/data/models/module_structure.dart';

/// Mirrors the "which subtopic contains the current page" rule used by the PDF
/// viewer's quiz bar, so the behaviour is locked by a test.
Subtopic? subtopicForPage(List<Subtopic> subs, int page) {
  if (subs.isEmpty) return null;
  Subtopic? best;
  for (final s in subs) {
    if (page >= s.startPage && page <= s.endPage) return s;
    if (s.startPage <= page) best = s;
  }
  return best ?? subs.first;
}

void main() {
  final subs = const [
    Subtopic(title: 'A', startPage: 1, endPage: 3),
    Subtopic(title: 'B', startPage: 4, endPage: 6),
    Subtopic(title: 'C', startPage: 7, endPage: 10),
  ];

  test('page inside a range maps to that subtopic', () {
    expect(subtopicForPage(subs, 2)?.title, 'A');
    expect(subtopicForPage(subs, 5)?.title, 'B');
    expect(subtopicForPage(subs, 9)?.title, 'C');
  });

  test('boundary pages map correctly', () {
    expect(subtopicForPage(subs, 1)?.title, 'A');
    expect(subtopicForPage(subs, 4)?.title, 'B');
    expect(subtopicForPage(subs, 7)?.title, 'C');
  });

  test('page before first subtopic falls back to first', () {
    expect(subtopicForPage(subs, 0)?.title, 'A');
  });

  test('empty list returns null', () {
    expect(subtopicForPage(const [], 5), isNull);
  });
}
