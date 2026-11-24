import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/models/screening_result.dart';

void main() {
  test('ScreeningResult round-trips through Map', () {
    final r = ScreeningResult(
      testName: 'Pupil symmetry', measurement: 'Relative asymmetry 4.2% over 5 frames',
      measurementUnit: '%', imageQuality: ImageQuality.high, confidence: Confidence.moderate,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [], limitations: const ['Compare under similar light'],
      recommendedAction: 'No further action.', whyFlagged: 'Below threshold.',
      timestamp: DateTime.utc(2026, 9, 25),
    );
    final back = ScreeningResult.fromMap(r.toMap());
    expect(back.testName, r.testName);
    expect(back.finding, r.finding);
    expect(back.imageQuality, r.imageQuality);
  });

  test('Unable factory is first-class', () {
    final r = ScreeningResult.unable(
      testName: 'Scleral color', imageQuality: ImageQuality.medium,
      reason: 'Calibration failed.', limitations: const ['Need neutral light']);
    expect(r.finding, ResultCategory.unableToAssess);
    expect(r.findingLabel, contains('Unable'));
  });
}
