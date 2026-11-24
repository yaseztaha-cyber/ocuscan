import 'dart:math';
import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 3 — Eye alignment from fixation + cover/uncover deltas.
class EyeAlignmentInput {
  final double leftGazeX; final double rightGazeX; // normalized -1..1
  final double leftGazeY; final double rightGazeY;
  final double coverDeltaLeft; // px shift when uncovered
  final double coverDeltaRight;
  final double ipdPx; // interpupillary distance for normalization
  const EyeAlignmentInput({
    required this.leftGazeX, required this.rightGazeX,
    required this.leftGazeY, required this.rightGazeY,
    required this.coverDeltaLeft, required this.coverDeltaRight,
    required this.ipdPx,
  });
}

class EyeAlignmentAnalyzer extends Analyzer<EyeAlignmentInput> {
  @override
  String get testName => 'Eye alignment';
  static const double gazeThreshold = 0.12; // normalized units
  static const double coverThresholdFrac = 0.04; // of IPD

  @override
  ScreeningResult analyze(EyeAlignmentInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Alignment tracking needs stable fixation on the target.',
      'Head movement confounds gaze estimates.',
      'Smartphone tracking is approximate; not a clinical cover test.',
    ]);
    if (veto != null) return veto;
    if (i.ipdPx <= 1) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Eye landmarks were not detected well enough to estimate alignment.',
        limitations: const ['Both eyes must be visible and stable.']);
    }
    final dx = (i.leftGazeX - i.rightGazeX).abs();
    final dy = (i.leftGazeY - i.rightGazeY).abs();
    final gazeDiff = sqrt(dx * dx + dy * dy);
    final coverMax = max(i.coverDeltaLeft.abs(), i.coverDeltaRight.abs()) / i.ipdPx;
    final flagged = gazeDiff >= gazeThreshold || coverMax >= coverThresholdFrac;
    if (flagged) {
      return ScreeningResult(
        testName: testName,
        measurement: 'Gaze difference ${gazeDiff.toStringAsFixed(3)}, cover shift ${(coverMax * 100).toStringAsFixed(2)}% of IPD',
        measurementUnit: '', imageQuality: q.quality,
        confidence: Confidence.low, // alignment is noisy: cap at low/moderate
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Possible eye-alignment abnormality detected',
        possibleAssociations: const ['Eye muscle balance variation', 'Uncorrected refractive error', 'Normal phoria', 'Tracking noise'],
        limitations: const ['This screening cannot determine the cause.', 'Cannot replace clinician cover testing.', 'Head movement affects results.'],
        recommendedAction: 'Repeat the guided cover test carefully. Consider professional evaluation if misalignment is persistent or with double vision.',
        whyFlagged: 'Estimated eye positions changed differently during fixation/cover steps (gaze diff ${gazeDiff.toStringAsFixed(3)} vs threshold $gazeThreshold; cover shift ${(coverMax*100).toStringAsFixed(2)}% vs ${(coverThresholdFrac*100).toStringAsFixed(1)}%). This does not establish a diagnosis.',
        timestamp: DateTime.now(),
        rawMetrics: {'gaze_diff': gazeDiff, 'cover_frac': coverMax});
    }
    return ScreeningResult(
      testName: testName,
      measurement: 'Gaze difference ${gazeDiff.toStringAsFixed(3)}, cover shift ${(coverMax * 100).toStringAsFixed(2)}% of IPD',
      measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['A normal screening result does not exclude alignment conditions.', 'Small deviations are below phone resolution.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Both gaze and cover-shift metrics were below screening thresholds.',
      timestamp: DateTime.now(), rawMetrics: {'gaze_diff': gazeDiff, 'cover_frac': coverMax});
  }
}
