import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';
import '../../core/utils/image_utils.dart';

// Module 2 — Eyelid position / possible asymmetry.
//
// The input is ML Kit eye-openness probability per eye (0..1, -1 unknown).
// It is not a millimeter or pixel lid distance. Closed or unknown eyes
// refuse measurement rather than producing an asymmetry estimate.
class EyelidInput {
  final double leftOpenness;
  final double rightOpenness;
  /// Measured gaze/head pitch in degrees (from headEulerAngleX).
  /// Default 0 means unknown/unavailable and passes through without
  /// gating; only finite values beyond [EyelidAnalyzer.maxPitchDeg]
  /// refuse measurement. NaN/infinite are treated as unknown.
  final double gazePitchDeg;
  const EyelidInput(
      {required this.leftOpenness, required this.rightOpenness, this.gazePitchDeg = 0});
}

class EyelidAnalyzer extends Analyzer<EyelidInput> {
  @override
  String get testName => 'Eyelid position';
  static const double flagPct = 20.0;

  /// Minimum openness accepted for comparison. Matches the tracker's
  /// open-eye threshold so a closed eye is never compared as if open.
  static const double minOpenProb = 0.35;

  /// Maximum tolerated head/gaze pitch. Beyond this the lid appearance
  /// is foreshortened and comparison would be false confidence, so the
  /// analyzer refuses measurement instead of guessing.
  static const double maxPitchDeg = 15.0;

  @override
  ScreeningResult analyze(EyelidInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Eyelid measurement needs both eyes sharply visible in even light.',
      'Gaze angle and brow position affect the estimate.',
    ]);
    if (veto != null) return veto;
    // Pitch gate: unknown pitch (default 0, NaN, or infinite) passes
    // through; only a measured finite tilt beyond threshold refuses.
    final gp = i.gazePitchDeg;
    if (gp.isFinite && gp.abs() > maxPitchDeg) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Head was tilted up/down during measurement (pitch ${gp.toStringAsFixed(1)}°). Straight-on capture is required.',
        limitations: const ['Head tilt affects eyelid appearance.', 'Repeat facing the camera directly at eye level.']);
    }
    if (i.leftOpenness < 0 ||
        i.leftOpenness > 1 ||
        i.rightOpenness < 0 ||
        i.rightOpenness > 1) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Eye-openness was not reported for one or both eyes.',
        limitations: const ['Eyes must be open and unobstructed.']);
    }
    if (i.leftOpenness < minOpenProb || i.rightOpenness < minOpenProb) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'One or both eyes were closed during the measurement, so eyelid comparison is unavailable.',
        limitations: const ['Repeat with both eyes open, looking straight ahead.']);
    }
    final asymPct = ImageUtils.percentDifference(i.leftOpenness, i.rightOpenness);
    if (asymPct >= flagPct) {
      return ScreeningResult(
        testName: testName, measurement: 'Eyelid-opening asymmetry ${asymPct.toStringAsFixed(1)}%',
        measurementUnit: '%', imageQuality: q.quality,
        confidence: q.quality == ImageQuality.high ? Confidence.moderate : Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Possible eyelid asymmetry detected',
        possibleAssociations: const ['Eyelid muscle or nerve variation', 'Swelling, fatigue, prior surgery', 'Normal variation'],
        limitations: const ['This screening cannot determine the cause.', 'Not a diagnosis of ptosis.', 'Brow position and gaze affect results.'],
        recommendedAction: 'Repeat looking straight ahead in even lighting. Consider professional evaluation if new, persistent, or affecting vision.',
        whyFlagged: 'Left openness ${(i.leftOpenness * 100).toStringAsFixed(0)}% vs right ${(i.rightOpenness * 100).toStringAsFixed(0)}% differs by ${asymPct.toStringAsFixed(1)}% (threshold $flagPct%). This is a probability comparison, not a lid-distance measurement.',
        timestamp: DateTime.now(),
        rawMetrics: {
          'asymmetry_pct': asymPct,
          'left_openness': i.leftOpenness,
          'right_openness': i.rightOpenness,
        });
    }
    return ScreeningResult(
      testName: testName, measurement: 'Eyelid-opening asymmetry ${asymPct.toStringAsFixed(1)}%',
      measurementUnit: '%', imageQuality: q.quality,
      confidence: q.quality == ImageQuality.high ? Confidence.moderate : Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['A normal screening result does not exclude eyelid conditions.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Asymmetry ${asymPct.toStringAsFixed(1)}% is below the $flagPct% threshold.',
      timestamp: DateTime.now(),
      rawMetrics: {
        'asymmetry_pct': asymPct,
        'left_openness': i.leftOpenness,
        'right_openness': i.rightOpenness,
      });
  }
}
