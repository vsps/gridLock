import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class _CellAnim {
  const _CellAnim({
    required this.fadeInStartMs,
    required this.fadeOutStartMs,
    required this.peak,
    required this.hue,
  });

  final int fadeInStartMs;
  final int fadeOutStartMs; // when fade-out begins (after hold at peak)
  final double peak;
  final double hue; // HSV hue 0–360

  static const int fadeInMs = 80;
  static const int fadeOutMs = 1000;

  double energyAt(int nowMs) {
    final sinceIn = nowMs - fadeInStartMs;
    if (sinceIn < 0) return 0;
    if (sinceIn < fadeInMs) return peak * sinceIn / fadeInMs;
    final sinceFadeOut = nowMs - fadeOutStartMs;
    if (sinceFadeOut < 0) return peak; // holding at peak
    if (sinceFadeOut >= fadeOutMs) return 0;
    return peak * (1.0 - sinceFadeOut / fadeOutMs);
  }

  bool isDone(int nowMs) => nowMs >= fadeOutStartMs + fadeOutMs;
}

/// Wave-based energy model with random hue per trigger and FIFO fade-out.
///
/// On each trigger:
/// - Rings fade IN from centre outward (cascade, 80 ms per ring).
/// - Once all rings are full, rings fade OUT from centre outward too
///   (150 ms stagger per ring), so the ripple dims as it expands.
/// - Each trigger gets a random HSV hue — cellColor() returns the blended Color.
class GridState extends ChangeNotifier {
  GridState() : _clock = Stopwatch()..start();

  static const int _stride = 64;
  static const double _dimPerRing = 0.10;
  static const double _minPeak = 0.05;
  static const int _fadeOutStagger = 150; // ms between successive rings fading out

  static const Color _offColor = Color(0xFF101018);

  final Map<int, _CellAnim> _anims = {};
  final Stopwatch _clock;
  Timer? _ticker;
  final math.Random _rng = math.Random();

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

  /// Blended fill colour for the cell, or null when the cell is at rest.
  Color? cellColor(int row, int col) {
    final anim = _anims[_key(row, col)];
    if (anim == null) return null;
    final energy = anim.energyAt(_now);
    if (energy <= 0) return null;
    final base = HSVColor.fromAHSV(1.0, anim.hue, 1.0, 1.0).toColor();
    return Color.lerp(_offColor, base, energy);
  }

  /// Trigger a full-board wave from ([row],[col]).
  /// Assigns a fresh random hue to every cell touched by this ripple.
  void trigger(int row, int col, int rows, int cols) {
    final now = _now;
    final hue = _rng.nextDouble() * 360;

    // BFS — depth of every reachable cell.
    final depths = <int, int>{};
    final queue = <(int, int, int)>[];

    void enqueue(int r, int c, int d) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return;
      final k = _key(r, c);
      if (depths.containsKey(k)) return;
      depths[k] = d;
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

    // Fade-out starts only after ALL rings have reached peak, then staggers
    // outward — so the centre begins fading before the outer rings.
    final maxDepth = depths.values.fold(0, math.max);
    final allPeakMs = now + (maxDepth + 1) * _CellAnim.fadeInMs;

    for (final entry in depths.entries) {
      final k = entry.key;
      final d = entry.value;
      final fadeInStart = now + d * _CellAnim.fadeInMs;
      final fadeOutStart = allPeakMs + d * _fadeOutStagger;
      final peak = (1.0 - d * _dimPerRing).clamp(_minPeak, 1.0);

      // Update only if this trigger would be brighter at the new peak moment.
      final existing = _anims[k];
      if (existing == null ||
          peak >= existing.energyAt(fadeInStart + _CellAnim.fadeInMs)) {
        _anims[k] = _CellAnim(
          fadeInStartMs: fadeInStart,
          fadeOutStartMs: fadeOutStart,
          peak: peak,
          hue: hue,
        );
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

  // ---- ticker ----------------------------------------------------------------

  void _ensureTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _now;
      _anims.removeWhere((_, a) => a.isDone(now));
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
