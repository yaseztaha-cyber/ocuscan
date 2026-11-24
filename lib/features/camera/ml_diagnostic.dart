// Isolated ML Kit diagnostic model (v0.7.7, Phase 3/8/9 protocol).
//
// Outcome vocabulary is deliberately distinct — a failed detector call
// must NEVER read as "no face":
// - pass: detector returned >= 1 face (VALID_FACE_RESULT).
// - noFace: detector ran clean and found nothing (NO_FACE_FOUND).
// - error: detector call threw (PROCESSING_ERROR), detail carries a
//   one-line error (full stacks go to the error export, never the UI).
// - skipped: preconditions unmet (camera idle, no retained bytes,
//   unsupported layout, no bundled asset) with an explicit reason.
//
// Pure Dart: outcome mapping, one-line error shaping, and the JSON
// report envelope. The screen runs the tests; this file judges them.

/// Installed ML Kit stack. Verify against pubspec.lock
/// (google_mlkit_face_detection / google_mlkit_commons) and the plugin's
/// android/build.gradle (com.google.mlkit:face-detection) on upgrade.
const String kMlPluginVersions =
    'face_detection 0.15.1 (native com.google.mlkit:face-detection:16.1.7) / '
    'commons 0.13.0';

/// Diagnostic outcome for one isolation test.
enum MlDiagOutcome { pass, noFace, error, skipped }

/// One isolation-test result.
class MlDiagItem {
  final String name;
  final MlDiagOutcome outcome;
  final String detail;
  const MlDiagItem(
      {required this.name, required this.outcome, required this.detail});

  Map<String, String> toJson() => {
        'test': name,
        'outcome': outcome.name,
        'detail': detail,
      };
}

/// Map a detector call result to an outcome. [faces] null means the call
/// threw (use [error] for the detail); empty means clean no-face.
MlDiagOutcome classifyDetectorResult(int? faceCount) {
  if (faceCount == null) return MlDiagOutcome.error;
  if (faceCount <= 0) return MlDiagOutcome.noFace;
  return MlDiagOutcome.pass;
}

/// One-line UI error: first line only, capped, no stack traces.
String shortError(Object e, [int max = 220]) {
  var s = e.toString().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
  if (s.length > max) s = '${s.substring(0, max)}…';
  return s;
}

/// Full diagnostic report envelope (shown on screen, DIAG events carry
/// the per-item lines into the error export).
class MlDiagReport {
  final String appVersion;
  final DateTime at;
  final List<MlDiagItem> items;
  const MlDiagReport(
      {required this.appVersion, required this.at, required this.items});

  Map<String, Object?> toJson() => {
        'format': 'ocuscan-ml-diagnostic',
        'ocuscan_version': appVersion,
        'ml_stack': kMlPluginVersions,
        'exportedAt': at.toIso8601String(),
        'items': [for (final i in items) i.toJson()],
      };

  /// One-line roll-up, e.g. "A:pass B:skipped C:error D:pass".
  String get summaryLine =>
      items.map((i) => '${i.name}:${i.outcome.name}').join(' ');
}

/// Detector-health thresholds (explicit, shared with the UI + export).
///
/// Rationale mirrors the existing latch gates in camera_pipeline.dart
/// (converter/bitmap/detector fallbacks all require >= 10 consecutive
/// errors with zero processed frames): a detector that throws on every
/// call from the first frame — e.g. the synchronous NullPointerException
/// inside ML Kit's `FaceDetection.getClient()` observed on OPPO CPH2121
/// (Android 12) — is "down", not "no face". Fewer consecutive errors are
/// "degraded" (transient), and anything below that is "healthy".
const int kMlDegradedAfterErrors = 3;
const int kMlDownAfterErrors = 10;

/// Single honest detector-health truth for the UI (replaces ad-hoc
/// boolean flags). Distinct vocabulary from [MlDiagOutcome] on purpose:
/// health describes the DETECTOR, outcome describes one TEST.
enum MlHealth { healthy, degraded, down }

/// Pure health rule from live counters. Negative inputs are clamped to 0
/// (counters must never go negative; clamping keeps the rule total).
MlHealth mlHealthFor({
  required int consecutiveErrors,
  required int framesProcessed,
}) {
  final errors = consecutiveErrors < 0 ? 0 : consecutiveErrors;
  final processed = framesProcessed < 0 ? 0 : framesProcessed;
  if (errors >= kMlDownAfterErrors && processed == 0) return MlHealth.down;
  if (errors >= kMlDegradedAfterErrors) return MlHealth.degraded;
  return MlHealth.healthy;
}

/// Display mapping for [MlHealth]: canonical lowercase code, never the
/// MlDiagOutcome pass/noFace words (a broken detector must never read
/// as "no face").
String mlHealthDisplayName(MlHealth health) => health.name;

extension MlHealthDescribe on MlHealth {
  /// One honest line naming the state and both live counts, e.g.
  /// "down: 12 consecutive ML errors, 0 frames processed".
  String describe({
    required int consecutiveErrors,
    required int framesProcessed,
  }) =>
      '$name: $consecutiveErrors consecutive ML errors, '
      '$framesProcessed frames processed';
}
