import 'package:flutter_test/flutter_test.dart';
import 'package:gridlock/grid/ripple_controller.dart';

void main() {
  group('RippleController.propagate', () {
    test('3x3 tap at centre yields correct wave depths', () {
      final waves = <String, int>{};
      RippleController.propagate(1, 1, 3, 3, (r, c, wave) {
        waves['$r,$c'] = wave;
      });

      // Origin
      expect(waves['1,1'], 0);
      // Cardinal neighbours
      expect(waves['0,1'], 1);
      expect(waves['2,1'], 1);
      expect(waves['1,0'], 1);
      expect(waves['1,2'], 1);
      // Corners (Manhattan distance 2)
      expect(waves['0,0'], 2);
      expect(waves['0,2'], 2);
      expect(waves['2,0'], 2);
      expect(waves['2,2'], 2);

      expect(waves.length, 9, reason: 'every cell visited once');
    });

    test('corner tap reaches the whole grid, each cell once', () {
      final visits = <String, int>{};
      RippleController.propagate(0, 0, 4, 4, (r, c, wave) {
        visits['$r,$c'] = (visits['$r,$c'] ?? 0) + 1;
      });
      expect(visits.length, 16);
      expect(visits.values.every((v) => v == 1), isTrue);
    });

    test('out-of-bounds start does nothing', () {
      var calls = 0;
      RippleController.propagate(5, 5, 3, 3, (_, __, ___) => calls++);
      expect(calls, 0);
    });
  });
}
