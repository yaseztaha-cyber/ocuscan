import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 6 — Visible ocular-surface growth (pterygium-style appearance).
// Conservative: flags only with strong multi-cue evidence; never grades severity.
class SurfaceGrowthInput {
  final double nasalVesselDensity; // 0..1 from segmentation
  final double temporalVesselDensity;
  final double triangularity; // shape score 0..1
  final double cornealEncroachmentFrac; // 0..1
  final double segmentationConfidence; // 0..1
  const SurfaceGrowthInput({
    required this.nasalVesselDensity, required this.temporalVesselDensity,
    required this.triangularity, required this.cornealEncroachmentFrac,
    required this.segmentationConfidence,
  });
}

class SurfaceGrowthAnalyzer extends Analyzer<SurfaceGrowthInput> {
  @override
  String get testName => 'Ocular surface';
  @override
  ScreeningResult analyze(SurfaceGrowthInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Surface detail needs a sharp close-up with both eyes open.',
      'Reflections and motion blur invalidate surface analysis.',
    ]);
    if (veto != null) return veto;
    if (i.segmentationConfidence < 0.5) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Eye-surface segmentation confidence was ${(i.segmentationConfidence*100).toStringAsFixed(0)}% (need ≥50%).',
        limitations: const ['Improve focus/lighting and repeat.']);
    }
    final vascular = i.nasalVesselDensity > 0.45 || i.temporalVesselDensity > 0.45;
    final shape = i.triangularity > 0.55 && i.cornealEncroachmentFrac > 0.08;
    if (vascular && shape) {
      return ScreeningResult(
        testName: testName,
        measurement: 'Vascular density ${((i.nasalVesselDensity > i.temporalVesselDensity ? i.nasalVesselDensity : i.temporalVesselDensity)*100).toStringAsFixed(0)}%, encroachment ${(i.cornealEncroachmentFrac*100).toStringAsFixed(1)}%',
        measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'A visible ocular-surface growth may be present',
        possibleAssociations: const ['Pterygium or pinguecula can look like this', 'Scar or imaging artifact'],
        limitations: const ['This image screening cannot establish a diagnosis.', 'Severity is not graded in this build.'],
        recommendedAction: 'Review the highlighted eye region in the app. Consider professional evaluation, especially with irritation, redness, or vision change.',
        whyFlagged: 'A fleshy vascular region with triangular shape extended toward the cornea beyond conservative thresholds.',
        timestamp: DateTime.now(),
        rawMetrics: {'nasal': i.nasalVesselDensity, 'temporal': i.temporalVesselDensity, 'tri': i.triangularity, 'encroach': i.cornealEncroachmentFrac});
    }
    return ScreeningResult(
      testName: testName, measurement: 'No growth pattern above thresholds',
      measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['Small lesions are below phone resolution.', 'A normal image result does not exclude surface conditions.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Vascular/shape cues were below conservative screening thresholds.',
      timestamp: DateTime.now());
  }
}
