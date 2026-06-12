import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anatomy_leader.dart';
import 'anatomy_models.dart';
import 'anatomy_overrides.dart';

/// Drag-to-pin tool for lining up a diagram's markers with its real image.
///
/// Because the bundled illustration differs from the old vector art, the const
/// part coordinates need re-pinning. Here each numbered dot is draggable; Save
/// persists the positions (the quiz reads them live), and "Copy Dart" emits an
/// `AnatomyPart(...)` list so the coords can be baked into `anatomy_data.dart`.
class AnatomyCalibrateScreen extends StatefulWidget {
  final AnatomyDiagram diagram;
  const AnatomyCalibrateScreen({super.key, required this.diagram});

  @override
  State<AnatomyCalibrateScreen> createState() => _AnatomyCalibrateScreenState();
}

class _AnatomyCalibrateScreenState extends State<AnatomyCalibrateScreen> {
  late List<Offset> _points; // normalized (x, y) per part
  int? _active; // last-moved marker, highlighted in the legend
  late double _aspect = widget.diagram.imageAspect;

  List<AnatomyPart> get _parts => widget.diagram.parts;

  @override
  void initState() {
    super.initState();
    _points = [for (final p in _parts) Offset(p.x, p.y)];
    _loadSaved();
    final asset = widget.diagram.imageAsset;
    if (asset != null) {
      assetImageAspect(asset).then((a) {
        if (mounted) setState(() => _aspect = a);
      }).catchError((_) {});
    }
  }

  Future<void> _loadSaved() async {
    final saved = await AnatomyOverrides.load(widget.diagram.id);
    if (!mounted || saved == null || saved.length != _parts.length) return;
    setState(() => _points = List.of(saved));
  }

  Future<void> _save() async {
    await AnatomyOverrides.save(widget.diagram.id, _points);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved — the quiz now uses these positions.')),
    );
  }

  Future<void> _reset() async {
    await AnatomyOverrides.clear(widget.diagram.id);
    if (!mounted) return;
    setState(() => _points = [for (final p in _parts) Offset(p.x, p.y)]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to the original coordinates.')),
    );
  }

  void _copyDart() {
    final b = StringBuffer();
    for (var i = 0; i < _parts.length; i++) {
      final p = _parts[i];
      final x = _points[i].dx.toStringAsFixed(3);
      final y = _points[i].dy.toStringAsFixed(3);
      final accepted = p.accepted.isEmpty
          ? ''
          : ", accepted: [${p.accepted.map((a) => "'$a'").join(', ')}]";
      b.writeln("AnatomyPart('${p.label}', $x, $y$accepted),");
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dart copied — paste into anatomy_data.dart.')),
    );
  }

  List<LeaderMarker> _markers(ColorScheme scheme) => [
        for (var i = 0; i < _points.length; i++)
          LeaderMarker(
            number: i + 1,
            norm: _points[i],
            badge: i == _active ? const Color(0xFFF59E0B) : scheme.primary,
            onBadge: scheme.onPrimary,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const hit = 40.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Calibrate · ${widget.diagram.name}'),
        actions: [
          IconButton(
            tooltip: 'Copy Dart coordinates',
            onPressed: _copyDart,
            icon: const Icon(Icons.code),
          ),
          IconButton(
            tooltip: 'Reset to original',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text(
            'Drag each numbered dot onto its structure, then Save. '
            'Use “Copy Dart” to bake the coordinates into the source.',
            style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: _aspect,
            child: LayoutBuilder(
              builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kAnatomyGutter),
                        child: widget.diagram.imageAsset != null
                            ? Image.asset(widget.diagram.imageAsset!,
                                fit: BoxFit.fill)
                            : const ColoredBox(color: Colors.black12),
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
                    // Invisible drag targets over each anatomical dot.
                    for (var i = 0; i < _points.length; i++)
                      Positioned(
                        left: anatomyPointPx(size, _points[i]).dx - hit / 2,
                        top: anatomyPointPx(size, _points[i]).dy - hit / 2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanDown: (_) => setState(() => _active = i),
                          onPanUpdate: (d) => setState(() {
                            final px =
                                anatomyPointPx(size, _points[i]) + d.delta;
                            _points[i] = anatomyPointNorm(size, px);
                          }),
                          child: const SizedBox(width: hit, height: hit),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Markers', style: text.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _parts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: i == _active
                        ? const Color(0xFFF59E0B)
                        : scheme.primary,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_parts[i].label, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
