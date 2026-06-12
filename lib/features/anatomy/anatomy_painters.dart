import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Builds a [CustomPainter] for an anatomy diagram id. [ink] is the line color,
/// [accent] a soft fill tint. Every painter draws inside the unit square (the
/// canvas [Size]) so part coordinates (0..1) line up exactly with the artwork.
typedef AnatomyPainterBuilder = CustomPainter Function(Color ink, Color accent);

CustomPainter? anatomyPainter(String id, Color ink, Color accent) {
  final b = _painters[id];
  return b == null ? null : b(ink, accent);
}

final Map<String, AnatomyPainterBuilder> _painters = {
  'heart': (ink, a) => _HeartPainter(ink, a),
  'neuron': (ink, a) => _NeuronPainter(ink, a),
  'cell': (ink, a) => _CellPainter(ink, a),
  'skin': (ink, a) => _SkinPainter(ink, a),
  'long_bone': (ink, a) => _LongBonePainter(ink, a),
  'eye': (ink, a) => _EyePainter(ink, a),
  'respiratory': (ink, a) => _RespiratoryPainter(ink, a),
  'digestive': (ink, a) => _DigestivePainter(ink, a),
  'nephron': (ink, a) => _NephronPainter(ink, a),
  'heart_valves': (ink, a) => _HeartValvesPainter(ink, a),
  'blood_vessel': (ink, a) => _BloodVesselPainter(ink, a),
  'urinary_system': (ink, a) => _UrinaryPainter(ink, a),
  'kidney': (ink, a) => _KidneyPainter(ink, a),
  'fetal_skull': (ink, a) => _FetalSkullPainter(ink, a),
};

/// Shared helpers for normalized drawing.
abstract class _Base extends CustomPainter {
  final Color ink;
  final Color accent;
  _Base(this.ink, this.accent);

  Paint get _stroke => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint _fill(double alpha) => Paint()
    ..color = accent.withValues(alpha: alpha)
    ..style = PaintingStyle.fill;

  Offset p(Size s, double x, double y) => Offset(x * s.width, y * s.height);

  @override
  bool shouldRepaint(covariant _Base old) =>
      old.ink != ink || old.accent != accent;
}

// ─────────────────────────────── Heart ─────────────────────────────────────

class _HeartPainter extends _Base {
  _HeartPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Outer heart silhouette.
    final body = Path()
      ..moveTo(s.width * .50, s.height * .30)
      ..cubicTo(s.width * .30, s.height * .10, s.width * .05, s.height * .30,
          s.width * .20, s.height * .55)
      ..cubicTo(s.width * .28, s.height * .75, s.width * .45, s.height * .82,
          s.width * .50, s.height * .92)
      ..cubicTo(s.width * .55, s.height * .82, s.width * .72, s.height * .75,
          s.width * .80, s.height * .55)
      ..cubicTo(s.width * .95, s.height * .30, s.width * .70, s.height * .10,
          s.width * .50, s.height * .30)
      ..close();
    c.drawPath(body, _fill(.10));
    c.drawPath(body, st);

    // Septum + chamber divisions.
    c.drawLine(p(s, .50, .34), p(s, .50, .88), st);
    c.drawLine(p(s, .20, .52), p(s, .45, .52), st); // R atrium/ventricle
    c.drawLine(p(s, .55, .52), p(s, .80, .52), st); // L atrium/ventricle

    // Great vessels (top).
    final vessels = _stroke..strokeWidth = 7;
    c.drawLine(p(s, .40, .30), p(s, .36, .06), vessels); // SVC
    c.drawLine(p(s, .47, .30), p(s, .50, .04), vessels); // Aorta arch start
    c.drawArc(
        Rect.fromCircle(center: p(s, .57, .10), radius: s.width * .09),
        math.pi, math.pi, false, _stroke..strokeWidth = 7); // aortic arch
    c.drawLine(p(s, .60, .30), p(s, .64, .08), vessels); // pulmonary artery
    c.drawLine(p(s, .33, .62), p(s, .14, .66), vessels); // IVC
  }
}

