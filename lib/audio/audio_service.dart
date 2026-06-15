import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../grid/pentatonic_map.dart';
import 'tone_generator.dart';

/// Pre-generates pentatonic tones and optionally loads user-provided WAV samples
/// or plays back in-app recordings. Dispatches the correct source based on the
/// active [SoundSource] set by [setSource].
class AudioService {
  final SoLoud _soloud = SoLoud.instance;

  // ----- synth tones ----------------------------------------------------------

  final Map<int, AudioSource> _synthSources = {}; // cell key → synth tone
  bool _synthLoaded = false;

  // ----- user samples (assets/samples/) ---------------------------------------

  final Map<int, AudioSource> _sampleSources = {};

  // ----- recordings (in-memory WAV blobs) -------------------------------------

  final Map<int, Uint8List> _recordings = {}; // cell key → raw WAV bytes
  final Map<int, AudioSource> _recordingSources = {};

  // ----- current mode ---------------------------------------------------------

  /// Call this before playback to tell the service which source to use.
  String? _mode; // 'synth' | 'samples' | 'playback'

  static const int maxRows = 8;
  static const int maxCols = 8; // large enough for unique cell keys

  int _key(int row, int col) => row * maxCols + col;

  // =========================================================================
  // Lifecycle
  // =========================================================================

  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init(
        sampleRate: ToneGenerator.sampleRate,
        channels: Channels.mono,
      );
    }
  }

  /// Pre-loads synthesised tones for every cell.
  Future<void> preloadSynth() async {
    if (_synthLoaded) return;
    await init();
    for (var row = 0; row < maxRows; row++) {
      for (var col = 0; col < maxCols; col++) {
        final wav = ToneGenerator.generateWav(PentatonicMap.frequency(row, col));
        final source =
            await _soloud.loadMem('synth_${_key(row, col)}.wav', wav);
        _synthSources[_key(row, col)] = source;
      }
    }
    _synthLoaded = true;
  }

  /// Attempts to load user-provided WAV samples from assets for every cell
  /// in the given [rows]×[cols] grid. Missing files are silently skipped
  /// (those pads will be silent in sample mode).
  Future<void> loadSamples(int rows, int cols) async {
    await init();
    for (var r = 0; r < rows && r < maxRows; r++) {
      for (var c = 0; c < cols && c < maxCols; c++) {
        final assetPath = 'assets/samples/sample_${r}_$c.wav';
        try {
          final data = await rootBundle.load(assetPath);
          final source = await _soloud.loadMem(
            'sample_${_key(r, c)}.wav',
            data.buffer.asUint8List(),
          );
          _sampleSources[_key(r, c)] = source;
        } on FlutterError {
          // File not found — pad stays silent in sample mode.
        }
      }
    }
  }

  /// Chooses which sound source [play] will use.
  void setMode(String mode) {
    _mode = mode;
  }

  // =========================================================================
  // Recording support
  // =========================================================================

  /// Stores a raw WAV blob for the given cell and loads it into the engine,
  /// disposing any previously-loaded recording for that cell so re-recording
  /// the same pad does not leak native sources.
  Future<void> storeRecording(int row, int col, Uint8List wavBytes) async {
    await init();
    final k = _key(row, col);
    _recordings[k] = wavBytes;

    final old = _recordingSources.remove(k);
    if (old != null) await _soloud.disposeSource(old);

    // Unique path per load so SoLoud never collides on a cached sound hash.
    _recordingSources[k] = await _soloud.loadMem(
      'rec_${k}_${DateTime.now().microsecondsSinceEpoch}.wav',
      wavBytes,
    );
  }

  /// Whether a recording exists for the given cell.
  bool hasRecording(int row, int col) =>
      _recordings.containsKey(_key(row, col));

  // =========================================================================
  // Playback
  // =========================================================================

  /// Plays the sound for the pad at ([row], [col]) in the current mode.
  Future<void> play(int row, int col) async {
    final k = _key(row, col);
    AudioSource? source;

    switch (_mode) {
      case 'samples':
        source = _sampleSources[k];
      case 'playback':
        source = _recordingSources[k];
      default: // synth
        source = _synthSources[k];
    }

    if (source == null || !_soloud.isInitialized) return;
    _soloud.play(source);
  }

  // =========================================================================
  // Teardown
  // =========================================================================

  void dispose() {
    if (_soloud.isInitialized) _soloud.deinit();
    _synthSources.clear();
    _sampleSources.clear();
    _recordingSources.clear();
    _recordings.clear();
    _synthLoaded = false;
  }
}
