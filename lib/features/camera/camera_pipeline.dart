// Camera pipeline logic: pure Dart, fully unit-tested. The single
// plugin import below (ML Kit face detection) contributes ONLY the
// FaceDetectorOptions data class for the canonical detector-config
// builder — constructing options performs no channel call, so every
// rule here stays provable without a device.
//
// Covers the v0.3.3 runtime-debug requirements as testable rules:
// - explicit camera stage machine (preview vs analysis never conflated),
// - ML input format choice from OBSERVED plane layout (never assumed),
// - startup watchdog evaluation (pure function of timestamps),
// - recovery ladder (escalating actions, never an infinite loop),
// - best-camera decision from capabilities + needs (technical reasons only),
// - anatomical left/right safety across front/rear/mirror/rotation.
//
// CameraService executes these rules against real hardware; the rules
// themselves are proven here without a device.
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Every distinguishable pipeline stage. Preview progress and analysis
/// progress are separate dimensions on purpose: a working preview with
/// failing analysis must read exactly that way, never "Starting camera".
enum CameraStage {
  idle,
  requestingPermission,
  initializing,
  switching,
  previewReady,
  streamStarting,
  firstFrame,
  processing,
  permissionDenied,
  initFailed,
  streamFailed,
  noFirstFrame,
  conversionFailed,
  mlDegraded,
}

/// Whether the preview (controller) path is up, independent of analysis.
bool previewUp(CameraStage s) =>
    s == CameraStage.previewReady ||
    s == CameraStage.streamStarting ||
    s == CameraStage.firstFrame ||
    s == CameraStage.processing;

/// Whether at least one frame reached the analyzer.
bool analysisFlowing(CameraStage s) =>
    s == CameraStage.firstFrame || s == CameraStage.processing;

/// ML input layout chosen from the OBSERVED frame, not assumed.
enum MlDeclaredFormat { nv21, yv12, bgra8888, unsupported }

/// Choose the declared ML format from observed plane count + requested
/// group. Real Android phones emit 2-plane NV21 or 3-plane planar YUV for
/// an NV21 request; declaring the wrong layout corrupts ML input while the
/// preview looks perfect — this choice is recorded per frame for /dev.
MlDeclaredFormat chooseMlFormat({
  required int planeCount,
  required String formatGroupName,
}) {
  if (planeCount <= 0) return MlDeclaredFormat.unsupported;
  if (planeCount == 1) return MlDeclaredFormat.bgra8888;
  if (planeCount == 2) return MlDeclaredFormat.nv21;
  if (formatGroupName == 'bgra8888') return MlDeclaredFormat.bgra8888;
  // 3+ planar planes: Y + V + U concatenation (YV12 order) as an explicit
  // best-effort; the assumption is logged in the frame inspector.
  return MlDeclaredFormat.yv12;
}

/// Startup watchdog: pure evaluation of timestamps. The service records
/// stream start / first frame times; the UI polls this — no hidden timers
/// in business logic, fully testable.
enum StartupState { idle, waiting, ok, timeout }

class StartupWatchdog {
  final Duration timeout;
  const StartupWatchdog({this.timeout = const Duration(seconds: 8)});

  StartupState evaluate({
    required bool streamStarted,
    required bool firstFrameReceived,
    required DateTime? startedAt,
    required DateTime now,
  }) {
    if (firstFrameReceived) return StartupState.ok;
    if (!streamStarted || startedAt == null) return StartupState.idle;
    if (now.difference(startedAt) > timeout) return StartupState.timeout;
    return StartupState.waiting;
  }
}

/// Recovery ladder: bounded escalation so the user is never trapped in an
/// adjust-forever loop. Attempt counting is owned by the UI layer.
enum RecoveryAction {
  none,
  autoResetTracker,
  showPanel,
  offerRestart,
  offerContinueUnable,
}

class RecoveryLadder {
  /// Seconds stuck without lock before each escalation step.
  final int autoResetAtSec;
  final int panelAtSec;
  final int restartAtSec;
  final int unableAtSec;
  const RecoveryLadder({
    this.autoResetAtSec = 15,
    this.panelAtSec = 30,
    this.restartAtSec = 60,
    this.unableAtSec = 120,
  });

  RecoveryAction actionFor({required int stuckSeconds}) {
    if (stuckSeconds >= unableAtSec) return RecoveryAction.offerContinueUnable;
    if (stuckSeconds >= restartAtSec) return RecoveryAction.offerRestart;
    if (stuckSeconds >= panelAtSec) return RecoveryAction.showPanel;
    if (stuckSeconds >= autoResetAtSec) {
      return RecoveryAction.autoResetTracker;
    }
    return RecoveryAction.none;
  }
}

