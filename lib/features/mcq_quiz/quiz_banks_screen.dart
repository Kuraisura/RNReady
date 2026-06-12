import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/module_structure.dart';
import '../../data/services/llm_service.dart';
import '../../data/services/study_content_service.dart';
import 'mcq_models.dart';
import 'quiz_launcher.dart';
import 'quiz_progress_store.dart';

final _generatorProvider = quizGeneratorProvider;

final _sectionsProvider = FutureProvider<List<ModuleSection>>(
  (_) => StudyContentService.instance.loadSections(),
);

/// Lists every subtopic (grouped by section). Tapping one generates a fresh
/// AI quiz from that subtopic's notes (cached after the first time).
class QuizBanksScreen extends ConsumerWidget {
  const QuizBanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(_sectionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Practice Quizzes')),
      body: sectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Could not load subtopics.')),
        data: (sections) {
          if (sections.isEmpty) {
            return const Center(child: Text('No subtopics available.'));
          }
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _IntroBanner()),
              for (final section in sections) ...[
                SliverToBoxAdapter(child: _SectionHeader(section: section)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  sliver: SliverList.separated(
                    itemCount: section.subtopics.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _SubtopicQuizTile(
                      number: i + 1,
                      subtopic: section.subtopics[i],
                      accent: section.color,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner();
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pick any subtopic — questions are generated from its notes and '
              'saved for offline retakes.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends ConsumerStatefulWidget {
  final ModuleSection section;
  const _SectionHeader({required this.section});

  @override
  ConsumerState<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends ConsumerState<_SectionHeader> {
  bool _saving = false;
  int _done = 0;
  int _total = 0;

  Future<void> _saveForOffline() async {
    final section = widget.section;
    final gen = ref.read(_generatorProvider);

    // Only generate for subtopics that aren't saved yet.
    final pending = <Subtopic>[];
    for (final s in section.subtopics) {
      if (!await gen.hasCache(s.startPage)) pending.add(s);
    }
    if (!mounted) return;
    if (pending.isEmpty) {
      _toast('“${section.title}” is already saved for offline. ✅');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save for offline?'),
        content: Text(
          'This will use the internet now to prepare ${pending.length} quizzes '
          'for “${section.title}”, so they work later with no data '
          '(e.g. in the jeepney).\n\n'
          'It may pause if the free AI limit is reached — just continue another '
          'day to finish.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _saving = true;
      _done = 0;
      _total = pending.length;
    });

    for (final s in pending) {
      if (!mounted) return;
      try {
        await gen.generate(
            title: s.title, startPage: s.startPage, count: 8);
        if (!mounted) return;
        setState(() => _done++);
      } on OfflineException {
        if (mounted) {
          setState(() => _saving = false);
          _toast('Went offline — saved $_done of $_total. Resume on Wi-Fi.');
        }
        return;
      } catch (e) {
        // Likely the daily free-AI limit (HTTP 429) — stop gracefully.
        if (mounted) {
          setState(() => _saving = false);
          final hitLimit = e.toString().contains('429');
          _toast(hitLimit
              ? 'Daily free-AI limit reached — saved $_done of $_total. '
                  'Continue tomorrow.'
              : 'Stopped — saved $_done of $_total.');
        }
        return;
      }
      // Be gentle on the free-tier rate limit.
      await Future.delayed(const Duration(milliseconds: 700));
    }

    if (mounted) {
      setState(() => _saving = false);
      _toast('Saved “${section.title}” for offline. ✅');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final section = widget.section;
    final done = sectionDoneCount(section, ref.watch(quizProgressProvider));
    final total = section.subtopics.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: section.color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(section.title,
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          // Subtopics completed in this section.
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: section.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$done/$total done',
                style: text.labelSmall?.copyWith(
                    color: section.color, fontWeight: FontWeight.w700)),
          ),
          // Save-for-offline action / progress.
          if (_saving)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$_done/$_total',
                    style: text.labelSmall?.copyWith(color: section.color)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: section.color),
                ),
              ],
            )
          else
            IconButton(
              tooltip: 'Save this section for offline',
              visualDensity: VisualDensity.compact,
              onPressed: _saveForOffline,
              icon: Icon(Icons.download_for_offline_outlined,
                  color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }
}

class _SubtopicQuizTile extends ConsumerStatefulWidget {
  final int number;
  final Subtopic subtopic;
  final Color accent;
  const _SubtopicQuizTile({
    required this.number,
    required this.subtopic,
    required this.accent,
  });

  @override
  ConsumerState<_SubtopicQuizTile> createState() => _SubtopicQuizTileState();
}

class _SubtopicQuizTileState extends ConsumerState<_SubtopicQuizTile> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    // Let the student choose which question formats to practice first.
    final types = await pickQuizTypes(context);
    if (types == null || !mounted) return; // cancelled
    setState(() => _busy = true);
    try {
      await launchSubtopicQuiz(context, ref, widget.subtopic, types: types);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(quizProgressProvider)[widget.subtopic.startPage];
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : _start,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              // Numbered badge (plain text — always renders, no tofu glyphs).
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${widget.number}',
                    style: text.labelLarge?.copyWith(color: widget.accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.subtopic.title,
                        style: text.titleSmall,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    _ScoreChip(progress: progress),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: widget.accent),
                )
              else
                Icon(Icons.chevron_right,
                    color: scheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Best-score badge for a subtopic tile: "Best 6/8 · 3 tries", or "Not done yet".
class _ScoreChip extends StatelessWidget {
  final QuizProgress? progress;
  const _ScoreChip({required this.progress});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = progress;

    if (p == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio_button_unchecked,
              size: 13, color: scheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Text('Not done yet',
              style: text.labelSmall
                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.55))),
        ],
      );
    }

    final pct = p.bestPercent;
    final color = pct >= 0.75
        ? const Color(0xFF34D399)
        : (pct >= 0.5 ? const Color(0xFFF59E0B) : const Color(0xFFF87171));
    final tries = p.attempts == 1 ? '1 try' : '${p.attempts} tries';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 13, color: color),
        const SizedBox(width: 4),
        Text('Best ${p.bestCorrect}/${p.bestTotal}',
            style: text.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text('· $tries',
            style: text.labelSmall
                ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }
}

// ─────────────────────────── Quiz-type chooser ─────────────────────────────

/// Shows a bottom sheet to choose which question formats to practice.
///
/// Returns the selected [QuizType]s, an EMPTY set for "mix of all", or `null`
/// if the user cancels. (Empty set is the same signal `launchSubtopicQuiz`
/// already treats as "all types".)
Future<Set<QuizType>?> pickQuizTypes(BuildContext context) {
  return showModalBottomSheet<Set<QuizType>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _QuizTypeSheet(),
  );
}

