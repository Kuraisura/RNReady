import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/organic_route.dart';
import '../../core/widgets/offline_view.dart';
import '../../data/models/module_structure.dart';
import '../../data/services/llm_service.dart';
import 'mcq_models.dart';
import 'mcq_quiz_screen.dart';
import 'quiz_generator_service.dart';

/// Shared quiz generator used by both the Practice Quizzes list and the
/// in-module "take a quiz" action.
final quizGeneratorProvider =
    Provider((_) => QuizGeneratorService(LlmService()));

/// Generates (online, fresh) or loads (offline, cached) a quiz for [sub],
/// shuffles it, and pushes the quiz screen. Shows a blocking spinner while
/// working and an offline sheet if there's nothing to play. Safe to call from
/// any widget with a [WidgetRef].
///
/// [types] restricts the question formats (empty = a mix of all four). The full
/// generated/cached pool is played (no cap) so the quiz covers the whole
/// subtopic, and the score is recorded against the subtopic for progress.
Future<void> launchSubtopicQuiz(
  BuildContext context,
  WidgetRef ref,
  Subtopic sub, {
  Set<QuizType> types = const {},
}) async {
  final gen = ref.read(quizGeneratorProvider);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  // Blocking progress dialog.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _GeneratingDialog(),
  );

  List<QuizQuestion> qs;
  try {
    try {
      qs = await gen.generate(
          title: sub.title, startPage: sub.startPage, types: types);
    } on OfflineException {
      final cached = await gen.cached(sub.startPage);
      if (cached == null || cached.isEmpty) {
        navigator.pop(); // dismiss spinner
        if (context.mounted) _showOfflineSheet(context);
        return;
      }
      qs = cached;
    }
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_friendlyError(e)),
      duration: const Duration(seconds: 6),
    ));
    return;
  }

  navigator.pop(); // dismiss spinner

  // Keep only the requested formats; fall back to the full pool if the filter
  // leaves nothing (e.g. an offline cache without that type yet).
  var pool = _filterByTypes(qs, types);
  if (pool.isEmpty) pool = qs;

  if (pool.isEmpty) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Could not build a quiz. Try again.')));
    return;
  }
  // No cap — play the whole pool so the subtopic is fully covered.
  final play = prepareForPlay(pool);
  final minutes = play.length.clamp(5, 90);
  navigator.push(OrganicRoute(McqQuizScreen(
    questions: play,
    timeLimit: Duration(minutes: minutes),
    subtopicPage: sub.startPage,
    subtopicTitle: sub.title,
  )));
}

/// Filters [qs] to the requested [types]. An empty set means "all types".
List<QuizQuestion> _filterByTypes(
    List<QuizQuestion> qs, Set<QuizType> types) {
  if (types.isEmpty) return qs;
  return [for (final q in qs) if (types.contains(q.type)) q];
}

void _showOfflineSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => const SizedBox(
      height: 260,
      child: OfflineView(
        message: 'This subtopic has no saved quiz yet. Connect once to '
            'generate it, then it works offline.',
      ),
    ),
  );
}

String _friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('All AI providers failed')) {
    return 'Quiz generation failed after trying Groq, Gemini, and OpenRouter. Check your keys and try again.';
  }
  if (s.length > 160) return 'Quiz generation failed. ${s.substring(0, 160)}…';
  return 'Quiz generation failed. $s';
}

class _GeneratingDialog extends StatefulWidget {
  const _GeneratingDialog();
  @override
  State<_GeneratingDialog> createState() => _GeneratingDialogState();
}

class _GeneratingDialogState extends State<_GeneratingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 24, 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.08).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Building your quiz', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Trying Groq, then Gemini, then OpenRouter',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
