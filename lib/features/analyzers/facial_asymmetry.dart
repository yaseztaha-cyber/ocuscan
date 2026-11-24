// Module 1 — Facial asymmetry from landmark movement amplitudes.
// Inputs are measured pixel displacements (left/right) per expression.
// Deterministic rule layer: no diagnosis, urgent-symptom flag is separate.

import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';
import '../../core/utils/image_utils.dart';

class FacialAsymmetryInput {
  final double leftBrow; final double rightBrow;
  final double leftLid; final double rightLid;
  final double leftMouth; final double rightMouth;
  final double leftCheek; final double rightCheek;
  final bool suddenOnsetReported;
  final double headYawDeg;

  const FacialAsymmetryInput({
    required this.leftBrow, required this.rightBrow,
    required this.leftLid, required this.rightLid,
    required this.leftMouth, required this.rightMouth,
    required this.leftCheek, required this.rightCheek,
    this.suddenOnsetReported = false,
    this.headYawDeg = 0,
  });
}

class FacialAsymmetryAnalyzer extends Analyzer<FacialAsymmetryInput> {
  @override
  String get testName => 'Facial movement symmetry';

  /// Conservative: flag only when max regional asymmetry >= 30% AND at
  /// least two regions agree, with head reasonably frontal.
  static const double flagThresholdPct = 30.0;

  @override
  ScreeningResult analyze(FacialAsymmetryInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Landmark tracking needs a sharp, frontal, well-lit face.',
      'Head rotation can mimic asymmetry.',
    ]);
    if (veto != null) return veto;
    if (i.headYawDeg.abs() > 15) {
      return ScreeningResult.unable(
        testName: testName, imageQuality: q.quality,
        reason: 'Head was turned during measurement (yaw ${i.headYawDeg.toStringAsFixed(1)}°). Straight-on capture is required.',
        limitations: const ['Head rotation mimics asymmetry.', 'Repeat facing the camera directly.'],
      );
    }
    final regions = {
      'brow': ImageUtils.percentDifference(i.leftBrow, i.rightBrow),
      'lid': ImageUtils.percentDifference(i.leftLid, i.rightLid),
      'mouth': ImageUtils.percentDifference(i.leftMouth, i.rightMouth),
      'cheek': ImageUtils.percentDifference(i.leftCheek, i.rightCheek),
    };
    final maxAsym = regions.values.fold<double>(0, (a, b) => a > b ? a : b);
    final flaggedRegions =
        regions.entries.where((e) => e.value >= flagThresholdPct).length;

    final sudden = i.suddenOnsetReported;
    if (maxAsym >= flagThresholdPct && flaggedRegions >= 2) {
      return ScreeningResult(
        testName: testName,
        measurement: 'Max regional asymmetry ${maxAsym.toStringAsFixed(1)}% across ${regions.length} regions',
        measurementUnit: '%',
        imageQuality: q.quality,
        confidence: q.quality == ImageQuality.high ? Confidence.moderate : Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Possible asymmetric facial movement detected',
        possibleAssociations: const [
          'Facial nerve conditions can sometimes show this pattern',
          'Prior injury, dental or muscular factors',
          'Normal variation',
        ],
        limitations: const [
          'This screening cannot determine the cause.',
          'Single-session camera tracking is approximate.',
          'Does not assess nerve function directly.',
        ],
        recommendedAction: sudden
            ? 'Sudden facial weakness can be urgent. Do not rely on this app — seek emergency care promptly, especially with speech changes, arm weakness, or vision changes.'
            : 'Repeat facing the camera directly. Consider professional evaluation if the asymmetry is new or persistent.',
        whyFlagged:
            'Estimated movement differed by ${maxAsym.toStringAsFixed(1)}% between sides in $flaggedRegions of 4 regions (brow ${regions['brow']!.toStringAsFixed(1)}%, lid ${regions['lid']!.toStringAsFixed(1)}%, mouth ${regions['mouth']!.toStringAsFixed(1)}%, cheek ${regions['cheek']!.toStringAsFixed(1)}%). This result does not establish a diagnosis.',
        timestamp: DateTime.now(),
        rawMetrics: {for (final e in regions.entries) e.key: e.value},
      );
    }
    return ScreeningResult(
      testName: testName,
      measurement: 'Max regional asymmetry ${maxAsym.toStringAsFixed(1)}%',
      measurementUnit: '%',
      imageQuality: q.quality,
      confidence: q.quality == ImageQuality.high ? Confidence.moderate : Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious asymmetry observed in this screening',
      possibleAssociations: const [],
      limitations: const [
        'A normal screening result does not exclude disease.',
        'Subtle asymmetry may be below camera resolution.',
      ],
      recommendedAction: sudden
          ? 'Even with a normal camera result, sudden facial weakness needs prompt in-person assessment. Do not rely on this app for this situation.'
          : 'No further action needed from this test. Repeat if symptoms appear.',
      whyFlagged: 'All regional differences were below the $flagThresholdPct% screening threshold (max ${maxAsym.toStringAsFixed(1)}%).',
      timestamp: DateTime.now(),
      rawMetrics: {for (final e in regions.entries) e.key: e.value},
    );
  }
}
