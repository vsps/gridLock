import 'package:flutter/foundation.dart';

/// Sound source for the grid pads.
enum SoundSource {
  /// Synthesised pentatonic tones (default).
  synth,

  /// Pre-recorded WAV samples loaded from assets/samples/.
  samples,

  /// Long-press to record a rolling 1s loop (no playback in this mode).
  record,

  /// Tap to play back recordings made in record mode.
  playback,
}

/// Parent-configurable grid settings.
class GridSettings extends ChangeNotifier {
  GridSettings({int rows = 5, int cols = 4})
      : _rows = rows.clamp(minDim, maxDim),
        _cols = cols.clamp(minDim, maxDim);

  static const int minDim = 3;
  static const int maxDim = 8;

  int _rows;
  int _cols;
  SoundSource _soundSource = SoundSource.synth;

  int get rows => _rows;
  int get cols => _cols;
  SoundSource get soundSource => _soundSource;

  void setRows(int value) {
    final v = value.clamp(minDim, maxDim);
    if (v != _rows) {
      _rows = v;
      notifyListeners();
    }
  }

  void setCols(int value) {
    final v = value.clamp(minDim, maxDim);
    if (v != _cols) {
      _cols = v;
      notifyListeners();
    }
  }

  void setSoundSource(SoundSource source) {
    if (source != _soundSource) {
      _soundSource = source;
      notifyListeners();
    }
  }
}
