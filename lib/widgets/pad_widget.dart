import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../grid/grid_state.dart';
import '../grid/pentatonic_map.dart';
import '../grid/ripple_controller.dart';

/// A single colourful pad. Tapping plays its tone and starts a visual-only
/// ripple to neighbouring pads.
class PadWidget extends StatelessWidget {
  const PadWidget({
    super.key,
    required this.row,
    required this.col,
    required this.rows,
    required this.cols,
  });

  final int row;
  final int col;
  final int rows;
  final int cols;

  static const int _waveDelayMs = 150;
  static const int _flashHoldMs = 200;

  Color _baseColor() {
    final index = row * PentatonicMap.columnStride + col;
    final hue = (index % 8) * 45.0; // eight evenly-spaced hues
    return HSLColor.fromAHSL(1.0, hue, 0.88, 0.55).toColor();
  }

  void _onTap(BuildContext context) {
    context.read<AudioService>().play(row, col);
    final grid = context.read<GridState>();

    RippleController.propagate(row, col, rows, cols, (r, c, wave) {
      Future.delayed(Duration(milliseconds: wave * _waveDelayMs), () {
        grid.setFlash(r, c, on: true);
        Future.delayed(const Duration(milliseconds: _flashHoldMs), () {
          grid.setFlash(r, c, on: false);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final flashing =
        context.select<GridState, bool>((g) => g.isFlashing(row, col));
    final base = _baseColor();
    final color = flashing
        ? HSLColor.fromColor(base).withLightness(0.90).toColor()
        : base;

    return GestureDetector(
      onTap: () => _onTap(context),
      child: AnimatedScale(
        scale: flashing ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: base.withAlpha(128),
                blurRadius: flashing ? 16 : 6,
                spreadRadius: flashing ? 2 : 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