// ─────────────────────────────── Neuron ────────────────────────────────────

class _NeuronPainter extends _Base {
  _NeuronPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Soma.
    final soma = Rect.fromCircle(center: p(s, .18, .5), radius: s.width * .10);
    c.drawOval(soma, _fill(.12));
    c.drawOval(soma, st);
    // Nucleus.
    c.drawCircle(p(s, .18, .5), s.width * .035, _fill(.5));
    c.drawCircle(p(s, .18, .5), s.width * .035, st);
    // Dendrites.
    for (final a in [-0.9, -0.5, 0.0, 0.5, 0.9]) {
      final dir = Offset(math.cos(math.pi + a), math.sin(a));
      final base = p(s, .18, .5) + dir * s.width * .10;
      c.drawLine(base, base + dir * s.width * .12, st);
      c.drawLine(base + dir * s.width * .12,
          base + dir * s.width * .12 + Offset(-6, -8), st);
    }
    // Axon.
    c.drawLine(p(s, .28, .5), p(s, .82, .5), _stroke..strokeWidth = 3);
    // Myelin sheaths (segments along axon).
    for (final x in [.40, .54, .68]) {
      final r = Rect.fromCenter(
          center: p(s, x, .5), width: s.width * .08, height: s.height * .08);
      c.drawOval(r, _fill(.18));
      c.drawOval(r, st);
    }
    // Axon terminals.
    for (final a in [-0.5, 0.0, 0.5]) {
      final base = p(s, .82, .5);
      final dir = Offset(math.cos(a), math.sin(a));
      c.drawLine(base, base + dir * s.width * .12, st);
    }
  }
}

// ──────────────────────────── Animal Cell ──────────────────────────────────

class _CellPainter extends _Base {
  _CellPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    final membrane = Rect.fromCircle(center: p(s, .5, .5), radius: s.width * .42);
    c.drawOval(membrane, _fill(.07));
    c.drawOval(membrane, st);
    // Nucleus.
    c.drawCircle(p(s, .42, .42), s.width * .15, _fill(.18));
    c.drawCircle(p(s, .42, .42), s.width * .15, st);
    c.drawCircle(p(s, .44, .40), s.width * .05, _fill(.5)); // nucleolus
    // Mitochondrion.
    final mito = Rect.fromCenter(
        center: p(s, .70, .60), width: s.width * .20, height: s.height * .10);
    c.drawOval(mito, _fill(.18));
    c.drawOval(mito, st);
    // Vacuole.
    c.drawCircle(p(s, .68, .32), s.width * .08, _fill(.10));
    c.drawCircle(p(s, .68, .32), s.width * .08, st);
    // Golgi (stacked arcs).
    for (var i = 0; i < 3; i++) {
      c.drawArc(
          Rect.fromCircle(
              center: p(s, .35, .68), radius: s.width * (.10 - i * .02)),
          math.pi * .2, math.pi * .6, false, st);
    }
  }
}

// ──────────────────────────── Skin layers ──────────────────────────────────

class _SkinPainter extends _Base {
  _SkinPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Three horizontal bands.
    final bands = [
      [.10, .30, .06], // epidermis
      [.30, .62, .12], // dermis
      [.62, .92, .20], // hypodermis
    ];
    for (final b in bands) {
      final r = Rect.fromLTRB(
          s.width * .08, s.height * b[0], s.width * .92, s.height * b[1]);
      c.drawRect(r, _fill(b[2]));
      c.drawRect(r, st);
    }
    // Hair shaft + follicle.
    c.drawLine(p(s, .30, .02), p(s, .30, .80), _stroke..strokeWidth = 3);
    c.drawOval(
        Rect.fromCenter(
            center: p(s, .30, .80), width: s.width * .06, height: s.height * .08),
        st);
    // Sweat gland (coiled) + duct.
    c.drawLine(p(s, .62, .14), p(s, .62, .74), st);
    c.drawCircle(p(s, .62, .78), s.width * .05, st);
  }
}

