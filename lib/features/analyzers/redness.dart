import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 7 — Eye-region redness proxy from landmark-centered ROIs.
//
// The inputs are not segmented sclera pixels. Each ROI is centered on a
// detected eye landmark and therefore includes eyelid, lash, iris, and
// neighboring skin as well as visible sclera. Results must retain the
// proxy limitation and color-confidence gate below.
class RednessInput {
  final double leftRedness; // mean r/(r+g+b) in the left eye-region ROI
  final double rightRedness;
  final double rednessSpread; // fraction of ROI pixels above red threshold
  final double whiteBalanceConfidence; // 0..1 prototype color-confidence proxy
  const RednessInput({required this.leftRedness, required this.rightRedness, required this.rednessSpread, required this.whiteBalanceConfidence});
}

class RednessAnalyzer extends Analyzer<RednessInput> {
  @override
  String get testName => 'Eye redness';
  static const double populationMean = 0.36;
  static const double flagDelta = 0.06;

  @override
  ScreeningResult analyze(RednessInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Color analysis needs neutral white lighting and correct white balance.',
      'Colored room lighting invalidates redness comparison.',
    ]);
    if (veto != null) return veto;
    if (i.whiteBalanceConfidence < 0.5) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'White-balance confidence too low for color comparison.',
        limitations: const ['Repeat under neutral white light without color filters.']);
    }
    final mean = (i.leftRedness + i.rightRedness) / 2;
    final delta = mean - populationMean;
    if (delta >= flagDelta || i.rednessSpread > 0.35) {
      final level = delta >= 0.12 ? 'increased' : 'mildly elevated';
      return ScreeningResult(
        testName: testName,
        measurement: 'Mean redness ${mean.toStringAsFixed(3)} ($level), spread ${(i.rednessSpread*100).toStringAsFixed(0)}%',
        measurementUnit: '', imageQuality: q.quality, confidence: Confidence.moderate,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Increased eye redness was observed',
        possibleAssociations: const ['Irritation', 'Dryness', 'Allergy', 'Infection', 'Trauma', 'Other conditions'],
        limitations: const ['Redness alone cannot identify a cause.', 'This result does not determine the cause.', 'Eye-region ROI is not segmented sclera; eyelids, lashes, iris, and skin can influence the value.'],
        recommendedAction: 'Avoid self-diagnosing the cause. Seek prompt care for pain, light sensitivity, vision change, discharge, injury, or chemical exposure.',
        whyFlagged: 'Mean eye-region redness ${mean.toStringAsFixed(3)} exceeded the reference by ${delta.toStringAsFixed(3)} with ${(i.rednessSpread*100).toStringAsFixed(0)}% of ROI pixels above the red threshold.',
        timestamp: DateTime.now(), rawMetrics: {'mean': mean, 'spread': i.rednessSpread});
    }
    return ScreeningResult(
      testName: testName, measurement: 'Mean redness ${mean.toStringAsFixed(3)}',
      measurementUnit: '', imageQuality: q.quality, confidence: Confidence.moderate,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['Lighting and white balance affect color; compare only across similar conditions.', 'Eye-region ROI is not segmented sclera.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Redness within the reference range for this capture.',
      timestamp: DateTime.now(), rawMetrics: {'mean': mean, 'spread': i.rednessSpread});
  }
}
