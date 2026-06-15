import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Thin wrapper around the `record` package for 1-second loop recording.
///
/// Requires `RECORD_AUDIO` permission in AndroidManifest.xml:
/// ```xml
/// <uses-permission android:name="android.permission.RECORD_AUDIO"/>
/// ```
class RecordService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  /// Whether a recording is currently in progress.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Starts recording a mono 44.1 kHz WAV. Call [stop] to finish.
  /// Automatically requests the microphone permission if needed.
  Future<void> start() async {
    if (await _recorder.hasPermission()) {
      final path =
          '${Directory.systemTemp.path}/gridlock_rec_'
          '${DateTime.now().millisecondsSinceEpoch}.wav';
      _currentPath = path;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
    }
  }

  /// Stops recording and returns the captured WAV bytes, or `null` on failure.
  Future<Uint8List?> stop() async {
    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) return null;
      final file = File(path);
      final bytes = await file.readAsBytes();
      // Clean up the temp file.
      file.delete().ignore();
      _currentPath = null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Cancels an in-progress recording without saving.
  Future<void> cancel() async {
    try {
      await _recorder.stop();
      // Clean up the temp file if it was created.
      if (_currentPath != null) {
        File(_currentPath!).delete().ignore();
        _currentPath = null;
      }
    } catch (_) {}
  }

  void dispose() {
    _recorder.dispose();
  }
}
