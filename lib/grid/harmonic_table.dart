import 'dart:math' as math;

/// Maps hex-grid coordinates to musical notes via the Tonnetz layout.
///
/// Uses axial (cube) coordinates so all three hex directions give the
/// correct intervals regardless of row parity:
///
///   Right        → +4 semitones (major third)
///   Up-right     → +7 semitones (perfect fifth)
///   Up-left      → +3 semitones (minor third)
///
/// The reference cell (refRow, refCol) is the lower-left visible corner
/// and is anchored to C2 (−24 semitones from C4).
class HarmonicTable {
  HarmonicTable._();

  static const double _c4Hz = 261.63;
  static const int _c2Offset = -24; // C2 relative to C4

  static const List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  // ---- axial (cube) conversion -----------------------------------------------

  /// Offset odd-r → axial (q, r).  q increases to the right; r is the row.
  static (int, int) _toAxial(int row, int col) {
    final q = col - (row - (row & 1)) ~/ 2;
    return (q, row);
  }

  // ---- public API ------------------------------------------------------------

  /// Semitones above C4.  Negative = below C4.
  /// (refRow, refCol) maps to C2 (−24).
  static int semitones(int row, int col, int refRow, int refCol) {
    final (refQ, refR) = _toAxial(refRow, refCol);
    final (q, r) = _toAxial(row, col);
    return (q - refQ) * 4 - (r - refR) * 3 + _c2Offset;
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
    final semMod = ((s % 12) + 12) % 12; // always 0–11
    final name = _noteNames[semMod];
    final octave = 4 + (s / 12).floor();
    return '$name$octave';
  }
}
