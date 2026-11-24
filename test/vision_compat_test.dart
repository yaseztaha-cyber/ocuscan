// Universal compatibility architecture tests: engine selection,
// capability states, frame-facts validation, observation model.
// Pure Dart, no plugins, no camera.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/camera/frame_validator.dart';
import 'package:ocuscan/features/vision/face_detection_engine.dart';
import 'package:ocuscan/features/vision/native_face_engine.dart';
import 'package:ocuscan/features/vision/vision_engine_manager.dart';

FrameFacts _nv21({int w = 640, int h = 480, int rot = 0}) => FrameFacts(
      width: w,
      height: h,
      planeCount: 2,
      planeLengths: [w * h, w * h ~/ 2],
      rowStrides: [w, w],
      rotationDeg: rot,
      timestampMs: 123,
    );

void main() {
  group('classifyEngineHealth', () {
    test('analyzed frames mean ready', () {
      expect(
          classifyEngineHealth(
              const VisionHealthSnapshot(framesProcessed: 5)),
          EngineClassification.ready);
    });
    test('no camera means unavailable, never degraded', () {
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(cameraUp: false)),
          EngineClassification.unavailable);
    });
    test('persistent failure with camera up is degraded', () {
      expect(
          classifyEngineHealth(
              const VisionHealthSnapshot(converterFailing: true)),
          EngineClassification.degraded);
      expect(
          classifyEngineHealth(
              const VisionHealthSnapshot(detectorFailing: true)),
          EngineClassification.degraded);
      expect(
          classifyEngineHealth(
              const VisionHealthSnapshot(nativeEngineFailed: true)),
          EngineClassification.degraded);
    });
    test('clean idle is ready (nothing proven wrong)', () {
      expect(classifyEngineHealth(const VisionHealthSnapshot()),
          EngineClassification.ready);
    });
  });

  group('capabilityStates', () {
    test('no cameras anywhere -> camera unsupported', () {
      final c = capabilityStates(const VisionHealthSnapshot(),
          hasFrontCamera: false, hasRearCamera: false);
      expect(c['camera'], CapabilityState.unsupported);
      expect(c['frontCamera'], CapabilityState.unsupported);
    });
    test('front-only device is honest about rear', () {
      final c = capabilityStates(const VisionHealthSnapshot(),
          hasFrontCamera: true, hasRearCamera: false);
      expect(c['camera'], CapabilityState.supported);
      expect(c['frontCamera'], CapabilityState.supported);
      expect(c['rearCamera'], CapabilityState.unsupported);
    });
    test('failing ML degrades capability, missing model is unsupported',
        () {
      final c = capabilityStates(
          const VisionHealthSnapshot(detectorFailing: true),
          hasFrontCamera: true,
          hasRearCamera: true);
      expect(c['nativeMlKit'], CapabilityState.unsupported);
      expect(c['bundledModel'], CapabilityState.unsupported);
      expect(c['fallbackEngine'], CapabilityState.unsupported);
      final limited = capabilityStates(
          const VisionHealthSnapshot(converterFailing: true),
          hasFrontCamera: true,
          hasRearCamera: true);
      expect(limited['nativeMlKit'], CapabilityState.limited);
    });
  });

  group('selectEngine', () {
    test('manual override always wins', () {
      expect(
          selectEngine(
              health: EngineClassification.ready,
              nativeAvailable: true,
              nativeFailed: false,
              fallbackModelPresent: false,
              manualOverride: VisionEngineId.cameraOnly),
          VisionEngineId.cameraOnly);
    });
    test('no camera -> cameraOnly', () {
      expect(
          selectEngine(
              health: EngineClassification.unavailable,
              nativeAvailable: true,
              nativeFailed: false,
              fallbackModelPresent: true),
          VisionEngineId.cameraOnly);
    });
    test('proven native wins when healthy', () {
      expect(
          selectEngine(
              health: EngineClassification.ready,
              nativeAvailable: true,
              nativeFailed: false,
              fallbackModelPresent: false),
          VisionEngineId.nativeMlKit);
    });
    test('unproven or failed native falls back to proven Dart path', () {
      expect(
          selectEngine(
              health: EngineClassification.degraded,
              nativeAvailable: false,
              nativeFailed: false,
              fallbackModelPresent: false),
          VisionEngineId.dartMlKit);
      expect(
          selectEngine(
              health: EngineClassification.degraded,
              nativeAvailable: true,
              nativeFailed: true,
              fallbackModelPresent: false),
          VisionEngineId.dartMlKit);
    });
    test('present fallback model outranks camera-only', () {
      expect(
          selectEngine(
              health: EngineClassification.degraded,
              nativeAvailable: false,
              nativeFailed: false,
              fallbackModelPresent: true),
          VisionEngineId.bundledFallback);
    });
  });

  group('detectorDown classifies unavailable (not degraded)', () {
    test('down detector + camera up is unavailable', () {
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(
              framesProcessed: 0,
              detectorFailing: true,
              detectorDown: true,
              cameraUp: true)),
          EngineClassification.unavailable);
    });
    test('failing-but-not-down stays degraded', () {
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(
              framesProcessed: 0,
              detectorFailing: true,
              cameraUp: true)),
          EngineClassification.degraded);
    });
    test('down flag wins over stale processed frames', () {
      // MlHealth.down requires zero processed frames, so this input is
      // impossible live; precedence pinned: a dead detector is
      // unavailable even if an old counter disagrees.
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(
              framesProcessed: 3, detectorDown: true, cameraUp: true)),
          EngineClassification.unavailable);
    });
    test('starved pipe (0.7.14 session: 95/622) is degraded, not ready',
        () {
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(
              framesProcessed: 95, framesReceived: 622, cameraUp: true)),
          EngineClassification.degraded);
    });
    test('slow pipe (mean 275ms) is degraded, not ready', () {
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(
              framesProcessed: 95,
              framesReceived: 622,
              meanLatencyMs: 275,
              cameraUp: true)),
          EngineClassification.degraded);
    });
    test('healthy pipe (0.7.13 session: 83/217, ~110ms) stays ready', () {
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(
              framesProcessed: 83,
              framesReceived: 217,
              meanLatencyMs: 110,
              cameraUp: true)),
          EngineClassification.ready);
    });
    test('small windows never trigger throughput rules', () {
      // Below the arrival minimums: old behavior preserved.
      expect(
          classifyEngineHealth(const VisionHealthSnapshot(
              framesProcessed: 3, framesReceived: 10, cameraUp: true)),
          EngineClassification.ready);
    });
    test('unavailable selects cameraOnly', () {
      expect(
          selectEngine(
              health: EngineClassification.unavailable,
              nativeAvailable: true,
              nativeFailed: false,
              fallbackModelPresent: false),
          VisionEngineId.cameraOnly);
    });
  });

  group('validateFrameFacts liveness extensions', () {
    FrameFacts aged({required int ts, required int now}) => FrameFacts(
        width: 64,
        height: 48,
        planeCount: 1,
        planeLengths: const [3072],
        rowStrides: const [64],
        rotationDeg: 0,
        timestampMs: ts);
    test('stale frames rejected only with an explicit nowMs', () {
      // No nowMs: no age opinion (backward compatible).
      expect(validateFrameFacts(aged(ts: 0, now: 0)),
          FrameValidity.valid);
      expect(
          validateFrameFacts(aged(ts: 1000, now: 9000), nowMs: 9000),
          const FrameValidity(false, 'stale-frame'));
      expect(
          validateFrameFacts(aged(ts: 1000, now: 5999),
              nowMs: 5999, maxAgeMs: 5000),
          FrameValidity.valid);
    });
    test('future timestamps pass (clock skew is not failure)', () {
      expect(validateFrameFacts(aged(ts: 9000, now: 1000), nowMs: 1000),
          FrameValidity.valid);
    });
    test('impossible buffer lengths rejected format-agnostically', () {
      FrameFacts sized(int total) => FrameFacts(
          width: 64,
          height: 48,
          planeCount: 1,
          planeLengths: const [3072],
          rowStrides: const [64],
          rotationDeg: 0,
          timestampMs: 1,
          totalBytes: total);
      // 64*48 = 3072: below luma-only and above BGRA both impossible.
      expect(validateFrameFacts(sized(1000)),
          const FrameValidity(false, 'impossible-length'));
      expect(validateFrameFacts(sized(3072 * 4 + 1)),
          const FrameValidity(false, 'impossible-length'));
      expect(validateFrameFacts(sized(3072)), FrameValidity.valid);
      expect(
          validateFrameFacts(sized(3072 + 1536)), FrameValidity.valid);
      expect(validateFrameFacts(sized(3072 * 4)), FrameValidity.valid);
    });
    test('unknown length skips the check', () {
      expect(
          validateFrameFacts(FrameFacts(
              width: 64,
              height: 48,
              planeCount: 1,
              planeLengths: const [3072],
              rowStrides: const [64],
              rotationDeg: 0,
              timestampMs: 1)),
          FrameValidity.valid);
    });
  });

  group('DeviceVisionProfile serializes technical facts only', () {
    test('toJson round-trips capability fields', () {
      const p = DeviceVisionProfile(
        androidApi: 31,
        manufacturer: 'OPPO',
        model: 'CPH2121',
        frontCamera: true,
        rearCamera: true,
        sensorOrientations: [270, 90],
        selectedEngine: 'dartMlKit',
        tested: true,
      );
      final j = p.toJson();
      expect(j['androidApi'], 31);
      expect(j['model'], 'CPH2121');
      expect(j['selectedEngine'], 'dartMlKit');
      expect((j['sensorOrientations'] as List).length, 2);
      expect(j.containsKey('identity'), false);
    });
  });

  group('validateFrameFacts contract', () {
    test('valid NV21 / all rotations pass', () {
      for (final r in [0, 90, 180, 270, -90, 360]) {
        expect(validateFrameFacts(_nv21(rot: r)), FrameValidity.valid,
            reason: 'rot=$r');
      }
    });
    test('bad dimensions rejected', () {
      expect(
          validateFrameFacts(_nv21(w: 0)),
          const FrameValidity(false, 'bad-dimensions'));
      expect(
          validateFrameFacts(_nv21(w: -4)),
          const FrameValidity(false, 'bad-dimensions'));
    });
    test('absurd size refused before allocation', () {
      expect(
          validateFrameFacts(_nv21(w: 1 << 20, h: 1 << 20)),
          const FrameValidity(false, 'frame-too-large'));
    });
    test('plane count 0 and 5 rejected; metadata must match', () {
      FrameFacts withCount(int n, List<int> lens, List<int> strides) =>
          FrameFacts(
              width: 64,
              height: 48,
              planeCount: n,
              planeLengths: lens,
              rowStrides: strides,
              rotationDeg: 0,
              timestampMs: 1);
      expect(validateFrameFacts(withCount(0, [], [])),
          const FrameValidity(false, 'bad-plane-count'));
      expect(
          validateFrameFacts(
              withCount(5, [1, 1, 1, 1, 1], [1, 1, 1, 1, 1])),
          const FrameValidity(false, 'bad-plane-count'));
      expect(
          validateFrameFacts(withCount(2, [100], [64, 64])),
          const FrameValidity(false, 'plane-metadata-mismatch'));
      expect(
          validateFrameFacts(withCount(2, [100, 50], [64])),
          const FrameValidity(false, 'plane-metadata-mismatch'));
    });
    test('empty plane, bad stride, bad rotation, bad timestamp', () {
      FrameFacts base() => _nv21(w: 64, h: 48);
      FrameFacts withLens(List<int> lens) => FrameFacts(
          width: 64,
          height: 48,
          planeCount: 2,
          planeLengths: lens,
          rowStrides: [64, 64],
          rotationDeg: 0,
          timestampMs: 1);
      expect(validateFrameFacts(withLens([0, 100])),
          const FrameValidity(false, 'empty-plane'));
      FrameFacts withStrides(List<int> strides) => FrameFacts(
          width: 64,
          height: 48,
          planeCount: 2,
          planeLengths: [64 * 48, 64 * 48 ~/ 2],
          rowStrides: strides,
          rotationDeg: 0,
          timestampMs: 1);
      expect(validateFrameFacts(withStrides([0, 64])),
          const FrameValidity(false, 'bad-stride'));
      expect(validateFrameFacts(_nv21(w: 64, h: 48, rot: 45)),
          const FrameValidity(false, 'bad-rotation'));
      expect(
          validateFrameFacts(FrameFacts(
              width: 64,
              height: 48,
              planeCount: 2,
              planeLengths: [64 * 48, 64 * 48 ~/ 2],
              rowStrides: [64, 64],
              rotationDeg: 0,
              timestampMs: -1)),
          const FrameValidity(false, 'bad-timestamp'));
      expect(base(), isNotNull);
    });
  });

  group('FaceObservation error carries classification, never geometry', () {
    test('error observation has no face and explicit class', () {
      final o = FaceObservation.error(
        error: MlErrorClass.processingError,
        engineId: 'native-mlkit',
        generation: 7,
      );
      expect(o.faceFound, false);
      expect(o.faceBox, isNull);
      expect(o.error, MlErrorClass.processingError);
      expect(o.generation, 7);
    });
  });

  group('nativeObservationFromMap (stale + error discipline)', () {
    Map<String, Object?> obs({int gen = 5}) => {
          'type': 'observation',
          'generation': gen,
          'faceFound': true,
          'faceCount': 1,
          'box': {'l': 0.25, 't': 0.25, 'r': 0.75, 'b': 0.75},
          'leftEye': {'x': 0.4, 'y': 0.4},
          'rightEye': {'x': 0.6, 'y': 0.4},
          'yawDeg': 5.0,
          'imageWidth': 720,
          'imageHeight': 480,
          'rotationDegrees': 270,
          'mirrored': true,
          'meanLuminance': 140.0,
          'latencyMs': 42.0,
        };
    test('current generation maps geometry, stale returns null', () {
      final o = nativeObservationFromMap(obs(),
          engineId: 'native-mlkit', currentGeneration: 5);
      expect(o, isNotNull);
      expect(o!.faceFound, true);
      expect(o.faceBox!.left, closeTo(0.25, 1e-9));
      expect(o.leftEye!.x, closeTo(0.4, 1e-9));
      expect(o.rotationDeg, 270);
      expect(o.mirrored, true);
      expect(
          nativeObservationFromMap(obs(gen: 4),
              engineId: 'native-mlkit', currentGeneration: 5),
          isNull);
    });
    test('error events classify, never invent geometry', () {
      final o = nativeObservationFromMap(
          {
            'type': 'error',
            'generation': 5,
            'class': 'INVALID_FRAME',
          },
          engineId: 'native-mlkit',
          currentGeneration: 5);
      expect(o, isNotNull);
      expect(o!.faceFound, false);
      expect(o.error, MlErrorClass.invalidFrame);
      expect(
          nativeObservationFromMap(
              {
                'type': 'error',
                'generation': 5,
                'class': 'SOMETHING_NEW',
              },
              engineId: 'native-mlkit',
              currentGeneration: 5)!
              .error,
          MlErrorClass.processingError);
    });
    test('blurVariance rides the parser, neutral when absent', () {
      final withBlur = nativeObservationFromMap(
          {...obs(), 'blurVariance': 812.5},
          engineId: 'native-mlkit',
          currentGeneration: 5);
      expect(withBlur, isNotNull);
      expect(withBlur!.blurVariance, closeTo(812.5, 1e-9));
      final withoutBlur = nativeObservationFromMap(obs(),
          engineId: 'native-mlkit', currentGeneration: 5);
      expect(withoutBlur, isNotNull);
      // Neutral non-gating sentinel, exactly like unknown.
      expect(withoutBlur!.blurVariance, 100);
    });
    test('non-observation types and bad dims return null', () {
      expect(
          nativeObservationFromMap({'type': 'session', 'generation': 5},
              engineId: 'native-mlkit', currentGeneration: 5),
          isNull);
      expect(
          nativeObservationFromMap(
              {...obs(), 'imageWidth': 0},
              engineId: 'native-mlkit',
              currentGeneration: 5),
          isNull);
    });
  });
}
