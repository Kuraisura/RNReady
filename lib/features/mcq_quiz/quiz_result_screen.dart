import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'mcq_models.dart';
import 'quiz_result.dart';

class QuizResultScreen extends StatelessWidget {
  final QuizResult result;
  const QuizResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = passed ? AppPalette.emerald : AppPalette.danger;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 12),
                  // ── Animated score ring ──
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: result.percent),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, _) => SizedBox(
                        width: 180,
                        height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(180, 180),
                              painter: _RingPainter(
                                  value, accent, scheme.surfaceContainerHighest),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${(value * 100).round()}%',
                                    style: text.displayMedium
                                        ?.copyWith(color: accent)),
                                Text('Score', style: text.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Verdict ──
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (_, t, child) => Opacity(opacity: t, child: child),
                      child: Column(children: [
                        Icon(passed ? Icons.verified : Icons.refresh,
                            color: accent, size: 40),
                        const SizedBox(height: 8),
                        Text(passed ? 'You Passed! 🎉' : 'Keep Studying 💪',
                            style: text.headlineMedium),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Stat row ──
                  Row(children: [
                    _StatCard(
                        label: 'Correct',
                        value:
                            '${result.correctCount}/${result.totalQuestions}',
                        color: AppPalette.emerald),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Points',
                        value: '${result.earnedPoints}/${result.totalPoints}',
                        color: scheme.primary),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Time',
                        value: _fmt(result.timeSpent),
                        color: const Color(0xFFA78BFA)),
                  ]),
                  const SizedBox(height: 28),
                  Text('Review Answers', style: text.headlineSmall),
                  const SizedBox(height: 12),
                  // ── Per-question review ──
                  for (var i = 0; i < result.answers.length; i++)
                    _ReviewTile(index: i, answer: result.answers[i]),
                ],
              ),
            ),
            // ── Actions ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: scheme.outline),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Retry'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  _RingPainter(this.progress, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    const stroke = 14.0;

    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(children: [
          Text(value, style: text.titleLarge?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: text.bodySmall),
        ]),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final int index;
  final AnsweredQuestion answer;
  const _ReviewTile({required this.index, required this.answer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final correct = answer.isCorrect;
    final partial = answer.isPartial;
    final color = correct
        ? AppPalette.emerald
        : (partial ? const Color(0xFFF59E0B) : AppPalette.danger);
    final icon = correct
        ? Icons.check_circle
        : (partial ? Icons.adjust : Icons.cancel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text('Question ${index + 1}',
                style: text.titleSmall?.copyWith(color: scheme.onSurface)),
            const Spacer(),
            Text(
                '${answer.earned.toStringAsFixed(answer.earned.truncateToDouble() == answer.earned ? 0 : 1)}'
                '/${answer.question.points}',
                style: text.labelMedium?.copyWith(color: color)),
          ]),
          const SizedBox(height: 8),
          Text(answer.question.prompt, style: text.bodyMedium),
          const SizedBox(height: 10),
          _ReviewAnswers(answer: answer, color: color),
          if (answer.question.rationale != null &&
              answer.question.rationale!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rationale',
                      style: text.labelSmall?.copyWith(
                          color: scheme.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(answer.question.rationale!,
                      style: text.bodySmall?.copyWith(height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the "your answer vs. correct" block for any question type.
class _ReviewAnswers extends StatelessWidget {
  final AnsweredQuestion answer;
  final Color color;
  const _ReviewAnswers({required this.answer, required this.color});

  @override
  Widget build(BuildContext context) {
    return switch (answer.question) {
      McqQuestion q => _mcq(context, q),
      IdentificationQuestion q => _identification(context, q),
      EnumerationQuestion q => _enumeration(context, q),
      MatchingQuestion q => _matching(context, q),
    };
  }

  Widget _line(BuildContext context, String label, String value, Color c) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: text.bodyMedium,
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
                text: value,
                style: text.bodyMedium
                    ?.copyWith(color: c, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _mcq(BuildContext context, McqQuestion q) {
    final r = answer.response;
    final picked = r is int ? q.options[r] : 'No answer';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(context, 'Your answer', picked, color),
        if (!answer.isCorrect)
          _line(context, 'Correct', q.options[q.correctIndex],
              AppPalette.emerald),
      ],
    );
  }

  Widget _identification(BuildContext context, IdentificationQuestion q) {
    final r = answer.response;
    final typed = (r is String && r.trim().isNotEmpty) ? r : 'No answer';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(context, 'Your answer', typed, color),
        if (!answer.isCorrect)
          _line(context, 'Accepted', q.canonical, AppPalette.emerald),
      ],
    );
  }

  Widget _enumeration(BuildContext context, EnumerationQuestion q) {
    final r = answer.response;
    final given = r is List
        ? [
            for (final e in r)
              if (e is String && e.trim().isNotEmpty) e.trim()
          ]
        : <String>[];
    final givenNorm = {for (final g in given) normalizeAnswer(g)};
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Required items:', style: text.bodyMedium),
        const SizedBox(height: 4),
        for (final variants in q.items)
          Builder(builder: (context) {
            final got =
                variants.any((v) => givenNorm.contains(normalizeAnswer(v)));
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(children: [
                Icon(got ? Icons.check : Icons.close,
                    size: 16,
                    color: got ? AppPalette.emerald : AppPalette.danger),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(variants.first, style: text.bodyMedium)),
              ]),
            );
          }),
      ],
    );
  }

  Widget _matching(BuildContext context, MatchingQuestion q) {
    final r = answer.response;
    final picks = r is Map ? Map<int, int>.from(r) : <int, int>{};
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < q.lefts.length; i++)
          Builder(builder: (context) {
            final chosen = picks[i];
            final right = q.correctPairs[i];
            final ok = chosen == right;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(ok ? Icons.check : Icons.close,
                        size: 16,
                        color: ok ? AppPalette.emerald : AppPalette.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${q.lefts[i]} → '
                        '${chosen is int && chosen < q.rights.length ? q.rights[chosen] : "—"}',
                        style: text.bodyMedium?.copyWith(
                            color: ok ? AppPalette.emerald : color),
                      ),
                    ),
                  ]),
                  if (!ok)
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Text('Correct: ${q.rights[right]}',
                          style: text.bodySmall
                              ?.copyWith(color: AppPalette.emerald)),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
