import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 9 — Visible corneal opacity. Conservative by design.
class CornealInput {
  final double opacityScore; // 0..1 combined cloudiness cue
  final double confidence; // segmentation confidence
  const CornealInput({required this.opacityScore, required this.confidence});
}

class CornealAnalyzer extends Analyzer<CornealInput> {
  @override
  String get testName => 'Corneal clarity';
  static const double flagThreshold = 0.72;
  @override
  ScreeningResult analyze(CornealInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Corneal detail needs a sharp, well-exposed close-up.',
      'Ordinary phone cameras have major limits for corneal detail.',
    ]);
    if (veto != null) return veto;
    if (i.confidence < 0.55) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Corneal segmentation confidence too low (${(i.confidence*100).toStringAsFixed(0)}%).',
        limitations: const ['Reflections or blur may obscure the cornea. Repeat with a clean, sharp capture.']);
    }
    if (i.opacityScore >= flagThreshold) {
      return ScreeningResult(
        testName: testName, measurement: 'Opacity cue ${(i.opacityScore*100).toStringAsFixed(0)}%',
        measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Possible corneal opacity detected',
        possibleAssociations: const ['Scar', 'Infection-related change', 'Reflection artifact'],
        limitations: const ['Conservative phone screening only.', 'Cannot exclude corneal disease when normal.'],
        recommendedAction: 'Consider professional evaluation, especially with vision change, pain, or light sensitivity.',
        whyFlagged: 'Cloudiness cues exceeded the conservative $flagThreshold threshold.',
        timestamp: DateTime.now(), rawMetrics: {'opacity': i.opacityScore});
    }
    return ScreeningResult(
      testName: testName, measurement: 'Opacity cue ${(i.opacityScore*100).toStringAsFixed(0)}%',
      measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious visible opacity identified in the captured image',
      possibleAssociations: const [],
      limitations: const ['A normal phone image does not exclude corneal disease.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Opacity cues below threshold in this capture.',
      timestamp: DateTime.now(), rawMetrics: {'opacity': i.opacityScore});
  }
}