// ───────────────────────────── Long bone ───────────────────────────────────

class _LongBonePainter extends _Base {
  _LongBonePainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Vertical long bone with bulbous ends.
    final path = Path()
      ..moveTo(s.width * .34, s.height * .12)
      ..cubicTo(s.width * .20, s.height * .10, s.width * .22, s.height * .26,
          s.width * .40, s.height * .28)
      ..lineTo(s.width * .42, s.height * .72)
      ..cubicTo(s.width * .24, s.height * .74, s.width * .22, s.height * .90,
          s.width * .36, s.height * .88)
      ..lineTo(s.width * .64, s.height * .88)
      ..cubicTo(s.width * .78, s.height * .90, s.width * .76, s.height * .74,
          s.width * .58, s.height * .72)
      ..lineTo(s.width * .60, s.height * .28)
      ..cubicTo(s.width * .78, s.height * .26, s.width * .80, s.height * .10,
          s.width * .66, s.height * .12)
      ..close();
    c.drawPath(path, _fill(.10));
    c.drawPath(path, st);
    // Medullary cavity (inner line on the shaft).
    c.drawLine(p(s, .50, .30), p(s, .50, .70), _stroke..strokeWidth = 1.4);
    // Epiphyseal lines.
    c.drawLine(p(s, .40, .28), p(s, .60, .28), st);
    c.drawLine(p(s, .42, .72), p(s, .58, .72), st);
  }
}

// ─────────────────────────────── Eye ───────────────────────────────────────

class _EyePainter extends _Base {
  _EyePainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    final globe = Rect.fromCircle(center: p(s, .5, .5), radius: s.width * .38);
    c.drawOval(globe, _fill(.07));
    c.drawOval(globe, st); // sclera/retina outer
    // Cornea bulge (left).
    c.drawArc(Rect.fromCircle(center: p(s, .14, .5), radius: s.width * .14),
        -math.pi / 2, math.pi, false, st);
    // Iris + lens.
    c.drawLine(p(s, .20, .36), p(s, .20, .64), _stroke..strokeWidth = 3); // iris
    final lens = Rect.fromCenter(
        center: p(s, .26, .5), width: s.width * .07, height: s.height * .20);
    c.drawOval(lens, _fill(.2));
    c.drawOval(lens, st);
    // Optic nerve (right).
    c.drawLine(p(s, .88, .5), p(s, .99, .5), _stroke..strokeWidth = 6);
    // Pupil mark.
    c.drawCircle(p(s, .20, .5), s.width * .015, Paint()..color = ink);
  }
}

// ──────────────────────── Respiratory system ──────────────────────────────

class _RespiratoryPainter extends _Base {
  _RespiratoryPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Trachea.
    c.drawLine(p(s, .50, .08), p(s, .50, .42), _stroke..strokeWidth = 6);
    // Bronchi.
    c.drawLine(p(s, .50, .42), p(s, .34, .55), _stroke..strokeWidth = 4);
    c.drawLine(p(s, .50, .42), p(s, .66, .55), _stroke..strokeWidth = 4);
    // Lungs.
    final lLung = Path()
      ..moveTo(s.width * .34, s.height * .50)
      ..cubicTo(s.width * .12, s.height * .55, s.width * .14, s.height * .88,
          s.width * .34, s.height * .86)
      ..cubicTo(s.width * .40, s.height * .80, s.width * .40, s.height * .60,
          s.width * .34, s.height * .50)
      ..close();
    final rLung = Path()
      ..moveTo(s.width * .66, s.height * .50)
      ..cubicTo(s.width * .88, s.height * .55, s.width * .86, s.height * .88,
          s.width * .66, s.height * .86)
      ..cubicTo(s.width * .60, s.height * .80, s.width * .60, s.height * .60,
          s.width * .66, s.height * .50)
      ..close();
    for (final lung in [lLung, rLung]) {
      c.drawPath(lung, _fill(.10));
      c.drawPath(lung, st);
    }
    // Diaphragm.
    c.drawArc(Rect.fromLTRB(s.width * .12, s.height * .80, s.width * .88,
        s.height * 1.02), math.pi, math.pi, false, _stroke..strokeWidth = 3);
  }
}

