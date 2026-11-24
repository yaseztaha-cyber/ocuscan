// VisionSession: explicit camera/detector lifecycle (Phase 1A §10).
//
// One session owns exactly one camera open + one detector instance +
// one generation token. Rules enforced by construction:
// - no processing after close (detector == closed → canProcess false)
// - no processing from old sessions (generation mismatch checked by
//   callers against detectorGeneration)
// - no double-close effect (close() is idempotent, stays closed)
// - no overlapping inference (activeInference flag; at most one)
// - no detector reuse after invalidation (invalidate() → invalid,
//   only nextGeneration() + re-creation clears it)
//
// Pure Dart: the Dart side is bookkeeping. The native engine enforces
// single-flight itself (single-thread analyzer); this model mirrors
// that state for UI, diagnostics, and tests.
class VisionCameraState {
  static const idle = 0;
  static const starting = 1;
  static const ready = 2;
  static const analyzing = 3;
  static const restarting = 4;
  static const failed = 5;
  static const stopping = 6;
}

class VisionDetectorState {
  static const idle = 0;
  static const creating = 1;
  static const ready = 2;
  static const invalid = 3;
  static const closed = 4;
}

class VisionSession {
  final String sessionId;
  final int camera;
  final int detector;
  final int detectorGeneration;
  final bool activeInference;
  final DateTime? lastFrameAt;

  const VisionSession({
    required this.sessionId,
    this.camera = VisionCameraState.idle,
    this.detector = VisionDetectorState.idle,
    this.detectorGeneration = 0,
    this.activeInference = false,
    this.lastFrameAt,
  });

  VisionSession withCamera(int state) => VisionSession(
        sessionId: sessionId,
        camera: state,
        detector: detector,
        detectorGeneration: detectorGeneration,
        activeInference: activeInference,
        lastFrameAt: lastFrameAt,
      );

  VisionSession withDetector(int state) => VisionSession(
        sessionId: sessionId,
        camera: camera,
        detector: state,
        detectorGeneration: detectorGeneration,
        activeInference: activeInference,
        lastFrameAt: lastFrameAt,
      );

  /// New detector instance: bumps the generation so in-flight callbacks
  /// from the previous instance are discarded by callers. Clears any
  /// in-flight flag (the old inference belongs to a dead generation).
  VisionSession nextGeneration() => VisionSession(
        sessionId: sessionId,
        camera: camera,
        detector: detector,
        detectorGeneration: detectorGeneration + 1,
        activeInference: false,
        lastFrameAt: lastFrameAt,
      );

  VisionSession markInference(bool active) => VisionSession(
        sessionId: sessionId,
        camera: camera,
        detector: detector,
        detectorGeneration: detectorGeneration,
        activeInference: active,
        lastFrameAt: lastFrameAt,
      );

  VisionSession touchFrame(DateTime at) => VisionSession(
        sessionId: sessionId,
        camera: camera,
        detector: detector,
        detectorGeneration: detectorGeneration,
        activeInference: activeInference,
        lastFrameAt: at,
      );

  /// Detector failed terminally: never reuse this instance again.
  VisionSession invalidate() => VisionSession(
        sessionId: sessionId,
        camera: camera,
        detector: VisionDetectorState.invalid,
        detectorGeneration: detectorGeneration,
        activeInference: false,
        lastFrameAt: lastFrameAt,
      );

  /// Idempotent close: detector closed, camera stopping, no inference.
  VisionSession close() => VisionSession(
        sessionId: sessionId,
        camera: VisionCameraState.stopping,
        detector: VisionDetectorState.closed,
        detectorGeneration: detectorGeneration,
        activeInference: false,
        lastFrameAt: lastFrameAt,
      );

  /// True only when a fresh inference may start on THIS session:
  /// camera ready, detector ready, nothing already in flight.
  /// Closed/invalid detectors and non-ready cameras never process.
  bool get canProcess =>
      camera == VisionCameraState.ready &&
      detector == VisionDetectorState.ready &&
      !activeInference;

  /// True when an observation belongs to this session's generation.
  bool ownsGeneration(int generation) =>
      generation == detectorGeneration;
}
