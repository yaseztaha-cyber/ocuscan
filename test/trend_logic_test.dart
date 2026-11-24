// Trend-logic unit tests: eye extraction, calibration reading,
// conservative comparability. No invented numbers anywhere.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/models/screening_result.dart';
import 'package:ocuscan/core/utils/trend_logic.dart';

ScreeningResult _row({
  required String measurement,
  ImageQuality q = ImageQuality.high,
  List<String> limitations = const [],
}) =>
    ScreeningResult(
      testName: 'Distance visual acuity',
      measurement: measurement,
      measurementUnit: '',
      imageQuality: q,
      confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'x',
      possibleAssociations: const [],
      limitations: limitations,
      recommendedAction: 'x',
      whyFlagged: 'x',
      timestamp: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('extractEye', () {
    test('finds eye tokens', () {
      expect(extractEye('6/12 (right eye) at 3 m'), 'right');
      expect(extractEye('6/12 (left eye), distance uncalibrated'), 'left');
      expect(extractEye('All regions seen (both eye)'), 'both');
    });
    test('null when unnamed', () {
      expect(extractEye('Relative asymmetry 4.2% over 5 frames'), isNull);
      expect(extractEye('Threshold near 2% at recorded conditions'),
          isNull);
    });
  });

  group('isCalibratedRecord', () {
    test('flags uncalibrated wording', () {
      expect(
          isCalibratedRecord(_row(
              measurement: '6/12 (right eye), distance uncalibrated')),
          false);
      expect(
          isCalibratedRecord(_row(
              measurement: 'x',
              limitations: ['Distance not verified at 3 m.'])),
          false);
      expect(isCalibratedRecord(_row(measurement: '6/12 at 3 m')),
          true);
    });
  });

  group('rowsComparable conservative', () {
    test('same quality + calibrated + same eye', () {
      expect(
          rowsComparable(
              _row(measurement: '6/12 (right eye) at 3 m'),
              _row(measurement: '6/9 (right eye) at 3 m')),
          true);
    });
    test('different quality blocks', () {
      expect(
          rowsComparable(
              _row(measurement: '6/12 (right eye)', q: ImageQuality.high),
              _row(
                  measurement: '6/12 (right eye)',
                  q: ImageQuality.medium)),
          false);
    });
    test('calibration mismatch blocks', () {
      expect(
          rowsComparable(
              _row(measurement: '6/12 (right eye) at 3 m'),
              _row(
                  measurement: '6/12 (right eye), distance uncalibrated')),
          false);
    });
    test('different eyes block', () {
      expect(
          rowsComparable(
              _row(measurement: '6/12 (right eye)'),
              _row(measurement: '6/12 (left eye)')),
          false);
    });
    test('both unspecified counts as same context', () {
      expect(
          rowsComparable(
              _row(measurement: 'Threshold near 2%'),
              _row(measurement: 'Threshold near 4%')),
          true);
    });
  });

  group('rowEye prefers stored columns', () {
    ScreeningResult stored(String eye) => ScreeningResult(
          testName: 'T',
          measurement: 'no eye token here',
          measurementUnit: '',
          imageQuality: ImageQuality.high,
          confidence: Confidence.low,
          finding: ResultCategory.noObviousAbnormality,
          findingLabel: 'x',
          possibleAssociations: const [],
          limitations: const [],
          recommendedAction: 'x',
          whyFlagged: 'x',
          timestamp: DateTime.utc(2026, 1, 1),
          eye: eye,
        );
    test('column wins over text', () {
      expect(rowEye(stored('left')), 'left');
      expect(rowEye(stored('')), isNull);
    });
    test('column mismatch blocks even when text matches', () {
      expect(
          rowsComparable(
              stored('right'), stored('left')),
          false);
      expect(
          comparabilityReason(stored('right'), stored('left')),
          'eye');
    });
  });

  group('comparabilityReason names the mismatch', () {
    test('null when comparable', () {
      expect(
          comparabilityReason(
              _row(measurement: '6/12 (right eye) at 3 m'),
              _row(measurement: '6/9 (right eye) at 3 m')),
          isNull);
    });
    test('quality, calibration, eye codes', () {
      expect(
          comparabilityReason(
              _row(measurement: 'x', q: ImageQuality.high),
              _row(measurement: 'x', q: ImageQuality.low)),
          'quality');
      expect(
          comparabilityReason(
              _row(measurement: '6/12 at 3 m'),
              _row(measurement: '6/12, distance uncalibrated')),
          'calibration');
      expect(
          comparabilityReason(
              _row(measurement: '6/12 (right eye)'),
              _row(measurement: '6/12 (left eye)')),
          'eye');
    });
    test('setup code on device/hardware/version drift', () {
      ScreeningResult withDevice(String? device, String? algo) =>
          ScreeningResult(
            testName: 'T',
            measurement: 'm',
            measurementUnit: '',
            imageQuality: ImageQuality.high,
            confidence: Confidence.low,
            finding: ResultCategory.noObviousAbnormality,
            findingLabel: 'x',
            possibleAssociations: const [],
            limitations: const [],
            recommendedAction: 'x',
            whyFlagged: 'x',
            timestamp: DateTime.utc(2026, 1, 1),
            deviceLabel: device ?? '',
            algorithmVersion: algo ?? '',
          );
      expect(
          comparabilityReason(
              withDevice('Phone A', 'v1'), withDevice('Phone B', 'v1')),
          'setup');
      expect(
          comparabilityReason(
              withDevice('Phone A', 'v1'), withDevice('Phone A', 'v2')),
          'setup');
    });
  });
}
