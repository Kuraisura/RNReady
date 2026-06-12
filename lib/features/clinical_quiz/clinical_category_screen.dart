import 'package:flutter/material.dart';

import '../../core/animations/organic_route.dart';
import '../../core/widgets/glass_card.dart';
import 'clinical_category.dart';
import 'clinical_quiz_screen.dart';

/// Shown when the user opens "Clinical Case" — lets them pick the kind of
/// scenario the AI should generate.
class ClinicalCategoryScreen extends StatelessWidget {
  const ClinicalCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Clinical Case')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Choose what kind of case to practice. The AI generates a fresh '
                'scenario, you answer, and it scores and coaches you.',
                style: text.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _CategoryCard(category: kClinicalCategories[i]),
                childCount: kClinicalCategories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ClinicalCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      tint: category.color,
      onTap: () => Navigator.push(
        context,
        OrganicRoute(ClinicalQuizScreen(category: category)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color, size: 24),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(category.label,
                      style: text.titleSmall,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(category.blurb,
                      style: text.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
