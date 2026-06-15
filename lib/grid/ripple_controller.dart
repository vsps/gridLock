/// Pure-logic breadth-first ripple propagation across a grid.
///
/// Emits each reachable cell along with its wave depth (0 = the tapped cell,
/// 1 = direct cardinal neighbours, 2 = their neighbours, ...). Callers turn the
/// wave depth into a staggered animation delay.
class RippleController {
  RippleController._();

  static const List<List<int>> _deltas = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  /// BFS from ([startRow], [startCol]) over a [rows] x [cols] grid.
  static void propagate(
    int startRow,
    int startCol,
    int rows,
    int cols,
    void Function(int row, int col, int wave) onCell,
  ) {
    if (startRow < 0 || startRow >= rows || startCol < 0 || startCol >= cols) {
      return;
    }

    final visited = <int>{};
    final queue = <List<int>>[]; // each entry: [row, col, wave]

    int key(int r, int c) => r * cols + c;

    visited.add(key(startRow, startCol));
    queue.add([startRow, startCol, 0]);

    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      final r = cur[0];
      final c = cur[1];
      final wave = cur[2];
      onCell(r, c, wave);

      for (final d in _deltas) {
        final nr = r + d[0];
        final nc = c + d[1];
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        final k = key(nr, nc);
        if (!visited.add(k)) continue;
        queue.add([nr, nc, wave + 1]);
      }
    }
  }
}
