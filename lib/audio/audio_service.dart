import 'package:soundpool/soundpool.dart';

import '../grid/pentatonic_map.dart';
import 'tone_generator.dart';

/// Pre-generates one pentatonic tone per physical grid cell and plays them with
/// low latency / concurrent streams via [soundpool].
class AudioService {
  Soundpool? _pool;
  final Map<int, int> _soundIds = {}; // cell key -> soundpool soundId
  bool _loaded = false;

  static const int maxRows = 8;
  static const int maxCols = PentatonicMap.columnStride;

  int _key(int row, int col) => row * maxCols + col;

  /// Synthesises every tone and loads it into the pool. Idempotent.
  Future<void> preload() async {
    if (_loaded) return;
    final pool = Soundpool.fromOptions(
      options: const SoundpoolOptions(
        streamType: StreamType.music,
        maxStreams: 8,
      ),
    );
    _pool = pool;
    for (var row = 0; row < maxRows; row++) {
      for (var col = 0; col < maxCols; col++) {
        final wav = ToneGenerator.generateWav(PentatonicMap.frequency(row, col));
        final id = await pool.loadUint8List(wav);
        _soundIds[_key(row, col)] = id;
      }
    }
    _loaded = true;
  }

  /// Plays the tone for the pad at ([row], [col]). No-op if not yet loaded.
  Future<void> play(int row, int col) async {
    final pool = _pool;
    final id = _soundIds[_key(row, col)];
    if (pool == null || id == null) return;
    await pool.play(id);
  }

  void dispose() {
    _pool?.dispose();
    _pool = null;
    _loaded = false;
  }
}