/// What a test needs from a camera. Self-guided positioning favors the
/// front camera; high-detail imaging favors raw capability.
enum TestCameraNeed { selfGuided, highDetail }

/// Capability facts per physical camera. Pre-init facts come from the OS
/// camera list; post-init facts (preview size, zoom) attach after open.
class CameraCapabilities {
  final String code; // 'front' | 'rear' | 'external'
  final String lensDirection;
  final int sensorOrientation;
  final String name;
  final int? previewWidth;
  final int? previewHeight;
  final double? maxZoom;

  const CameraCapabilities({
    required this.code,
    required this.lensDirection,
    required this.sensorOrientation,
    required this.name,
    this.previewWidth,
    this.previewHeight,
    this.maxZoom,
  });

  int get pixelCount =>
      (previewWidth != null && previewHeight != null)
          ? previewWidth! * previewHeight!
          : 0;
}

class BestCameraDecision {
  final String code;
  final List<String> reasons;
  const BestCameraDecision(this.code, this.reasons);
}

/// Deterministic best-camera decision. Technical reasons only — never a
/// medical-accuracy claim. Ties and unknowns resolve to front (the
/// self-guidable default), stated explicitly.
BestCameraDecision recommendCamera({
  required TestCameraNeed need,
  required List<CameraCapabilities> available,
}) {
  if (available.isEmpty) {
    return const BestCameraDecision(
        'front', ['No camera list available; defaulting to front.']);
  }
  CameraCapabilities? front;
  CameraCapabilities? rear;
  for (final c in available) {
    if (c.code == 'front') front ??= c;
    if (c.code == 'rear') rear ??= c;
  }
  switch (need) {
    case TestCameraNeed.selfGuided:
      if (front != null) {
        return const BestCameraDecision('front', [
          'Self-guided positioning needs a visible preview while facing the camera.'
        ]);
      }
      return const BestCameraDecision('rear',
          ['No front camera on this device; assisted rear mode required.']);
    case TestCameraNeed.highDetail:
      if (rear != null && front != null) {
        if (rear.pixelCount > front.pixelCount && front.pixelCount > 0) {
          return BestCameraDecision('rear', [
            'Higher measured preview resolution (${rear.previewWidth}x${rear.previewHeight}) '
                'for this high-detail eye test.'
          ]);
        }
        if (front.pixelCount >= rear.pixelCount && rear.pixelCount > 0) {
          return const BestCameraDecision('front', [
            'Front preview resolution is equal or higher on this device; keeping self-guided mode.'
          ]);
        }
        return const BestCameraDecision('rear', [
          'Rear camera present; resolution not yet measured — rear may provide more detail.'
        ]);
      }
      if (rear != null) {
        return const BestCameraDecision(
            'rear', ['Only rear camera available.']);
      }
      return const BestCameraDecision(
          'front', ['Only front camera available.']);
  }
}

/// Anatomical side safety: the canonical internal representation is always
/// the SUBJECT's physical eye. The overlay may mirror the selfie preview,
/// but analyzer data must not swap. This helper resolves which screen side
/// a physical eye appears on, so labels stay correct under every
/// front/rear/mirror/rotation combination — and tests pin it down.
enum PhysicalEye { left, right }

/// Returns true when the subject's left eye appears on the LEFT half of
/// the displayed (already mapped) preview. For a mirrored front selfie it
/// appears on the right (like a mirror); otherwise on the left.
bool subjectLeftOnScreenLeft({required bool mirrored}) => !mirrored;

/// Adaptive acquisition (more data over time, per device).
///
/// When frames flow but the detector sees zero faces for a long run, the
/// likely cause is input-side (too few pixels on a distant/small face for
/// the current resolution) rather than thresholds. The honest response is
/// to spend more pixels once: escalate resolution a single step and keep
/// going. Bounded (once per session), logged, reversible on next entry.
class AcquisitionAdapter {
  /// Consecutive faceless PROCESSED frames that trigger one escalation.
  final int escalateAfterFrames;
  const AcquisitionAdapter({this.escalateAfterFrames = 150});

  /// Pure rule: escalate only when frames actually flow, none had faces,
  /// and no escalation happened yet this session.
  bool shouldEscalate({
    required int consecutiveFacelessProcessed,
    required bool alreadyEscalated,
  }) {
    if (alreadyEscalated) return false;
    return consecutiveFacelessProcessed >= escalateAfterFrames;
  }
}

