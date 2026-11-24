// Shared live-tracker overlay: draws the REPORTED geometry only (face
// box, smoothed eye points with anatomical L/R labels, eye regions).
// Stale positions render dimmed. Nothing is drawn when the tracker
// reports nothing — absence of markers IS the diagnostic.
//
// Used by the screening eye-positioning view and the research-only eye
// tracking debug screen. Anatomical labels follow the PHYSICAL camera
// image (mirror-correct) and are never swapped for RTL layouts.

import 'package:flutter/material.dart';
import '../../features/camera/eye_tracking.dart';

class EyeOverlay extends StatelessWidget {
  final EyeStatus? status;
  final Size rawSize;
  final int rotationDeg;
  final bool mirrored;
  final bool locked;
  final double pulse;
  const EyeOverlay({
    super.key,
    required this.status,
    required this.rawSize,
    required this.rotationDeg,
    required this.mirrored,
    this.locked = false,
    this.pulse = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final box =
          Size(constraints.maxWidth, constraints.maxHeight);
      return CustomPaint(
        size: box,
        painter: _EyeOverlayPainter(
          status: status,
          rawSize: rawSize.width > 0 ? rawSize : const Size(1280, 720),
          rotationDeg: rotationDeg,
          mirrored: mirrored,
          boxSize: box,
          locked: locked,
          pulse: pulse,
        ),
      );
    });
  }
}

class _EyeOverlayPainter extends CustomPainter {
  final EyeStatus? status;
  final Size rawSize;
  final int rotationDeg;
  final bool mirrored;
  final Size boxSize;
  final bool locked;
  final double pulse;

  // Anatomical labels are laid out once: per-frame TextPainter.layout()
  // on the UI thread is pure overhead for two constant glyphs.
  static final TextPainter _leftLabel = TextPainter(
    text: const TextSpan(
        text: 'L',
        style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700)),
    textDirection: TextDirection.ltr,
  )..layout();
  static final TextPainter _rightLabel = TextPainter(
    text: const TextSpan(
        text: 'R',
        style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700)),
    textDirection: TextDirection.ltr,
  )..layout();

  _EyeOverlayPainter({
    required this.status,
    required this.rawSize,
    required this.rotationDeg,
    required this.mirrored,
    required this.boxSize,
    required this.locked,
    required this.pulse,
  });

  Offset _map(Offset raw) => EyeCoords.imageToPreview(
      raw: raw,
      rawSize: rawSize,
      rotationDeg: rotationDeg,
      mirrored: mirrored,
      previewSize: boxSize);

  @override
  void paint(Canvas canvas, Size size) {
    final st = status;
    if (st == null || st.faceBox == null) return;
    final dim = st.positionsStale;
    final int alpha = dim ? 120 : 255;
    final b = st.faceBox!;
    final p1 = _map(Offset(b.left, b.top));
    final p2 = _map(Offset(b.right, b.bottom));
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color =
          (locked ? const Color(0xFF7FD1C0) : Colors.white)
              .withAlpha(alpha);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromPoints(p1, p2), const Radius.circular(18)),
        boxPaint);
    if (locked) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF7FD1C0)
            .withAlpha((140 + 80 * pulse).round().clamp(0, 255));
      final grow = 6 + 4 * pulse;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromPoints(
                  p1 - Offset(grow, grow), p2 + Offset(grow, grow)),
              const Radius.circular(22)),
          ring);
    }
    _drawEye(canvas, st.smoothLeft, true, alpha);
    _drawEye(canvas, st.smoothRight, false, alpha);
  }

  void _drawEye(Canvas canvas, EyePoint? pt, bool isLeft, int alpha) {
    if (pt == null) return;
    final c = _map(Offset(pt.x, pt.y));
    final region = EyeCoords.eyeRegion(pt, 0.16);
    final r1 = _map(Offset(region.left, region.top));
    final r2 = _map(Offset(region.right, region.bottom));
    final regionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (isLeft ? const Color(0xFF7FD1C0) : Colors.amberAccent)
          .withAlpha(alpha);
    canvas.drawRect(Rect.fromPoints(r1, r2), regionPaint);
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = (isLeft ? const Color(0xFF0E7C7B) : const Color(0xFF9A6B00))
          .withAlpha(alpha);
    canvas.drawCircle(c, 7, dotPaint);
    canvas.drawCircle(
        c,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withAlpha(alpha));
    // Anatomical label follows the PHYSICAL image (mirror-correct).
    // Never swapped for RTL: L always marks the subject's left eye.
    (isLeft ? _leftLabel : _rightLabel).paint(canvas, c + const Offset(9, -18));
  }

  @override
  bool shouldRepaint(covariant _EyeOverlayPainter old) =>
      old.status != status ||
      old.boxSize != boxSize ||
      old.pulse != pulse ||
      old.locked != locked ||
      // Mapping inputs: a camera switch (mirror flip) or rotation change
      // with otherwise identical values must still repaint, or markers
      // render with the previous lens's geometry.
      old.rawSize != rawSize ||
      old.rotationDeg != rotationDeg ||
      old.mirrored != mirrored;
}
