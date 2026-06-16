import 'package:flutter/foundation.dart';

class GridSettings extends ChangeNotifier {
  int _bpm = 128;
  int _zoom = 5; // 1–9; hexRadius = zoom * 10 dp

  int get bpm => _bpm;
  int get zoom => _zoom;
  double get hexRadius => _zoom * 10.0;

  void setBpm(int v) {
    final clamped = v.clamp(60, 200);
    if (clamped != _bpm) {
      _bpm = clamped;
      notifyListeners();
    }
  }

  void setZoom(int v) {
    final clamped = v.clamp(1, 9);
    if (clamped != _zoom) {
      _zoom = clamped;
      notifyListeners();
    }
  }
}