class _QuizTypeSheet extends StatefulWidget {
  const _QuizTypeSheet();

  @override
  State<_QuizTypeSheet> createState() => _QuizTypeSheetState();
}

class _QuizTypeSheetState extends State<_QuizTypeSheet> {
  final Set<QuizType> _selected = {};

  static const _labels = <QuizType, (String, String)>{
    QuizType.multipleChoice: ('Multiple choice', 'Pick the correct option'),
    QuizType.identification: ('Identification', 'Type the correct term'),
    QuizType.enumeration: ('Enumeration', 'List several required items'),
    QuizType.matching: ('Matching', 'Pair each item to its match'),
  };

  void _toggle(QuizType t) => setState(() {
        _selected.contains(t) ? _selected.remove(t) : _selected.add(t);
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose question types', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Leave all unchecked for a mix of every type.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          for (final entry in _labels.entries)
            _TypeRow(
              label: entry.value.$1,
              subtitle: entry.value.$2,
              selected: _selected.contains(entry.key),
              onTap: () => _toggle(entry.key),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_selected.isEmpty
                  ? 'Start mixed quiz'
                  : 'Start (${_selected.length} type'
                      '${_selected.length == 1 ? '' : 's'})'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _TypeRow({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 2 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected ? scheme.primary : null)),
                      Text(subtitle,
                          style: text.bodySmall?.copyWith(
                              color:
                                  scheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
