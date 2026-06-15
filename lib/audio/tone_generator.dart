import 'dart:math' as math;
import 'dart:typed_data';

/// Generates short sine-wave tones as in-memory PCM WAV byte buffers.
///
/// No bundled audio assets are used — every pad tone is synthesised in pure
/// Dart at startup. A short fade-in / fade-out envelope avoids click artifacts.
class ToneGenerator {
  ToneGenerator._();

  static const int sampleRate = 44100;
  static const int _bitsPerSample = 16;
  static const int _channels = 1;
  static const int _headerBytes = 44;

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

    final fadeIn = (sampleRate * 0.010).round(); // 10 ms
    final fadeOut = (sampleRate * 0.030).round(); // 30 ms

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      var amp = math.sin(2 * math.pi * frequencyHz * t);

      var env = 1.0;
      if (fadeIn > 0 && i < fadeIn) {
        env = i / fadeIn;
      }
      final tail = numSamples - i;
      if (fadeOut > 0 && tail < fadeOut) {
        env = math.min(env, tail / fadeOut);
      }
      amp *= env;

      var val = (amp * 32767).round();
      if (val > 32767) val = 32767;
      if (val < -32768) val = -32768;
      bytes.setInt16(offset, val, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }
}
