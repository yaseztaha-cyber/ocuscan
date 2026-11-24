import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 5 — Pupil response to light. SAFE-ONLY: disabled unless the
// hardware path is reproducible. No unsafe flash usage. Never diagnose.
class PupilResponseInput {
  final bool hardwareSupportsSafeTest;
  final List<double> leftSeries; // relative pupil area over time
  final List<double> rightSeries;
  final double baselineFrames;
  const PupilResponseInput({
    required this.hardwareSupportsSafeTest,
    required this.leftSeries,
    required this.rightSeries,
    this.baselineFrames = 5,
  });
}

class PupilResponseAnalyzer extends Analyzer<PupilResponseInput> {
  @override
  String get testName => 'Pupil light response';

  @override
  ScreeningResult analyze(PupilResponseInput i, QualityVerdict q) {
    if (!i.hardwareSupportsSafeTest) {
      return ScreeningResult(
        testName: testName, measurement: 'not measured', measurementUnit: '',
        imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.unableToAssess,
        findingLabel: 'Pupil response could not be assessed reliably',
        possibleAssociations: const [],
        limitations: const [
          'This phone build does not provide a controlled, safe light stimulus.',
          'The module is disabled rather than estimated. No bright-light self-testing is advised.',
        ],
        recommendedAction: 'No action needed from this module. Other screening tests remain available.',
        whyFlagged: 'Hardware safety gate: controlled reproducible illumination is unavailable, so the test reports unable-to-assess by design.',
        timestamp: DateTime.now());
    }
    final veto = lowQualityShortCircuit(testName, q, const [
      'Response tracking needs stable fixation and exposure.',
    ]);
    if (veto != null) return veto;
    if (i.leftSeries.length < 10 || i.rightSeries.length < 10) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Not enough stable frames to measure a response curve.',
        limitations: const ['Keep the head still and repeat.']);
    }
    double constrict(List<double> s) {
      final base = s.take(i.baselineFrames.toInt()).reduce((a, b) => a + b) / i.baselineFrames;
      final minV = s.reduce((a, b) => a < b ? a : b);
      if (base <= 0) return 0;
      return (base - minV) / base;
    }
    final cl = constrict(i.leftSeries);
    final cr = constrict(i.rightSeries);
    final diff = (cl - cr).abs();
    if (cl < 0.05 && cr < 0.05) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'No measurable constriction in either eye under this stimulus; the stimulus may be inadequate.',
        limitations: const ['Phone illumination is not a clinical light source.']);
    }
    if (diff > 0.15) {
      return ScreeningResult(
        testName: testName,
        measurement: 'Left constriction ${(cl*100).toStringAsFixed(1)}%, right ${(cr*100).toStringAsFixed(1)}%',
        measurementUnit: '%', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'An unusual pupil-response pattern was observed',
        possibleAssociations: const ['Normal variation', 'Medication effects', 'Measurement artifact'],
        limitations: const ['This test cannot determine a neurological cause.', 'Phone stimulus is approximate.'],
        recommendedAction: 'Repeat under identical conditions. Consider professional evaluation if persistent or with symptoms.',
        whyFlagged: 'Left/right constriction differed by ${(diff*100).toStringAsFixed(1)} percentage points.',
        timestamp: DateTime.now(), rawMetrics: {'left': cl, 'right': cr});
    }
    return ScreeningResult(
      testName: testName,
      measurement: 'Left constriction ${(cl*100).toStringAsFixed(1)}%, right ${(cr*100).toStringAsFixed(1)}%',
      measurementUnit: '%', imageQuality: q.quality, confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['A normal screening pattern does not exclude disease.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Both eyes showed comparable relative constriction.',
      timestamp: DateTime.now(), rawMetrics: {'left': cl, 'right': cr});
  }
}