/// Per-configuration hit-rate tracking: how often each stream config
/// actually yields faces on THIS device. Accumulated live (in-session);
/// surfaced in diagnostics and the research export so future decisions
/// (and future training-data choices) rest on measured rates, not claims.
class ConfigHitRates {
  final Map<String, int> frames = {};
  final Map<String, int> faces = {};

  void record(String config, {required bool faceFound}) {
    frames[config] = (frames[config] ?? 0) + 1;
    if (faceFound) faces[config] = (faces[config] ?? 0) + 1;
  }

  double rate(String config) {
    final f = frames[config] ?? 0;
    if (f == 0) return -1;
    return (faces[config] ?? 0) / f;
  }

  Map<String, String> summary() => {
        for (final c in frames.keys)
          c: '${faces[c] ?? 0}/${frames[c]} '
              '(${(rate(c) * 100).toStringAsFixed(1)}%)',
      };

  void clear() {
    frames.clear();
    faces.clear();
  }
}

/// Observed frame layout refined by actual plane byte sizes (v0.5
/// hotfix). Plane COUNT alone lies on some devices: a "3-plane" frame
/// whose middle plane holds a full-width interleaved chroma row is
/// really NV21 in a split wrapper, and concatenating all three planes
/// as planar corrupts ML input while the preview stays perfect.
enum FrameLayoutKind {
  nv21Interleaved,
  yv12Planar,
  bgra,
  /// Luma-only YUV frame (observed: single-plane NV21 holding just the Y
  /// plane). Face detection is luminance-driven, so the packer pairs the
  /// real Y with synthesized neutral chroma (128) into a valid NV21
  /// buffer. Declared as nv21; the kind name is logged per frame so /dev
  /// always shows that chroma was synthesized, never measured.
  nv21LumaOnly,
  unknown,
}

class FrameLayout {
  final FrameLayoutKind kind;
  /// Which plane indices to concatenate, in order.
  final List<int> usePlanes;
  /// Declared ML format name for logs/metadata.
  final String mlFormatName;
  const FrameLayout(this.kind, this.usePlanes, this.mlFormatName);
}

/// Refine the layout from observed plane byte sizes. All arithmetic uses
/// integer pixel counts; chroma rows assume standard 4:2:0 subsampling.
FrameLayout refineLayout({
  required int planeCount,
  required List<int> planeLengths,
  required int width,
  required int height,
  required String formatGroupName,
}) {
  if (planeCount <= 0 || planeLengths.isEmpty) {
    return const FrameLayout(
        FrameLayoutKind.unknown, [], 'unsupported');
  }
  if (width <= 0 || height <= 0) {
    return const FrameLayout(
        FrameLayoutKind.unknown, [], 'unsupported');
  }
  if (planeCount == 1) {
    // Single-plane frames need the group name: a complete BGRA buffer
    // is usable, a pre-concatenated NV21 buffer is usable, but JPEG (or
    // anything else short of a known size) must stay unsupported and
    // loud — never mislabeled as pixels.
    final only = planeLengths[0];
    if (formatGroupName == 'jpeg') {
      return const FrameLayout(
          FrameLayoutKind.unknown, [], 'unsupported');
    }
    if (only == width * height * 4) {
      return const FrameLayout(
          FrameLayoutKind.bgra, [0], 'bgra8888');
    }
    if (only == width * height * 3 ~/ 2) {
      return const FrameLayout(
          FrameLayoutKind.nv21Interleaved, [0], 'nv21');
    }
    // Oversized single YUV plane (observed: 720x480 NV21 with 541,392
    // bytes — padded/strided, neither luma-exact nor packed-exact).
    // Exact-packed is preferred above (real chroma kept); here Y is
    // extracted row-wise with the stride label and chroma synthesized.
    // `>=` (not `==`): trailing padding is ignored, never parsed.
    if ((formatGroupName == 'nv21' || formatGroupName == 'yuv420') &&
        only >= width * height) {
      return const FrameLayout(
          FrameLayoutKind.nv21LumaOnly, [0], 'nv21');
    }
    return const FrameLayout(
        FrameLayoutKind.unknown, [], 'unsupported');
  }
  final yLen = width * height;
  if (planeCount == 2) {
    return const FrameLayout(
        FrameLayoutKind.nv21Interleaved, [0, 1], 'nv21');
  }
  // 3+ planes: inspect the middle plane.
  final chromaFull = planeLengths.length > 1 && planeLengths[1] >= yLen ~/ 2;
  if (chromaFull) {
    // Full-width interleaved chroma in plane 1: NV21 in disguise.
    // Plane 2 (if any) is padding/empty — do NOT append it.
    return const FrameLayout(
        FrameLayoutKind.nv21Interleaved, [0, 1], 'nv21');
  }
  if (formatGroupName == 'bgra8888') {
    return const FrameLayout(
        FrameLayoutKind.bgra, [0], 'bgra8888');
  }
  return const FrameLayout(
      FrameLayoutKind.yv12Planar, [0, 2, 1], 'yv12');
}

