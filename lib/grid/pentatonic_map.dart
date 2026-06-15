import 'dart:math' as math;

/// Maps a grid cell to a frequency in Hz using a major pentatonic scale.
///
/// A fixed [columnStride] is used so a cell's pitch stays stable regardless of
/// the current grid width — this lets [AudioService] pre-cache one tone per
/// physical cell once, instead of regenerating whenever the grid is resized.
class PentatonicMap {
  PentatonicMap._();

  /// Root note: A3.
  static const double _baseFreq = 220.0;

  /// Semitone offsets of a major pentatonic scale from the root.
  static const List<int> _intervals = [0, 2, 4, 7, 9];

  /// Fixed stride for cell indexing. Must be >= the maximum supported columns.
  static const int columnStride = 8;

  /// Frequency in Hz for the pad at ([row], [col]).
  static double frequency(int row, int col) {
    final cellIndex = row * columnStride + col;
    final noteIndex = cellIndex % _intervals.length;
    final octaveShift = cellIndex ~/ _intervals.length;
    final semitones = _intervals[noteIndex] + octaveShift * 12;
    return _baseFreq * math.pow(2, semitones / 12.0);
  }
}
