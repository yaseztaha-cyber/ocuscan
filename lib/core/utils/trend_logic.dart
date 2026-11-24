// Trend logic (v0.6, pure): eye extraction, calibration reading, and
// pairwise comparability for same-test rows over time. Conservative by
// design: comparability requires same quality, same calibration state,
// and same eye (or equally unspecified). No numeric invention —
// measurements display as recorded text.
import '../models/screening_result.dart';

/// Eye token from measurement text, e.g. '6/12 (right eye) at 3 m'.
/// Null when the record does not name an eye.
String? extractEye(String measurement) {
  final m = RegExp(r'\((right|left|both)[^)]*eye\)').firstMatch(measurement);
  return m?.group(1);
}

/// Whether the record was produced under verified conditions (i.e. NOT
/// flagged uncalibrated/unverified in its own text).
bool isCalibratedRecord(ScreeningResult r) {
  final hay =
      '${r.measurement} ${r.limitations.join(' ')}'.toLowerCase();
  return !(hay.contains('uncalibrated') || hay.contains('not verified'));
}

/// Two same-test rows are comparable when quality, calibration state,
/// and eye all match. Anything else → compare cautiously.
bool rowsComparable(ScreeningResult a, ScreeningResult b) =>
    comparabilityReason(a, b) == null;

/// Explicit eye token, preferring the stored column (v6+) over the
/// legacy measurement-text regex. Empty column = unspecified old row.
String? rowEye(ScreeningResult r) =>
    r.eye.isNotEmpty ? r.eye : extractEye(r.measurement);

/// Machine-readable reason two rows are NOT comparable (null when they
/// are): 'quality', 'calibration', 'eye', or 'setup' (different device,
/// hardware, or analyzer version). Lets the UI name the mismatch instead
/// of showing a bare Caution pill.
String? comparabilityReason(ScreeningResult a, ScreeningResult b) {
  if (a.imageQuality != b.imageQuality) return 'quality';
  if (isCalibratedRecord(a) != isCalibratedRecord(b)) return 'calibration';
  if (rowEye(a) != rowEye(b)) return 'eye';
  if (a.deviceLabel != b.deviceLabel ||
      a.hardware != b.hardware ||
      a.algorithmVersion != b.algorithmVersion) {
    return 'setup';
  }
  return null;
}