/// Expected concatenated byte length for a layout, given row stride.
/// NV21: Y rows + one interleaved chroma row per 2 Y rows (chroma stride
/// equals luma stride — full-width VU pairs). Planar: half-stride chroma.
/// A real buffer far from this length means the layout assumption is
/// wrong and the bytes must NOT be sent to ML Kit.
int expectedMlLength({
  required FrameLayoutKind kind,
  required int width,
  required int height,
  required int bytesPerRow,
}) {
  switch (kind) {
    case FrameLayoutKind.nv21Interleaved:
    case FrameLayoutKind.nv21LumaOnly:
      return bytesPerRow * height + bytesPerRow * (height ~/ 2);
    case FrameLayoutKind.yv12Planar:
      return bytesPerRow * height +
          (bytesPerRow ~/ 2) * (height ~/ 2) * 2;
    case FrameLayoutKind.bgra:
      return width * height * 4;
    case FrameLayoutKind.unknown:
      return -1;
  }
}

/// Whether the Y rows carry padding (stride != width). Padding itself is
/// legal when declared via metadata; this flag is for diagnostics.
bool strideHasPadding(
        {required int bytesPerRow, required int width}) =>
    bytesPerRow != width;

/// One plane's bytes plus its row stride, in pixel units as documented
/// by the camera plugin (width/height may be null on old platforms).
/// bytesPerPixel converts ambiguous stride labels: some devices report
/// bytesPerRow in PIXELS (observed 720 for a 720-wide BGRA plane) rather
/// than bytes, in which case stride * bytesPerPixel == the byte stride.
class PlaneBytes {
  final List<int> bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
  final int? width;
  final int? height;
  const PlaneBytes(
      {required this.bytes,
      required this.bytesPerRow,
      this.bytesPerPixel,
      this.width,
      this.height});
}

/// Effective byte stride for row stepping: unwraps pixel-unit labels
/// (stride * pixelStride == row bytes) to the byte stride ML Kit reads.
/// Anything else keeps the label as-is; row copying still validates
/// every row against the real buffer, so a wrong label fails loudly.
int effectiveByteStride(PlaneBytes p, int rowBytes) {
  final bpp = p.bytesPerPixel ?? 0;
  if (bpp > 1 &&
      p.bytesPerRow > 0 &&
      p.bytesPerRow < rowBytes &&
      p.bytesPerRow * bpp == rowBytes) {
    return rowBytes;
  }
  return p.bytesPerRow;
}

/// Latch rule for the YV12 declaration fallback: persistent NATIVE
/// converter failures (ML Kit fromByteArray NPE class) with zero analyzed
/// frames mean the declared format's native path is broken on this
/// device — not the pixels. Latching once per session to YV12 for
/// NV21-family bytes (identical luma, alternate native path, chroma
/// order swap immaterial to face detection) is strictly more honest
/// than failing every frame, and fully logged at the call site.
/// M4: the FIRST rung fires at 5 (not 10) for pure converter errors —
/// five identical converter NPEs with zero processed frames are already
/// decisive, and this rung only changes the declared format (same luma),
/// so early latching is safe. Later rungs stay at 10 (pinned by tests).
bool shouldLatchFormatFallback({
  required int consecMlErrors,
  required int framesProcessed,
  required bool alreadyLatched,
  required bool converterError,
}) =>
    converterError &&
    !alreadyLatched &&
    framesProcessed == 0 &&
    consecMlErrors >= 5;

/// Latch rule for the RGBA-bitmap input rung: persistent NATIVE
/// converter failures under the YV12 declaration mean both byte-array
/// native paths are broken on this device. Raw upright RGBA through
/// InputImage.fromBitmap takes a third native path (Bitmap, no byte
/// converter, no file IO). Same gate shape, one rung further down.
bool shouldLatchBitmapFallback({
  required int consecMlErrors,
  required int framesProcessed,
  required bool yv12Latched,
  required bool bitmapLatched,
  required bool converterError,
}) =>
    converterError &&
    yv12Latched &&
    !bitmapLatched &&
    framesProcessed == 0 &&
    consecMlErrors >= 10;

