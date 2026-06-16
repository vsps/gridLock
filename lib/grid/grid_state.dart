import 'dart:async';

import 'package:flutter/foundation.dart';

/// Per-cell energy (0–1) that decays over 2 s and propagates to hex neighbours
/// at depth 1 (+50 %) and depth 2 (+25 %) on each trigger.
///
/// No ripple flash — callers just read [cellEnergy] to tint cells.
class GridState extends ChangeNotifier {
  GridState() : _clock = Stopwatch()..start();

  static const int _stride = 64; // wide enough for any grid width

  static const double _decayPerMs = 1.0 / 2000.0; // full decay in 2 s

  static const double _pressBoost = 0.25;
  static const double _wave1Boost = 0.50;
  static const double _wave2Boost = 0.25;

  final Map<int, double> _energy = {};
  final Stopwatch _clock;
  Timer? _ticker;
  int _lastTickMs = 0;

  int _key(int row, int col) => row * _stride + col;
  int get _now => _clock.elapsedMilliseconds;

  // ---- slide dedup -----------------------------------------------------------

  int _lastPadKey = -1;

  void beginSwipe() => _lastPadKey = -1;

  bool tryClaimPad(int row, int col) {
    final k = _key(row, col);
    if (k == _lastPadKey) return false;
    _lastPadKey = k;
    return true;
  }

  // ---- public API ------------------------------------------------------------

  double cellEnergy(int row, int col) =>
      (_energy[_key(row, col)] ?? 0.0).clamp(0.0, 1.0);

  void addEnergy(int row, int col, int rows, int cols) {
    _applyBoost(row, col, _pressBoost, rows, cols);
    _propagateEnergy(row, col, rows, cols);
    _ensureTicker();
    notifyListeners();
  }

  // ---- hex adjacency ---------------------------------------------------------

  /// Returns the 6 hex neighbours for offset-row layout.
  static List<(int, int)> hexNeighbors(int row, int col) {
    if (row.isEven) {
      return [
        (row - 1, col - 1), (row - 1, col),
        (row,     col - 1), (row,     col + 1),
        (row + 1, col - 1), (row + 1, col),
      ];
    } else {
      return [
        (row - 1, col),     (row - 1, col + 1),
        (row,     col - 1), (row,     col + 1),
        (row + 1, col),     (row + 1, col + 1),
      ];
    }
  }

  // ---- propagation -----------------------------------------------------------

  void _applyBoost(int row, int col, double boost, int rows, int cols) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    final k = _key(row, col);
    _energy[k] = ((_energy[k] ?? 0.0) + boost).clamp(0.0, 1.0);
  }

  void _propagateEnergy(int row, int col, int rows, int cols) {
    final visited = <int>{_key(row, col)};
    final wave1 = <(int, int)>[];
    final wave2 = <(int, int)>[];

    for (final (nr, nc) in hexNeighbors(row, col)) {
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      if (visited.add(_key(nr, nc))) wave1.add((nr, nc));
    }
    for (final (r1, c1) in wave1) {
      _applyBoost(r1, c1, _wave1Boost, rows, cols);
      for (final (nr, nc) in hexNeighbors(r1, c1)) {
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        if (visited.add(_key(nr, nc))) wave2.add((nr, nc));
      }
    }
    for (final (r2, c2) in wave2) {
      _applyBoost(r2, c2, _wave2Boost, rows, cols);
    }
  }

  // ---- ticker ----------------------------------------------------------------

  void _ensureTicker() {
    _lastTickMs = _now;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _now;
      final elapsed = now - _lastTickMs;
      _lastTickMs = now;

      final decay = _decayPerMs * elapsed;
      _energy.updateAll((_, v) => (v - decay).clamp(0.0, 1.0));
      _energy.removeWhere((_, v) => v == 0.0);

      notifyListeners();
      if (_energy.isEmpty) {
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
