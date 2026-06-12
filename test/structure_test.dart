import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rn_ready/data/models/module_structure.dart';

void main() {
  test('module_structure.json parses into 6 sections with subtopics', () {
    final raw =
        File('assets/study/module_structure.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final sections = [
      for (final s in (json['sections'] as List))
        ModuleSection.fromJson(s as Map<String, dynamic>),
    ];
    expect(sections.length, 6);
    // Every section has a page range and at least one subtopic.
    for (final s in sections) {
      expect(s.subtopics, isNotEmpty);
      expect(s.startPage, lessThanOrEqualTo(s.endPage));
      for (final sub in s.subtopics) {
        expect(sub.title.trim(), isNotEmpty);
        expect(sub.startPage, inInclusiveRange(s.startPage, s.endPage));
        expect(sub.startPage, lessThanOrEqualTo(sub.endPage));
      }
    }
    // First section is NP I starting on page 1.
    expect(sections.first.title, contains('NURSING PRACTICE I'));
    expect(sections.first.startPage, 1);
  });

  test('subtopic_text.json has text for first subtopic pages', () {
    final raw = File('assets/study/subtopic_text.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final text = json['text'] as Map<String, dynamic>;
    expect(text, isNotEmpty);
    // Some entries should carry real content.
    final nonEmpty = text.values.where((v) => (v as String).length > 50);
    expect(nonEmpty.length, greaterThan(50));
  });
}