/// Latch rule for the minimal-detector fallback: failures INSIDE the
/// detector (non-converter ml-process errors — e.g. a synchronous NPE in
/// ML Kit's obfuscated detector prep, which Flutter's framework wraps as
/// code "error" with the Java stack as details) after the input rungs
/// are already latched (bitmap and/or file: byte paths exhausted, some
/// input construction proven). Different detector options take a
/// different internal path; landmarks stay on because eyes are the
/// measurement.
bool shouldLatchDetectorFallback({
  required int consecMlErrors,
  required int framesProcessed,
  required bool fileLatched,
  required bool bitmapLatched,
  required bool detectorLatched,
  required bool converterError,
  required bool detectorError,
}) =>
    detectorError &&
    !converterError &&
    (fileLatched || bitmapLatched) &&
    !detectorLatched &&
    framesProcessed == 0 &&
    consecMlErrors >= 10;

/// Typed ML-failure classification (M8). The old call-site sniffed
/// `'$e'.contains('InputImageConverterError')` inline, which misroutes
/// wrapped detector-internal NPEs (PlatformException code "error" with
/// the Java stack in details — the CPH2121 signature) down the
/// byte-format rungs instead of the detector rung. One taxonomy, logged
/// explicitly at the call site; pure and unit-tested.
enum MlFailureKind { converter, detector, unknown }

MlFailureKind classifyMlFailure(String text) {
  if (text.contains('InputImageConverterError')) {
    return MlFailureKind.converter;
  }
  if (text.contains('NullPointerException')) return MlFailureKind.detector;
  return MlFailureKind.unknown;
}

/// Failover gate: the automatic native attempt fires exactly once
/// until explicitly re-armed. Prevents the restore→degrade→failover
/// loop (each cycle would kill the live preview for seconds).
bool nativeFailoverDue({
  required bool nativeActive,
  required bool attempted,
  required bool exhausted,
  required bool disposed,
}) =>
    !nativeActive && !attempted && !exhausted && !disposed;

/// Native-primary gate (v0.7.17 architecture): every fresh session entry
/// offers the zero-copy native CameraX engine first; the Dart
/// plugin-camera ladder is the automatic fallback, never the default.
/// Fires only for fresh chain starts (startAt 0 — Dart-chain retries
/// must never bounce back into native), never twice per attempt, never
/// against an explicit Dart choice or a silent-native failover.
bool nativePrimaryDue({
  required int startAt,
  required bool nativeActive,
  required bool nativeFailed,
  required bool suppressed,
  required bool manualDart,
  required bool disposed,
}) =>
    startAt == 0 &&
    !nativeActive &&
    !nativeFailed &&
    !suppressed &&
    !manualDart &&
    !disposed;

/// Degraded-mode attempt throttle (performance): with persistent failure
/// and zero analyzed frames, attempting ML on every frame burns CPU and
/// battery (conversion copies, JPEG encode, file IO, channel traffic,
/// UI rebuilds) for an identical failure ~7x/second. Allow one attempt
/// per [cooldown]; throttled frames count received + dropped and skip
/// ALL conversion/ML work. Releases automatically on success (the error
/// counter resets) and immediately on every latch transition (callers
/// clear the timestamp so the new rung attempts at once).
bool mlAttemptDue({
  required int consecErrors,
  required int framesProcessed,
  required DateTime now,
  required DateTime? lastAttempt,
  Duration cooldown = const Duration(seconds: 2),
}) {
  if (framesProcessed > 0 || consecErrors < 10) return true;
  final last = lastAttempt;
  if (last == null) return true;
  return now.difference(last) >= cooldown;
}

/// Refuse-to-allocate cap: real camera streams stay far below 16 MP;
// anything bigger is garbage metadata, and w*h*4 bytes per frame would
// OOM the isolate long before ML Kit saw it. Loud refusal, never a
// half-allocated corrupt buffer.
const int maxFramePixels = 16 * 1024 * 1024;

/// Copy one row safely with a single range copy; returns false when the
/// source cannot supply it. Bounds-checked per row so a lying stride
/// label fails loudly instead of corrupting the buffer.
bool copyRow(
    List<int> out, int cursor, List<int> src, int srcOffset, int count) {
  if (cursor < 0 || srcOffset < 0 || count < 0) return false;
  if (srcOffset + count > src.length) return false;
  if (cursor + count > out.length) return false;
  out.setRange(cursor, cursor + count, src, srcOffset);
  return true;
}

