import 'package:flutter/material.dart';

import '../mcq_quiz/mcq_models.dart' show normalizeAnswer;

/// One labeled point on an anatomy diagram. [x]/[y] are normalized (0..1)
/// positions inside the diagram's drawing box, where the leader dot is placed.
class AnatomyPart {
  final String label; // canonical correct answer (shown when revealed)
  final double x;
  final double y;
  final List<String> accepted; // extra accepted spellings/synonyms

  const AnatomyPart(
    this.label,
    this.x,
    this.y, {
    this.accepted = const [],
  });

  /// True if [answer] matches the label or any accepted synonym (fuzzy).
  bool matches(String answer) {
    final got = normalizeAnswer(answer);
    if (got.isEmpty) return false;
    if (normalizeAnswer(label) == got) return true;
    for (final a in accepted) {
      if (normalizeAnswer(a) == got) return true;
    }
    return false;
  }
}

/// A labelable anatomy structure: either a real bundled illustration
/// ([imageAsset]) or, as a fallback, the vector diagram drawn by the painter
/// registered under [id]. Plus the parts the student must identify.
class AnatomyDiagram {
  final String id; // also the painter key
  final String name; // "The Heart"
  final String system; // "Cardiovascular"
  final IconData icon;
  final List<AnatomyPart> parts;

  /// Bundled real illustration, e.g. 'assets/images/anatomy/heart.png'. When
  /// null the vector painter for [id] is drawn instead.
  final String? imageAsset;

  /// width / height of [imageAsset]. The drawing box matches this ratio so the
  /// image fills it without distortion and part coords (0..1) stay aligned.
  final double imageAspect;

  /// Attribution line shown under the diagram (required for CC-BY sources;
  /// null for public-domain plates that need none).
  final String? credit;

  const AnatomyDiagram({
    required this.id,
    required this.name,
    required this.system,
    required this.icon,
    required this.parts,
    this.imageAsset,
    this.imageAspect = 1,
    this.credit,
  });
}
