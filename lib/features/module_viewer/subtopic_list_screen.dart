import 'package:flutter/material.dart';

import '../../core/animations/fade_route.dart';
import '../../data/models/module_structure.dart';
import '../../data/services/study_content_service.dart';
import '../module_slides/module_slides_screen.dart';

/// Lists the subtopics of one NURSING PRACTICE section. Tapping a subtopic opens
/// its generated study slide deck ([ModuleSlidesScreen]).
class SubtopicListScreen extends StatelessWidget {
  final ModuleSection section;
  const SubtopicListScreen({super.key, required this.section});

  void _open(BuildContext context, Subtopic sub) {
    Navigator.push(
      context,
      FadeScaleRoute(ModuleSlidesScreen(subtopic: sub, accent: section.color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = section.color;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 132,
            backgroundColor: scheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(section.title,
                  style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.30),
                      scheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.slideshow_outlined, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap a subtopic to study its slide deck • '
                      '${section.subtopics.length} subtopics',
                      style: text.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            sliver: SliverList.separated(
              itemCount: section.subtopics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = section.subtopics[i];
                return _SubtopicTile(
                  index: i + 1,
                  subtopic: s,
                  accent: accent,
                  onTap: () => _open(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtopicTile extends StatelessWidget {
  final int index;
  final Subtopic subtopic;
  final Color accent;
  final VoidCallback onTap;
  const _SubtopicTile({
    required this.index,
    required this.subtopic,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$index',
                    style: text.labelLarge?.copyWith(color: accent)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(subtopic.title,
                        style: text.titleSmall, maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    _DeckStatus(startPage: subtopic.startPage),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small availability hint: "12 slides" when generated, else "Not generated".
class _DeckStatus extends StatelessWidget {
  final int startPage;
  const _DeckStatus({required this.startPage});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: StudyContentService.instance.slideDeck(startPage),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 14);
        }
        final deck = snap.data;
        final ready = deck != null && !deck.isEmpty;
        final color = ready
            ? const Color(0xFF34D399)
            : scheme.onSurface.withValues(alpha: 0.45);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ready ? Icons.slideshow : Icons.hourglass_empty,
                size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              ready ? '${deck.slides.length} slides' : 'Not generated yet',
              style: text.labelSmall?.copyWith(color: color),
            ),
          ],
        );
      },
    );
  }
}
