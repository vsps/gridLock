import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grid_settings.dart';
import 'pad_widget.dart';

/// Lays out the pad grid, filling the available space without scrolling.
/// Cell aspect ratio is computed from the constraints so any rows×cols
/// combination fits on screen.
class GridViewWidget extends StatelessWidget {
  const GridViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GridSettings>();
    final rows = settings.rows;
    final cols = settings.cols;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / cols;
          final cellHeight = constraints.maxHeight / rows;
          final aspect = cellHeight == 0 ? 1.0 : cellWidth / cellHeight;

          return GridView.builder(
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
        },
      ),
    );
  }
}
