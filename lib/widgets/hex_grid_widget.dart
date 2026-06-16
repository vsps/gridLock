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
/// Layout: offset-row hex circles, centered on middle C.
/// - Tap → first trigger quantised to next 1/16th tick.
/// - Slide → immediate trigger per new cell.
/// - Hold → retrigger every half-bar (8 ticks), echo level grows per bar held.
class HexGridWidget extends StatefulWidget {
  const HexGridWidget({super.key});

  @override
  State<HexGridWidget> createState() => _HexGridWidgetState();
}

class _HexGridWidgetState extends State<HexGridWidget> {
  // pointerId → (row, col)
  final Map<int, (int, int)> _pointerCell = {};

  // cellKey → when finger first pressed this cell
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

  // ---- layout helpers --------------------------------------------------------

  _Layout _layout(BuildContext context) {
    final hexR = context.read<GridSettings>().hexRadius;
    final size = MediaQuery.of(context).size;
    final cellW = hexR * 2;
    final rowH = hexR * math.sqrt(3);
    var cols = (size.width / cellW).ceil() + 2;
    var rows = (size.height / rowH).ceil() + 2;
    if (cols.isEven) cols++;
    if (rows.isEven) rows++;
    final centerRow = rows ~/ 2;
    final centerCol = cols ~/ 2;
    final originX = (size.width - cols * cellW) / 2;
    final originY = (size.height - rows * rowH) / 2;
    return _Layout(rows, cols, hexR, originX, originY, centerRow, centerCol);
  }

  Offset _cellCenter(_Layout lay, int row, int col) {
    final x =
        lay.originX + col * lay.hexR * 2 + (row.isOdd ? lay.hexR : 0) + lay.hexR;
    final y = lay.originY + row * lay.hexR * math.sqrt(3) + lay.hexR;
    return Offset(x, y);
  }

