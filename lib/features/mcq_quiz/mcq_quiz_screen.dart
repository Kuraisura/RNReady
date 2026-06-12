import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/animations/organic_route.dart';
import '../../core/widgets/glass_card.dart';
import 'mcq_models.dart';
import 'quiz_progress_store.dart';
import 'quiz_result.dart';
import 'quiz_result_screen.dart';

/// Plays a quiz bank that may mix four question formats. Each question's answer
/// is stored as a generic `Object?` in [_responses], shaped per type:
///   • MCQ            → int (option index)
///   • Identification → String
///   • Enumeration    → `List<String>`
///   • Matching       → `Map<int,int>`
class McqQuizScreen extends ConsumerStatefulWidget {
  final List<QuizQuestion> questions;
  final Duration timeLimit;

  /// Subtopic identity, when this quiz was launched from a specific subtopic.
  /// When set, the final score is recorded to [quizProgressProvider] so the
  /// Practice Quizzes list can show a best-score badge and section progress.
  final int? subtopicPage;
  final String? subtopicTitle;

  const McqQuizScreen({
    super.key,
    required this.questions,
    this.timeLimit = const Duration(hours: 2, minutes: 29, seconds: 29),
    this.subtopicPage,
    this.subtopicTitle,
  });

  @override
  ConsumerState<McqQuizScreen> createState() => _McqQuizScreenState();
}

