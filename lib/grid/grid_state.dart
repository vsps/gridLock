import 'dart:async';

import 'package:flutter/material.dart';

/// Tracks per-cell energy (0-100 %) that decays over time and ripples outward
/// when a pad hits 100 %.
///
/// Pressing a pad adds 25 %. When energy reaches 100 % the pad resets to 0 %
/// and fires a propagation: cardinal neighbours +50 %, their neighbours +25 %.
/// If a neighbour hits 100 % from propagation it cascades.
///
/// A fast visual flash wave sweeps across **all** cells on every trigger
/// (staggered by Manhattan distance) so the user sees a wave even though
/// only neighbours receive energy.
class GridState extends ChangeNotifier {
  GridState() : _clock = Stopwatch()..start();

  // Layout stride for unique cell keys.
  static const int _stride = 8;

  // ---- tunables --------------------------------------------------------------

  /// Decay rate: fraction of full energy lost per millisecond (100 % in 1.5 s).
  static const double _decayPerMs = 1.0 / 1500.0;

  static const double _pressBoost = 0.25;
  static const double _primaryBoost = 0.50;
  static const double _secondaryBoost = 0.25;

  /// Flash wave: stagger per Manhattan-distance step and total flash duration.
  static const int _flashStaggerMs = 25;
  static const int _flashDurationMs = 350;

  static const List<List<int>> _deltas = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  // ---- state -----------------------------------------------------------------

  final Map<int, double> _energy = {};

  /// Flash animation: cell key → wall-clock start time (ms).
  final Map<int, int> _flashStart = {};

  final Stopwatch _clock;
  Timer? _ticker;
  int _lastTickMs = 0;

  int _key(int row, int col) => row * _stride + col;
  int get _now => _clock.elapsedMilliseconds;

  // ---- public API ------------------------------------------------------------

  /// Current energy for the cell, 0.0 – 1.0.
  double cellEnergy(int row, int col) =>
      (_energy[_key(row, col)] ?? 0.0).clamp(0.0, 1.0);

  /// Flash colour for the cell, or null when no flash is active.
  Color? flashColor(int row, int col) {
    final start = _flashStart[_key(row, col)];
    if (start == null) return null;
    final elapsed = _now - start;
    if (elapsed < 0 || elapsed > _flashDurationMs) return null;
    if (elapsed < 80) return Colors.red;
    final t = (elapsed - 80) / (_flashDurationMs - 80);
    return Color.lerp(Colors.red, const Color(0x00000000), t);
  }

  /// Adds [_pressBoost] energy to the pad at ([row], [col]). If the pad
  /// reaches 100 % it triggers a ripple propagation across the given grid.
  void addEnergy(int row, int col, int rows, int cols) {
    _applyBoost(row, col, _pressBoost, rows, cols);
    _ensureTicker();
    notifyListeners();
  }

  /// Slide-aware claim — prevents re-triggering from jitter within one cell
  /// while allowing a pad to fire again once the finger leaves and returns.
  int _lastPadKey = -1;

  void beginSwipe() {
    _lastPadKey = -1;
  }

  bool tryClaimPad(int row, int col) {
    final k = _key(row, col);
    if (k == _lastPadKey) return false;
    _lastPadKey = k;
    return true;
  }

  // ---- internal --------------------------------------------------------------

  void _applyBoost(int row, int col, double boost, int rows, int cols) {
    final k = _key(row, col);
    final old = _energy[k] ?? 0.0;
    final neu = (old + boost).clamp(0.0, 1.0);

    if (neu >= 1.0 && old < 1.0) {
      _energy[k] = 0.0;
      _startFlashWave(row, col, rows, cols);
      _propagateEnergy(row, col, rows, cols);
    } else {
      _energy[k] = neu;
    }
  }

  /// Visual flash BFS across **all** cells.
  void _startFlashWave(int startRow, int startCol, int rows, int cols) {
    final now = _now;
    final visited = <int>{};
    final queue = <List<int>>[];

    visited.add(_key(startRow, startCol));
    queue.add([startRow, startCol, 0]);

    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      final r = cur[0];
      final c = cur[1];
      final wave = cur[2];
      _flashStart[_key(r, c)] = now + wave * _flashStaggerMs;

      for (final d in _deltas) {
        final nr = r + d[0];
        final nc = c + d[1];
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        final nk = _key(nr, nc);
        if (visited.add(nk)) {
          queue.add([nr, nc, wave + 1]);
        }
      }
    }
  }

  /// Energy propagation: neighbours +50 %, their neighbours +25 %.
  void _propagateEnergy(int startRow, int startCol, int rows, int cols) {
    final visited = <int>{_key(startRow, startCol)};
    final wave1 = <int>[];

    for (final d in _deltas) {
      final nr = startRow + d[0];
      final nc = startCol + d[1];
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      final nk = _key(nr, nc);
      if (visited.add(nk)) wave1.add(nk);
    }

    for (final nk in wave1) {
      final r = nk ~/ _stride;
      final c = nk % _stride;
      _applyBoost(r, c, _primaryBoost, rows, cols);
    }

    for (final nk in wave1) {
      final r = nk ~/ _stride;
      final c = nk % _stride;
      for (final d in _deltas) {
        final nr = r + d[0];
        final nc = c + d[1];
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        final nnk = _key(nr, nc);
        if (visited.add(nnk)) {
          _applyBoost(nr, nc, _secondaryBoost, rows, cols);
        }
      }
    }
  }

  // ---- ticker ----------------------------------------------------------------

  void _ensureTicker() {
    _lastTickMs = _clock.elapsedMilliseconds;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _clock.elapsedMilliseconds;
      final elapsed = now - _lastTickMs;
      _lastTickMs = now;

      final decay = _decayPerMs * elapsed;
      _energy.updateAll((_, v) => (v - decay).clamp(0.0, 1.0));
      _energy.removeWhere((_, v) => v == 0.0);

      _flashStart.removeWhere((_, t) => now - t > _flashDurationMs + 100);

      notifyListeners();
      if (_energy.isEmpty && _flashStart.isEmpty) {
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
