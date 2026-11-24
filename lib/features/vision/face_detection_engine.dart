// Face-detection engine abstraction (universal compatibility milestone,
// §25 migration interface).
//
// The rest of the app consumes [FaceObservation] and never cares whether
// the result came from ML Kit (Dart path), the native CameraX engine, a
// bundled fallback model, or future hardware. Face observations are
// infrastructure (localization/tracking) — never diagnoses.

import 'dart:async';
import 'dart:ui' show Rect;

import '../camera/eye_tracking.dart' show EyePoint;

/// ML/camera failure classification (Phase 16). A failed detector call
/// is NEVER reported as "no face": [noFace] requires a clean call that
/// returned zero faces.
enum MlErrorClass {
  noFace,
  processingError,
  engineUnavailable,
  cameraError,
  invalidFrame,
  modelUnavailable,
  permissionDenied,
}

/// One face-detection observation in IMAGE space (sensor-order pixels,
// normalized 0..1). The consumer maps to preview space with rotation +
/// mirror metadata via EyeCoords — mirroring stays a presentation
/// property and never swaps anatomical identity.
class FaceObservation {
  final bool faceFound;
  final Rect? faceBox;
  final EyePoint? leftEye;
  final EyePoint? rightEye;
  final double yawDeg;
  final double rollDeg;
  final double leftOpenProb;
  final double rightOpenProb;
  final int faceCount;
  final int imageWidth;
  final int imageHeight;
  final int rotationDeg;
  final bool mirrored;
  final double meanLuminance;
  /// Laplacian-variance sharpness on a coarse grid (same scale as the
  /// Dart sampler, so tracker thresholds mean the same on every path).
  /// 100 = neutral non-gating sentinel (unknown), never a measurement.
  final double blurVariance;
  final String engineId;
  final int generation;
  final double latencyMs;
  final DateTime time;
  final MlErrorClass? error;

  FaceObservation({
    required this.faceFound,
    this.faceBox,
    this.leftEye,
    this.rightEye,
    this.yawDeg = 0,
    this.rollDeg = 0,
    this.leftOpenProb = -1,
    this.rightOpenProb = -1,
    this.faceCount = 0,
    required this.imageWidth,
    required this.imageHeight,
    required this.rotationDeg,
    required this.mirrored,
    required this.meanLuminance,
    this.blurVariance = 100,
    required this.engineId,
    required this.generation,
    this.latencyMs = 0,
    DateTime? time,
    this.error,
  }) : time = time ?? DateTime.now();

  /// Error observation: no geometry, explicit classification.
  FaceObservation.error({
    required MlErrorClass this.error,
    required this.engineId,
    required this.generation,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.rotationDeg = 0,
    this.mirrored = false,
    this.meanLuminance = 120,
    this.blurVariance = 100,
    this.latencyMs = 0,
    DateTime? time,
  })  : faceFound = false,
        faceBox = null,
        leftEye = null,
        rightEye = null,
        yawDeg = 0,
        rollDeg = 0,
        leftOpenProb = -1,
        rightOpenProb = -1,
        faceCount = 0,
        time = time ?? DateTime.now();
}

/// Bundled face-detection model identity (§6/§9: explicit model version).
/// The hash is EMPTY (unknown): ML Kit does not publish a retrievable
/// model digest, and inventing one would corrupt traceability. Empty
/// means "not recorded", never a placeholder hash.
const String kFaceDetectionModelVersion =
    'com.google.mlkit:face-detection:16.1.7 (bundled)';
const String kFaceDetectionModelHash = '';

/// Validated face-result status (§14). Only validated fields cross
/// this boundary: a thrown call is PROCESSING_ERROR, never "no face";
/// confidence is NOT invented (the engine provides none, so none is
/// reported — asymmetry/quality numbers live in analyzers, not here).
enum VisionFaceStatus {
  faceFound,
  noFace,
  processingError,
  engineUnavailable,
  invalidFrame,
  /// Harness-level only (never a detector verdict): preconditions unmet
  /// (camera idle, asset unreadable), so the detector never ran. Mirrors
  /// the long-standing MlDiagOutcome.skipped precedent.
  skipped,
}

/// Map one observation to its validated status. Clean call + zero
/// faces = noFace; anything thrown or classified is never noFace.
VisionFaceStatus visionFaceStatus(FaceObservation o) {
  final e = o.error;
  if (e == null) return o.faceFound ? VisionFaceStatus.faceFound : VisionFaceStatus.noFace;
  switch (e) {
    case MlErrorClass.noFace:
      // Defensive: an error observation should never carry noFace.
      return VisionFaceStatus.noFace;
    case MlErrorClass.engineUnavailable:
      return VisionFaceStatus.engineUnavailable;
    case MlErrorClass.invalidFrame:
      return VisionFaceStatus.invalidFrame;
    default:
      // processingError, cameraError, modelUnavailable,
      // permissionDenied: the engine failed, it did not find nothing.
      return VisionFaceStatus.processingError;
  }
}

/// Engine contract. Exactly one inference in flight per engine; results
/// carry the session generation so stale callbacks are discarded.
abstract class FaceDetectionEngine {
  /// Stable id: 'dart-mlkit' | 'native-mlkit' | 'bundled-fallback'.
  String get engineId;
  bool get running;
  int get generation;
  Stream<FaceObservation> get observations;
  Future<void> start({required bool front});
  Future<void> stop();
}
