import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Quantisation for initial note-on.
enum Quantisation {
  off(0, 'Off'),
  eighth(8, '1/8'),
  sixteenth(4, '1/16'),
  thirtySecond(2, '1/32');

  const Quantisation(this.ticks, this.label);
  final int ticks;
  final String label;
}

/// Clock subdivisions for note retrigger while a pad is held.
enum RetriggerInterval {
  whole(32, '1/1'),
  half(16, '1/2'),
  quarter(8, '1/4'),
  eighth(4, '1/8'),
  sixteenth(2, '1/16');

  const RetriggerInterval(this.ticks, this.label);
  final int ticks;
  final String label;
}

class GridSettings extends ChangeNotifier {
  int _bpm = 128;
  int _zoom = 5;
  RetriggerInterval _retrigger = RetriggerInterval.half;
  bool _arpEnabled = false;
  ArpPattern _arpPattern = ArpPattern.triad;
  bool _echoEnabled = true;
  Quantisation _quantisation = Quantisation.off;
  bool _loaded = false;

  int get bpm => _bpm;
  int get zoom => _zoom;
  double get hexRadius => _zoom * 10.0;
  RetriggerInterval get retrigger => _retrigger;
  bool get arpEnabled => _arpEnabled;
  ArpPattern get arpPattern => _arpPattern;
  bool get echoEnabled => _echoEnabled;
  Quantisation get quantisation => _quantisation;

  // ---- persistence -----------------------------------------------------------

  static const _kBpm = 'bpm';
  static const _kZoom = 'zoom';
  static const _kRetrigger = 'retrigger';
  static const _kArpEnabled = 'arp';
  static const _kArpPattern = 'arpPat';
  static const _kEcho = 'echo';
  static const _kQuant = 'quant';

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _bpm = prefs.getInt(_kBpm) ?? 128;
    _zoom = prefs.getInt(_kZoom) ?? 5;
    _retrigger = RetriggerInterval.values[prefs.getInt(_kRetrigger) ?? 2];
    _arpEnabled = prefs.getBool(_kArpEnabled) ?? false;
    _arpPattern = ArpPattern.values[prefs.getInt(_kArpPattern) ?? 2];
    _echoEnabled = prefs.getBool(_kEcho) ?? true;
    _quantisation = Quantisation.values[prefs.getInt(_kQuant) ?? 0];
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBpm, _bpm);
    await prefs.setInt(_kZoom, _zoom);
    await prefs.setInt(_kRetrigger, _retrigger.index);
    await prefs.setBool(_kArpEnabled, _arpEnabled);
    await prefs.setInt(_kArpPattern, _arpPattern.index);
    await prefs.setBool(_kEcho, _echoEnabled);
    await prefs.setInt(_kQuant, _quantisation.index);
  }

  // ---- setters ---------------------------------------------------------------

  void setBpm(int v) {
    final c = v.clamp(60, 200);
    if (c != _bpm) { _bpm = c; _save(); notifyListeners(); }
  }

  void setZoom(int v) {
    final c = v.clamp(1, 9);
    if (c != _zoom) { _zoom = c; _save(); notifyListeners(); }
  }

  void setRetrigger(RetriggerInterval v) {
    if (v != _retrigger) { _retrigger = v; _save(); notifyListeners(); }
  }

  void setArpEnabled(bool v) {
    if (v != _arpEnabled) { _arpEnabled = v; _save(); notifyListeners(); }
  }

  void setArpPattern(ArpPattern v) {
    if (v != _arpPattern) { _arpPattern = v; _save(); notifyListeners(); }
  }

  void setEchoEnabled(bool v) {
    if (v != _echoEnabled) { _echoEnabled = v; _save(); notifyListeners(); }
  }

  void setQuantisation(Quantisation v) {
    if (v != _quantisation) { _quantisation = v; _save(); notifyListeners(); }
  }
}