class _McqQuizScreenState extends ConsumerState<McqQuizScreen> {
  int _index = 0;
  final Map<int, Object?> _responses = {}; // questionIndex -> response
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 0) {
        _timer?.cancel();
        _finish(); // auto-submit when time runs out
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeString {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get _isLast => _index == widget.questions.length - 1;

  QuizQuestion get _q => widget.questions[_index];

  bool get _currentAnswered => _q.isAnswered(_responses[_index]);

  void _setResponse(Object? value) =>
      setState(() => _responses[_index] = value);

  void _finish() {
    _timer?.cancel();
    final answered = [
      for (var i = 0; i < widget.questions.length; i++)
        AnsweredQuestion(widget.questions[i], _responses[i]),
    ];
    final result = QuizResult(answered, widget.timeLimit - _remaining);

    // Record the score for this subtopic so the list can show progress.
    if (widget.subtopicPage != null) {
      ref.read(quizProgressProvider.notifier).record(
            page: widget.subtopicPage!,
            title: widget.subtopicTitle ?? '',
            correct: result.correctCount,
            total: result.totalQuestions,
          );
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      OrganicRoute(QuizResultScreen(result: result)),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final progress = (_index + 1) / widget.questions.length;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: time limit + progress bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Time limit: $_timeString', style: text.titleMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
              ),
            ),

            // ── Sub-header: question count + type badge + points ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Question ${_index + 1} of ${widget.questions.length}',
                      style: text.titleSmall),
                  Text('${q.points} point(s)', style: text.titleSmall),
                ],
              ),
            ),

            // ── Question + type-specific input ──
            Expanded(
              child: ListView(
                // Key by index so text controllers reset between questions.
                key: ValueKey(_index),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  // Scenario card — glass surface with serif case-study prose.
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _TypeBadge(q.type),
                            const SizedBox(width: 8),
                            Text('Q${_index + 1}',
                                style: text.labelMedium
                                    ?.copyWith(color: scheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(q.prompt,
                            style: text.titleLarge?.copyWith(height: 1.45)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AnswerArea(
                    question: q,
                    response: _responses[_index],
                    onChanged: _setResponse,
                  ),
                ],
              ),
            ),

            // ── Bottom-right Next / Finish button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _currentAnswered ? _next : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    disabledBackgroundColor:
                        scheme.primary.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_isLast ? 'Finish' : 'Next',
                      style:
                          text.labelLarge?.copyWith(color: scheme.onPrimary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small coloured pill naming the question format, so the student knows what
/// kind of answer is expected.
class _TypeBadge extends StatelessWidget {
  final QuizType type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      QuizType.multipleChoice => ('MULTIPLE CHOICE', const Color(0xFF38BDF8)),
      QuizType.identification => ('IDENTIFICATION', const Color(0xFFA78BFA)),
      QuizType.enumeration => ('ENUMERATION', const Color(0xFFEC4899)),
      QuizType.matching => ('MATCHING', const Color(0xFF10B981)),
    };
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: text.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Dispatches to the correct input widget for the question type.
class _AnswerArea extends StatelessWidget {
  final QuizQuestion question;
  final Object? response;
  final ValueChanged<Object?> onChanged;
  const _AnswerArea({
    required this.question,
    required this.response,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return switch (question) {
      McqQuestion q => _McqInput(
          question: q,
          selected: response is int ? response as int : null,
          onChanged: onChanged,
        ),
      IdentificationQuestion q => _IdentificationInput(
          question: q,
          value: response is String ? response as String : '',
          onChanged: onChanged,
        ),
      EnumerationQuestion q => _EnumerationInput(
          question: q,
          values: response is List ? List<String>.from(response as List) : null,
          onChanged: onChanged,
        ),
      MatchingQuestion q => _MatchingInput(
          question: q,
          pairs: response is Map ? Map<int, int>.from(response as Map) : null,
          onChanged: onChanged,
        ),
    };
  }
}

// ─────────────────────────── Multiple choice ───────────────────────────────

class _McqInput extends StatelessWidget {
  final McqQuestion question;
  final int? selected;
  final ValueChanged<Object?> onChanged;
  const _McqInput({
    required this.question,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < question.options.length; i++)
          _OptionCard(
            label: question.options[i],
            selected: selected == i,
            onTap: () => onChanged(i),
          ),
      ],
    );
  }
}

/// Rounded card with animated border + radio.
class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color:
              selected ? scheme.primary.withValues(alpha: 0.10) : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: scheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: (text.bodyLarge ?? const TextStyle()).copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Identification ────────────────────────────────

class _IdentificationInput extends StatefulWidget {
  final IdentificationQuestion question;
  final String value;
  final ValueChanged<Object?> onChanged;
  const _IdentificationInput({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_IdentificationInput> createState() => _IdentificationInputState();
}

class _IdentificationInputState extends State<_IdentificationInput> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type your answer',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        TextField(
          controller: _c,
          textCapitalization: TextCapitalization.sentences,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: 'e.g. the condition / term…',
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outline)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outline)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Enumeration ───────────────────────────────────

class _EnumerationInput extends StatefulWidget {
  final EnumerationQuestion question;
  final List<String>? values;
  final ValueChanged<Object?> onChanged;
  const _EnumerationInput({
    required this.question,
    required this.values,
    required this.onChanged,
  });

  @override
  State<_EnumerationInput> createState() => _EnumerationInputState();
}

class _EnumerationInputState extends State<_EnumerationInput> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final n = widget.question.count;
    _controllers = List.generate(
      n,
      (i) => TextEditingController(
        text: (widget.values != null && i < widget.values!.length)
            ? widget.values![i]
            : '',
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() =>
      widget.onChanged([for (final c in _controllers) c.text]);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('List ${widget.question.count} — order does not matter',
            style: text.titleSmall),
        const SizedBox(height: 10),
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  child: Text('${i + 1}',
                      style: text.labelMedium?.copyWith(color: scheme.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controllers[i],
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _emit(),
                    decoration: InputDecoration(
                      hintText: 'Item ${i + 1}',
                      filled: true,
                      fillColor: scheme.surface,
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: scheme.outline)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: scheme.outline)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: scheme.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── Matching ──────────────────────────────────────

class _MatchingInput extends StatefulWidget {
  final MatchingQuestion question;
  final Map<int, int>? pairs;
  final ValueChanged<Object?> onChanged;
  const _MatchingInput({
    required this.question,
    required this.pairs,
    required this.onChanged,
  });

  @override
  State<_MatchingInput> createState() => _MatchingInputState();
}

class _MatchingInputState extends State<_MatchingInput> {
  late Map<int, int> _pairs;

  /// Display order for the right column. Stored rights are aligned with lefts
  /// (answer = diagonal), so we shuffle the *display* once — deterministically,
  /// seeded by the prompt — to keep it a real matching task without re-ordering
  /// on every rebuild. [_display] maps a dropdown row → storage index.
  late final List<int> _display;

  @override
  void initState() {
    super.initState();
    _pairs = widget.pairs != null ? Map<int, int>.from(widget.pairs!) : {};
    final n = widget.question.rights.length;
    _display = List.generate(n, (i) => i);
    // Fisher–Yates with a fixed seed → stable shuffle, no Math.random reliance.
    var seed = widget.question.prompt.hashCode & 0x7fffffff;
    for (var i = n - 1; i > 0; i--) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final j = seed % (i + 1);
      final tmp = _display[i];
      _display[i] = _display[j];
      _display[j] = tmp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rights = widget.question.rights;

    String letter(int i) => String.fromCharCode(65 + i); // A, B, C…

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Match each item on the left to the correct letter',
            style: text.titleSmall),
        const SizedBox(height: 12),

        // ── Legend: full, wrapped text for every right-side option ──
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var d = 0; d < _display.length; d++)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: d == _display.length - 1 ? 0 : 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LetterChip(letter(d), scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(rights[_display[d]],
                            style: text.bodyMedium), // wraps fully, no clipping
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Each left item picks a letter ──
        for (var i = 0; i < widget.question.lefts.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.question.lefts[i],
                      style:
                          text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                // Compact letter selector — no text to truncate.
                Wrap(
                  spacing: 6,
                  children: [
                    for (var d = 0; d < _display.length; d++)
                      _LetterOption(
                        label: letter(d),
                        selected: _pairs[i] == _display[d],
                        onTap: () {
                          setState(() => _pairs[i] = _display[d]);
                          widget.onChanged(Map<int, int>.from(_pairs));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small filled chip showing a legend letter (A, B, C…).
class _LetterChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LetterChip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Tappable A/B/C selector button used per left item.
class _LetterOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LetterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}
