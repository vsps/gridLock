import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../grid/grid_state.dart';
import '../models/grid_settings.dart';
import 'pad_widget.dart';

/// Lays out the pad grid and handles slide-across pointer events at the
/// grid level (so dragging across cells triggers each one once per swipe).
class GridViewWidget extends StatelessWidget {
  const GridViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GridSettings>();
    final mode = settings.soundSource;
    final rows = settings.rows;
    final cols = settings.cols;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 56, bottom: 56),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / cols;
          final cellHeight = constraints.maxHeight / rows;
          final aspect = cellHeight == 0 ? 1.0 : cellWidth / cellHeight;

          final grid = GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows * cols,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: aspect,
            ),
            itemBuilder: (context, index) {
              final r = index ~/ cols;
              final c = index % cols;
              return PadWidget(row: r, col: c, rows: rows, cols: cols);
            },
          );

          // Record mode: no slide, pads handle their own long-press.
          if (mode == SoundSource.record) return grid;

          // Slide-across for synth / samples / playback.
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              final c = _col(e.localPosition.dx, cellWidth, cols);
              final r = _row(e.localPosition.dy, cellHeight, rows);
              final grid = context.read<GridState>();
              grid.beginSwipe();
              _activate(context, r, c, rows, cols);
            },
            onPointerMove: (e) {
              final c = _col(e.localPosition.dx, cellWidth, cols);
              final r = _row(e.localPosition.dy, cellHeight, rows);
              if (context.read<GridState>().tryClaimPad(r, c)) {
                _activate(context, r, c, rows, cols);
              }
            },
            child: grid,
          );
        },
      ),
    );
  }

  static int _col(double x, double cellW, int cols) =>
      (x / cellW).floor().clamp(0, cols - 1);

  static int _row(double y, double cellH, int rows) =>
      (y / cellH).floor().clamp(0, rows - 1);

  static void _activate(
      BuildContext context, int r, int c, int rows, int cols) {
    context.read<AudioService>().play(r, c);
    context.read<GridState>().addEnergy(r, c, rows, cols);
  }
}
