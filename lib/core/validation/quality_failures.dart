// QualityGate failure categorization for failure analysis.
//
// This is a pure mapping from a QualityVerdict's issue strings to research
// failure codes. It does NOT change gate behavior — QualityGate.evaluate is
// reused untouched. Every rejected capture records one or more of:
//
// LOW_ILLUMINATION / OVEREXPOSURE / BLUR / LOW_RESOLUTION /
// BAD_FACE_GEOMETRY / EYE_NOT_VISIBLE / OTHER

import '../pipeline/quality_gate.dart';
import 'experiment_models.dart';

/// Map a single QualityGate issue string to a failure code.
QualityFailureCode codeForIssue(String issue) {
  final s = issue.toLowerCase();
  if (s.contains('resolution')) return QualityFailureCode.lowResolution;
  if (s.contains('too dark') || s.contains('underexposed')) {
    return QualityFailureCode.lowIllumination;
  }
  if (s.contains('too bright') || s.contains('overexposed')) {
    return QualityFailureCode.overexposure;
  }
  if (s.contains('blur') || s.contains('out of focus') || s.contains('soft')) {
    return QualityFailureCode.blur;
  }
  if (s.contains('both eyes') ||
      s.contains('obstructed') ||
      s.contains('eye area')) {
    return QualityFailureCode.eyeNotVisible;
  }
  if (s.contains('centered') ||
      s.contains('angle') ||
      s.contains('too far') ||
      s.contains('too close')) {
    return QualityFailureCode.badFaceGeometry;
  }
  return QualityFailureCode.other;
}

/// Categorize all issues of a verdict. Empty issues → empty set
/// (an accepted capture has no failure codes).
Set<QualityFailureCode> categorizeFailures(QualityVerdict verdict) =>
    verdict.issues.map(codeForIssue).toSet();

/// Primary (first-severity) failure code for single-column trial storage.
/// Severity order follows impact on measurability.
QualityFailureCode primaryFailure(QualityVerdict verdict) {
  const order = [
    QualityFailureCode.eyeNotVisible,
    QualityFailureCode.blur,
    QualityFailureCode.lowResolution,
    QualityFailureCode.lowIllumination,
    QualityFailureCode.overexposure,
    QualityFailureCode.badFaceGeometry,
    QualityFailureCode.other,
  ];
  final codes = categorizeFailures(verdict);
  if (codes.isEmpty) return QualityFailureCode.other;
  for (final c in order) {
    if (codes.contains(c)) return c;
  }
  return QualityFailureCode.other;
}
