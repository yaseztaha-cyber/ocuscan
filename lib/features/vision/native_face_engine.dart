// Native CameraX vision engine client — Dart side of the universal
// native pipeline (§2/§3: `ocuscan.vision/commands` + `ocuscan.vision/events`).
//
// All native calls are MissingPlugin-safe (dev routes, desktop tests)
// and every failure degrades to ENGINE_UNAVAILABLE — never a crash,
// never silence. Results carry the native session generation; stale
// generations are discarded before they reach the listener.

import 'dart:async';

import 'package:flutter/services.dart';

import '../camera/eye_tracking.dart' show EyePoint;
import 'face_detection_engine.dart';

/// Session info returned by a native start().
class NativeVisionSession {
  final int textureId;
  final int generation;
  final String lensFacing;
  final int sensorRotationDegrees;
  const NativeVisionSession({
    required this.textureId,
    required this.generation,
    required this.lensFacing,
    required this.sensorRotationDegrees,
  });
}

/// Map a native error class string to [MlErrorClass]. Unknown classes
/// are processing errors — never no-face.
MlErrorClass nativeErrorClassOf(String? clazz) {
  switch (clazz) {
    case 'INVALID_FRAME':
      return MlErrorClass.invalidFrame;
    case 'ENGINE_UNAVAILABLE':
      return MlErrorClass.engineUnavailable;
    case 'CAMERA_ERROR':
      return MlErrorClass.cameraError;
    case 'MODEL_UNAVAILABLE':
      return MlErrorClass.modelUnavailable;
    case 'PERMISSION_DENIED':
      return MlErrorClass.permissionDenied;
    case 'NO_FACE':
      return MlErrorClass.noFace;
    default:
      return MlErrorClass.processingError;
  }
}

