import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/fade_route.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/module_structure.dart';
import '../../data/services/study_content_service.dart';
import '../ai_tutor/ai_tutor_screen.dart';
import '../mcq_quiz/quiz_banks_screen.dart' show pickQuizTypes;
import '../mcq_quiz/quiz_launcher.dart';
import 'slide_models.dart';

/// PowerPoint-style study deck for one subtopic. Replaces the raw PDF viewer:
/// content is the app's own generated slides (from the extracted module text),
/// swiped one slide at a time. Keeps the "Quiz this subtopic" and "Ask AI"
/// actions the PDF screen used to offer.
class ModuleSlidesScreen extends ConsumerStatefulWidget {
  final Subtopic subtopic;
  final Color accent;
  const ModuleSlidesScreen({
    super.key,
    required this.subtopic,
    required this.accent,
  });

  @override
  ConsumerState<ModuleSlidesScreen> createState() => _ModuleSlidesScreenState();
}

class _ModuleSlidesScreenState extends ConsumerState<ModuleSlidesScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _loading = true;
  SlideDeck? _deck;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d =
        await StudyContentService.instance.slideDeck(widget.subtopic.startPage);
    if (mounted) {
      setState(() {
        _deck = d;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _quiz() async {
    final types = await pickQuizTypes(context);
    if (types == null || !mounted) return;
    await launchSubtopicQuiz(context, ref, widget.subtopic, types: types);
  }

  Future<void> _askAi() async {
    final text = await StudyContentService.instance
        .subtopicText(widget.subtopic.startPage);
    if (!mounted) return;
    Navigator.push(
      context,
      FadeScaleRoute(AiTutorScreen(pageContext: text.isEmpty ? null : text)),
    );
  }

  void _go(int delta) {
    final slides = _deck?.slides ?? const [];
    final next = (_index + delta).clamp(0, slides.length - 1);
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slides = _deck?.slides ?? const <Slide>[];
    final hasSlides = slides.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subtopic.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (hasSlides)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1} / ${slides.length}',
                    style: text.labelLarge?.copyWith(color: widget.accent)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasSlides
              ? _EmptyDeck(accent: widget.accent)
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: slides.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _SlideView(
                          slide: slides[i],
                          accent: widget.accent,
                          index: i,
                          total: slides.length,
                        ),
                      ),
                    ),
                    _ProgressDots(
                      count: slides.length,
                      index: _index,
                      accent: widget.accent,
                    ),
                    _NavRow(
                      index: _index,
                      total: slides.length,
                      accent: widget.accent,
                      onBack: () => _go(-1),
                      onNext: () => _go(1),
                    ),
                  ],
                ),
      bottomNavigationBar: _ActionBar(onQuiz: _quiz, onAsk: _askAi),
    );
  }
}

// ─────────────────────────────── one slide ─────────────────────────────────

class _SlideView extends StatelessWidget {
  final Slide slide;
  final Color accent;
  final int index;
  final int total;
  const _SlideView({
    required this.slide,
    required this.accent,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GlassCard(
        tint: accent,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: switch (slide) {
            TitleSlide s => _title(context, s),
            BulletsSlide s => _bullets(context, s.heading, s.bullets),
            SummarySlide s => _bullets(context, s.heading, s.bullets, check: true),
            TermsSlide s => _terms(context, s),
            TableSlide s => _table(context, s),
          },
        ),
      ),
    );
  }

  Widget _kicker(BuildContext context, String label) {
    final text = Theme.of(context).textTheme;
    return Text(label.toUpperCase(),
        style: text.labelSmall?.copyWith(
            color: accent, fontWeight: FontWeight.w700, letterSpacing: 0.8));
  }

  Widget _title(BuildContext context, TitleSlide s) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _kicker(context, 'Topic'),
        const SizedBox(height: 12),
        Text(s.heading, style: text.displaySmall),
        if (s.subtitle.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(s.subtitle,
              style: text.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75))),
        ],
      ],
    );
  }

  Widget _bullets(BuildContext context, String heading, List<String> bullets,
      {bool check = false}) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heading.isNotEmpty) ...[
          Text(heading, style: text.headlineSmall),
          const SizedBox(height: 16),
        ],
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    check ? Icons.check_circle : Icons.circle,
                    size: check ? 16 : 8,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(b, style: text.bodyLarge?.copyWith(height: 1.5))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _terms(BuildContext context, TermsSlide s) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.heading, style: text.headlineSmall),
        const SizedBox(height: 16),
        for (final t in s.terms)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.term,
                    style: text.titleMedium?.copyWith(color: accent)),
                const SizedBox(height: 2),
                Text(t.definition,
                    style: text.bodyMedium?.copyWith(height: 1.5)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _table(BuildContext context, TableSlide s) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final colCount = s.columns.isNotEmpty
        ? s.columns.length
        : (s.rows.isEmpty ? 0 : s.rows.first.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.heading.isNotEmpty) ...[
          Text(s.heading, style: text.headlineSmall),
          const SizedBox(height: 14),
        ],
        if (colCount == 0)
          Text('No table data.', style: text.bodyMedium)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(160),
                border: TableBorder.all(color: scheme.outline, width: 1),
                defaultVerticalAlignment: TableCellVerticalAlignment.top,
                children: [
                  if (s.columns.isNotEmpty)
                    TableRow(
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18)),
                      children: [
                        for (final c in s.columns)
                          _td(Text(c,
                              style: text.labelLarge?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700))),
                      ],
                    ),
                  for (final row in s.rows)
                    TableRow(
                      children: [
                        for (var i = 0; i < colCount; i++)
                          _td(Text(i < row.length ? row[i] : '',
                              style: text.bodySmall)),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _td(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: child,
      );
}

// ─────────────────────────────── chrome ────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  final int count;
  final int index;
  final Color accent;
  const _ProgressDots(
      {required this.count, required this.index, required this.accent});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);
    // Cap rendered dots so very long decks don't overflow the row.
    const maxDots = 16;
    final shown = count <= maxDots ? count : maxDots;
    final active = count <= maxDots
        ? index
        : (index * (maxDots - 1) / (count - 1)).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < shown; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == active ? accent : muted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final int index;
  final int total;
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _NavRow({
    required this.index,
    required this.total,
    required this.accent,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: isFirst ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Previous',
          ),
          const Spacer(),
          IconButton.filled(
            onPressed: isLast ? null : onNext,
            style: IconButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Theme.of(context).colorScheme.onPrimary),
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'Next',
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onQuiz;
  final VoidCallback onAsk;
  const _ActionBar({required this.onQuiz, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAsk,
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text('Ask AI'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: scheme.outline),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onQuiz,
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('Quiz this subtopic'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  final Color accent;
  const _EmptyDeck({required this.accent});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.slideshow_outlined, size: 56, color: accent),
            const SizedBox(height: 16),
            Text('Slides not generated yet',
                style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'This subtopic’s study deck hasn’t been built yet. Run '
              'tool/generate_slides.py to create it, then it works offline.',
              style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
