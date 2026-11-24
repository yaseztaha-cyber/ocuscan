// Vision engine capability management (universal compatibility
// milestone, §9/§11).
//
// Capability states — never claim more than proven:
// - supported: healthy on this device.
// - limited: works with restrictions (logged, shown honestly).
// - unsupported: proven unavailable (or never available); the app
//   degrades instead of breaking.
//
// Pure Dart: selection and classification are total functions over
// explicit snapshots, fully unit-tested. No plugins, no camera.

/// Engine choices. `bundledFallback` is a RESERVED slot: no fallback
/// model ships with the app (no runtime, no license cleared), so it
/// always classifies unsupported until one is integrated. Never faked.
enum VisionEngineId {
  dartMlKit,
  nativeMlKit,
  bundledFallback,
  cameraOnly,
}

/// Per-area capability state.
enum CapabilityState { supported, limited, unsupported }

/// Whole-engine health for gating screening start (§10).
enum EngineClassification { ready, degraded, unavailable }

/// Technical-only snapshot posted by the runtime (service / native
/// engine). No identity, no images — counters and flags.
class VisionHealthSnapshot {
  final int framesProcessed;
  final bool converterFailing;
  final bool detectorFailing;
  final bool cameraUp;
  final bool nativeEngineFailed;
  final bool fallbackModelPresent;
  /// Detector proven down (MlHealth.down: persistent errors, zero
  /// processed frames). Stronger than detectorFailing: a down detector
  /// classifies UNAVAILABLE, not merely degraded.
  final bool detectorDown;
  /// Total analyzer arrivals this session (including single-flight drops).
  /// 0 = unknown/unreported: throughput rules are skipped, never guessed.
  final int framesReceived;
  /// Mean end-to-end inference latency in ms over a recent window.
  /// 0 = unknown/unreported: the slowness rule is skipped, never guessed.
  final double meanLatencyMs;
  const VisionHealthSnapshot({
    this.framesProcessed = 0,
    this.converterFailing = false,
    this.detectorFailing = false,
    this.cameraUp = true,
    this.nativeEngineFailed = false,
    this.fallbackModelPresent = false,
    this.detectorDown = false,
    this.framesReceived = 0,
    this.meanLatencyMs = 0,
  });
}

/// Classify engine health: persistent failure with zero frames and no
/// camera is unavailable; a detector proven down is unavailable (its
/// engine choice would be useless); a pipeline that moves but STARVES
/// (most arrivals dropped by single-flight over a real window) or crawls
/// (high mean inference latency) is degraded — "frames processed" alone
/// must never read ready while tracking is unusable; anything else
/// failing with the camera up is degraded, never silently dead.
EngineClassification classifyEngineHealth(VisionHealthSnapshot s) {
  if (!s.cameraUp) return EngineClassification.unavailable;
  if (s.detectorDown) return EngineClassification.unavailable;
  if (s.framesProcessed > 0) {
    // Starved pipe: <35% of arrivals survive over a >=50-arrival window.
    if (s.framesReceived >= 50 &&
        s.framesProcessed / s.framesReceived < 0.35) {
      return EngineClassification.degraded;
    }
    // Slow pipe: mean inference >=250ms over a >=20-arrival window.
    if (s.framesReceived >= 20 && s.meanLatencyMs >= 250) {
      return EngineClassification.degraded;
    }
    return EngineClassification.ready;
  }
  if (s.converterFailing || s.detectorFailing || s.nativeEngineFailed) {
    return EngineClassification.degraded;
  }
  return EngineClassification.ready;
}

/// Capability per area from a health snapshot + static facts.
Map<String, CapabilityState> capabilityStates(
  VisionHealthSnapshot s, {
  required bool hasFrontCamera,
  required bool hasRearCamera,
}) {
  final camera = !hasFrontCamera && !hasRearCamera
      ? CapabilityState.unsupported
      : (s.cameraUp
          ? CapabilityState.supported
          : CapabilityState.unsupported);
  final mlKit = s.detectorFailing || s.nativeEngineFailed
      ? CapabilityState.unsupported
      : (s.converterFailing
          ? CapabilityState.limited
          : CapabilityState.supported);
  return {
    'camera': camera,
    'frontCamera': hasFrontCamera
        ? CapabilityState.supported
        : CapabilityState.unsupported,
    'rearCamera': hasRearCamera
        ? CapabilityState.supported
        : CapabilityState.unsupported,
    'nativeMlKit': mlKit,
    'bundledModel': s.fallbackModelPresent
        ? CapabilityState.supported
        : CapabilityState.unsupported,
    'fallbackEngine': s.fallbackModelPresent
        ? CapabilityState.supported
        : CapabilityState.unsupported,
  };
}

/// Select the engine: explicit manual override wins (Compat Lab);
/// otherwise the proven Dart ML Kit path stays default until the native
/// engine passes its own health check on THIS device (nativeAvailable).
/// A failed native engine falls back (never retries silently); a
/// present fallback model outranks camera-only; camera loss means
/// camera-only. Dart-path failures are a service-internal ladder matter
/// reported via the health snapshot, not a selection input.
VisionEngineId selectEngine({
  required EngineClassification health,
  required bool nativeAvailable,
  required bool nativeFailed,
  required bool fallbackModelPresent,
  VisionEngineId? manualOverride,
}) {
  if (manualOverride != null) return manualOverride;
  if (health == EngineClassification.unavailable) {
    return VisionEngineId.cameraOnly;
  }
  if (nativeAvailable && !nativeFailed) return VisionEngineId.nativeMlKit;
  if (fallbackModelPresent) return VisionEngineId.bundledFallback;
  return VisionEngineId.dartMlKit;
}

/// Device vision profile (§11): technical compatibility facts only.
/// No identity, no advertising use. Serializes into the error export.
class DeviceVisionProfile {
  final int androidApi;
  final String manufacturer;
  final String model;
  final bool frontCamera;
  final bool rearCamera;
  final List<int> sensorOrientations;
  final bool cameraAnalysis;
  final bool mlKit;
  final bool bundledModel;
  final bool fallbackModel;
  final String selectedEngine;
  final String? maxReliableResolution;
  final bool tested;
  const DeviceVisionProfile({
    this.androidApi = 0,
    this.manufacturer = '',
    this.model = '',
    this.frontCamera = false,
    this.rearCamera = false,
    this.sensorOrientations = const [],
    this.cameraAnalysis = false,
    this.mlKit = false,
    this.bundledModel = false,
    this.fallbackModel = false,
    this.selectedEngine = 'cameraOnly',
    this.maxReliableResolution,
    this.tested = false,
  });

  Map<String, Object?> toJson() => {
        'androidApi': androidApi,
        'manufacturer': manufacturer,
        'model': model,
        'frontCamera': frontCamera,
        'rearCamera': rearCamera,
        'sensorOrientations': sensorOrientations,
        'cameraAnalysis': cameraAnalysis,
        'mlKit': mlKit,
        'bundledModel': bundledModel,
        'fallbackModel': fallbackModel,
        'selectedEngine': selectedEngine,
        'maxReliableResolution': maxReliableResolution,
        'tested': tested,
      };
}
