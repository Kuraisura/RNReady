import '../../data/services/llm_service.dart';
import '../../data/services/study_content_service.dart';

/// Generates an unlimited stream of fresh clinical-case scenarios, each seeded
/// by a random subtopic drawn from the reviewer's structure so cases stay
/// grounded in the actual board-exam content.
class ClinicalCaseService {
  ClinicalCaseService(this._llm);
  final LlmService _llm;

  /// Rotating index so successive cases avoid repeating the same subtopic.
  int _cursor = 0;

  /// Produces one new scenario prompt. Throws [OfflineException] when offline.
  /// [focus] (from a [ClinicalCategory]) steers the scenario type; empty = any.
  Future<String> generate({String focus = ''}) async {
    final topics = await StudyContentService.instance.allSubtopicTitles();
    final seed = topics.isEmpty
        ? 'general medical-surgical nursing'
        : topics[(_cursor++ * 7919) % topics.length];

    final focusLine =
        focus.trim().isEmpty ? '' : '\n\nFOCUS FOR THIS CASE: ${focus.trim()}';

    final raw = await _llm.chat(
      temperature: 0.9, // high → varied scenarios each call
      [
        {
          'role': 'system',
          'content':
              'You are an item writer for the Philippine Nurse Licensure Exam. '
                  'Write ONE realistic clinical scenario (3–5 sentences) that '
                  'tests prioritization, safety, or ethical judgment. End with a '
                  'single clear question asking what the nurse should do. '
                  'Output ONLY the scenario and question — no answer, no labels, '
                  'no preamble.'
        },
        {
          'role': 'user',
          'content': 'Topic to base the case on: $seed$focusLine',
        },
      ],
    );
    return raw.trim();
  }
}
