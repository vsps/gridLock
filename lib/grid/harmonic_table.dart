import 'dart:math' as math;

/// Maps hex-grid coordinates to musical notes via the Tonnetz layout.
///
/// Moving right (+col): +7 semitones (perfect fifth).
/// Moving up (decreasing row index): +4 semitones (major third).
///
/// The reference cell (refRow, refCol) is the lower-left visible corner and
/// is anchored to C2 (−24 semitones from C4).
class HarmonicTable {
  HarmonicTable._();

  static const double _c4Hz = 261.63;
  static const int _c2Offset = -24; // C2 relative to C4

  static const List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// Semitones above C4. Negative = below C4.
  /// (refRow, refCol) maps to C2 (−24).
  static int semitones(int row, int col, int refRow, int refCol) {
    return (col - refCol) * 7 + (refRow - row) * 4 + _c2Offset;
  }

  /// Frequency in Hz.
  static double frequency(int row, int col, int refRow, int refCol) {
    final s = semitones(row, col, refRow, refCol);
    return _c4Hz * math.pow(2, s / 12.0);
  }

  /// True when [s] is any C note.
  static bool isC(int s) => s % 12 == 0;

  /// Display name including octave, e.g. "F#3".
  static String noteName(int s) {
    final semMod = s % 12;
    final name = _noteNames[(semMod + 1200) % 12];
    final octave = 4 + (s ~/ 12) - (semMod < 0 ? 1 : 0);
    return '$name$octave';
  }
}
