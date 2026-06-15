import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../audio/record_service.dart';
import '../grid/grid_state.dart';
import '../grid/pentatonic_map.dart';
import '../models/grid_settings.dart';

/// A single pad in the grid.
///
/// In non-record modes the pad is purely visual — the parent
/// [GridViewWidget] handles slide-across activation.
///
/// In [SoundSource.record] mode a [GestureDetector] long-press starts a
/// rolling 1-second recording. The pad fades from dim red to bright green
/// each second, synced with the recording loop.
class PadWidget extends StatefulWidget {
  const PadWidget({
    super.key,
    required this.row,
    required this.col,
    required this.rows,
    required this.cols,
  });

  final int row;
  final int col;
  final int rows;
  final int cols;

  @override
  State<PadWidget> createState() => _PadWidgetState();
}

class _PadWidgetState extends State<PadWidget> {
  static const Color _offColor = Color(0xFF101018);
  static const Color _rootColor = Color(0xFF192A19); // pale green tint
  static const Color _borderColor = Color(0xFF2A2A2A);
  static const Color _recordStart = Color(0xFF4A0000);
  static const Color _recordEnd = Color(0xFF00CC00);

  static const int _loopMs = 1000;

  // ---- recording state -------------------------------------------------------

  bool _recording = false;
  double _cycleProgress = 0.0;
  int _cycleStartMs = 0;
  Timer? _animTimer;

  /// In-flight loop rollover (stop + restart). Guards against overlapping
  /// rollovers and lets [_finishRecording] wait for one to settle.
  Future<void>? _cycleOp;

  /// Last *complete* 1-second clip captured during the hold. Preferred over the
  /// in-progress partial so the saved loop is a clean second regardless of when
  /// the finger lifts.
  Uint8List? _lastCompleteWav;

  // Service refs captured at record start, so async callbacks never touch
  // `context` after the widget may have unmounted.
  RecordService? _rec;
  AudioService? _audio;

  // ---- long-press handlers (record mode only) --------------------------------

  Future<void> _onLongPressStart(LongPressStartDetails details) async {
    if (context.read<GridSettings>().soundSource != SoundSource.record) return;
    if (_recording) return;

    final rec = context.read<RecordService>();
    final audio = context.read<AudioService>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await rec.start();
    if (!mounted) {
      // Widget gone while awaiting; release the recorder if we grabbed it.
      if (result == RecordStartResult.started) rec.cancel();
      return;
    }
    switch (result) {
      case RecordStartResult.denied:
        messenger.showSnackBar(const SnackBar(
          content: Text('Microphone permission denied — cannot record.'),
        ));
        return;
      case RecordStartResult.busy:
        // Another pad is already recording (single-recorder).
        return;
      case RecordStartResult.started:
        break;
    }

    _rec = rec;
    _audio = audio;
    _lastCompleteWav = null;
    _cycleStartMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _recording = true;
      _cycleProgress = 0.0;
    });

    _animTimer =
        Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_recording) _finishRecording();
  }

  void _onLongPressUp() {
    if (_recording) _finishRecording();
  }

  /// Drives the progress animation and kicks off a loop rollover once a full
  /// second has elapsed (one rollover at a time via [_cycleOp]).
  void _tick() {
    if (!_recording) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _cycleStartMs;
    if (mounted) {
      setState(() => _cycleProgress = (elapsed % _loopMs) / _loopMs);
    }
    if (elapsed >= _loopMs && _cycleOp == null) {
      _cycleOp = _rollover();
    }
  }

  /// Finalises the current 1 s clip and, if still held, starts the next loop.
  Future<void> _rollover() async {
    final wav = await _rec!.stop();
    if (wav != null) _lastCompleteWav = wav;
    if (_recording) {
      await _rec!.start();
      _cycleStartMs = DateTime.now().millisecondsSinceEpoch;
    }
    _cycleOp = null;
  }

  Future<void> _finishRecording() async {
    if (!_recording) return;
    _recording = false; // synchronous: stops any pending rollover restart
    _animTimer?.cancel();
    _animTimer = null;

    // Let an in-flight rollover settle (it won't restart now that _recording
    // is false), then stop the recorder. stop() is idempotent, so a
    // double-stop after the rollover already stopped is a harmless no-op.
    final pending = _cycleOp;
    if (pending != null) await pending;
    final partial = await _rec?.stop();

    // Prefer the last full second; fall back to the partial if released early.
    final saved = _lastCompleteWav ?? partial;
    if (saved != null) {
      await _audio?.storeRecording(widget.row, widget.col, saved);
    }
    _lastCompleteWav = null;
    _rec = null;
    _audio = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    // If torn down mid-recording (mode switch, grid resize), release the
    // shared recorder so it isn't left running for the next session.
    if (_recording) {
      _recording = false;
      _rec?.cancel();
    }
    super.dispose();
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rippleColor =
        context.watch<GridState>().cellColor(widget.row, widget.col);
    final mode = context.watch<GridSettings>().soundSource;
    final audio = context.read<AudioService>();

    Color fillColor;
    if (_recording) {
      final t = _cycleProgress.clamp(0.0, 1.0);
      fillColor = Color.lerp(_recordStart, _recordEnd, t)!;
    } else if (rippleColor != null) {
      fillColor = rippleColor;
    } else if ((mode == SoundSource.playback || mode == SoundSource.record) &&
        audio.hasRecording(widget.row, widget.col)) {
      fillColor = const Color(0xFF1A1A22);
    } else if (PentatonicMap.isRoot(widget.row, widget.col)) {
      fillColor = _rootColor;
    } else {
      fillColor = _offColor;
    }

    final base = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
      ),
    );

    // Record mode: long-press fires the pad's own gesture detector.
    if (mode == SoundSource.record) {
      return GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onLongPressUp: _onLongPressUp,
        child: base,
      );
    }

    // All other modes: the parent grid handles slide / tap activation.
    return base;
  }
}
