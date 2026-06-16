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
  final int fadeOutStartMs;
  final double peak;
  final double hue;

  static const int fadeInMs = 150;
  static const int fadeOutMs = 500;

  double energyAt(int nowMs) {
    final sinceIn = nowMs - fadeInStartMs;
    if (sinceIn < 0) return 0;
    if (sinceIn < fadeInMs) return peak * sinceIn / fadeInMs;
    final sinceFadeOut = nowMs - fadeOutStartMs;
    if (sinceFadeOut < 0) return peak;
    if (sinceFadeOut >= fadeOutMs) return 0;
    return peak * (1.0 - sinceFadeOut / fadeOutMs);
  }

  bool isDone(int nowMs) => nowMs >= fadeOutStartMs + fadeOutMs;
}

/// Wave-based energy model with random hue per trigger and smooth blending.
///
/// Each trigger pushes a new [_CellAnim] onto every cell.  [cellColor]
/// sums the energies of all active anims for that cell and blends their
/// hues, so overlapping ripples smoothly fade on and off together.
class GridState extends ChangeNotifier {
  GridState() : _clock = Stopwatch()..start();

  static const int _stride = 64;
  static const double _dimPerRing = 0.10;
  static const double _minPeak = 0.05;
  static const int _fadeOutStagger = 150;

  static const Color _offColor = Color(0xFF101018);

  final Map<int, List<_CellAnim>> _anims = {};
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

  /// Blended fill colour from all active anims, or null when at rest.
  Color? cellColor(int row, int col) {
    final list = _anims[_key(row, col)];
    if (list == null || list.isEmpty) return null;

    final now = _now;
    double totalEnergy = 0;
    double weightedHueX = 0;
    double weightedHueY = 0;

    for (final a in list) {
      final e = a.energyAt(now);
      if (e <= 0) continue;
      totalEnergy += e;
      final rad = a.hue * math.pi / 180;
      weightedHueX += e * math.cos(rad);
      weightedHueY += e * math.sin(rad);
    }

    if (totalEnergy <= 0) return null;

    // Blend hues on the colour wheel, then mix toward off-colour.
    final blendedRad = math.atan2(weightedHueY, weightedHueX);
    final blendedHue = (blendedRad * 180 / math.pi) % 360;
    final clampedEnergy = totalEnergy.clamp(0.0, 1.0);

    final base =
        HSVColor.fromAHSV(1.0, blendedHue, 1.0, 1.0).toColor();
    return Color.lerp(_offColor, base, clampedEnergy);
  }

  /// Trigger a full-board wave.  Appends a fresh [_CellAnim] to every cell
  /// so overlapping ripples blend smoothly.
  void trigger(int row, int col, int rows, int cols) {
    final now = _now;
    final hue = _rng.nextDouble() * 360;

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

    final maxDepth = depths.values.fold(0, math.max);
    final allPeakMs = now + (maxDepth + 1) * _CellAnim.fadeInMs;

    for (final entry in depths.entries) {
      final k = entry.key;
      final d = entry.value;
      final fadeInStart = now + d * _CellAnim.fadeInMs;
      final fadeOutStart = allPeakMs + d * _fadeOutStagger;
      final peak = (1.0 - d * _dimPerRing).clamp(_minPeak, 1.0);

      (_anims[k] ??= []).add(_CellAnim(
        fadeInStartMs: fadeInStart,
        fadeOutStartMs: fadeOutStart,
        peak: peak,
        hue: hue,
      ));
    }

    _ensureTicker();
    notifyListeners();
  }

  // ---- hex adjacency ---------------------------------------------------------

  static List<(int, int)> hexNeighbors(int row, int col) {
    if (row.isEven) {
      return [
        (row - 1, col - 1), (row - 1, col),
        (row, col - 1),     (row, col + 1),
        (row + 1, col - 1), (row + 1, col),
      ];
    } else {
      return [
        (row - 1, col),     (row - 1, col + 1),
        (row, col - 1),     (row, col + 1),
        (row + 1, col),     (row + 1, col + 1),
      ];
    }
  }

  // ---- ticker ----------------------------------------------------------------

  void _ensureTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _now;
      for (final list in _anims.values) {
        list.removeWhere((a) => a.isDone(now));
      }
      _anims.removeWhere((_, list) => list.isEmpty);
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
