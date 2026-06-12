import 'dart:async';

import 'package:flutter/material.dart';

/// Resolves a bundled image's real width/height ratio so the drawing box can
/// match it exactly (no letterboxing, so part coords stay aligned). Falls back
/// to the caller's default on error.
Future<double> assetImageAspect(String asset) {
  final completer = Completer<double>();
  final stream = AssetImage(asset).resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) {
        completer.complete(info.image.width / info.image.height);
      }
      stream.removeListener(listener);
    },
    onError: (e, _) {
      if (!completer.isCompleted) completer.completeError(e);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// One marker to render: a dot at the anatomical point [norm] (normalized 0..1
/// inside the *image* rect) wired by a leader line to a numbered badge parked
/// in the nearest side gutter.
class LeaderMarker {
  final int number;
  final Offset norm; // (x, y) in 0..1 over the image area
  final Color badge; // badge fill (encodes given/blank/correct/wrong)
  final Color onBadge; // number color
  const LeaderMarker({
    required this.number,
    required this.norm,
    required this.badge,
    required this.onBadge,
  });
}

/// Width reserved on each side of the image for the number badges + leader
/// lines. The image is laid out in the centre column; badges live in the
/// gutters so they never cover anatomy.
const double kAnatomyGutter = 34;

const double _dotR = 4.5;
const double _badgeR = 13;

/// Maps a normalized point to a pixel offset inside the centred image rect.
Offset anatomyPointPx(Size size, Offset norm, {double gutter = kAnatomyGutter}) {
  final w = size.width - gutter * 2;
  return Offset(gutter + norm.dx * w, norm.dy * size.height);
}

/// Inverse of [anatomyPointPx]: pixel → normalized, clamped to 0..1.
Offset anatomyPointNorm(Size size, Offset px,
    {double gutter = kAnatomyGutter}) {
  final w = size.width - gutter * 2;
  final nx = w <= 0 ? 0.0 : ((px.dx - gutter) / w);
  final ny = size.height <= 0 ? 0.0 : (px.dy / size.height);
  return Offset(nx.clamp(0.0, 1.0).toDouble(), ny.clamp(0.0, 1.0).toDouble());
}

/// Computes the gutter badge centre for every marker, laid out top-to-bottom on
/// the side nearest each point so badges in a column don't overlap.
List<Offset> anatomyBadgeCentres(Size size, List<LeaderMarker> markers,
    {double gutter = kAnatomyGutter}) {
  final centres = List<Offset>.filled(markers.length, Offset.zero);
  final leftX = gutter / 2;
  final rightX = size.width - gutter / 2;

  for (final side in [true, false]) {
    final idx = <int>[];
    for (var i = 0; i < markers.length; i++) {
      final onLeft = markers[i].norm.dx < 0.5;
      if (onLeft == side) idx.add(i);
    }
    idx.sort((a, b) => markers[a].norm.dy.compareTo(markers[b].norm.dy));
    final n = idx.length;
    final usable = size.height - _badgeR * 2;
    for (var k = 0; k < n; k++) {
      final t = n == 1 ? 0.5 : k / (n - 1);
      final y = _badgeR + t * usable;
      centres[idx[k]] = Offset(side ? leftX : rightX, y);
    }
  }
  return centres;
}

/// Draws the dots, leader lines and numbered gutter badges. Shared by the quiz
/// (static) and the calibrate screen (live preview).
class AnatomyLeaderPainter extends CustomPainter {
  final List<LeaderMarker> markers;
  final Color line;
  final Color surface; // badge border, for contrast over the image
  final double gutter;

  AnatomyLeaderPainter({
    required this.markers,
    required this.line,
    required this.surface,
    this.gutter = kAnatomyGutter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centres = anatomyBadgeCentres(size, markers, gutter: gutter);
    final linePaint = Paint()
      ..color = line.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Leader lines + point dots first, so badges sit on top.
    for (var i = 0; i < markers.length; i++) {
      final point = anatomyPointPx(size, markers[i].norm, gutter: gutter);
      canvas.drawLine(point, centres[i], linePaint);
      canvas.drawCircle(point, _dotR + 1.5,
          Paint()..color = surface.withValues(alpha: 0.9));
      canvas.drawCircle(point, _dotR, Paint()..color = markers[i].badge);
    }

    // Numbered badges.
    for (var i = 0; i < markers.length; i++) {
      final c = centres[i];
      canvas.drawCircle(
          c, _badgeR + 1.5, Paint()..color = surface.withValues(alpha: 0.95));
      canvas.drawCircle(c, _badgeR, Paint()..color = markers[i].badge);
      final tp = TextPainter(
        text: TextSpan(
          text: '${markers[i].number}',
          style: TextStyle(
            color: markers[i].onBadge,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant AnatomyLeaderPainter old) =>
      old.markers != markers || old.line != line || old.surface != surface;
}