/// Whether the observed planes are already tightly packed, so the bytes
/// can be concatenated directly with zero extra copies. Anything else
/// goes through [tightPackFrame]. Conservative: any doubt → pack.
bool isTightLayout({
  required FrameLayoutKind kind,
  required List<PlaneBytes> planes,
  required int width,
  required int height,
}) {
  bool planeTight(int i, int stride, int length) {
    if (i < 0 || i >= planes.length) return false;
    final p = planes[i];
    return p.bytesPerRow == stride && p.bytes.length == length;
  }

  switch (kind) {
    case FrameLayoutKind.nv21Interleaved:
      if (planes.length < 2) return false;
      if (planeTight(0, width, width * height) &&
          planeTight(1, width, width * (height ~/ 2))) {
        return true;
      }
      // Completeness fallback (cross-device): stride labels in pixels
      // instead of bytes, or equivalent unit quirks, still concatenate
      // to the canonical packed length. Luma is intact in this case, so
      // analysis proceeds; the layout is logged per frame for /dev.
      if (planes[0].bytes.length + planes[1].bytes.length ==
          width * height * 3 ~/ 2) {
        return true;
      }
      return false;
    case FrameLayoutKind.yv12Planar:
      if (planes.length < 3) return false;
      if (planeTight(0, width, width * height) &&
          planeTight(2, width ~/ 2, (width ~/ 2) * (height ~/ 2)) &&
          planeTight(1, width ~/ 2, (width ~/ 2) * (height ~/ 2))) {
        return true;
      }
      if (planes[0].bytes.length +
              planes[1].bytes.length +
              planes[2].bytes.length ==
          width * height * 3 ~/ 2) {
        return true;
      }
      return false;
    case FrameLayoutKind.bgra:
      if (planes.isEmpty) return false;
      // Single-plane completeness is the ground truth: stride labels lie
      // in UNITS on some devices (bytesPerRow == width, i.e. pixels not
      // bytes — observed 720x480 BGRA with stride 720). A complete w*h*4
      // buffer concatenates to a valid ML input whatever the label says.
      if (planes[0].bytes.length == width * height * 4) return true;
      return planeTight(0, width * 4, width * height * 4);
    case FrameLayoutKind.nv21LumaOnly:
      // Never "tight": the raw plane is luma-only and MUST pass through
      // the packer for neutral-chroma synthesis. Direct concatenation
      // would hand ML Kit a truncated buffer.
      return false;
    case FrameLayoutKind.unknown:
      return false;
  }
}

