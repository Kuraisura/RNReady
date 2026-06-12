import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import 'anatomy_calibrate_screen.dart';
import 'anatomy_leader.dart';
import 'anatomy_models.dart';
import 'anatomy_overrides.dart';
import 'anatomy_painters.dart';

/// Interactive "label the blanks" quiz for one anatomy diagram. Each round a
/// random subset of parts is hidden; the student fills them in and is scored.
class AnatomyQuizScreen extends StatefulWidget {
  final AnatomyDiagram diagram;
  const AnatomyQuizScreen({super.key, required this.diagram});

  @override
  State<AnatomyQuizScreen> createState() => _AnatomyQuizScreenState();
}

class _AnatomyQuizScreenState extends State<AnatomyQuizScreen> {
  final _rng = Random();
  final Map<int, TextEditingController> _controllers = {};

  late Set<int> _blanks; // indices of hidden parts this round
  bool _checked = false;
  int _score = 0; // % after checking

  // Parts with any saved calibration applied (coords only — labels/count match
  // the const data, so round state stays valid when this reloads).
  List<AnatomyPart> _parts = const [];

  // Real image aspect, resolved at runtime so the box matches the illustration.
  late double _aspect = widget.diagram.imageAspect;

  @override
  void initState() {
    super.initState();
    _parts = widget.diagram.parts;
    _newRound();
    _loadOverrides();
    final asset = widget.diagram.imageAsset;
    if (asset != null) {
      assetImageAspect(asset).then((a) {
        if (mounted) setState(() => _aspect = a);
      }).catchError((_) {});
    }
  }

  Future<void> _loadOverrides() async {
    final p = await effectiveParts(widget.diagram);
    if (!mounted) return;
    setState(() => _parts = p);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _newRound() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    // Hide ~60% of the parts (at least 2, leave at least one shown as a hint).
    final n = _parts.length;
    final target = (n * 0.6).round().clamp(2, n - 1);
    final order = List<int>.generate(n, (i) => i)..shuffle(_rng);
    _blanks = order.take(target).toSet();
    for (final i in _blanks) {
      _controllers[i] = TextEditingController();
    }
    _checked = false;
    _score = 0;
    setState(() {});
  }

  void _check() {
    var correct = 0;
    for (final i in _blanks) {
      if (_parts[i].matches(_controllers[i]!.text)) correct++;
    }
    setState(() {
      _checked = true;
      _score = _blanks.isEmpty
          ? 100
          : (correct / _blanks.length * 100).round();
    });
    FocusScope.of(context).unfocus();
  }

  bool _isCorrect(int i) => _parts[i].matches(_controllers[i]!.text);

  /// Builds the leader markers for the current round, colour-coded by state:
  /// given (hint) / blank / correct / wrong.
  List<LeaderMarker> _markers(ColorScheme scheme) {
    const slate = Color(0xFF64748B);
    const green = Color(0xFF34D399);
    const red = Color(0xFFF87171);
    return [
      for (var i = 0; i < _parts.length; i++)
        LeaderMarker(
          number: i + 1,
          norm: Offset(_parts[i].x, _parts[i].y),
          badge: !_blanks.contains(i)
              ? slate
              : !_checked
                  ? scheme.primary
                  : _isCorrect(i)
                      ? green
                      : red,
          onBadge: _blanks.contains(i) && !_checked
              ? scheme.onPrimary
              : Colors.white,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.diagram.name),
        actions: [
          if (widget.diagram.imageAsset != null)
            IconButton(
              tooltip: 'Calibrate marker positions',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AnatomyCalibrateScreen(diagram: widget.diagram),
                  ),
                );
                _loadOverrides(); // pick up any saved changes
              },
              icon: const Icon(Icons.edit_location_alt_outlined),
            ),
          IconButton(
            tooltip: 'New round',
            onPressed: _newRound,
            icon: const Icon(Icons.casino_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // ── Diagram with numbered markers + leader lines ──
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: widget.diagram.imageAsset != null ? _aspect : 1,
                  child: Stack(
                    children: [
                      // Base layer: real illustration (inset by the gutters so
                      // the badges sit beside it) or the vector fallback.
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: kAnatomyGutter),
                          child: widget.diagram.imageAsset != null
                              ? Image.asset(widget.diagram.imageAsset!,
                                  fit: BoxFit.fill)
                              : CustomPaint(
                                  painter: anatomyPainter(widget.diagram.id,
                                      scheme.onSurface, scheme.primary),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: AnatomyLeaderPainter(
                            markers: _markers(scheme),
                            line: scheme.onSurface,
                            surface: scheme.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.diagram.credit != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.diagram.credit!,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.45),
                        fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Score (after checking) ──
          if (_checked) ...[
            _ScoreBar(score: _score),
            const SizedBox(height: 16),
          ],

          // ── Labels / answers ──
          Text('Labels',
              style: text.titleSmall?.copyWith(color: scheme.onSurface)),
          const SizedBox(height: 8),
          for (var i = 0; i < _parts.length; i++)
            _LabelRow(
              number: i + 1,
              part: _parts[i],
              isBlank: _blanks.contains(i),
              controller: _controllers[i],
              checked: _checked,
              correct: _blanks.contains(i) && _checked ? _isCorrect(i) : null,
            ),
          const SizedBox(height: 20),

          // ── Actions ──
          if (!_checked)
            FilledButton.icon(
              onPressed: _check,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Check answers'),
            )
          else
            OutlinedButton.icon(
              onPressed: _newRound,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('New round (reshuffle blanks)'),
            ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final int number;
  final AnatomyPart part;
  final bool isBlank;
  final TextEditingController? controller;
  final bool checked;
  final bool? correct;
  const _LabelRow({
    required this.number,
    required this.part,
    required this.isBlank,
    required this.controller,
    required this.checked,
    required this.correct,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final badgeColor = correct == null
        ? (isBlank ? scheme.primary : scheme.onSurface.withValues(alpha: 0.3))
        : (correct! ? const Color(0xFF34D399) : const Color(0xFFF87171));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            child: Text('$number',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isBlank
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        enabled: !checked,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Type label #$number…',
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: scheme.outline)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: scheme.outline)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      if (checked && correct == false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text('Answer: ${part.label}',
                              style: text.bodySmall?.copyWith(
                                  color: const Color(0xFF34D399),
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(part.label,
                        style: text.bodyLarge?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.75))),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final int score;
  const _ScoreBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = score >= 75
        ? const Color(0xFF34D399)
        : score >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFF87171);
    return GlassCard(
      tint: c,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 6,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score', style: text.labelMedium?.copyWith(color: c)),
                Text('$score%', style: text.headlineSmall?.copyWith(color: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
