import 'package:flutter/material.dart';

import '../grid/harmonic_table.dart';

/// Paints a single hex cell as a circle with energy-based fill and optional
/// note label when the radius is large enough.
class HexCellPainter extends CustomPainter {
  const HexCellPainter({
    required this.energy,
    required this.semitones,
    required this.hexRadius,
    required this.isHeld,
  });

  final double energy;
  final int semitones;
  final double hexRadius;
  final bool isHeld;

  static const Color _off = Color(0xFF101018);
  static const Color _amber = Color(0xFFFF6A00);
  static const Color _red = Color(0xFFFF2020);
  static const Color _heldBorder = Color(0xFFFFFFCC);
  static const Color _cBorder = Color(0xFF88AAFF);
  static const Color _defaultBorder = Color(0xFF2A2A2A);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = hexRadius - 3;

    // Fill colour based on energy.
    Color fill;
    if (energy <= 0) {
      fill = _off;
    } else if (energy <= 0.5) {
      fill = Color.lerp(_off, _amber, energy * 2)!;
    } else {
      fill = Color.lerp(_amber, _red, (energy - 0.5) * 2)!;
    }

    final fillPaint = Paint()..color = fill;
    canvas.drawCircle(Offset(cx, cy), r, fillPaint);

    // Border: held = bright, C note = blue tint, default = dim.
    final borderColor = isHeld
        ? _heldBorder
        : HarmonicTable.isC(semitones)
            ? _cBorder
            : _defaultBorder;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHeld ? 2.5 : 1.0;
    canvas.drawCircle(Offset(cx, cy), r, borderPaint);

    // Note label when cells are large enough.
    if (hexRadius > 25) {
      final label = HarmonicTable.noteName(semitones);
      final span = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withAlpha(isHeld ? 220 : 140),
          fontSize: (hexRadius * 0.28).clamp(8, 14),
          fontWeight: FontWeight.w500,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(HexCellPainter old) =>
      old.energy != energy ||
      old.semitones != semitones ||
      old.isHeld != isHeld ||
      old.hexRadius != hexRadius;
}
