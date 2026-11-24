import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 8 — Scleral yellowing. Requires lighting calibration first.
class ScleralInput {
  final double yellowness; // normalized proxy
  final bool calibrationPassed;
  final bool warmLight;
  final bool coloredLight;
  final double calibrationConfidence;
  const ScleralInput({required this.yellowness, required this.calibrationPassed, required this.warmLight, required this.coloredLight, required this.calibrationConfidence});
}

class ScleralAnalyzer extends Analyzer<ScleralInput> {
  @override
  String get testName => 'Scleral color';
  static const double flagThreshold = 0.18;

  @override
  ScreeningResult analyze(ScleralInput i, QualityVerdict q) {
    if (!i.calibrationPassed || i.coloredLight || i.calibrationConfidence < 0.6) {
      return ScreeningResult(
        testName: testName, measurement: 'not measured', measurementUnit: '',
        imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.unableToAssess,
        findingLabel: 'Unable to assess scleral color reliably',
        possibleAssociations: const [],
        limitations: const [
          'Color calibration failed or lighting is unsuitable.',
          'Warm or colored ambient light invalidates scleral color.',
          'Repeat the lighting calibration under neutral white light.',
        ],
        recommendedAction: 'Repeat the calibration step in neutral lighting. Do not interpret scleral color from this capture.',
        whyFlagged: 'Calibration gate: passed=${i.calibrationPassed}, colored=${i.coloredLight}, confidence=${i.calibrationConfidence.toStringAsFixed(2)}.',
        timestamp: DateTime.now());
    }
    final veto = lowQualityShortCircuit(testName, q, const [
      'Scleral color needs high-quality, neutral-light capture.',
    ]);
    if (veto != null) return veto;
    if (i.warmLight && i.yellowness < flagThreshold + 0.05) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Warm lighting detected with borderline yellowness; cannot distinguish illumination from discoloration.',
        limitations: const ['Repeat under neutral white lighting.']);
    }
    if (i.yellowness >= flagThreshold) {
      return ScreeningResult(
        testName: testName,
        measurement: 'Yellowness index ${i.yellowness.toStringAsFixed(3)}',
        measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Yellow discoloration of the visible sclera was observed',
        possibleAssociations: const ['Jaundice has multiple possible causes', 'Lighting residual'],
        limitations: const ['This screening cannot determine the cause.', 'Cannot diagnose liver or blood conditions.'],
        recommendedAction: 'Repeat under neutral lighting after calibration. Seek medical evaluation for persistent yellowing, especially with dark urine, pale stools, or abdominal symptoms.',
        whyFlagged: 'Yellowness ${i.yellowness.toStringAsFixed(3)} met the $flagThreshold screening threshold after passing calibration.',
        timestamp: DateTime.now(), rawMetrics: {'yellowness': i.yellowness});
    }
    return ScreeningResult(
      testName: testName, measurement: 'Yellowness index ${i.yellowness.toStringAsFixed(3)}',
      measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['Only valid under the calibrated lighting of this capture.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Yellowness below threshold under calibrated lighting.',
      timestamp: DateTime.now(), rawMetrics: {'yellowness': i.yellowness});
  }
}
