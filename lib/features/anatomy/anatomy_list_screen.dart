import 'package:flutter/material.dart';

import '../../core/animations/organic_route.dart';
import '../../core/widgets/glass_card.dart';
import 'anatomy_data.dart';
import 'anatomy_models.dart';
import 'anatomy_painters.dart';
import 'anatomy_quiz_screen.dart';

/// Lists every bundled anatomy structure. Tapping one starts a label-the-blank
/// quiz for that diagram.
class AnatomyListScreen extends StatelessWidget {
  const AnatomyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Anatomy Lab')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Pick a structure. Some labels are hidden each round — fill the '
                'blanks and get scored. It reshuffles every time.',
                style: text.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.86,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _AnatomyCard(diagram: kAnatomyDiagrams[i]),
                childCount: kAnatomyDiagrams.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnatomyCard extends StatelessWidget {
  final AnatomyDiagram diagram;
  const _AnatomyCard({required this.diagram});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: () => Navigator.push(
          context, OrganicRoute(AnatomyQuizScreen(diagram: diagram))),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini preview of the diagram.
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: diagram.imageAsset != null
                    ? Image.asset(diagram.imageAsset!, fit: BoxFit.contain)
                    : CustomPaint(
                        painter: anatomyPainter(
                            diagram.id, scheme.onSurface, scheme.primary),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(diagram.icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(diagram.name,
                    style: text.titleSmall,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text('${diagram.system} • ${diagram.parts.length} parts',
              style: text.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
