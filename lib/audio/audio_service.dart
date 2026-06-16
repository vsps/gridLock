import 'dart:math' as math;

import 'package:flutter_soloud/flutter_soloud.dart';

import 'tone_generator.dart';

/// Synth-only audio service backed by SoLoud.
///
/// Tones are keyed by (semitones, echoLevel) and lazy-generated on demand.
/// Polyphony is hard-capped at 6 voices.
class AudioService {
  final SoLoud _soloud = SoLoud.instance;

  final Map<(int, int), AudioSource> _sources = {};

  static const int _maxVoices = 20;

  // ---- lifecycle -------------------------------------------------------------

  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init(
        sampleRate: ToneGenerator.sampleRate,
        channels: Channels.mono,
      );
      _soloud.setMaxActiveVoiceCount(_maxVoices);
    }
  }

  /// Pre-generates echo-level-0 tones for a wide semitone range (C1–C7).
  Future<void> preloadSynth() async {
    await init();
    for (var s = -36; s <= 36; s++) {
      await _getOrCreate(s, 0);
    }
  }

  /// Plays the tone for [semitones] above/below C4 with [echoLevel] (0–4).
  /// Generates and caches the source on first use.
  Future<void> playWithEcho(int semitones, int echoLevel) async {
    if (!_soloud.isInitialized) return;
    final source = await _getOrCreate(semitones, echoLevel.clamp(0, 4));
    _soloud.play(source);
  }

  // ---- internal --------------------------------------------------------------

  Future<AudioSource> _getOrCreate(int semitones, int echoLevel) async {
    final key = (semitones, echoLevel);
    final cached = _sources[key];
    if (cached != null) return cached;

    final freq = 261.63 * math.pow(2, semitones / 12.0);
    final wav = ToneGenerator.generateWav(
      freq.toDouble(),
      semitonesFromC4: semitones,
      echoLevel: echoLevel,
    );
    final source =
        await _soloud.loadMem('tone_${semitones}_$echoLevel.wav', wav);
    _sources[key] = source;
    return source;
  }

  // ---- teardown --------------------------------------------------------------

  void dispose() {
    if (_soloud.isInitialized) _soloud.deinit();
    _sources.clear();
  }
}
