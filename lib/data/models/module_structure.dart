import 'package:flutter/material.dart';

/// One fine-grained subtopic inside a section, mapped to a PDF page range.
class Subtopic {
  final String title;
  final int startPage;
  final int endPage;
  const Subtopic({
    required this.title,
    required this.startPage,
    required this.endPage,
  });

  factory Subtopic.fromJson(Map<String, dynamic> j) => Subtopic(
        title: j['title'] as String,
        startPage: (j['startPage'] as num).toInt(),
        endPage: (j['endPage'] as num).toInt(),
      );
}

/// One major NURSING PRACTICE section, its page range, accent colour, and the
/// subtopics extracted from the coloured heading bands.
class ModuleSection {
  final String title;
  final int startPage;
  final int endPage;
  final Color color;
  final List<Subtopic> subtopics;
  const ModuleSection({
    required this.title,
    required this.startPage,
    required this.endPage,
    required this.color,
    required this.subtopics,
  });

  factory ModuleSection.fromJson(Map<String, dynamic> j) => ModuleSection(
        title: j['title'] as String,
        startPage: (j['startPage'] as num).toInt(),
        endPage: (j['endPage'] as num).toInt(),
        color: _hexColor(j['color'] as String?),
        subtopics: [
          for (final s in (j['subtopics'] as List? ?? const []))
            Subtopic.fromJson(s as Map<String, dynamic>),
        ],
      );

  int get pageCount => endPage - startPage + 1;
}

Color _hexColor(String? hex) {
  if (hex == null || !hex.startsWith('#') || hex.length != 7) {
    return const Color(0xFF5EEAD4);
  }
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