/// Build a TIGHTLY-PACKED ML buffer from strided planes.
///
/// ML Kit on Android ignores row stride and reads standard packed
/// layouts, so padded rows must be stripped row by row. Returns null
/// when any row is missing (caller records a loud conversion error
/// instead of sending corrupt bytes). Buffers are pre-sized and filled
/// with range copies (no per-byte loops), and absurd dimensions are
/// refused before allocating.
///
/// - NV21: Y (H rows of W) + VU interleaved (H/2 rows of W).
/// - YV12: Y + V (W/2 x H/2) + U (W/2 x H/2).
/// - BGRA: single plane, W*4 bytes per row.
/// - Luma-only: real Y + synthesized neutral chroma (see kind docs).
///
/// Chroma note: when Y packs but chroma does not, this returns null and
/// the caller may use [packLumaFallback] (real luma + neutral chroma)
/// instead of dropping a detectable frame. That fallback is logged at
/// the call site, never silent.
List<int>? tightPackFrame({
  required List<PlaneBytes> planes,
  required int width,
  required int height,
  required FrameLayoutKind kind,
}) {
  if (width <= 0 || height <= 0 || planes.isEmpty) return null;
  if (width * height > maxFramePixels) return null;
  final yLen = width * height;
  final chromaLen = width * (height ~/ 2);
  final total = switch (kind) {
    FrameLayoutKind.nv21Interleaved => yLen + chromaLen,
    FrameLayoutKind.yv12Planar =>
      yLen + 2 * ((width ~/ 2) * (height ~/ 2)),
    FrameLayoutKind.bgra => yLen * 4,
    FrameLayoutKind.nv21LumaOnly => yLen + chromaLen,
    FrameLayoutKind.unknown => -1,
  };
  if (total <= 0) return null;
  final out = Uint8List(total);
  var cursor = 0;
  bool rows(List<int> bytes, int stride, int rowBytes, int rowCount) {
    if (stride <= 0 || rowBytes <= 0 || rowBytes > stride) return false;
    for (var r = 0; r < rowCount; r++) {
      if (!copyRow(out, cursor, bytes, r * stride, rowBytes)) {
        return false;
      }
      cursor += rowBytes;
    }
    return true;
  }

  bool done() => cursor == out.length;

  switch (kind) {
    case FrameLayoutKind.nv21Interleaved:
      if (planes.length < 2) return null;
      if (!rows(planes[0].bytes,
          effectiveByteStride(planes[0], width), width, height)) {
        return null;
      }
      if (!rows(planes[1].bytes,
          effectiveByteStride(planes[1], width), width, height ~/ 2)) {
        return null;
      }
      return done() ? out : null;
    case FrameLayoutKind.yv12Planar:
      if (planes.length < 3) return null;
      if (!rows(planes[0].bytes,
          effectiveByteStride(planes[0], width), width, height)) {
        return null;
      }
      if (!rows(planes[2].bytes,
          effectiveByteStride(planes[2], width ~/ 2), width ~/ 2, height ~/ 2)) {
        return null;
      }
      if (!rows(planes[1].bytes,
          effectiveByteStride(planes[1], width ~/ 2), width ~/ 2, height ~/ 2)) {
        return null;
      }
      return done() ? out : null;
    case FrameLayoutKind.bgra:
      if (planes.isEmpty) return null;
      // Complete single-plane buffer: already packed regardless of the
      // stride label's units (see isTightLayout) — pass it through whole.
      // Anything else falls to row-wise packing, which fails loudly on
      // unit-mismatched strides instead of sending corrupt bytes.
      if (planes[0].bytes.length == yLen * 4) {
        out.setRange(0, out.length, planes[0].bytes, 0);
        cursor = out.length;
        return done() ? out : null;
      }
      if (!rows(planes[0].bytes,
          effectiveByteStride(planes[0], width * 4), width * 4, height)) {
        return null;
      }
      return done() ? out : null;
    case FrameLayoutKind.nv21LumaOnly:
      // Luma-only frame: copy the real Y (whole when complete, row-wise
      // otherwise so padded/strided Y still works), then synthesize
      // neutral chroma (128 = no color). Face detection reads luma; the
      // synthesis is logged via the layout kind, never hidden.
      if (planes.isEmpty) return null;
      if (planes[0].bytes.length == yLen) {
        out.setRange(0, yLen, planes[0].bytes, 0);
        cursor = yLen;
      } else if (!rows(planes[0].bytes,
          effectiveByteStride(planes[0], width), width, height)) {
        return null;
      }
      out.fillRange(cursor, cursor + chromaLen, 128);
      cursor += chromaLen;
      return done() ? out : null;
    case FrameLayoutKind.unknown:
      return null;
  }
}

/// Luma fallback for YUV frames whose chroma is unreadable (short plane,
/// garbage stride, pixelStride-2 interleaved garbage): keep the real Y
/// and synthesize neutral chroma rather than dropping a frame ML Kit
/// could detect faces in. Returns null only when Y itself is unreadable
/// (then nothing honest remains and the caller fails loudly).
/// The caller MUST log the fallback (layout kind + event) — synthesis
/// is always declared, never silent.
List<int>? packLumaFallback({
  required List<PlaneBytes> planes,
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0 || planes.isEmpty) return null;
  if (width * height > maxFramePixels) return null;
  final y = planes[0];
  final yLen = width * height;
  final out = Uint8List(yLen + width * (height ~/ 2));
  if (y.bytes.length == yLen) {
    out.setRange(0, yLen, y.bytes, 0);
  } else {
    final stride = effectiveByteStride(y, width);
    if (stride <= 0 || width > stride) return null;
    for (var r = 0; r < height; r++) {
      final off = r * stride;
      if (off + width > y.bytes.length) return null;
      if (!copyRow(out, r * width, y.bytes, off, width)) return null;
    }
  }
  out.fillRange(yLen, out.length, 128);
  return out;
}

/// Stream configuration fallback chain (v0.4 hotfix): some devices fail
/// to bind the analysis stream at a given resolution/format combination
/// (preview keeps working — separate path). On stream failure the service
/// retries with the next entry instead of giving up. Order matters:
/// preferred quality first, widest compatibility last.
enum StreamConfig {
  mediumNv21,
  lowNv21,
  mediumYuv420,
  lowYuv420,
  highNv21,
  highYuv420,
}

const List<StreamConfig> streamFallbackChain = [
  StreamConfig.mediumNv21,
  StreamConfig.lowNv21,
  StreamConfig.mediumYuv420,
  StreamConfig.lowYuv420,
];