  (int, int)? _hitTest(_Layout lay, Offset pos) {
    final approxRow =
        ((pos.dy - lay.originY - lay.hexR) / (lay.hexR * math.sqrt(3))).round();
    final approxCol =
        ((pos.dx - lay.originX - lay.hexR) / (lay.hexR * 2)).round();

    (int, int)? best;
    double bestDist = double.infinity;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = approxRow + dr;
        final c = approxCol + dc;
        if (r < 0 || r >= lay.rows || c < 0 || c >= lay.cols) continue;
        final center = _cellCenter(lay, r, c);
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

  void _activate(
    _Layout lay,
    int row,
    int col, {
    bool quantized = false,
    int echoLevel = 0,
  }) {
    final audio = context.read<AudioService>();
    final gridState = context.read<GridState>();
    final clock = _clock;
    final sem = HarmonicTable.semitones(row, col, lay.centerRow, lay.centerCol);

    void fire() {
      audio.playWithEcho(sem, echoLevel);
      gridState.addEnergy(row, col, lay.rows, lay.cols);
    }

    if (quantized && clock != null) {
      final delay = clock.msToNextTick();
      if (delay <= 0) {
        fire();
      } else {
        final k = _key(row, col);
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted && _heldSince.containsKey(k)) fire();
        });
      }
    } else {
      fire();
    }
  }

  // ---- clock retrigger -------------------------------------------------------

  void _onClockTick() {
    if (!mounted) return;
    final clock = _clock;
    if (clock == null) return;
    final tick = clock.tickCount;
    if (tick % ClockService.ticksPerHalfBar != 0) return;
    if (tick == _lastRetriggerTick) return;
    _lastRetriggerTick = tick;
    if (_heldSince.isEmpty) return;

    final lay = _layout(context);
    final bpmVal = context.read<GridSettings>().bpm;
    final barMs = (60000.0 / bpmVal * 4).round();

    for (final entry in List.of(_heldSince.entries)) {
      final k = entry.key;
      final since = entry.value;
      final barsHeld =
          DateTime.now().difference(since).inMilliseconds ~/ barMs;
      final echo = barsHeld.clamp(0, 4);
      _echoLevel[k] = echo;

      final row = k ~/ 1000;
      final col = k % 1000;
      _activate(lay, row, col, echoLevel: echo);
    }
    setState(() {});
  }

  // ---- pointer events --------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    final lay = _layout(context);
    final cell = _hitTest(lay, e.localPosition);
    if (cell == null) return;
    final (row, col) = cell;
    final k = _key(row, col);

    _pointerCell[e.pointer] = cell;
    _heldSince.putIfAbsent(k, () => DateTime.now());
    _echoLevel.putIfAbsent(k, () => 0);

    context.read<GridState>().beginSwipe();
    _activate(lay, row, col, quantized: true, echoLevel: _echoLevel[k]!);
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent e) {
    final lay = _layout(context);
    final cell = _hitTest(lay, e.localPosition);
    if (cell == null) return;
    final prev = _pointerCell[e.pointer];
    if (prev == cell) return;

    // Release previous cell if no other pointer holds it.
    if (prev != null) {
      final prevK = _key(prev.$1, prev.$2);
      final stillHeld = _pointerCell.entries
          .any((en) => en.key != e.pointer && en.value == prev);
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
      _activate(lay, row, col, echoLevel: _echoLevel[k]!);
    }
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent e) => _releasePointer(e.pointer);
  void _onPointerCancel(PointerCancelEvent e) => _releasePointer(e.pointer);

  void _releasePointer(int pointerId) {
    final cell = _pointerCell.remove(pointerId);
    if (cell == null) return;
    final k = _key(cell.$1, cell.$2);
    final stillHeld =
        _pointerCell.values.any((c) => c == cell);
    if (!stillHeld) {
      _heldSince.remove(k);
      _echoLevel.remove(k);
    }
    setState(() {});
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watch so layout recomputes if zoom changes.
    final settings = context.watch<GridSettings>();
    final lay = _Layout.fromSettings(settings, MediaQuery.of(context).size);
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
          gridState: gridState,
          heldKeys: heldKeys,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ---- layout data class --------------------------------------------------------

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
    final hexR = settings.hexRadius;
    final cellW = hexR * 2;
    final rowH = hexR * math.sqrt(3);
    var cols = (size.width / cellW).ceil() + 2;
    var rows = (size.height / rowH).ceil() + 2;
    if (cols.isEven) cols++;
    if (rows.isEven) rows++;
    return _Layout(
      rows,
      cols,
      hexR,
      (size.width - cols * cellW) / 2,
      (size.height - rows * rowH) / 2,
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
}

// ---- painter -----------------------------------------------------------------

class _HexGridPainter extends CustomPainter {
  const _HexGridPainter({
    required this.layout,
    required this.gridState,
    required this.heldKeys,
  }) : super(repaint: gridState);

  final _Layout layout;
  final GridState gridState;
  final Set<int> heldKeys;

  @override
  void paint(Canvas canvas, Size size) {
    final lay = layout;
    final cellW = lay.hexR * 2;
    final rowH = lay.hexR * math.sqrt(3);

    for (var row = 0; row < lay.rows; row++) {
      for (var col = 0; col < lay.cols; col++) {
        final cx =
            lay.originX + col * cellW + (row.isOdd ? lay.hexR : 0) + lay.hexR;
        final cy = lay.originY + row * rowH + lay.hexR;
        final sem =
            HarmonicTable.semitones(row, col, lay.centerRow, lay.centerCol);
        final energy = gridState.cellEnergy(row, col);
        final key = row * 1000 + col;
        final isHeld = heldKeys.contains(key);

        canvas.save();
        canvas.translate(cx - lay.hexR, cy - lay.hexR);
        HexCellPainter(
          energy: energy,
          semitones: sem,
          hexRadius: lay.hexR,
          isHeld: isHeld,
        ).paint(canvas, Size(lay.hexR * 2, lay.hexR * 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_HexGridPainter old) =>
      old.layout.hexR != layout.hexR ||
      old.layout.rows != layout.rows ||
      old.heldKeys.length != heldKeys.length;
}
