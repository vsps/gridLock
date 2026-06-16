import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridlock/audio/tone_generator.dart';

void main() {
  group('ToneGenerator.generateWav', () {
    test('produces a well-formed 44.1kHz mono 16-bit WAV header', () {
      final bytes = ToneGenerator.generateWav(440.0, baseDurationMs: 100);
      final view = ByteData.sublistView(bytes);

      String tag(int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));

      expect(tag(0), 'RIFF');
      expect(tag(8), 'WAVE');
      expect(tag(12), 'fmt ');
      expect(view.getUint16(20, Endian.little), 1, reason: 'PCM format');
      expect(view.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(view.getUint32(24, Endian.little), 44100, reason: 'sample rate');
      expect(view.getUint16(34, Endian.little), 16, reason: 'bits per sample');
      expect(tag(36), 'data');
    });

    test('sample count and data size match the requested duration', () {
      const durationMs = 100;
      final bytes = ToneGenerator.generateWav(440.0, baseDurationMs: durationMs);
      final view = ByteData.sublistView(bytes);

      const expectedSamples = 44100 * durationMs ~/ 1000;
      const expectedData = expectedSamples * 2; // 16-bit mono

      expect(view.getUint32(40, Endian.little), expectedData);
      expect(bytes.length, 44 + expectedData);
    });
  });
}
