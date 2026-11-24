// Single source of truth for the release version string.
// Keep in sync with pubspec.yaml (enforced by evidence_safety_test).
// Diagnostics, history rows, reports, and About all read this constant
// so a release bump cannot leave stale versions in the UI or exports.
const String kOcuScanVersion = '0.7.24+32';
