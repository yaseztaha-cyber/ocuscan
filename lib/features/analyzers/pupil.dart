import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';
import '../../core/utils/image_utils.dart';

// Module 4 — Pupil asymmetry across multiple frames.
// Reports RELATIVE asymmetry only (never mm without calibration).
class PupilFrame {
  final double leftArea; final double rightArea; // px^2 visible pupil
  final bool leftOccluded; final bool rightOccluded;
  final bool reflection;
  const PupilFrame({required this.leftArea, required this.rightArea, this.leftOccluded = false, this.rightOccluded = false, this.reflection = false});
}

class PupilInput {
  final List<PupilFrame> frames;
  final bool lightingStable;
  const PupilInput({required this.frames, required this.lightingStable});
}

class PupilAnalyzer extends Analyzer<PupilInput> {
  @override
  String get testName => 'Pupil symmetry';
  static const double flagIndex = 0.20; // 20% relative asymmetry
  static const int minValidFrames = 3;

  @override
  ScreeningResult analyze(PupilInput input, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Pupil comparison needs both eyes simultaneously visible in stable light.',
      'Reflections, occlusion, or motion invalidate frames.',
      'Millimeter diameters are not reported without physical calibration.',
    ]);
    if (veto != null) return veto;
    if (!input.lightingStable) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Lighting changed during capture; pupils react to light so comparison would be misleading.',
        limitations: const ['Repeat under stable, even lighting.']);
    }
    final valid = input.frames.where((f) =>
      !f.leftOccluded && !f.rightOccluded && !f.reflection && f.leftArea > 0 && f.rightArea > 0).toList();
    if (valid.length < minValidFrames) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Only ${valid.length} reliable frames (need $minValidFrames). One pupil was hidden, moving, or affected by reflections.',
        limitations: const ['Test uses multiple frames; single frames are never used alone.']);
    }
    double sum = 0;
    for (final f in valid) {
      sum += ImageUtils.asymmetryIndex(f.leftArea, f.rightArea);
    }
    final meanIndex = sum / valid.length;
    // Consistency: std across frames should be small.
    double variance = 0;
    for (final f in valid) {
      final d = ImageUtils.asymmetryIndex(f.leftArea, f.rightArea) - meanIndex;
      variance += d * d;
    }
    variance /= valid.length;
    if (variance > 0.02) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Pupil measurements varied too much between frames to be reliable (variance ${variance.toStringAsFixed(4)}).',
        limitations: const ['Keep the head still and lighting constant, then repeat.']);
    }
    if (meanIndex >= flagIndex) {
      return ScreeningResult(
        testName: testName,
        measurement: 'Relative asymmetry ${(meanIndex * 100).toStringAsFixed(1)}% over ${valid.length} frames',
        measurementUnit: '%', imageQuality: q.quality, confidence: Confidence.moderate,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Possible pupil-size asymmetry detected',
        possibleAssociations: const ['Physiologic anisocoria', 'Medication effects', 'Prior injury or surgery', 'Lighting artifact'],
        limitations: const ['This test cannot determine the cause.', 'Relative comparison only — not millimeters.'],
        recommendedAction: 'Repeat under controlled lighting. Seek professional evaluation if the difference is new, persistent, or with vision changes, headache, or drooping eyelid.',
        whyFlagged: 'Mean relative asymmetry ${(meanIndex*100).toStringAsFixed(1)}% met the ${(flagIndex*100).toStringAsFixed(0)}% screening threshold across ${valid.length} consistent frames.',
        timestamp: DateTime.now(), rawMetrics: {'mean_index': meanIndex, 'frames': valid.length.toDouble()});
    }
    return ScreeningResult(
      testName: testName,
      measurement: 'Relative asymmetry ${(meanIndex * 100).toStringAsFixed(1)}% over ${valid.length} frames',
      measurementUnit: '%', imageQuality: q.quality, confidence: Confidence.moderate,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['A normal screening result does not exclude pupil conditions.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Mean asymmetry ${(meanIndex*100).toStringAsFixed(1)}% below threshold across ${valid.length} frames.',
      timestamp: DateTime.now(), rawMetrics: {'mean_index': meanIndex, 'frames': valid.length.toDouble()});
  }
}
