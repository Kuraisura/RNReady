import 'dart:convert';

/// Parsed, structured Nursing Care Plan.
///
/// The AI returns JSON (see `care_plan_prompt.dart`) which we parse into this
/// model once, then render as either the stacked **card** view or the 6-column
/// **grid** view. Keeping a single source of truth means both layouts — and the
/// "Save to Notes" Markdown export — stay in sync.
class CarePlan {
  const CarePlan({required this.summary, required this.rows});

  /// A one-line restatement of the patient situation (for the Notes title and
  /// the card header). May be empty.
  final String summary;

  /// One entry per prioritized nursing diagnosis (typically 1–3).
  final List<CarePlanDiagnosis> rows;

  /// Attempts to parse the model's reply into a [CarePlan].
  ///
  /// Tolerant of the common ways an LLM wraps JSON: ```json fences, leading
  /// prose, or a trailing comma. Returns `null` when nothing usable is found so
  /// the UI can fall back to showing the raw text instead of crashing.
  static CarePlan? tryParse(String raw) {
    final jsonText = _extractJson(raw);
    if (jsonText == null) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      final rawRows = decoded['rows'];
      if (rawRows is! List || rawRows.isEmpty) return null;
      final rows = rawRows
          .whereType<Map>()
          .map(CarePlanDiagnosis.fromJson)
          .toList(growable: false);
      if (rows.isEmpty) return null;
      return CarePlan(
        summary: (decoded['summary'] as String?)?.trim() ?? '',
        rows: rows,
      );
    } catch (_) {
      return null;
    }
  }

  /// Pulls the first balanced `{...}` block out of [raw], ignoring code fences
  /// and any surrounding prose the model may have added.
  static String? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    return raw.substring(start, end + 1);
  }

  /// Renders the plan as GitHub-flavored Markdown for the Notes feature, which
  /// stores plain Markdown strings.
  String toMarkdown() {
    final b = StringBuffer();
    if (summary.isNotEmpty) b.writeln('_${summary}_\n');
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      b.writeln('## Nursing Diagnosis ${i + 1}\n');
      b.writeln('**Diagnosis:** ${r.diagnosis}\n');
      b.writeln('### Assessment');
      if (r.subjective.isNotEmpty) b.writeln('**Subjective:** ${r.subjective}\n');
      if (r.objective.isNotEmpty) b.writeln('**Objective:** ${r.objective}\n');
      b.writeln('### Outcomes');
      if (r.shortTermOutcome.isNotEmpty) {
        b.writeln('- **Short-term:** ${r.shortTermOutcome}');
      }
      if (r.longTermOutcome.isNotEmpty) {
        b.writeln('- **Long-term:** ${r.longTermOutcome}');
      }
      b.writeln('\n### Interventions & Rationale');
      for (var j = 0; j < r.interventions.length; j++) {
        final iv = r.interventions[j];
        b.writeln('${j + 1}. ${iv.action} — *Rationale:* ${iv.rationale}');
      }
      b.writeln('\n### Evaluation');
      b.writeln('${r.evaluation}\n');
    }
    return b.toString().trim();
  }
}

/// One nursing diagnosis row — the six ADPIE components shown across the
/// screenshot's columns.
class CarePlanDiagnosis {
  const CarePlanDiagnosis({
    required this.subjective,
    required this.objective,
    required this.diagnosis,
    required this.shortTermOutcome,
    required this.longTermOutcome,
    required this.interventions,
    required this.evaluation,
  });

  final String subjective;
  final String objective;
  final String diagnosis;
  final String shortTermOutcome;
  final String longTermOutcome;
  final List<Intervention> interventions;
  final String evaluation;

  factory CarePlanDiagnosis.fromJson(Map json) {
    final rawIv = json['interventions'];
    final interventions = rawIv is List
        ? rawIv.whereType<Map>().map(Intervention.fromJson).toList(growable: false)
        : const <Intervention>[];
    return CarePlanDiagnosis(
      subjective: _str(json['subjective']),
      objective: _str(json['objective']),
      diagnosis: _str(json['diagnosis']),
      shortTermOutcome: _str(json['shortTermOutcome']),
      longTermOutcome: _str(json['longTermOutcome']),
      interventions: interventions,
      evaluation: _str(json['evaluation']),
    );
  }

  /// Combined outcomes text for the single "Outcomes" grid cell.
  String get outcomes {
    final parts = <String>[
      if (shortTermOutcome.isNotEmpty) 'Short-term: $shortTermOutcome',
      if (longTermOutcome.isNotEmpty) 'Long-term: $longTermOutcome',
    ];
    return parts.join('\n\n');
  }
}

/// A single nursing action paired with its evidence-based rationale.
class Intervention {
  const Intervention({required this.action, required this.rationale});

  final String action;
  final String rationale;

  factory Intervention.fromJson(Map json) => Intervention(
        action: _str(json['action']),
        rationale: _str(json['rationale']),
      );
}

/// Coerces any JSON value to a trimmed string (numbers, nulls, nested lists all
/// become sensible text so a stray type from the model never breaks rendering).
String _str(Object? v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  if (v is List) return v.map(_str).where((s) => s.isNotEmpty).join('; ');
  return v.toString().trim();
}
