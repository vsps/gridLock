import 'dart:async';

import 'package:flutter/material.dart';

import 'ripple_controller.dart';

/// Tracks the colour ripple animation across grid cells and per-swipe
/// deduplication so a sliding finger triggers each pad at most once.
class GridState extends ChangeNotifier {
  GridState() : _clock = Stopwatch()..start();

  // Layout stride (large enough for unique cell keys across all grid sizes).
  static const int _stride = 8;

  // Animation timing (milliseconds).
  static const int _staggerMs = 60;
  static const int _redMs = 120;
  static const int _transitionMs = 180;
  static const int _fadeMs = 300;
  static const int _totalMs = _redMs + _transitionMs + _fadeMs;

  // Off-state colour (matches the scaffold background).
  static const Color _offColor = Color(0xFF101018);

  /// Cell key → wall-clock activation time (ms).
  final Map<int, int> _activations = {};

  final Stopwatch _clock;
  Timer? _ticker;

  int _key(int row, int col) => row * _stride + col;
  int get _now => _clock.elapsedMilliseconds;

  // ----- swipe-slide tracking --------------------------------------------------

  // Last cell the pointer triggered during the current slide. Dedup is against
  // only this cell (not the whole swipe) so dragging back over a pad re-fires
  // it, while jitter within one cell does not retrigger.
  int _lastCellKey = -1;

  /// Call on every new pointer-down to start a fresh slide gesture.
  void beginSwipe() {
    _lastCellKey = -1;
  }

  /// Returns true when the pointer has entered a different cell than the one it
  /// last triggered, marking the new cell as current.
  bool tryEnterCell(int row, int col) {
    final k = _key(row, col);
    if (k == _lastCellKey) return false;
    _lastCellKey = k;
    return true;
  }

  // ----- ripple API ------------------------------------------------------------

  /// Starts a ripple centred on ([row], [col]) across a [rows]×[cols] grid.
  void triggerRipple(int row, int col, int rows, int cols) {
    _activations.clear();
    final now = _now;
    RippleController.propagate(row, col, rows, cols, (r, c, wave) {
      _activations[_key(r, c)] = now + wave * _staggerMs;
    });
    _ensureTicker();
    notifyListeners();
  }

  /// Returns the ripple colour for the given cell, or `null` when idle.
  Color? cellColor(int row, int col) {
    final activation = _activations[_key(row, col)];
    if (activation == null) return null;
    final elapsed = _now - activation;
    if (elapsed < 0 || elapsed > _totalMs) return null;

    if (elapsed < _redMs) {
      return Colors.red;
    } else if (elapsed < _redMs + _transitionMs) {
      final t = (elapsed - _redMs) / _transitionMs;
      return Color.lerp(Colors.red, Colors.green, t)!;
    } else {
      final t = (elapsed - _redMs - _transitionMs) / _fadeMs;
      return Color.lerp(Colors.green, _offColor, t)!;
    }
  }

  // ----- internal --------------------------------------------------------------

  void _ensureTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _activations.removeWhere((_, t) => _now - t > _totalMs + 200);
      notifyListeners();
      if (_activations.isEmpty) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
