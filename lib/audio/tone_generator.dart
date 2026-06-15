import 'dart:math' as math;
import 'dart:typed_data';

/// Generates short tones as in-memory PCM WAV byte buffers.
///
/// No bundled audio assets are used — every pad tone is synthesised in pure
/// Dart at startup. The waveform is a sine with a touch of 2nd/3rd harmonic and
/// a gentle vibrato (frequency wobble) for warmth, shaped by an ADSR amplitude
/// envelope so notes pluck in and tail off without click artifacts.
class ToneGenerator {
  ToneGenerator._();

  static const int sampleRate = 44100;
  static const int _bitsPerSample = 16;
  static const int _channels = 1;
  static const int _headerBytes = 44;

  // ---- timbre ----------------------------------------------------------------

  static const double _harmonic2 = 0.25; // octave above
  static const double _harmonic3 = 0.12; // fifth above that
  static const double _vibratoHz = 5.5;
  static const double _vibratoDepth = 0.006; // ±0.6% pitch wobble
  static const double _masterGain = 0.7; // headroom so harmonics don't clip

  // ---- ADSR (seconds) --------------------------------------------------------

  static const double _attackSec = 0.012;
  static const double _decaySec = 0.060;
  static const double _sustainLevel = 0.65;
  static const double _releaseSec = 0.090;

  /// Returns a well-formed mono 16-bit PCM WAV for a [frequencyHz] sine tone.
  static Uint8List generateWav(double frequencyHz, {int durationMs = 300}) {
    final numSamples = (sampleRate * durationMs) ~/ 1000;
    const bytesPerSample = _bitsPerSample ~/ 8;
    final dataSize = numSamples * _channels * bytesPerSample;
    final fileSize = _headerBytes + dataSize;

    final bytes = ByteData(fileSize);
    var offset = 0;

    void writeString(String s) {
      for (final c in s.codeUnits) {
        bytes.setUint8(offset++, c);
      }
    }

    void writeU32(int v) {
      bytes.setUint32(offset, v, Endian.little);
      offset += 4;
    }

    void writeU16(int v) {
      bytes.setUint16(offset, v, Endian.little);
      offset += 2;
    }

    // RIFF header
    writeString('RIFF');
    writeU32(fileSize - 8);
    writeString('WAVE');

    // fmt chunk
    writeString('fmt ');
    writeU32(16); // PCM fmt chunk size
    writeU16(1); // audioFormat = PCM
    writeU16(_channels);
    writeU32(sampleRate);
    writeU32(sampleRate * _channels * bytesPerSample); // byteRate
    writeU16(_channels * bytesPerSample); // blockAlign
    writeU16(_bitsPerSample);

    // data chunk
    writeString('data');
    writeU32(dataSize);

    // ADSR boundaries in samples, clamped so the release always reaches zero
    // even for very short tones.
    final attack = (sampleRate * _attackSec).round();
    final decay = (sampleRate * _decaySec).round();
    final release = math.min(
      (sampleRate * _releaseSec).round(),
      math.max(1, numSamples - attack - decay),
    );
    final releaseStart = numSamples - release;
    const norm = 1.0 / (1.0 + _harmonic2 + _harmonic3);

    var phase = 0.0;
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Vibrato: integrate the instantaneous frequency into a running phase.
      final instFreq = frequencyHz *
          (1 + _vibratoDepth * math.sin(2 * math.pi * _vibratoHz * t));
      phase += 2 * math.pi * instFreq / sampleRate;

      // Sine plus a couple of harmonics for a warmer timbre.
      final wave = (math.sin(phase) +
              _harmonic2 * math.sin(2 * phase) +
              _harmonic3 * math.sin(3 * phase)) *
          norm;

      // ADSR amplitude envelope.
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

      var val = (wave * env * _masterGain * 32767).round();
      if (val > 32767) val = 32767;
      if (val < -32768) val = -32768;
      bytes.setInt16(offset, val, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }
}
