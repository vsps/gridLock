import 'dart:async';

import 'package:flutter/foundation.dart';

class _CellAnim {
  const _CellAnim({required this.waveStartMs, required this.peak});
  final int waveStartMs; // stopwatch ms when fade-in begins
  final double peak;     // max energy (1.0 at ring 0, -10% per ring)
}

/// Wave-based energy model.
///
/// Each trigger BFS-propagates across the whole grid. Ring N starts fading in
/// once ring N-1 reaches full brightness (i.e., after N × fadeInMs). Each ring
/// is 10 % dimmer than the previous. Fade-in is fast; fade-out is slow (2 s).
class GridState extends ChangeNotifier {
  GridState() : _clock = Stopwatch()..start();

  static const int _stride = 64;
  static const int _fadeInMs = 80;
  static const int _fadeOutMs = 2000;
  static const double _dimPerRing = 0.10;
  static const double _minPeak = 0.05;

  final Map<int, _CellAnim> _anims = {};
  final Stopwatch _clock;
  Timer? _ticker;

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

  double cellEnergy(int row, int col) => _energyAt(_anims[_key(row, col)], _now);

  /// Trigger a wave from ([row],[col]), propagating across the whole [rows]×[cols] grid.
  void trigger(int row, int col, int rows, int cols) {
    final now = _now;

    // BFS — record each cell's ring depth from the trigger point.
    final depth = <int, int>{};
    final queue = <(int, int, int)>[];

    void enqueue(int r, int c, int d) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return;
      final k = _key(r, c);
      if (depth.containsKey(k)) return;
      depth[k] = d;
      queue.add((r, c, d));
    }

    enqueue(row, col, 0);
    var head = 0;
    while (head < queue.length) {
      final (r, c, d) = queue[head++];
      for (final (nr, nc) in hexNeighbors(r, c)) {
        enqueue(nr, nc, d + 1);
      }
    }

    // Apply animations — only update a cell if the new wave is brighter at the
    // moment it would peak than whatever is already scheduled.
    for (final entry in depth.entries) {
      final k = entry.key;
      final d = entry.value;
      final waveStart = now + d * _fadeInMs;
      final peak = (1.0 - d * _dimPerRing).clamp(_minPeak, 1.0);
      final peakTime = waveStart + _fadeInMs;
      final existing = _anims[k];
      if (existing == null || peak > _energyAt(existing, peakTime)) {
        _anims[k] = _CellAnim(waveStartMs: waveStart, peak: peak);
      }
    }

    _ensureTicker();
    notifyListeners();
  }

  // ---- hex adjacency ---------------------------------------------------------

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

  // ---- helpers ---------------------------------------------------------------

  static double _energyAt(_CellAnim? anim, int nowMs) {
    if (anim == null) return 0;
    final elapsed = nowMs - anim.waveStartMs;
    if (elapsed < 0) return 0;
    if (elapsed < _fadeInMs) return anim.peak * elapsed / _fadeInMs;
    final decay = elapsed - _fadeInMs;
    if (decay >= _fadeOutMs) return 0;
    return anim.peak * (1.0 - decay / _fadeOutMs);
  }

  // ---- ticker ----------------------------------------------------------------

  void _ensureTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _now;
      _anims.removeWhere((_, a) => now - a.waveStartMs >= _fadeInMs + _fadeOutMs);
      notifyListeners();
      if (_anims.isEmpty) {
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