/// Build an observation from a native event map. Pure function —
/// unit-tested (box mapping, error classification, generation check).
FaceObservation? nativeObservationFromMap(
  Map<String, Object?> m, {
  required String engineId,
  required int currentGeneration,
}) {
  final gen = (m['generation'] as num?)?.toInt() ?? -1;
  if (gen != currentGeneration) return null; // stale session
  if (m['type'] == 'error') {
    return FaceObservation.error(
      error: nativeErrorClassOf(m['class'] as String?),
      engineId: engineId,
      generation: gen,
      imageWidth: (m['imageWidth'] as num?)?.toInt() ?? 0,
      imageHeight: (m['imageHeight'] as num?)?.toInt() ?? 0,
    );
  }
  if (m['type'] != 'observation') return null;
  final w = (m['imageWidth'] as num?)?.toInt() ?? 0;
  final h = (m['imageHeight'] as num?)?.toInt() ?? 0;
  if (w <= 0 || h <= 0) return null;
  Rect? boxOf(Map<String, Object?>? b) {
    if (b == null) return null;
    double n(Object? v, int max) =>
        ((v as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    return Rect.fromLTRB(
        n(b['l'], 1), n(b['t'], 1), n(b['r'], 1), n(b['b'], 1));
  }

  EyePoint? ptOf(Map<String, Object?>? p) {
    if (p == null) return null;
    return EyePoint(
      ((p['x'] as num?)?.toDouble() ?? -1),
      ((p['y'] as num?)?.toDouble() ?? -1),
    );
  }

  Map<String, Object?>? sub(Object? v) =>
      v is Map ? Map<String, Object?>.from(v) : null;
  return FaceObservation(
    faceFound: (m['faceFound'] as bool?) ?? false,
    faceBox: boxOf(sub(m['box'])),
    leftEye: ptOf(sub(m['leftEye'])),
    rightEye: ptOf(sub(m['rightEye'])),
    yawDeg: (m['yawDeg'] as num?)?.toDouble() ?? 0,
    rollDeg: (m['rollDeg'] as num?)?.toDouble() ?? 0,
    leftOpenProb: (m['leftOpenProb'] as num?)?.toDouble() ?? -1,
    rightOpenProb: (m['rightOpenProb'] as num?)?.toDouble() ?? -1,
    faceCount: (m['faceCount'] as num?)?.toInt() ?? 0,
    imageWidth: w,
    imageHeight: h,
    rotationDeg: (m['rotationDegrees'] as num?)?.toInt() ?? 0,
    mirrored: (m['mirrored'] as bool?) ?? false,
    meanLuminance: (m['meanLuminance'] as num?)?.toDouble() ?? 120,
    blurVariance: (m['blurVariance'] as num?)?.toDouble() ?? 100,
    engineId: engineId,
    generation: gen,
    latencyMs: (m['latencyMs'] as num?)?.toDouble() ?? 0,
  );
}

class NativeFaceEngine implements FaceDetectionEngine {
  static const MethodChannel _commands =
      MethodChannel('ocuscan.vision/commands');
  static const EventChannel _events =
      EventChannel('ocuscan.vision/events');

  @override
  String get engineId => 'native-mlkit';

  bool _running = false;
  int _generation = 0;
  NativeVisionSession? _session;
  StreamSubscription<dynamic>? _sub;
  final StreamController<FaceObservation> _controller =
      StreamController<FaceObservation>.broadcast();

  @override
  bool get running => _running;

  @override
  int get generation => _generation;

  @override
  Stream<FaceObservation> get observations => _controller.stream;

  NativeVisionSession? get session => _session;

  /// Native camera inventory (lens facings, counts). Missing plugin
  /// (tests/desktop) reports unavailable instead of throwing.
  Future<Map<String, Object?>> capabilities() async {
    try {
      final res = await _commands.invokeMethod<Map<Object?, Object?>>(
          'capabilities');
      if (res == null) return {'available': false};
      return {
        'available': true,
        ...Map<String, Object?>.from(res),
      };
    } catch (_) {
      return {'available': false};
    }
  }

  @override
  Future<void> start({required bool front}) async {
    await startWithResult(front: front);
  }

  /// Start and return the session facts (texture id for the Dart
  /// Texture widget, generation token, sensor metadata).
  Future<NativeVisionSession> startWithResult(
      {required bool front}) async {
    final res = await _commands.invokeMethod<Map<Object?, Object?>>(
        'start', {'front': front});
    if (res == null) {
      throw StateError('native start returned nothing');
    }
    final m = Map<String, Object?>.from(res);
    final session = NativeVisionSession(
      textureId: (m['textureId'] as num).toInt(),
      generation: (m['generation'] as num).toInt(),
      lensFacing: (m['lensFacing'] as String?) ?? (front ? 'front' : 'rear'),
      sensorRotationDegrees:
          (m['sensorRotationDegrees'] as num?)?.toInt() ?? 0,
    );
    _session = session;
    _generation = session.generation;
    _running = true;
    await _sub?.cancel();
    _sub = _events.receiveBroadcastStream().listen(_onEvent,
        onError: (_) {}, onDone: () {});
    return session;
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final obs = nativeObservationFromMap(Map<String, Object?>.from(event),
        engineId: engineId, currentGeneration: _generation);
    if (obs != null && !_controller.isClosed) _controller.add(obs);
  }

  @override
  Future<void> stop() async {
    final gen = _generation;
    _running = false;
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    _session = null;
    try {
      await _commands.invokeMethod('stop', {'generation': gen});
    } catch (_) {
      // Stopped or never started: already in the desired state.
    }
  }

  /// Native health counters (analyzed/dropped/invalid, detector state).
  Future<Map<String, Object?>> health() async {
    try {
      final res =
          await _commands.invokeMethod<Map<Object?, Object?>>('health');
      if (res == null) return {'running': false};
      return Map<String, Object?>.from(res);
    } catch (_) {
      return {'running': false, 'error': 'unavailable'};
    }
  }
}
