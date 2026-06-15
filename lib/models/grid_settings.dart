import 'package:flutter/foundation.dart';

/// Parent-configurable grid dimensions.
class GridSettings extends ChangeNotifier {
  GridSettings({int rows = 4, int cols = 4})
      : _rows = rows.clamp(minDim, maxDim),
        _cols = cols.clamp(minDim, maxDim);

  static const int minDim = 3;
  static const int maxDim = 8;

  int _rows;
  int _cols;

  int get rows => _rows;
  int get cols => _cols;

  void setRows(int value) {
    final v = value.clamp(minDim, maxDim);
    if (v != _rows) {
      _rows = v;
      notifyListeners();
    }
  }

  void setCols(int value) {
    final v = value.clamp(minDim, maxDim);
    if (v != _cols) {
      _cols = v;
      notifyListeners();
    }
  }
}
