import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/offline_view.dart';
import '../../data/services/llm_service.dart';
import 'clinical_case_service.dart';
import 'clinical_category.dart';
import 'clinical_instructor_prompt.dart';

final _llmProvider = Provider((_) => LlmService());
final _caseServiceProvider =
    Provider((ref) => ClinicalCaseService(ref.read(_llmProvider)));

/// Presents clinical-case scenarios for free-text answers, then has the AI
/// "Clinical Instructor" evaluate them. Scenarios are AI-generated and endless;
/// a fixed [scenario] can also be supplied to pin one case. An optional
/// [category] steers the kind of scenario generated.
class ClinicalQuizScreen extends ConsumerStatefulWidget {
  /// Optional pinned scenario. When null, cases are generated on demand.
  final String? scenario;

  /// Optional focus area (Functions of an Organ, Accidents, Diseases, …).
  final ClinicalCategory? category;
  const ClinicalQuizScreen({super.key, this.scenario, this.category});

  @override
  ConsumerState<ClinicalQuizScreen> createState() => _ClinicalQuizScreenState();
}

class _ClinicalQuizScreenState extends ConsumerState<ClinicalQuizScreen> {
  final _answer = TextEditingController();
  final _focus = FocusNode();

  String? _scenario; // current case text
  bool _loadingCase = false;
  bool _offline = false;
  bool _submitting = false;
  String? _feedback;
  int? _score; // 0..100 parsed from the AI's SCORE line

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    if (widget.scenario != null) {
      _scenario = widget.scenario;
    } else {
      _newCase();
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _newCase() async {
    setState(() {
      _loadingCase = true;
      _offline = false;
      _feedback = null;
      _scenario = null;
      _answer.clear();
    });
    try {
      final c = await ref
          .read(_caseServiceProvider)
          .generate(focus: widget.category?.focus ?? '');
      if (mounted) setState(() => _scenario = c);
    } on OfflineException {
      if (mounted) setState(() => _offline = true);
    } catch (e) {
      if (mounted) {
        setState(() => _scenario = 'Could not generate a case. $e');
      }
    } finally {
      if (mounted) setState(() => _loadingCase = false);
    }
  }

  Future<void> _submit() async {
    if (_answer.text.trim().isEmpty || _submitting || _scenario == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _feedback = null;
      _score = null;
    });
    try {
      final result = await ref.read(_llmProvider).chat(
        temperature: 0.3,
        [
          {'role': 'system', 'content': clinicalInstructorSystemPrompt},
          {
            'role': 'user',
            'content':
                'CLINICAL SCENARIO:\n$_scenario\n\nSTUDENT ANSWER:\n${_answer.text}'
          },
        ],
      );
      if (!mounted) return;
      final (score, body) = _parseScore(result);
      setState(() {
        _score = score;
        _feedback = body;
      });
    } on OfflineException {
      if (mounted) setState(() => _offline = true);
    } catch (_) {
      // Never surface a raw red error — show a calm, friendly message.
      if (mounted) {
        setState(() => _feedback =
            "## Couldn't evaluate\nSomething went wrong reaching the "
            'instructor. Please check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Extracts the leading `SCORE: <n>%` (if present) and returns the remaining
  /// feedback body with that line stripped.
  (int?, String) _parseScore(String raw) {
    final m = RegExp(r'SCORE:\s*(\d{1,3})\s*%', caseSensitive: false)
        .firstMatch(raw);
    int? score;
    if (m != null) {
      score = int.tryParse(m.group(1)!);
      if (score != null) score = score.clamp(0, 100);
    }
    // Remove the "## Score" heading + the SCORE line so the card isn't
    // duplicated (the number is shown in the ring instead).
    var body = raw;
    body = body.replaceFirst(
        RegExp(r'##\s*Score\s*', caseSensitive: false), '');
    body = body.replaceFirst(
        RegExp(r'SCORE:\s*\d{1,3}\s*%', caseSensitive: false), '');
    return (score, body.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final focused = _focus.hasFocus;
    final canNewCase = widget.scenario == null;

    if (_offline) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category?.label ?? 'Clinical Case')),
        body: OfflineView(
          message: 'Clinical cases are generated by AI and need internet.',
          onRetry: canNewCase ? _newCase : () => setState(() => _offline = false),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category?.label ?? 'Clinical Case'),
        actions: [
          if (canNewCase)
            IconButton(
              tooltip: 'New case',
              onPressed: _loadingCase ? null : _newCase,
              icon: const Icon(Icons.casino_outlined),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Scenario card ──
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CLINICAL SCENARIO',
                      style: text.labelMedium?.copyWith(color: scheme.primary)),
                  const SizedBox(height: 10),
                  if (_loadingCase)
                    const _LoadingCase()
                  else
                    Text(_scenario ?? '',
                        style: text.titleLarge?.copyWith(height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Text('Your clinical reasoning',
                style: text.titleSmall?.copyWith(color: scheme.onSurface)),
            const SizedBox(height: 10),

            // ── Answer input ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: focused ? scheme.primary : scheme.outline,
                  width: focused ? 2 : 1.2,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.18),
                            blurRadius: 16,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: TextField(
                controller: _answer,
                focusNode: _focus,
                minLines: 5,
                maxLines: 10,
                style: text.bodyLarge,
                decoration: const InputDecoration(
                  hintText:
                      'Outline your immediate prioritization steps and the '
                      'rationale behind them…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(18),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Submit button ──
            LayoutBuilder(
              builder: (context, constraints) {
                final fullWidth =
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
                return Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    height: 54,
                    width: _submitting ? 54 : fullWidth,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius:
                          BorderRadius.circular(_submitting ? 27 : 16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(_submitting ? 27 : 16),
                        onTap: _loadingCase ? null : _submit,
                        child: Center(
                          child: _submitting
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: scheme.onPrimary,
                                      strokeWidth: 2.5))
                              : Text('Submit for Evaluation',
                                  style: text.labelLarge
                                      ?.copyWith(color: scheme.onPrimary)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Feedback ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _feedback == null
                  ? const SizedBox.shrink()
                  : Column(
                      key: const ValueKey('fb'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_score != null) _ScoreBadge(score: _score!),
                        if (_score != null) const SizedBox(height: 16),
                        _FeedbackCard(_feedback!),
                      ],
                    ),
            ),

            // ── Next case CTA after feedback ──
            if (_feedback != null && canNewCase) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _newCase,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next case'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingCase extends StatelessWidget {
  const _LoadingCase();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Text('Generating a fresh case…',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  Color _color() {
    if (score >= 75) return const Color(0xFF34D399); // pass green
    if (score >= 50) return const Color(0xFFF59E0B); // amber
    return const Color(0xFFF87171); // red
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final c = _color();
    return GlassCard(
      tint: c,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(c),
                    ),
                  ),
                  Text('${(v * 100).round()}',
                      style: text.titleMedium?.copyWith(color: c)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Score',
                    style: text.labelMedium?.copyWith(color: c)),
                const SizedBox(height: 4),
                Text('$score%',
                    style: text.headlineMedium?.copyWith(color: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String markdown;
  const _FeedbackCard(this.markdown);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      tint: scheme.primary,
      padding: const EdgeInsets.all(20),
      child: MarkdownBody(
        data: markdown,
        styleSheet: MarkdownStyleSheet(
          p: text.bodyMedium,
          h2: text.headlineSmall?.copyWith(color: scheme.primary),
          h3: text.titleMedium?.copyWith(color: scheme.primary),
          strong: TextStyle(
              fontFamily: AppFonts.sans,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface),
          listBullet: text.bodyMedium,
          blockquote: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
