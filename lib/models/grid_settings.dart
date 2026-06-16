import 'package:flutter/foundation.dart';

/// Arpeggiator patterns.
enum ArpPattern {
  up('Up'),
  down('Down'),
  triad('Triad'),
  convDiv('Conv/Div'),
  random('Random');

  const ArpPattern(this.label);
  final String label;
}

/// Clock subdivisions for note retrigger while a pad is held.
enum RetriggerInterval {
  whole(16, '1/1'),
  half(8, '1/2'),
  quarter(4, '1/4'),
  eighth(2, '1/8'),
  sixteenth(1, '1/16');

  const RetriggerInterval(this.ticks, this.label);
  final int ticks; // 1/16th-note ticks per interval
  final String label;
}

class GridSettings extends ChangeNotifier {
  int _bpm = 128;
  int _zoom = 5;
  RetriggerInterval _retrigger = RetriggerInterval.half;
  bool _arpEnabled = false;
  ArpPattern _arpPattern = ArpPattern.triad;
  bool _echoEnabled = true;

  int get bpm => _bpm;
  int get zoom => _zoom;
  double get hexRadius => _zoom * 10.0;
  RetriggerInterval get retrigger => _retrigger;
  bool get arpEnabled => _arpEnabled;
  ArpPattern get arpPattern => _arpPattern;
  bool get echoEnabled => _echoEnabled;

  void setBpm(int v) {
    final c = v.clamp(60, 200);
    if (c != _bpm) { _bpm = c; notifyListeners(); }
  }

  void setZoom(int v) {
    final c = v.clamp(1, 9);
    if (c != _zoom) { _zoom = c; notifyListeners(); }
  }

  void setRetrigger(RetriggerInterval v) {
    if (v != _retrigger) { _retrigger = v; notifyListeners(); }
  }

  void setArpEnabled(bool v) {
    if (v != _arpEnabled) { _arpEnabled = v; notifyListeners(); }
  }

  void setArpPattern(ArpPattern v) {
    if (v != _arpPattern) { _arpPattern = v; notifyListeners(); }
  }

  void setEchoEnabled(bool v) {
    if (v != _echoEnabled) { _echoEnabled = v; notifyListeners(); }
  }
}
