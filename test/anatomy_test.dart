import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rn_ready/features/anatomy/anatomy_data.dart';
import 'package:rn_ready/features/anatomy/anatomy_painters.dart';

void main() {
  test('every anatomy diagram is well-formed', () {
    expect(kAnatomyDiagrams.length, greaterThanOrEqualTo(8));
    for (final d in kAnatomyDiagrams) {
      expect(d.parts.length, greaterThanOrEqualTo(4),
          reason: '${d.name} needs enough parts to make a quiz');
      // A painter must exist for every diagram id.
      expect(anatomyPainter(d.id, Colors.black, Colors.blue), isNotNull,
          reason: 'missing painter for ${d.id}');
      for (final p in d.parts) {
        expect(p.x, inInclusiveRange(0.0, 1.0));
        expect(p.y, inInclusiveRange(0.0, 1.0));
        expect(p.label.trim(), isNotEmpty);
      }
    }
  });

  test('part matching is fuzzy and synonym-aware', () {
    final heart = kAnatomyDiagrams.firstWhere((d) => d.id == 'heart');
    final svc = heart.parts.firstWhere((p) => p.label == 'Superior vena cava');
    expect(svc.matches('  superior VENA cava.'), isTrue);
    expect(svc.matches('SVC'), isTrue);
    expect(svc.matches('aorta'), isFalse);
  });
}
