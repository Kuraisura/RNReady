/// Slide-deck model for the generated, PowerPoint-style study modules.
///
/// Decks are produced offline by `tool/generate_slides.py` from the extracted
/// PDF text and bundled as `assets/study/module_slides.json`. At runtime they
/// are loaded via `StudyContentService.slideDeck()` and rendered by
/// `ModuleSlidesScreen`.
///
/// JSON back-compat: a slide with an unknown/missing `type` is treated as a
/// bullets slide, mirroring how `mcq_models` defaults unknown question types.
library;

/// One subtopic's deck.
class SlideDeck {
  /// Subtopic start page — the same id used everywhere else (quiz cache,
  /// progress store, `subtopic_text.json`).
  final int page;
  final String title;
  final List<Slide> slides;

  const SlideDeck({
    required this.page,
    required this.title,
    required this.slides,
  });

  factory SlideDeck.fromJson(int page, Map<String, dynamic> j) => SlideDeck(
        page: page,
        title: (j['title'] as String?)?.trim() ?? '',
        slides: [
          for (final s in (j['slides'] as List? ?? const []))
            if (s is Map<String, dynamic>) Slide.fromJson(s),
        ],
      );

  bool get isEmpty => slides.isEmpty;
}

enum SlideType { title, bullets, table, terms, summary }

SlideType _typeFromString(String? raw) {
  switch (raw) {
    case 'title':
      return SlideType.title;
    case 'table':
      return SlideType.table;
    case 'terms':
      return SlideType.terms;
    case 'summary':
      return SlideType.summary;
    case 'bullets':
    default:
      return SlideType.bullets;
  }
}

/// Base class for every slide. Holds the common heading and the type tag.
sealed class Slide {
  final SlideType type;
  final String heading;

  const Slide({required this.type, required this.heading});

  factory Slide.fromJson(Map<String, dynamic> j) {
    final type = _typeFromString(j['type'] as String?);
    final heading = (j['heading'] as String?)?.trim() ?? '';
    switch (type) {
      case SlideType.title:
        return TitleSlide(
          heading: heading,
          subtitle: (j['subtitle'] as String?)?.trim() ?? '',
        );
      case SlideType.table:
        return TableSlide(
          heading: heading,
          columns: _strList(j['columns']),
          rows: [
            for (final r in (j['rows'] as List? ?? const [])) _strList(r),
          ],
        );
      case SlideType.terms:
        return TermsSlide(
          heading: heading.isEmpty ? 'Key Terms' : heading,
          terms: [
            for (final t in (j['terms'] as List? ?? const []))
              if (t is Map)
                TermItem(
                  term: _str(t['term']),
                  definition: _str(t['definition']),
                ),
          ],
        );
      case SlideType.summary:
        return SummarySlide(
          heading: heading.isEmpty ? 'Key Takeaways' : heading,
          bullets: _strList(j['bullets']),
        );
      case SlideType.bullets:
        return BulletsSlide(heading: heading, bullets: _strList(j['bullets']));
    }
  }
}

/// Cover slide: a big heading and an optional one-line subtitle.
class TitleSlide extends Slide {
  final String subtitle;
  const TitleSlide({required super.heading, required this.subtitle})
      : super(type: SlideType.title);
}

/// A heading with concise bullet points.
class BulletsSlide extends Slide {
  final List<String> bullets;
  const BulletsSlide({required super.heading, required this.bullets})
      : super(type: SlideType.bullets);
}

/// A real table preserved from the source (rendered as a scrollable grid).
class TableSlide extends Slide {
  final List<String> columns;
  final List<List<String>> rows;
  const TableSlide({
    required super.heading,
    required this.columns,
    required this.rows,
  }) : super(type: SlideType.table);
}

/// Key-term / definition pairs.
class TermsSlide extends Slide {
  final List<TermItem> terms;
  const TermsSlide({required super.heading, required this.terms})
      : super(type: SlideType.terms);
}

/// Closing recap bullets.
class SummarySlide extends Slide {
  final List<String> bullets;
  const SummarySlide({required super.heading, required this.bullets})
      : super(type: SlideType.summary);
}

class TermItem {
  final String term;
  final String definition;
  const TermItem({required this.term, required this.definition});
}

// ── coercion helpers (tolerant of stray JSON shapes) ────────────────────────

String _str(Object? v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  return v.toString().trim();
}

List<String> _strList(Object? v) {
  if (v is List) {
    return [
      for (final e in v)
        if (_str(e).isNotEmpty) _str(e),
    ];
  }
  final s = _str(v);
  return s.isEmpty ? const [] : [s];
}
