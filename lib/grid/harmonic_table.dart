import 'dart:math' as math;

/// Maps hex-grid coordinates to musical notes via the Tonnetz layout.
///
/// Moving right (+col): +7 semitones (perfect fifth).
/// Moving up (+row toward lower index): +4 semitones (major third).
/// Center cell is always middle C (C4 = 261.63 Hz).
class HarmonicTable {
  HarmonicTable._();

  static const double _c4Hz = 261.63;

  static const List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// Semitones above C4 for this cell. May be negative (below middle C).
  static int semitones(int row, int col, int centerRow, int centerCol) {
    return (col - centerCol) * 7 + (centerRow - row) * 4;
  }

  /// Frequency in Hz.
  static double frequency(int row, int col, int centerRow, int centerCol) {
    final s = semitones(row, col, centerRow, centerCol);
    return _c4Hz * math.pow(2, s / 12.0);
  }

  /// True when the cell is any C note.
  static bool isC(int s) => s % 12 == 0;

  /// Display name including octave, e.g. "F#3".
  static String noteName(int s) {
    final semMod = s % 12;
    final name = _noteNames[(semMod + 1200) % 12];
    final octave = 4 + (s ~/ 12) - (semMod < 0 ? 1 : 0);
    return '$name$octave';
  }
}
