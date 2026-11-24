// Statistics unit tests: correct mean/SD/median/range/CV, empty dataset,
// single sample, insufficient-sample gating, histogram, agreement pairs,
// unable-to-assess rate. No data is fabricated by the library — tests feed
// explicit inputs and verify exact outputs.

import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/validation/statistics.dart';

void main() {
  group('describe', () {
    test('computes correct descriptives for a known sample', () {
      // 1..5: mean 3, sample SD sqrt(2.5) ≈ 1.5811, median 3, range 4.
      final s = describe([1, 2, 3, 4, 5])!;
      expect(s.n, 5);
      expect(s.mean, closeTo(3.0, 1e-9));
      expect(s.median, closeTo(3.0, 1e-9));
      expect(s.sd, closeTo(1.5811388300841898, 1e-9));
      expect(s.min, 1.0);
      expect(s.max, 5.0);
      expect(s.range, 4.0);
      expect(s.cv, closeTo(1.5811388300841898 / 3.0, 1e-9));
    });

    test('even-count median averages the middle two', () {
      final s = describe([1, 2, 3, 4])!;
      expect(s.median, closeTo(2.5, 1e-9));
    });

    test('empty dataset returns null (never invents values)', () {
      expect(describe([]), isNull);
    });

    test('single sample: mean/median/min/max set, SD null', () {
      final s = describe([0.041])!;
      expect(s.n, 1);
      expect(s.mean, closeTo(0.041, 1e-12));
      expect(s.median, closeTo(0.041, 1e-12));
      expect(s.sd, isNull);
      expect(s.cv, isNull);
      expect(s.min, 0.041);
      expect(s.max, 0.041);
    });

    test('two samples give a sample SD', () {
      final s = describe([2.0, 4.0])!;
      expect(s.sd, closeTo(1.4142135623730951, 1e-9));
    });

    test('NaN values are ignored', () {
      final s = describe([1.0, double.nan, 3.0])!;
      expect(s.n, 2);
      expect(s.mean, closeTo(2.0, 1e-9));
    });
  });

  group('sample-size gating', () {
    test('n < 3 is insufficient, n >= 3 is sufficient', () {
      expect(hasEnoughData(0), false);
      expect(hasEnoughData(1), false);
      expect(hasEnoughData(2), false);
      expect(hasEnoughData(3), true);
      expect(hasEnoughData(20), true);
    });

    test('insufficient message is explicit', () {
      expect(insufficientDataMessage, contains('Insufficient data'));
    });
  });

  group('histogram', () {
    test('counts sum to input length', () {
      final h = histogram([0.1, 0.2, 0.3, 0.9, 0.95], bins: 4);
      expect(h.fold<int>(0, (a, b) => a + b), 5);
    });

    test('empty input yields honest zero bins', () {
      expect(histogram([], bins: 6), List.filled(6, 0));
    });

    test('constant input lands in one bin', () {
      final h = histogram([0.5, 0.5, 0.5], bins: 4);
      expect(h.fold<int>(0, (a, b) => a + b), 3);
    });
  });

  group('agreement', () {
    test('identical pairs give zero difference', () {
      final a = agreement([(6 / 9, 6 / 9), (1.0, 1.0)])!;
      expect(a.n, 2);
      expect(a.meanAbsDiff, closeTo(0.0, 1e-12));
      expect(a.meanDiff, closeTo(0.0, 1e-12));
    });

    test('known bias is recovered', () {
      final a = agreement([(1.0, 0.0), (3.0, 2.0)])!;
      expect(a.meanAbsDiff, closeTo(1.0, 1e-9));
      expect(a.meanDiff, closeTo(1.0, 1e-9));
      expect(a.sdDiff, closeTo(0.0, 1e-9));
      expect(a.meanRelDiff, closeTo((2.0 + 0.4) / 2, 1e-9));
    });

    test('empty pairs return null', () {
      expect(agreement([]), isNull);
    });

    test('single pair has no SD', () {
      final a = agreement([(0.5, 0.4)])!;
      expect(a.sdDiff, isNull);
      expect(a.n, 1);
    });
  });

  group('unableRate', () {
    test('computes the rate', () {
      expect(unableRate(8, 100), closeTo(0.08, 1e-12));
      expect(unableRate(0, 10), 0.0);
    });

    test('zero trials give null, not zero', () {
      expect(unableRate(0, 0), isNull);
    });
  });
}
