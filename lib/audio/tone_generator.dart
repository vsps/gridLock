import 'dart:math' as math;
import 'dart:typed_data';

/// Generates short tones as in-memory PCM WAV byte buffers.
///
/// Supports overdrive (scales with distance from C4) and baked-in echo tails
/// (echoLevel 0–4 adds progressively longer reverb tails).
class ToneGenerator {
  ToneGenerator._();

  static double _tanh(double x) {
    final e2x = math.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }

  static const int sampleRate = 44100;
  static const int _bitsPerSample = 16;
  static const int _channels = 1;
  static const int _headerBytes = 44;

  // ---- timbre ----------------------------------------------------------------

  static const double _harmonic2 = 0.25;
  static const double _harmonic3 = 0.12;
  static const double _harmonic4 = 0.08; // extra warmth for low notes
  static const double _harmonic5 = 0.05;
  static const double _vibratoHz = 5.5;
  static const double _vibratoDepth = 0.006;
  static const double _masterGain = 0.7;

  // ---- ADSR ------------------------------------------------------------------

  static const double _attackSec = 0.012;
  static const double _decaySec = 0.060;
  static const double _sustainLevel = 0.65;
  static const double _releaseSec = 0.090;

  // ---- echo ------------------------------------------------------------------

  // Delay tap interval in samples (~375 ms, 1/8th at 128 bpm).
  static const int _echoDelaySamples = (sampleRate * 375) ~/ 1000;
  static const double _echoDecay = 0.5; // each tap is half the previous

  /// Returns a WAV for [frequencyHz] with overdrive and optional echo tails.
  ///
  /// [semitonesFromC4]: distance from middle C — drives harmonic boost and
  /// overdrive strength. Negative = below C4 (bass), positive = above.
  /// [echoLevel]: 0–4, each level bakes in one additional delay tap.
  static Uint8List generateWav(
    double frequencyHz, {
    int semitonesFromC4 = 0,
    int echoLevel = 0,
    int baseDurationMs = 300,
  }) {
    final echoTaps = echoLevel.clamp(0, 4);
    final tailSamples = echoTaps * _echoDelaySamples;
    final numSamples =
        (sampleRate * baseDurationMs) ~/ 1000 + tailSamples;

    const bytesPerSample = _bitsPerSample ~/ 8;
    final dataSize = numSamples * _channels * bytesPerSample;
    final fileSize = _headerBytes + dataSize;

    final bytes = ByteData(fileSize);
    var offset = 0;

    void writeString(String s) {
      for (final c in s.codeUnits) { bytes.setUint8(offset++, c); }
    }

    void writeU32(int v) {
      bytes.setUint32(offset, v, Endian.little);
      offset += 4;
    }

    void writeU16(int v) {
      bytes.setUint16(offset, v, Endian.little);
      offset += 2;
    }

    writeString('RIFF');
    writeU32(fileSize - 8);
    writeString('WAVE');
    writeString('fmt ');
    writeU32(16);
    writeU16(1);
    writeU16(_channels);
    writeU32(sampleRate);
    writeU32(sampleRate * _channels * bytesPerSample);
    writeU16(_channels * bytesPerSample);
    writeU16(_bitsPerSample);
    writeString('data');
    writeU32(dataSize);

    // Overdrive: tanh soft-clip, strength proportional to distance from C4.
    final distNorm = (semitonesFromC4.abs() / 24.0).clamp(0.0, 1.0);
    final odGain = 1.0 + distNorm * 3.0;
    final odNorm = _tanh(odGain); // for normalisation

    // Extra harmonics only for notes below C4.
    final addLowHarmonics = semitonesFromC4 < 0;
    final norm = 1.0 /
        (1.0 +
            _harmonic2 +
            _harmonic3 +
            (addLowHarmonics ? _harmonic4 + _harmonic5 : 0.0));

    final baseSamples = (sampleRate * baseDurationMs) ~/ 1000;
    final attack = (sampleRate * _attackSec).round();
    final decay = (sampleRate * _decaySec).round();
    final release = math.min(
      (sampleRate * _releaseSec).round(),
      math.max(1, baseSamples - attack - decay),
    );
    final releaseStart = baseSamples - release;

    // Render raw PCM into a Float64 buffer so we can add echo taps cleanly.
    final pcm = Float64List(numSamples);

    var phase = 0.0;
    for (var i = 0; i < baseSamples; i++) {
      final t = i / sampleRate;
      final instFreq =
          frequencyHz * (1 + _vibratoDepth * math.sin(2 * math.pi * _vibratoHz * t));
      phase += 2 * math.pi * instFreq / sampleRate;

      double wave = math.sin(phase) +
          _harmonic2 * math.sin(2 * phase) +
          _harmonic3 * math.sin(3 * phase);
      if (addLowHarmonics) {
        wave += _harmonic4 * math.sin(4 * phase) +
            _harmonic5 * math.sin(5 * phase);
      }
      wave *= norm;

      // ADSR
      double env;
      if (i < attack) {
        env = attack > 0 ? i / attack : 1.0;
      } else if (i < attack + decay) {
        env = 1.0 - (1.0 - _sustainLevel) * ((i - attack) / decay);
      } else if (i < releaseStart) {
        env = _sustainLevel;
      } else {
        env = _sustainLevel * (1.0 - (i - releaseStart) / release);
      }

      // Overdrive (tanh soft-clip), normalised so peak ≈ 1.
      final driven = _tanh(wave * env * odGain) / odNorm;
      pcm[i] = driven * _masterGain;
    }

    // Bake echo taps.
    for (var tap = 1; tap <= echoTaps; tap++) {
      final tapGain = math.pow(_echoDecay, tap).toDouble();
      final tapOffset = tap * _echoDelaySamples;
      for (var i = 0; i < baseSamples; i++) {
        final dst = i + tapOffset;
        if (dst < numSamples) pcm[dst] += pcm[i] * tapGain;
      }
    }

    // Write to WAV.
    for (var i = 0; i < numSamples; i++) {
      var val = (pcm[i] * 32767).round().clamp(-32768, 32767);
      bytes.setInt16(offset, val, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }
}
