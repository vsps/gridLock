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
/// Lower-left visible cell = C2. Right = +P5, up = +M3.
/// 50 px top/bottom margins; only fully-visible circles are drawn/interactive.
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
  int _arpStep = 0;
  ClockService? _clock;

  static const List<int> _up = [0, 2, 4];       // 1-2-3
  static const List<int> _down = [4, 2, 0];     // 3-2-1
  static const List<int> _triad = [0, 4, 7];    // 1-3-5
  static const List<int> _convDiv = [0, 7, 4];  // 1-5-3
  static const List<int> _randomPool = [0, 2, 4, 7];
  final math.Random _rng = math.Random();

  int _nextArpOffset(ArpPattern p) {
    switch (p) {
      case ArpPattern.up:
        return _up[_arpStep % _up.length];
      case ArpPattern.down:
        return _down[_arpStep % _down.length];
      case ArpPattern.triad:
        return _triad[_arpStep % _triad.length];
      case ArpPattern.convDiv:
        return _convDiv[_arpStep % _convDiv.length];
      case ArpPattern.random:
        return _randomPool[_rng.nextInt(_randomPool.length)];
    }
  }

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

  bool _isVisible(_Layout lay, Size size, double cx, double cy) =>
      cx - lay.hexR >= 0 &&
      cx + lay.hexR <= size.width &&
      cy - lay.hexR >= _margin &&
      cy + lay.hexR <= size.height - _margin;

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
    final sem = HarmonicTable.semitones(row, col, lay.refRow, lay.refCol);
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
    final settings = context.read<GridSettings>();
    if (tick % settings.retrigger.ticks != 0) return;
    if (tick == _lastRetriggerTick) return;
    _lastRetriggerTick = tick;
    if (_heldSince.isEmpty) return;

    final lay = _makeLayout(context);
    final bpm = settings.bpm;
    final barMs = (60000.0 / bpm * 4).round();
    final arp = settings.arpEnabled;
    final arpOffset = arp ? _nextArpOffset(settings.arpPattern) : 0;

    final audio = context.read<AudioService>();
    final gridState = context.read<GridState>();

    for (final entry in List.of(_heldSince.entries)) {
      final k = entry.key;
      final barsHeld = DateTime.now().difference(entry.value).inMilliseconds ~/ barMs;
      final echo = settings.echoEnabled ? barsHeld.clamp(0, 4) : 0;
      _echoLevel[k] = echo;

      final row = k ~/ 1000;
      final col = k % 1000;
      final baseSem = HarmonicTable.semitones(row, col, lay.refRow, lay.refCol);

      audio.playWithEcho(baseSem + (arp ? arpOffset : 0), echo);
      gridState.trigger(row, col, lay.rows, lay.cols);
    }

    if (arp) _arpStep = (_arpStep + 1) % _up.length;
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
  const _Layout({
    required this.rows,
    required this.cols,
    required this.hexR,
    required this.originX,
    required this.originY,
    required this.refRow,
    required this.refCol,
  });

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

    final originX = (size.width - cols * cellW) / 2;
    final originY = margin + (effectiveH - rows * rowH) / 2;

    // Lower-left visible cell — anchored to C2 in HarmonicTable.
    final lastRow = ((size.height - margin - originY - 2 * hexR) / rowH)
        .floor()
        .clamp(0, rows - 1);
    final firstCol = lastRow.isOdd
        ? (-(originX + hexR) / cellW).ceil().clamp(0, cols - 1)
        : (-originX / cellW).ceil().clamp(0, cols - 1);

    return _Layout(
      rows: rows,
      cols: cols,
      hexR: hexR,
      originX: originX,
      originY: originY,
      refRow: lastRow,
      refCol: firstCol,
    );
  }

  final int rows;
  final int cols;
  final double hexR;
  final double originX;
  final double originY;

  /// Lower-left visible cell — maps to C2 via [HarmonicTable.semitones].
  final int refRow;
  final int refCol;

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
        final cx =
            lay.originX + col * lay.cellW + (row.isOdd ? lay.hexR : 0) + lay.hexR;
        final cy = lay.originY + row * lay.rowH + lay.hexR;

        if (cx - lay.hexR < 0 ||
            cx + lay.hexR > size.width ||
            cy - lay.hexR < margin ||
            cy + lay.hexR > size.height - margin) {
          continue;
        }

        final sem = HarmonicTable.semitones(row, col, lay.refRow, lay.refCol);
        final color = gridState.cellColor(row, col);
        final key = row * 1000 + col;

        canvas.save();
        canvas.translate(cx - lay.hexR, cy - lay.hexR);
        HexCellPainter(
          activeColor: color,
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
      old.heldKeys != heldKeys;
}
