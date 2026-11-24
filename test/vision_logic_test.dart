// v0.4 vision-logic tests: adaptive staircase behavior and seeded
// shuffle reproducibility. Pure logic, no UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/vision/display_metrics.dart';
import 'package:ocuscan/features/vision_lab/vision_logic.dart';

void main() {
  group('Staircase', () {
    test('descends on correct, ascends on wrong', () {
      final s = Staircase(level: 4, max: 7);
      s.respond(true);
      expect(s.level, 5);
      s.respond(false);
      expect(s.level, 4);
    });
    test('clamps at bounds', () {
      final s = Staircase(level: 7, max: 7);
      s.respond(true);
      expect(s.level, 7);
      final t = Staircase(level: 0, max: 7);
      t.respond(false);
      expect(t.level, 0);
    });
    test('counts reversals and stops', () {
      final s = Staircase(
          level: 3, max: 7, maxReversals: 2, maxTrials: 100);
      expect(s.done, false);
      s.respond(true); // up, no reversal yet
      expect(s.reversals, 0);
      s.respond(false); // reversal 1
      expect(s.reversals, 1);
      s.respond(true); // reversal 2 -> done
      expect(s.reversals, 2);
      expect(s.done, true);
    });
    test('stops at max trials without reversals', () {
      final s = Staircase(
          level: 0, max: 7, maxReversals: 99, maxTrials: 5);
      for (var i = 0; i < 5; i++) {
        s.respond(true);
      }
      expect(s.done, true);
      expect(s.history.length, 5);
    });
    test('threshold averages last reversals', () {
      final s = Staircase(level: 2, max: 7, maxReversals: 99);
      // Oscillate around 4/5: up to 5, down to 4, up to 5, down to 4...
      s.respond(true); // 2->3
      s.respond(true); // 3->4
      s.respond(true); // 4->5
      s.respond(false); // rev@5 ->4
      s.respond(true); // rev@4 ->5
      s.respond(false); // rev@5 ->4
      s.respond(true); // rev@4 ->5
      final t = s.threshold;
      expect(t >= 3 && t <= 6, true, reason: 'threshold=$t');
    });
    test('threshold without reversals returns current level', () {
      final s = Staircase(level: 4, max: 7);
      s.respond(true);
      s.respond(true);
      expect(s.threshold, 6);
    });
    test('sequence readout records every trial', () {
      final s = Staircase(level: 0, max: 7);
      s.respond(true);
      s.respond(false);
      expect(s.sequence, 'L0✓ L1✗');
    });
  });

  group('seededShuffle', () {
    test('same seed reproduces order', () {
      final a = seededShuffle([1, 2, 3, 4, 5, 6, 7, 8], 42);
      final b = seededShuffle([1, 2, 3, 4, 5, 6, 7, 8], 42);
      expect(a, b);
    });
    test('different seeds usually differ', () {
      final a = seededShuffle([1, 2, 3, 4, 5, 6, 7, 8], 1);
      final b = seededShuffle([1, 2, 3, 4, 5, 6, 7, 8], 2);
      expect(a == b, false);
    });
    test('is a permutation', () {
      final a = seededShuffle([1, 2, 3, 4, 5], 7)..sort();
      expect(a, [1, 2, 3, 4, 5]);
    });
  });

  group('existing rules intact', () {
    test('levelPassed 3/5 conservative rule', () {
      expect(VisionLogic.levelPassed(3, 5), true);
      expect(VisionLogic.levelPassed(2, 5), false);
    });
  });

  group('CardCalibration', () {
    test('85.6mm card maps box width to px-per-mm', () {
      expect(CardCalibration.pxPerMm(856.0), closeTo(10.0, 1e-9));
      expect(CardCalibration.pxPerMm(0), -1);
      expect(CardCalibration.pxPerMm(-5), -1);
      expect(CardCalibration.pxPerMm(double.nan), -1);
    });
    test('6/6 letter at 3m is ~4.36mm', () {
      // 5 arcmin at 3000 mm: 2*3000*tan(2.5') ≈ 4.364 mm.
      expect(CardCalibration.mmForArcMin(5, 3000), closeTo(4.364, 0.01));
      expect(CardCalibration.mmForArcMin(0, 3000), -1);
      expect(CardCalibration.mmForArcMin(5, -1), -1);
    });
    test('logical px scales with calibrated density', () {
      expect(CardCalibration.logicalPxForMm(4.364, 10.0),
          closeTo(43.64, 0.01));
      expect(CardCalibration.logicalPxForMm(4.364, 0), -1);
      expect(CardCalibration.logicalPxForMm(-1, 10.0), -1);
    });
    test('card aspect ratio matches ID-1', () {
      expect(CardCalibration.cardHeightMm / CardCalibration.cardWidthMm,
          closeTo(0.6306, 0.001));
    });
  });

  group('directionOptotypes', () {
    test('only tumbling E/C with valid rotations', () {
      for (var i = 0; i < 20; i++) {
        final opts = VisionLogic.directionOptotypes(4);
        expect(opts, hasLength(4));
        for (final o in opts) {
          expect(['E', 'C'], contains(o.symbol));
          expect([0, 90, 180, 270], contains(o.rotationDeg));
        }
      }
    });
  });

  group('directionArrow truth table', () {
    test('unrotated E/C points right, RotatedBox turns clockwise', () {
      expect(VisionLogic.directionArrow(0), '→');
      expect(VisionLogic.directionArrow(90), '↓');
      expect(VisionLogic.directionArrow(180), '←');
      expect(VisionLogic.directionArrow(270), '↑');
    });
    test('unknown rotations never guessed', () {
      expect(VisionLogic.directionArrow(45), '?');
      expect(VisionLogic.directionArrow(-90), '↑');
      expect(VisionLogic.directionArrow(360), '→');
    });
  });

  group('DisplayMetrics physical sizing', () {
    // 5 arcmin (6/6 letter) at 3000 mm on a 400 dpi screen:
    // height = 2*3000*tan(2.5') ≈ 4.364 mm → ≈68.7 physical px.
    test('6/6 letter math at 400dpi/3m', () {
      const m = DisplayMetrics(
          xdpi: 400, ydpi: 400, densityDpi: 400, widthPx: 1080, heightPx: 2400);
      final px = m.logicalPixelsForArcMin(
          arcMin: 5, distanceMm: 3000, devicePixelRatio: 2.0);
      expect(px, closeTo(34.3, 0.5));
    });
    test('larger arcmin and closer distance scale up', () {
      const m = DisplayMetrics(
          xdpi: 400, ydpi: 400, densityDpi: 400, widthPx: 1080, heightPx: 2400);
      final small = m.logicalPixelsForArcMin(
          arcMin: 5, distanceMm: 3000, devicePixelRatio: 2.0);
      final big = m.logicalPixelsForArcMin(
          arcMin: 50, distanceMm: 3000, devicePixelRatio: 2.0);
      expect(big, greaterThan(small * 9));
    });
    test('invalid metrics refuse with -1', () {
      const bad = DisplayMetrics.invalid();
      expect(bad.valid, false);
      expect(
          bad.logicalPixelsForArcMin(
              arcMin: 5, distanceMm: 3000, devicePixelRatio: 2.0),
          -1);
      expect(
          const DisplayMetrics(
                  xdpi: -1,
                  ydpi: 400,
                  densityDpi: 400,
                  widthPx: 0,
                  heightPx: 0)
              .valid,
          false);
    });
    test('fromMap tolerates missing channel data', () {
      expect(DisplayMetrics.fromMap(null).valid, false);
      expect(DisplayMetrics.fromMap({}).valid, false);
      final m = DisplayMetrics.fromMap(
          {'xdpi': 420, 'ydpi': 420, 'densityDpi': 420});
      expect(m.valid, true);
      expect(m.widthPx, 0);
    });
  });
}
