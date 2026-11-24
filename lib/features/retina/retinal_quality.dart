// Dedicated retinal image quality gate (v0.7 §31, §24): focus,
// illumination, field of view, artifacts, motion, contrast, retinal
// visibility, optic-disc and vessel visibility where relevant.
// Pure logic over abstracted signals — no images, no model. Ungradable
// images refuse analysis with named reasons; no forced prediction.
// No UI wiring in this build (future hardware track).
class RetinalQualityInput {
  /// 0..100 sharpness/focus score.
  final double focus;
  /// 0..100 illumination evenness score.
  final double illumination;
  /// 0..1 fraction of expected fundus field visible.
  final double fieldCoverage;
  /// 0..1 artifact load (reflections, lashes, specks).
  final double artifacts;
  /// 0..100 motion blur score (higher = sharper).
  final double stillness;
  /// 0..100 Michelson-style contrast score.
  final double contrast;
  final bool retinaVisible;
  final bool opticDiscVisible;
  final bool vesselsVisible;
  const RetinalQualityInput({
    required this.focus,
    required this.illumination,
    required this.fieldCoverage,
    required this.artifacts,
    required this.stillness,
    required this.contrast,
    required this.retinaVisible,
    required this.opticDiscVisible,
    required this.vesselsVisible,
  });
}

class RetinalQualityVerdict {
  final bool gradable;
  final List<String> reasons;
  const RetinalQualityVerdict(
      {required this.gradable, required this.reasons});
}

class RetinalQualityGate {
  /// Minimum viable thresholds for a gradable research image. Conservative
  /// by design: doubt means ungradable.
  static const double minFocus = 55;
  static const double minIllumination = 50;
  static const double minFieldCoverage = 0.7;
  static const double maxArtifacts = 0.3;
  static const double minStillness = 55;
  static const double minContrast = 45;

  static RetinalQualityVerdict evaluate(RetinalQualityInput i) {
    final reasons = <String>[];
    if (!i.retinaVisible) {
      reasons.add('No retinal view present.');
    }
    if (i.focus < minFocus) {
      reasons.add(
          'Focus ${i.focus.toStringAsFixed(0)} below $minFocus.');
    }
    if (i.illumination < minIllumination) {
      reasons.add(
          'Illumination ${i.illumination.toStringAsFixed(0)} below $minIllumination.');
    }
    if (i.fieldCoverage < minFieldCoverage) {
      reasons.add(
          'Field coverage ${(i.fieldCoverage * 100).toStringAsFixed(0)}% below ${(minFieldCoverage * 100).toStringAsFixed(0)}%.');
    }
    if (i.artifacts > maxArtifacts) {
      reasons.add(
          'Artifact load ${(i.artifacts * 100).toStringAsFixed(0)}% above ${(maxArtifacts * 100).toStringAsFixed(0)}%.');
    }
    if (i.stillness < minStillness) {
      reasons.add(
          'Motion score ${i.stillness.toStringAsFixed(0)} below $minStillness.');
    }
    if (i.contrast < minContrast) {
      reasons.add(
          'Contrast ${i.contrast.toStringAsFixed(0)} below $minContrast.');
    }
    if (!i.opticDiscVisible) {
      reasons.add('Optic disc not visible where relevant.');
    }
    if (!i.vesselsVisible) {
      reasons.add('Vessels not visible where relevant.');
    }
    if (reasons.isEmpty) {
      return const RetinalQualityVerdict(
          gradable: true, reasons: ['All retinal quality checks passed.']);
    }
    return RetinalQualityVerdict(gradable: false, reasons: reasons);
  }
}
