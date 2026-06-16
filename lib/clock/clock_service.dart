import 'dart:async';

import 'package:flutter/foundation.dart';

/// BPM clock ticking at 1/32nd-note resolution (8 ticks per beat).
///
/// Listeners are notified on every tick. Check [tickCount] % N to detect
/// bar subdivisions. [msToNextTick] gives the delay to the next tick boundary
/// for quantised scheduling.
class ClockService extends ChangeNotifier {
  int _bpm;
  int _tickCount = 0;
  Timer? _timer;
  DateTime _lastTickTime = DateTime.now();

  /// Half-bar in ticks (4/4 at 32nd-note resolution: 16 ticks = half bar).
  static const int ticksPerHalfBar = 16;
  static const int ticksPerBar = 32;
  static const int ticksPerBeat = 8;

  ClockService({int bpm = 128}) : _bpm = bpm;

  int get tickCount => _tickCount;
  int get bpm => _bpm;

  Duration get _interval =>
      Duration(microseconds: (60000000 / (_bpm * ticksPerBeat)).round());

  void start() {
    _timer?.cancel();
    _lastTickTime = DateTime.now();
    _timer = Timer.periodic(_interval, (_) => _onTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void setBpm(int bpm) {
    _bpm = bpm.clamp(60, 200);
    if (_timer != null) {
      stop();
      start();
    }
  }

  /// Milliseconds until the next 1/32nd-note tick boundary.
  int msToNextTick() {
    final elapsed =
        DateTime.now().difference(_lastTickTime).inMicroseconds / 1000.0;
    final intervalMs = _interval.inMicroseconds / 1000.0;
    final remaining = intervalMs - (elapsed % intervalMs);
    return remaining.ceil();
  }

  void _onTick() {
    _lastTickTime = DateTime.now();
    _tickCount++;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
