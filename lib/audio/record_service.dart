import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Outcome of a [RecordService.start] attempt.
enum RecordStartResult {
  /// Recording began successfully.
  started,

  /// Another recording is already in progress (single-recorder invariant).
  busy,

  /// Microphone permission was denied, or the recorder failed to start.
  denied,
}

/// Thin wrapper around the `record` package, enforcing a single active
/// recording at a time (one shared [AudioRecorder] hardware stream).
///
/// Requires `RECORD_AUDIO` permission in AndroidManifest.xml:
/// ```xml
/// <uses-permission android:name="android.permission.RECORD_AUDIO"/>
/// ```
class RecordService {
  final AudioRecorder _recorder = AudioRecorder();

  // Single-recorder guard. Flipped synchronously (before any await) so two
  // concurrent start()/stop() calls can never race past the check.
  bool _busy = false;
  String? _currentPath;

  /// Whether a recording is currently in progress.
  bool get isBusy => _busy;

  /// Starts recording a mono 44.1 kHz WAV. Call [stop] to finish.
  ///
  /// Returns [RecordStartResult.busy] if a recording is already running, or
  /// [RecordStartResult.denied] if the microphone permission is unavailable.
  Future<RecordStartResult> start() async {
    if (_busy) return RecordStartResult.busy;
    _busy = true; // claim synchronously so a second caller sees busy

    if (!await _recorder.hasPermission()) {
      _busy = false;
      return RecordStartResult.denied;
    }

    final path = '${Directory.systemTemp.path}/gridlock_rec_'
        '${DateTime.now().millisecondsSinceEpoch}.wav';
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      _currentPath = path;
      return RecordStartResult.started;
    } catch (_) {
      _busy = false;
      _currentPath = null;
      return RecordStartResult.denied;
    }
  }

  /// Stops recording and returns the captured WAV bytes, or `null` if no
  /// recording was active or the capture failed. Idempotent: calling [stop]
  /// when not recording is a no-op that returns `null`.
  Future<Uint8List?> stop() async {
    if (!_busy) return null;
    _busy = false; // release synchronously so a concurrent stop() no-ops
    try {
      final path = await _recorder.stop();
      _currentPath = null;
      if (path == null || path.isEmpty) return null;
      final file = File(path);
      final bytes = await file.readAsBytes();
      file.delete().ignore();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Cancels an in-progress recording without returning its bytes.
  Future<void> cancel() async {
    if (!_busy) return;
    _busy = false;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (_currentPath != null) {
      File(_currentPath!).delete().ignore();
      _currentPath = null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
