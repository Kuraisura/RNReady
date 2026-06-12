import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/fade_up.dart';
import '../../core/animations/organic_route.dart';
import '../../core/animations/pressable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/module_structure.dart';
import '../../data/services/study_content_service.dart';
import '../ai_tutor/ai_tutor_screen.dart';
import '../anatomy/anatomy_list_screen.dart';
import '../care_plan/care_plan_screen.dart';
import '../clinical_quiz/clinical_category_screen.dart';
import '../mcq_quiz/quiz_banks_screen.dart';
import '../mcq_quiz/quiz_progress_store.dart';
import '../module_viewer/subtopic_list_screen.dart';
import '../notes/notes_screen.dart';

/// Loads the section -> subtopic outline once for the dashboard.
final sectionsProvider = FutureProvider<List<ModuleSection>>(
  (_) => StudyContentService.instance.loadSections(),
);

/// Per-section accent icons (cycled), purely cosmetic.
const _sectionIcons = <IconData>[
  Icons.groups_outlined,
  Icons.pregnant_woman_outlined,
  Icons.emergency_outlined,
  Icons.monitor_heart_outlined,
  Icons.psychology_outlined,
  Icons.balance_outlined,
];

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(sectionsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackdrop(),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _Greeting()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    children: [
                      FadeUp(
                        delay: const Duration(milliseconds: 80),
                        child: Row(
                          children: [
                            _QuickAction(
                              label: 'AI Tutor',
                              icon: Icons.forum_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () => Navigator.push(context,
                                  OrganicRoute(const AiTutorScreen())),
                            ),
                            const SizedBox(width: 12),
                            _QuickAction(
                              label: 'Clinical Case',
                              icon: Icons.medical_information_outlined,
                              color: const Color(0xFF7DD3C0),
                              onTap: () => Navigator.push(
                                context,
                                OrganicRoute(const ClinicalCategoryScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeUp(
                        delay: const Duration(milliseconds: 140),
                        child: Row(
                          children: [
                            _QuickAction(
                              label: 'Care Plan',
                              icon: Icons.assignment_outlined,
                              color: const Color(0xFF67B8A8),
                              onTap: () => Navigator.push(context,
                                  OrganicRoute(const CarePlanScreen())),
                            ),
                            const SizedBox(width: 12),
                            _QuickAction(
                              label: 'Notes',
                              icon: Icons.edit_note,
                              color: AppPalette.highlightInk,
                              onTap: () => Navigator.push(context,
                                  OrganicRoute(const NotesScreen())),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeUp(
                        delay: const Duration(milliseconds: 200),
                        child: Row(
                          children: [
                            _QuickAction(
                              label: 'Anatomy Lab',
                              icon: Icons.accessibility_new,
                              color: const Color(0xFF94A3B8),
                              onTap: () => Navigator.push(context,
                                  OrganicRoute(const AnatomyListScreen())),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeUp(
                  delay: const Duration(milliseconds: 260),
                  child: _ExamBanner(
                    onTap: () => Navigator.push(
                        context, OrganicRoute(const QuizBanksScreen())),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Text('Nursing practice sections',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              ...switch (sectionsAsync) {
                AsyncData(:final value) when value.isNotEmpty => [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList.separated(
                        itemCount: value.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => FadeUp(
                          delay: Duration(milliseconds: 40 * i),
                          child: _SectionCard(
                            section: value[i],
                            icon: _sectionIcons[i % _sectionIcons.length],
                          ),
                        ),
                      ),
                    ),
                  ],
                AsyncData() => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('Module structure not found.')),
                      ),
                    ),
                  ],
                AsyncError() => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('Could not load modules.')),
                      ),
                    ),
                  ],
                _ => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: _ShimmerBlock()),
                      ),
                    ),
                  ],
              },
            ],
          ),
        ],
      ),
    );
  }
}

class _AmbientBackdrop extends StatefulWidget {
  const _AmbientBackdrop();

  @override
  State<_AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<_AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.expand();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            children: [
              Positioned(
                top: -80 + (t * 24),
                right: -40,
                child: _Blob(
                  size: 220,
                  color: (dark ? AppPalette.mint : AppPalette.emerald)
                      .withValues(alpha: dark ? 0.10 : 0.08),
                ),
              ),
              Positioned(
                top: 280 - (t * 30),
                left: -90,
                child: _Blob(
                  size: 260,
                  color: AppPalette.navy700.withValues(alpha: dark ? 0.55 : 0.08),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

/// Greeting header with a time-of-day salutation and the theme toggle.
class _Greeting extends ConsumerWidget {
  const _Greeting();

  static String _salutation(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greeting = _salutation(DateTime.now().hour);

    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('$greeting',
                        style: text.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7))),
                  ),
                  _ThemeToggle(isDark: isDark),
                ],
              ),
              const SizedBox(height: 6),
              Text('Ready to pass the PNLE?', style: text.displaySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  final bool isDark;
  const _ThemeToggle({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: isDark ? 'Switch to light' : 'Switch to dark',
        onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
              turns: anim,
              child: FadeTransition(opacity: anim, child: child)),
          child: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            key: ValueKey(isDark),
            color: scheme.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: GlassCard(
          tint: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(label, style: text.labelLarge?.copyWith(color: color)),
          ]),
        ),
      ),
    );
  }
}

class _ExamBanner extends StatefulWidget {
  final VoidCallback onTap;
  const _ExamBanner({required this.onTap});

  @override
  State<_ExamBanner> createState() => _ExamBannerState();
}

class _ExamBannerState extends State<_ExamBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Pressable(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      AppPalette.navy800,
                      AppPalette.navy700,
                      Color(0xFF0E5C50),
                    ],
                    begin: Alignment(-1 + _c.value, -1),
                    end: Alignment(1 - _c.value, 1),
                  ),
                ),
                child: child,
              );
            },
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Practice quizzes',
                        style: text.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Board-style questions generated from your notes',
                        style: text.bodyMedium
                            ?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: scheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded,
                    color: scheme.onPrimary, size: 28),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends ConsumerWidget {
  final ModuleSection section;
  final IconData icon;
  const _SectionCard({required this.section, required this.icon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = section.color;
    final done = sectionDoneCount(section, ref.watch(quizProgressProvider));
    final total = section.subtopics.length;
    return Pressable(
      onTap: () => Navigator.push(
        context,
        OrganicRoute(SubtopicListScreen(section: section)),
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(children: [
            Hero(
              tag: 'module-${section.title}',
              child: Material(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, color: accent, size: 26),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.title, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$total subtopics • $done/$total done • '
                    'pp.${section.startPage}-${section.endPage}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.4)),
          ]),
        ),
      ),
    );
  }
}