// ──────────────────────── Digestive system ────────────────────────────────

class _DigestivePainter extends _Base {
  _DigestivePainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Esophagus.
    c.drawLine(p(s, .46, .06), p(s, .46, .34), _stroke..strokeWidth = 4);
    // Stomach.
    final stomach = Path()
      ..moveTo(s.width * .46, s.height * .34)
      ..cubicTo(s.width * .30, s.height * .34, s.width * .24, s.height * .52,
          s.width * .40, s.height * .54)
      ..cubicTo(s.width * .52, s.height * .54, s.width * .52, s.height * .40,
          s.width * .46, s.height * .34)
      ..close();
    c.drawPath(stomach, _fill(.14));
    c.drawPath(stomach, st);
    // Liver.
    final liver = Path()
      ..moveTo(s.width * .52, s.height * .30)
      ..lineTo(s.width * .82, s.height * .30)
      ..lineTo(s.width * .80, s.height * .46)
      ..close();
    c.drawPath(liver, _fill(.16));
    c.drawPath(liver, st);
    // Large intestine (frame).
    final colon = Path()
      ..moveTo(s.width * .30, s.height * .56)
      ..lineTo(s.width * .30, s.height * .80)
      ..lineTo(s.width * .70, s.height * .80)
      ..lineTo(s.width * .70, s.height * .54);
    c.drawPath(colon, _stroke..strokeWidth = 7);
    // Small intestine (coils).
    for (var i = 0; i < 3; i++) {
      c.drawCircle(p(s, .50, .68), s.width * (.10 - i * .03), st);
    }
  }
}

// ─────────────────────────────── Nephron ───────────────────────────────────

class _NephronPainter extends _Base {
  _NephronPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Glomerulus inside Bowman's capsule.
    c.drawCircle(p(s, .22, .24), s.width * .10, _fill(.10));
    c.drawCircle(p(s, .22, .24), s.width * .10, st);
    c.drawCircle(p(s, .22, .24), s.width * .06, _fill(.4));
    // PCT.
    c.drawLine(p(s, .32, .24), p(s, .48, .26), _stroke..strokeWidth = 4);
    // Loop of Henle (descending/ascending U).
    final loop = Path()
      ..moveTo(s.width * .48, s.height * .26)
      ..lineTo(s.width * .52, s.height * .80)
      ..arcToPoint(Offset(s.width * .64, s.height * .80),
          radius: const Radius.circular(20))
      ..lineTo(s.width * .60, s.height * .30);
    c.drawPath(loop, _stroke..strokeWidth = 4);
    // DCT.
    c.drawLine(p(s, .60, .30), p(s, .74, .28), _stroke..strokeWidth = 4);
    // Collecting duct.
    c.drawLine(p(s, .80, .22), p(s, .84, .92), _stroke..strokeWidth = 6);
    c.drawLine(p(s, .74, .28), p(s, .80, .30), st);
  }
}

// ──────────────────────────── Heart valves ─────────────────────────────────

class _HeartValvesPainter extends _Base {
  _HeartValvesPainter(super.ink, super.a);

