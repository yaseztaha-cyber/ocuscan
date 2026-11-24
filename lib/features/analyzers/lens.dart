import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 10 — Visible lens opacity. EXPERIMENTAL. Front camera is not a slit lamp.
class LensInput {
  final double opacityScore;
  final double captureSupport; // 0..1: red-reflex style capture quality
  final bool closeUpMethod; // true only if guided close-up protocol used
  const LensInput({required this.opacityScore, required this.captureSupport, required this.closeUpMethod});
}

class LensAnalyzer extends Analyzer<LensInput> {
  @override
  String get testName => 'Lens clarity (experimental)';
  @override
  ScreeningResult analyze(LensInput i, QualityVerdict q) {
    if (!i.closeUpMethod || i.captureSupport < 0.6) {
      return ScreeningResult(
        testName: testName, measurement: 'not measured', measurementUnit: '',
        imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.unableToAssess,
        findingLabel: 'This feature could not be assessed reliably using this image',
        possibleAssociations: const [],
        limitations: const [
          'Experimental module: ordinary front-camera capture is not equivalent to slit-lamp examination.',
          'Requires the guided close-up capture protocol.',
        ],
        recommendedAction: 'Use the guided capture or skip this experimental module. This result is not a diagnosis and cannot determine whether a cataract is present.',
        whyFlagged: 'Capture-support gate failed (method=${i.closeUpMethod}, support=${i.captureSupport.toStringAsFixed(2)}).',
        timestamp: DateTime.now());
    }
    final veto = lowQualityShortCircuit(testName, q, const [
      'Experimental lens screening needs high-quality close-up capture.',
    ]);
    if (veto != null) return veto;
    if (i.opacityScore >= 0.75) {
      return ScreeningResult(
        testName: testName, measurement: 'Opacity cue ${(i.opacityScore*100).toStringAsFixed(0)}% (experimental)',
        measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Possible visible lens opacity detected',
        possibleAssociations: const ['Advanced lens changes can look like this', 'Reflection artifact'],
        limitations: const ['Experimental screening only.', 'This result is not a diagnosis and cannot determine whether a cataract is present.'],
        recommendedAction: 'Consider a routine eye examination for vision changes. Do not interpret this as a cataract diagnosis.',
        whyFlagged: 'Opacity cues exceeded the experimental threshold under supported capture.',
        timestamp: DateTime.now(), rawMetrics: {'opacity': i.opacityScore});
    }
    return ScreeningResult(
      testName: testName, measurement: 'Opacity cue ${(i.opacityScore*100).toStringAsFixed(0)}% (experimental)',
      measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['Experimental module; normal result does not exclude lens conditions.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Opacity cues below experimental threshold.',
      timestamp: DateTime.now(), rawMetrics: {'opacity': i.opacityScore});
  }
}
