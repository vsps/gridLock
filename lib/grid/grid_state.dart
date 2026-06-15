import 'package:flutter/foundation.dart';

import 'pentatonic_map.dart';

/// Tracks which pads are currently in their "flash" animation state, driven by
/// the ripple controller. Pads listen via `context.select` so only the cells
/// whose flash state changed rebuild.
class GridState extends ChangeNotifier {
  final Set<int> _flashing = {};

  // Stride must exceed max columns so each cell maps to a unique key.
  static const int _stride = PentatonicMap.columnStride;

  int _key(int row, int col) => row * _stride + col;

  bool isFlashing(int row, int col) => _flashing.contains(_key(row, col));

  void setFlash(int row, int col, {required bool on}) {
    final k = _key(row, col);
    final changed = on ? _flashing.add(k) : _flashing.remove(k);
    if (changed) notifyListeners();
  }
}