  // Three-cusp "Mercedes" valve symbol.
  void _tricusp(Canvas c, Offset center, double r, Paint st) {
    for (var i = 0; i < 3; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / 3;
      final tip = center + Offset(math.cos(ang), math.sin(ang)) * r;
      c.drawLine(center, tip, st);
    }
    c.drawCircle(center, r, st);
  }

  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Base-of-heart cross-section.
    final base = Rect.fromCircle(center: p(s, .5, .5), radius: s.width * .42);
    c.drawOval(base, _fill(.06));
    c.drawOval(base, st);
    final r = s.width * .085;
    _tricusp(c, p(s, .50, .22), r, st); // pulmonary
    _tricusp(c, p(s, .44, .42), r, st); // aortic
    _tricusp(c, p(s, .66, .60), r, st); // tricuspid
    // Mitral = bicuspid (two cusps).
    final m = p(s, .36, .64);
    c.drawCircle(m, r, st);
    c.drawLine(m + Offset(0, -r), m + Offset(0, r), st);
  }
}

// ─────────────────────────── Blood vessels ─────────────────────────────────

class _BloodVesselPainter extends _Base {
  _BloodVesselPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Artery — thick double wall.
    final artery = Rect.fromCenter(
        center: p(s, .5, .22), width: s.width * .7, height: s.height * .14);
    c.drawRRect(
        RRect.fromRectAndRadius(artery, const Radius.circular(16)),
        _fill(.10));
    c.drawRRect(
        RRect.fromRectAndRadius(artery, const Radius.circular(16)), st);
    c.drawRRect(
        RRect.fromRectAndRadius(artery.deflate(7), const Radius.circular(10)),
        st);
    // Vein — thinner wall + valve.
    final vein = Rect.fromCenter(
        center: p(s, .5, .52), width: s.width * .7, height: s.height * .12);
    c.drawRRect(
        RRect.fromRectAndRadius(vein, const Radius.circular(16)), _fill(.10));
    c.drawRRect(RRect.fromRectAndRadius(vein, const Radius.circular(16)), st);
    c.drawRRect(
        RRect.fromRectAndRadius(vein.deflate(3), const Radius.circular(12)),
        st);
    // Valve flaps inside the vein.
    c.drawLine(p(s, .58, .47), p(s, .62, .52), st);
    c.drawLine(p(s, .58, .57), p(s, .62, .52), st);
    // Capillary — single thin tube.
    c.drawLine(p(s, .18, .80), p(s, .82, .80), st);
    c.drawLine(p(s, .18, .835), p(s, .82, .835), st);
  }
}

// ─────────────────────────── Urinary system ────────────────────────────────

class _UrinaryPainter extends _Base {
  _UrinaryPainter(super.ink, super.a);

  void _kidney(Canvas c, Size s, double cx, double cy, Paint st,
      {bool flip = false}) {
    final dir = flip ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(s.width * (cx - .06 * dir), s.height * (cy - .07))
      ..cubicTo(
          s.width * (cx - .12 * dir), s.height * (cy - .04),
          s.width * (cx - .12 * dir), s.height * (cy + .04),
          s.width * (cx - .06 * dir), s.height * (cy + .07))
      ..cubicTo(
          s.width * (cx + .02 * dir), s.height * (cy + .09),
          s.width * (cx + .04 * dir), s.height * (cy - .02),
          s.width * (cx - .02 * dir), s.height * (cy - .06))
      ..close();
    c.drawPath(path, _fill(.12));
    c.drawPath(path, st);
  }

  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    _kidney(c, s, .30, .28, st);
    _kidney(c, s, .70, .28, st, flip: true);
    // Adrenal glands (caps).
    c.drawArc(Rect.fromCircle(center: p(s, .30, .19), radius: s.width * .04),
        math.pi, math.pi, false, st);
    c.drawArc(Rect.fromCircle(center: p(s, .70, .19), radius: s.width * .04),
        math.pi, math.pi, false, st);
    // Ureters.
    c.drawLine(p(s, .31, .35), p(s, .46, .72), _stroke..strokeWidth = 3);
    c.drawLine(p(s, .69, .35), p(s, .54, .72), _stroke..strokeWidth = 3);
    // Bladder.
    final bladder = Path()
      ..moveTo(s.width * .42, s.height * .74)
      ..quadraticBezierTo(s.width * .50, s.height * .92, s.width * .58,
          s.height * .74)
      ..quadraticBezierTo(
          s.width * .50, s.height * .80, s.width * .42, s.height * .74)
      ..close();
    c.drawPath(bladder, _fill(.14));
    c.drawPath(bladder, st);
    // Urethra.
    c.drawLine(p(s, .50, .86), p(s, .50, .96), _stroke..strokeWidth = 3);
  }
}

