// Native frame-facts validation (§4/§15): explicit format contract,
// no reinterpretation.
//
// A frame is usable for ML ONLY when its observed facts satisfy the
// contract of a known layout. Anything else is INVALID_FRAME with a
// machine-readable reason — never a guess, never silent truncation,
// never "luma-only presented as complete YUV".
//
// Pure Dart so the whole contract matrix is unit-tested without a
// device (rotations, mirror is presentation-only and out of scope
// here, malformed frames, unsupported formats).

import '../camera/camera_pipeline.dart' show maxFramePixels;

/// Observed facts of one camera frame (no pixels cross this boundary).
class FrameFacts {
  final int width;
  final int height;
  final int planeCount;
  final List<int> planeLengths;
  final List<int> rowStrides;
  final int rotationDeg;
  final int timestampMs;

  /// Total buffer bytes when known (-1 = unknown, check skipped).
  /// Honest format-agnostic bounds: at least one luma byte per pixel,
  /// at most four bytes per pixel (BGRA_8888). Anything outside is
  /// impossible for width×height regardless of declared format.
  final int totalBytes;
  const FrameFacts({
    required this.width,
    required this.height,
    required this.planeCount,
    required this.planeLengths,
    required this.rowStrides,
    required this.rotationDeg,
    required this.timestampMs,
    this.totalBytes = -1,
  });
}

/// Validation verdict with a stable reason code.
class FrameValidity {
  final bool ok;
  final String reason;
  const FrameValidity(this.ok, this.reason);
  static const valid = FrameValidity(true, 'ok');
  static FrameValidity invalid(String reason) =>
      FrameValidity(false, reason);

  @override
  bool operator ==(Object other) =>
      other is FrameValidity &&
      other.ok == ok &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(ok, reason);
}

/// Validate structural frame facts. Semantic layout choice (NV21 vs
/// planar vs BGRA) stays in refineLayout; this gate rejects garbage
/// before any byte is trusted.
///
/// Optional liveness checks (off by default so existing callers and the
/// contract matrix are unaffected):
/// - [nowMs]/[maxAgeMs]: reject frames older than [maxAgeMs] as
///   'stale-frame'. Needs a real sensor timestamp; callers without one
///   must NOT pass nowMs (a wall-clock substitute would false-positive
///   every queued frame).
/// - [FrameFacts.totalBytes]: reject 'impossible-length' buffers.
FrameValidity validateFrameFacts(
  FrameFacts f, {
  int? nowMs,
  int maxAgeMs = 5000,
}) {
  if (f.width <= 0 || f.height <= 0) {
    return FrameValidity.invalid('bad-dimensions');
  }
  if (f.width * f.height > maxFramePixels) {
    return FrameValidity.invalid('frame-too-large');
  }
  if (f.totalBytes >= 0) {
    final pixels = f.width * f.height;
    if (f.totalBytes < pixels || f.totalBytes > pixels * 4) {
      return FrameValidity.invalid('impossible-length');
    }
  }
  if (f.planeCount <= 0 || f.planeCount > 4) {
    return FrameValidity.invalid('bad-plane-count');
  }
  if (f.planeLengths.length != f.planeCount ||
      f.rowStrides.length != f.planeCount) {
    return FrameValidity.invalid('plane-metadata-mismatch');
  }
  for (var i = 0; i < f.planeCount; i++) {
    if (f.planeLengths[i] <= 0) {
      return FrameValidity.invalid('empty-plane');
    }
    if (f.rowStrides[i] <= 0) {
      return FrameValidity.invalid('bad-stride');
    }
  }
  const r = [0, 90, 180, 270];
  if (!r.contains(((f.rotationDeg % 360) + 360) % 360)) {
    return FrameValidity.invalid('bad-rotation');
  }
  if (f.timestampMs < 0) {
    return FrameValidity.invalid('bad-timestamp');
  }
  if (nowMs != null && f.timestampMs >= 0) {
    final age = nowMs - f.timestampMs;
    // Negative age = clock skew between sensor and wall clock: pass
    // (never invent a failure mode from unsynchronized clocks).
    if (age > maxAgeMs) {
      return FrameValidity.invalid('stale-frame');
    }
  }
  return FrameValidity.valid;
}