/// High-first chain used exactly once per session when frames flow but no
/// face appears for a long run (resolution escalation).
const List<StreamConfig> highFirstChain = [
  StreamConfig.highNv21,
  StreamConfig.highYuv420,
  StreamConfig.mediumNv21,
  StreamConfig.lowNv21,
  StreamConfig.mediumYuv420,
  StreamConfig.lowYuv420,
];

/// Stale-stream evaluation (pure): a controller can report ready with a
/// "running" stream that silently delivers nothing (OS stole the session,
/// capture race, dead subscription). Re-init must rebuild in that case
/// instead of no-op returning a dead pipeline.
bool streamLooksDead({  required bool ready,
  required bool streamActive,
  required int framesReceived,
  required DateTime? streamStartedAt,
  required int lastFrameAgeMs,
  required DateTime now,
}) {
  if (!ready || !streamActive) return false;
  // Stream claims to run but nothing ever arrived.
  if (framesReceived == 0 &&
      streamStartedAt != null &&
      now.difference(streamStartedAt) >
          const Duration(seconds: 10)) {
    return true;
  }
  // Frames flowed once, then silence for 15 s.
  if (framesReceived > 0 && lastFrameAgeMs > 15000) return true;
  return false;
}

/// Detector-recreation policy (pure; NOT wired into CameraService yet).
///
/// Context: on some devices (e.g. OPPO CPH2121, Android 12) the on-device
/// ML Kit `FaceDetection.getClient()` throws a synchronous
/// NullPointerException and every subsequent `process()` fails, so
/// `framesProcessed` stays 0 while `consecutiveErrors` climbs. Recreating
/// the detector (close + FaceDetection.getClient again) is the only
/// rung that re-runs detector construction; the byte-layout / bitmap /
/// file / minimal-detector latches in this file only change the INPUT.
///
/// Gate mirrors the latch gates (>= 10 consecutive errors with zero
/// processed frames) so recreation is attempted exactly when the
/// detector — not the pixels — looks broken. Bounded so it can never
/// loop: at most [maxRecreates] recreates per session, at least
/// [minInterval] apart (default 5 s / 3 per session).
///
/// FOLLOW-UP (left for the main agent): wire into CameraService —
/// track `recreatesSoFar` + `lastRecreateAt` alongside the existing
/// consec-error / processed counters, call this helper on each ML
/// error, and on `true` close + rebuild the FaceDetector, stamp
/// `lastRecreateAt = now`, increment `recreatesSoFar`, and log the
/// transition (DIAG + error export) with the describe() line from
/// ml_diagnostic.dart.
const int kMaxDetectorRecreatesPerSession = 3;
const Duration kMinDetectorRecreateInterval = Duration(seconds: 5);
const int kDetectorRecreateAfterErrors = 10;

/// Fast-tier experiment note (v0.7.15): automatic accurate→fast
/// switching shipped in v0.7.14 and CPH2121 falsified it on-device
/// (275ms vs ~110ms accurate, drops 61%→84%). The default path is
/// accurate again; fast is re-armed only via the dev-only
/// CameraService.setPreferFastTier toggle (/ml-test) with
/// per-generation latency stats in the export deciding the next step.
/// No automatic tier rule lives here until a tier proves faster on
/// real hardware.
///
/// Canonical live detector configuration — THE single source of truth
/// for every detector built in the app (service live path, oracle
/// probes, Test H). Contours are OFF (nothing consumes them);
/// landmarks stay ON in every tier (eyes are the measurement);
/// classification + tracking follow the tier. v0.7.18 proved why this
/// must be singular: the oracle probes ran minimal while live ran full
/// and the miss read as a detector failure instead of a config gap.
FaceDetectorOptions liveDetectorOptions({
  bool minimal = false,
  bool fast = false,
}) =>
    FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      enableClassification: !minimal,
      enableTracking: !minimal && !fast,
      performanceMode:
          (minimal || fast) ? FaceDetectorMode.fast : FaceDetectorMode.accurate,
    );

bool detectorRecreateDue({
  required int consecutiveErrors,
  required int framesProcessed,
  required DateTime now,
  required DateTime? lastRecreateAt,
  required int recreatesSoFar,
  int maxRecreates = kMaxDetectorRecreatesPerSession,
  Duration minInterval = kMinDetectorRecreateInterval,
}) {
  if (framesProcessed != 0) return false;
  if (consecutiveErrors < kDetectorRecreateAfterErrors) return false;
  if (recreatesSoFar < 0) return false;
  if (recreatesSoFar >= maxRecreates) return false;
  final last = lastRecreateAt;
  if (last != null && now.difference(last) < minInterval) return false;
  return true;
}
