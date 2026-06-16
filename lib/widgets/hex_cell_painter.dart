import 'package:flutter/material.dart';

import '../grid/harmonic_table.dart';

/// Paints a single hex cell as a circle.
///
/// [activeColor] is the blended ripple colour from GridState (null = at rest).
class HexCellPainter extends CustomPainter {
  const HexCellPainter({
    required this.activeColor,
    required this.semitones,
    required this.hexRadius,
    required this.isHeld,
  });

  final Color? activeColor;
  final int semitones;
  final double hexRadius;
  final bool isHeld;

  static const Color _off = Color(0xFF101018);
  static const Color _heldBorder = Color(0xFFFFFFCC);
  static const Color _cBorder = Color(0xFF88AAFF);
  static const Color _defaultBorder = Color(0xFF2A2A2A);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = hexRadius - 3;

    final fillPaint = Paint()..color = activeColor ?? _off;
    canvas.drawCircle(Offset(cx, cy), r, fillPaint);

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

    if (hexRadius > 25) {
      final label = HarmonicTable.noteName(semitones);
      final textColor = activeColor != null
          ? Colors.white.withAlpha(220)
          : Colors.white.withAlpha(80);
      final span = TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
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
      old.activeColor != activeColor ||
      old.semitones != semitones ||
      old.isHeld != isHeld ||
      old.hexRadius != hexRadius;
}