// ─────────────────────────── Kidney anatomy ────────────────────────────────

class _KidneyPainter extends _Base {
  _KidneyPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Bean shape, hilum (concave) on the left.
    final bean = Path()
      ..moveTo(s.width * .60, s.height * .12)
      ..cubicTo(s.width * .92, s.height * .14, s.width * .92, s.height * .86,
          s.width * .60, s.height * .88)
      ..cubicTo(s.width * .42, s.height * .82, s.width * .50, s.height * .60,
          s.width * .44, s.height * .50)
      ..cubicTo(s.width * .50, s.height * .40, s.width * .42, s.height * .18,
          s.width * .60, s.height * .12)
      ..close();
    c.drawPath(bean, _fill(.08));
    c.drawPath(bean, st);
    // Cortex band (inner outline).
    final cortex = Path()
      ..moveTo(s.width * .62, s.height * .20)
      ..cubicTo(s.width * .82, s.height * .22, s.width * .82, s.height * .78,
          s.width * .62, s.height * .80);
    c.drawPath(cortex, st);
    // Renal pyramids (medulla triangles).
    for (final y in [.36, .50, .64]) {
      final t = Path()
        ..moveTo(s.width * .78, s.height * y)
        ..lineTo(s.width * .58, s.height * (y - .04))
        ..lineTo(s.width * .58, s.height * (y + .04))
        ..close();
      c.drawPath(t, _fill(.18));
      c.drawPath(t, st);
    }
    // Renal pelvis (funnel) → ureter.
    final pelvis = Path()
      ..moveTo(s.width * .54, s.height * .42)
      ..lineTo(s.width * .40, s.height * .50)
      ..lineTo(s.width * .54, s.height * .58);
    c.drawPath(pelvis, st);
    c.drawLine(p(s, .40, .50), p(s, .16, .60), _stroke..strokeWidth = 4);
  }
}

// ──────────────────────────── Fetal skull ──────────────────────────────────

class _FetalSkullPainter extends _Base {
  _FetalSkullPainter(super.ink, super.a);
  @override
  void paint(Canvas c, Size s) {
    final st = _stroke;
    // Top-down oval skull.
    final skull = Rect.fromCenter(
        center: p(s, .5, .5), width: s.width * .58, height: s.height * .82);
    c.drawOval(skull, _fill(.06));
    c.drawOval(skull, st);
    // Sagittal suture (midline).
    c.drawLine(p(s, .50, .26), p(s, .50, .74), st);
    // Coronal suture (front transverse).
    c.drawLine(p(s, .26, .36), p(s, .74, .36), st);
    // Lambdoid suture (back transverse).
    c.drawLine(p(s, .30, .64), p(s, .70, .64), st);
    // Anterior fontanelle (diamond) — front-center.
    final ant = Path()
      ..moveTo(s.width * .50, s.height * .30)
      ..lineTo(s.width * .44, s.height * .37)
      ..lineTo(s.width * .50, s.height * .44)
      ..lineTo(s.width * .56, s.height * .37)
      ..close();
    c.drawPath(ant, _fill(.22));
    c.drawPath(ant, st);
    // Posterior fontanelle (triangle) — back-center.
    final post = Path()
      ..moveTo(s.width * .50, s.height * .60)
      ..lineTo(s.width * .455, s.height * .67)
      ..lineTo(s.width * .545, s.height * .67)
      ..close();
    c.drawPath(post, _fill(.22));
    c.drawPath(post, st);
  }
}
