import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../clock/clock_service.dart';
import '../grid/grid_state.dart';
import '../grid/harmonic_table.dart';
import '../models/grid_settings.dart';
import 'hex_cell_painter.dart';

/// Full-screen harmonic table (Tonnetz) keyboard.
///
/// 50 px top/bottom margins; only fully-visible circles are drawn and
/// interactive. Wave propagation cascades outward via [GridState.trigger].
class HexGridWidget extends StatefulWidget {
  const HexGridWidget({super.key});

  @override
  State<HexGridWidget> createState() => _HexGridWidgetState();
}

class _HexGridWidgetState extends State<HexGridWidget> {
  static const double _margin = 50.0;

  final Map<int, (int, int)> _pointerCell = {};
  final Map<int, DateTime> _heldSince = {};
  final Map<int, int> _echoLevel = {};

  int _lastRetriggerTick = -1;
  ClockService? _clock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newClock = context.read<ClockService>();
    if (newClock != _clock) {
      _clock?.removeListener(_onClockTick);
      _clock = newClock;
      _clock!.addListener(_onClockTick);
    }
  }

  @override
  void dispose() {
    _clock?.removeListener(_onClockTick);
    super.dispose();
  }

  // ---- layout ----------------------------------------------------------------

  _Layout _makeLayout(BuildContext ctx) =>
      _Layout.fromSettings(context.read<GridSettings>(), MediaQuery.of(ctx).size);

  Offset _cellCenter(_Layout lay, int row, int col) {
    final x = lay.originX + col * lay.cellW + (row.isOdd ? lay.hexR : 0) + lay.hexR;
    final y = lay.originY + row * lay.rowH + lay.hexR;
    return Offset(x, y);
  }

  bool _isVisible(_Layout lay, Size size, double cx, double cy) {
    return cx - lay.hexR >= 0 &&
        cx + lay.hexR <= size.width &&
        cy - lay.hexR >= _margin &&
        cy + lay.hexR <= size.height - _margin;
  }

  (int, int)? _hitTest(_Layout lay, Size size, Offset pos) {
    final approxRow = ((pos.dy - lay.originY - lay.hexR) / lay.rowH).round();
    final approxCol = ((pos.dx - lay.originX - lay.hexR) / lay.cellW).round();

    (int, int)? best;
    double bestDist = double.infinity;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = approxRow + dr;
        final c = approxCol + dc;
        if (r < 0 || r >= lay.rows || c < 0 || c >= lay.cols) continue;
        final center = _cellCenter(lay, r, c);
        if (!_isVisible(lay, size, center.dx, center.dy)) continue;
        final dist = (pos - center).distance;
        if (dist < lay.hexR && dist < bestDist) {
          bestDist = dist;
          best = (r, c);
        }
      }
    }
    return best;
  }

  static int _key(int row, int col) => row * 1000 + col;

  // ---- audio -----------------------------------------------------------------

  void _fire(_Layout lay, int row, int col, int echoLevel) {
    final sem = HarmonicTable.semitones(row, col, lay.centerRow, lay.centerCol);
    context.read<AudioService>().playWithEcho(sem, echoLevel);
    context.read<GridState>().trigger(row, col, lay.rows, lay.cols);
  }

  void _activate(_Layout lay, int row, int col, {bool quantized = false}) {
    final k = _key(row, col);
    final echo = _echoLevel[k] ?? 0;
    if (quantized) {
      final delay = _clock?.msToNextTick() ?? 0;
      if (delay <= 0) {
        _fire(lay, row, col, echo);
      } else {
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted && _heldSince.containsKey(k)) {
            _fire(lay, row, col, _echoLevel[k] ?? 0);
          }
        });
      }
    } else {
      _fire(lay, row, col, echo);
    }
  }

  // ---- clock retrigger -------------------------------------------------------

  void _onClockTick() {
    if (!mounted) return;
    final tick = _clock?.tickCount ?? 0;
    if (tick % ClockService.ticksPerHalfBar != 0) return;
    if (tick == _lastRetriggerTick) return;
    _lastRetriggerTick = tick;
    if (_heldSince.isEmpty) return;

    final lay = _makeLayout(context);
    final bpm = context.read<GridSettings>().bpm;
    final barMs = (60000.0 / bpm * 4).round();

    for (final entry in List.of(_heldSince.entries)) {
      final k = entry.key;
      final barsHeld = DateTime.now().difference(entry.value).inMilliseconds ~/ barMs;
      final echo = barsHeld.clamp(0, 4);
      _echoLevel[k] = echo;
      _fire(lay, k ~/ 1000, k % 1000, echo);
    }
    setState(() {});
  }

  // ---- pointer events --------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    final size = MediaQuery.of(context).size;
    final lay = _makeLayout(context);
    final cell = _hitTest(lay, size, e.localPosition);
    if (cell == null) return;
    final (row, col) = cell;
    final k = _key(row, col);

    _pointerCell[e.pointer] = cell;
    _heldSince.putIfAbsent(k, () => DateTime.now());
    _echoLevel.putIfAbsent(k, () => 0);

    context.read<GridState>().beginSwipe();
    _activate(lay, row, col, quantized: true);
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent e) {
    final size = MediaQuery.of(context).size;
    final lay = _makeLayout(context);
    final cell = _hitTest(lay, size, e.localPosition);
    if (cell == null) return;
    final prev = _pointerCell[e.pointer];
    if (prev == cell) return;

    if (prev != null) {
      final prevK = _key(prev.$1, prev.$2);
      final stillHeld =
          _pointerCell.entries.any((en) => en.key != e.pointer && en.value == prev);
      if (!stillHeld) {
        _heldSince.remove(prevK);
        _echoLevel.remove(prevK);
      }
    }

    final (row, col) = cell;
    final k = _key(row, col);
    _pointerCell[e.pointer] = cell;
    _heldSince.putIfAbsent(k, () => DateTime.now());
    _echoLevel.putIfAbsent(k, () => 0);

    if (context.read<GridState>().tryClaimPad(row, col)) {
      _activate(lay, row, col);
    }
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent e) => _releasePointer(e.pointer);
  void _onPointerCancel(PointerCancelEvent e) => _releasePointer(e.pointer);

  void _releasePointer(int pointerId) {
    final cell = _pointerCell.remove(pointerId);
    if (cell == null) return;
    final k = _key(cell.$1, cell.$2);
    if (!_pointerCell.values.contains(cell)) {
      _heldSince.remove(k);
      _echoLevel.remove(k);
    }
    setState(() {});
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GridSettings>();
    final size = MediaQuery.of(context).size;
    final lay = _Layout.fromSettings(settings, size);
    final gridState = context.watch<GridState>();
    final heldKeys = Set<int>.from(_heldSince.keys);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: CustomPaint(
        painter: _HexGridPainter(
          layout: lay,
          size: size,
          margin: _margin,
          gridState: gridState,
          heldKeys: heldKeys,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ---- layout ---------------------------------------------------------------

class _Layout {
  const _Layout(
    this.rows,
    this.cols,
    this.hexR,
    this.originX,
    this.originY,
    this.centerRow,
    this.centerCol,
  );

  factory _Layout.fromSettings(GridSettings settings, Size size) {
    const margin = 50.0;
    final hexR = settings.hexRadius;
    final cellW = hexR * 2;
    final rowH = hexR * math.sqrt(3);
    final effectiveH = size.height - 2 * margin;
    var cols = (size.width / cellW).ceil() + 2;
    var rows = (effectiveH / rowH).ceil() + 2;
    if (cols.isEven) cols++;
    if (rows.isEven) rows++;
    return _Layout(
      rows,
      cols,
      hexR,
      (size.width - cols * cellW) / 2,
      margin + (effectiveH - rows * rowH) / 2,
      rows ~/ 2,
      cols ~/ 2,
    );
  }

  final int rows;
  final int cols;
  final double hexR;
  final double originX;
  final double originY;
  final int centerRow;
  final int centerCol;

  double get cellW => hexR * 2;
  double get rowH => hexR * math.sqrt(3);
}

// ---- painter ---------------------------------------------------------------

class _HexGridPainter extends CustomPainter {
  const _HexGridPainter({
    required this.layout,
    required this.size,
    required this.margin,
    required this.gridState,
    required this.heldKeys,
  }) : super(repaint: gridState);

  final _Layout layout;
  final Size size;
  final double margin;
  final GridState gridState;
  final Set<int> heldKeys;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final lay = layout;

    for (var row = 0; row < lay.rows; row++) {
      for (var col = 0; col < lay.cols; col++) {
        final cx = lay.originX + col * lay.cellW + (row.isOdd ? lay.hexR : 0) + lay.hexR;
        final cy = lay.originY + row * lay.rowH + lay.hexR;

        // Skip any circle that would be clipped.
        if (cx - lay.hexR < 0 ||
            cx + lay.hexR > size.width ||
            cy - lay.hexR < margin ||
            cy + lay.hexR > size.height - margin) {
          continue;
        }

        final sem = HarmonicTable.semitones(row, col, lay.centerRow, lay.centerCol);
        final energy = gridState.cellEnergy(row, col);
        final key = row * 1000 + col;

        canvas.save();
        canvas.translate(cx - lay.hexR, cy - lay.hexR);
        HexCellPainter(
          energy: energy,
          semitones: sem,
          hexRadius: lay.hexR,
          isHeld: heldKeys.contains(key),
        ).paint(canvas, Size(lay.hexR * 2, lay.hexR * 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_HexGridPainter old) =>
      old.layout.hexR != layout.hexR ||
      old.layout.rows != layout.rows ||
      old.heldKeys.length != heldKeys.length ||
      old.heldKeys != heldKeys;
}
