// v0.3.2 eye-tracking core tests: coordinate transforms (portrait,
// landscape, mirrored, non-mirrored, resolutions), Y-plane sampling,
// tracker state machine (gates, loss budget, stability window), and
// analyzer-specific needs. No camera or plugins required.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/camera/eye_tracking.dart';

EyeGeometry _geo({
  bool face = true,
  Rect? box,
  EyePoint? l = const EyePoint(0.42, 0.38),
  EyePoint? r = const EyePoint(0.58, 0.38),
  bool noLeft = false,
  bool noRight = false,
  double yaw = 0,
  double roll = 0,
  double lOpen = 0.9,
  double rOpen = 0.9,
}) =>
    EyeGeometry(
      faceFound: face,
      faceBox: box ?? const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
      leftEye: noLeft ? null : l,
      rightEye: noRight ? null : r,
      yawDeg: yaw,
      rollDeg: roll,
      leftOpenProb: lOpen,
      rightOpenProb: rOpen,
      imageWidth: 720,
      imageHeight: 1280,
    );

const _goodQ = FrameQuality(
    meanLuminance: 120, blurVariance: 60, overexposedFraction: 0.02,
    width: 720, height: 1280);

void main() {
  group('mlKitRotationDeg', () {
    test('front portrait sensor270 -> 270', () {
      expect(
          EyeCoords.mlKitRotationDeg(
              sensorOrientationDeg: 270,
              deviceOrientationQuarterTurns: 0,
              frontCamera: true),
          270);
    });
    test('back portrait sensor90 -> 90', () {
      expect(
          EyeCoords.mlKitRotationDeg(
              sensorOrientationDeg: 90,
              deviceOrientationQuarterTurns: 0,
              frontCamera: false),
          90);
    });
    test('front landscape-left adds 90', () {
      expect(
          EyeCoords.mlKitRotationDeg(
              sensorOrientationDeg: 270,
              deviceOrientationQuarterTurns: 1,
              frontCamera: true),
          0);
    });
    test('back landscape-left subtracts 90', () {
      expect(
          EyeCoords.mlKitRotationDeg(
              sensorOrientationDeg: 90,
              deviceOrientationQuarterTurns: 1,
              frontCamera: false),
          0);
    });
    test('always a valid quarter turn', () {
      for (var s in [0, 90, 180, 270]) {
        for (var d = 0; d < 4; d++) {
          for (var f in [true, false]) {
            final r = EyeCoords.mlKitRotationDeg(
                sensorOrientationDeg: s,
                deviceOrientationQuarterTurns: d,
                frontCamera: f);
            expect([0, 90, 180, 270], contains(r));
          }
        }
      }
    });
  });

  group('imageToPreview portrait mirrored (front selfie)', () {
    // Raw sensor landscape 1280x720, rotation 270 -> upright 720x1280.
    const raw = Size(1280, 720);
    const preview = Size(400, 600);
    test('center maps to center', () {
      final p = EyeCoords.imageToPreview(
          raw: const Offset(0.5, 0.5), rawSize: raw, rotationDeg: 270,
          mirrored: true, previewSize: preview);
      expect(p.dx, closeTo(200, 1));
      expect(p.dy, closeTo(300, 1));
    });
    test('mirror flips horizontally around center', () {
      final a = EyeCoords.imageToPreview(
          raw: const Offset(0.25, 0.5), rawSize: raw, rotationDeg: 270,
          mirrored: true, previewSize: preview);
      final b = EyeCoords.imageToPreview(
          raw: const Offset(0.25, 0.5), rawSize: raw, rotationDeg: 270,
          mirrored: false, previewSize: preview);
      expect(a.dx + b.dx, closeTo(400, 1));
      expect(a.dy, closeTo(b.dy, 1));
    });
    test('subject left eye appears on viewer right (mirror-correct)', () {
      // Subject's left eye sits at raw x < 0.5 in this synthetic setup;
      // mirrored preview must show it right of center (like a mirror).
      final p = EyeCoords.imageToPreview(
          raw: const Offset(0.35, 0.4), rawSize: raw, rotationDeg: 270,
          mirrored: true, previewSize: preview);
      expect(p.dx > 200, true);
    });
    test('output stays inside widget for cover-fit crop', () {
      for (var x = 0.0; x <= 1.0; x += 0.1) {
        for (var y = 0.0; y <= 1.0; y += 0.1) {
          final p = EyeCoords.imageToPreview(
              raw: Offset(x, y), rawSize: raw, rotationDeg: 270,
              mirrored: true, previewSize: preview);
          expect(p.dx.isFinite && p.dy.isFinite, true);
        }
      }
    });
  });

  group('imageToPreview other orientations', () {
    test('rotation0 non-mirrored identity scaling', () {
      final p = EyeCoords.imageToPreview(
          raw: const Offset(0.25, 0.25), rawSize: const Size(640, 480),
          rotationDeg: 0, mirrored: false,
          previewSize: const Size(640, 480));
      expect(p.dx, closeTo(160, 1));
      expect(p.dy, closeTo(120, 1));
    });
    test('rotation180 flips both axes', () {
      final p = EyeCoords.imageToPreview(
          raw: const Offset(0.25, 0.25), rawSize: const Size(640, 480),
          rotationDeg: 180, mirrored: false,
          previewSize: const Size(640, 480));
      expect(p.dx, closeTo(480, 1));
      expect(p.dy, closeTo(360, 1));
    });
    test('rotation90 swaps dimensions sanely', () {
      final p = EyeCoords.imageToPreview(
          raw: const Offset(0.5, 0.5), rawSize: const Size(640, 480),
          rotationDeg: 90, mirrored: false,
          previewSize: const Size(480, 640));
      expect(p.dx, closeTo(240, 2));
      expect(p.dy, closeTo(320, 2));
    });
  });

  group('uprightAspect is exact (never clamped)', () {
    test('field case: 720x480 rot270 -> portrait 2/3', () {
      expect(EyeCoords.uprightAspect(const Size(720, 480), 270),
          closeTo(480 / 720, 1e-9));
    });
    test('landscape passthrough: 1280x720 rot0 stays 16/9', () {
      // The old 1.2 clamp narrowed this to 1.2 and misaligned every
      // overlay marker on wide (rear/landscape) frames.
      expect(EyeCoords.uprightAspect(const Size(1280, 720), 0),
          closeTo(16 / 9, 1e-9));
    });
    test('rot180 keeps orientation, negatives normalize', () {
      expect(EyeCoords.uprightAspect(const Size(640, 480), 180),
          closeTo(640 / 480, 1e-9));
      expect(EyeCoords.uprightAspect(const Size(640, 480), -90),
          closeTo(480 / 640, 1e-9));
    });
    test('degenerate sizes fall back to portrait 3/4', () {
      expect(EyeCoords.uprightAspect(const Size(0, 480), 0), 3 / 4);
      expect(
          EyeCoords.uprightAspect(const Size(640, 0), 90), 3 / 4);
    });
  });

  group('status value equality (truthful shouldRepaint)', () {
    EyeStatus ready(double x) => EyeStatus(
          state: DetectionState.ready,
          smoothLeft: EyePoint(x, 0.4),
          smoothRight: const EyePoint(0.6, 0.4),
          stableFrames: 3,
          locked: false,
          leftLocated: true,
          rightLocated: true,
          eyesOpen: true,
          faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
          yawDeg: 5,
          faceFraction: 0.4,
        );
    test('identical values are equal (no repaint)', () {
      expect(ready(0.4), ready(0.4));
      expect(ready(0.4).hashCode, ready(0.4).hashCode);
      expect(const EyePoint(0.1, 0.2), const EyePoint(0.1, 0.2));
    });
    test('any field change breaks equality (repaint)', () {
      final a = ready(0.4);
      expect(a == ready(0.41), false);
      expect(
          a ==
              EyeStatus(
                state: DetectionState.ready,
                smoothLeft: const EyePoint(0.4, 0.4),
                smoothRight: const EyePoint(0.6, 0.4),
                stableFrames: 4,
                locked: false,
                leftLocated: true,
                rightLocated: true,
                eyesOpen: true,
                faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
                yawDeg: 5,
                faceFraction: 0.4,
              ),
          false);
      expect(a == const EyeStatus(state: DetectionState.faceNotFound),
          false);
    });
  });

  group('eyeRegion', () {    test('centered box', () {
      final r = EyeCoords.eyeRegion(const EyePoint(0.5, 0.5), 0.2);
      expect(r.left, closeTo(0.4, 1e-9));
      expect(r.top, closeTo(0.4, 1e-9));
      expect(r.right, closeTo(0.6, 1e-9));
      expect(r.bottom, closeTo(0.6, 1e-9));
    });
    test('clamps at edges without inverting', () {
      final r = EyeCoords.eyeRegion(const EyePoint(0.02, 0.98), 0.2);
      expect(r.left, 0.0);
      expect(r.bottom, 1.0);
      expect(r.left <= r.right && r.top <= r.bottom, true);
    });
  });

  group('sampleYPlane', () {
    test('uniform mid-gray plane', () {
      final y = List<int>.filled(64 * 48, 120);
      final q = EyeCoords.sampleYPlane(y, 64, 48, 64);
      expect(q.meanLuminance, closeTo(120, 1));
      expect(q.overexposedFraction, 0);
      expect(q.blurVariance, closeTo(0, 1e-6));
    });
    test('dark plane reads dark', () {
      final y = List<int>.filled(64 * 48, 20);
      final q = EyeCoords.sampleYPlane(y, 64, 48, 64);
      expect(q.meanLuminance, lessThan(38));
    });
    test('sharp checkerboard has high blur variance', () {
      final y = List<int>.generate(
          64 * 48, (i) => ((i ~/ 8) % 2 == 0) ? 40 : 220);
      final q = EyeCoords.sampleYPlane(y, 64, 48, 64);
      expect(q.blurVariance, greaterThan(8));
    });
    test('handles row stride padding', () {
      final y = List<int>.filled(48 * 80, 150);
      final q = EyeCoords.sampleYPlane(y, 64, 48, 80);
      expect(q.meanLuminance, closeTo(150, 1));
    });
    test('empty input -> unknown, never throws', () {
      final q = EyeCoords.sampleYPlane([], 0, 0, 0);
      expect(q.meanLuminance, 120);
    });
  });

  group('EyeTracker state machine', () {
    test('no face -> faceNotFound and reset', () {
      final t = EyeTracker();
      final s = t.update(const EyeGeometry(faceFound: false), _goodQ);
      expect(s.state, DetectionState.faceNotFound);
      expect(s.smoothLeft, isNull);
      expect(s.locked, false);
    });
    test('ready path locks after stability window', () {
      final t = EyeTracker();
      EyeStatus? s;
      for (var i = 0; i < 5; i++) {
        s = t.update(_geo(), _goodQ);
      }
      expect(s!.state, DetectionState.ready);
      expect(s.locked, true);
      expect(s.stableFrames, 5);
      expect(s.smoothLeft, isNotNull);
      expect(s.eyesOpen, true);
    });
    test('not locked before window', () {
      final t = EyeTracker();
      final s = t.update(_geo(), _goodQ);
      expect(s.ready, true);
      expect(s.locked, false);
    });
    test('too small / too large / angled faces', () {
      final t = EyeTracker();
      expect(
          t
              .update(
                  _geo(box: const Rect.fromLTWH(0.4, 0.4, 0.2, 0.1)),
                  _goodQ)
              .state,
          DetectionState.faceTooSmall);
      expect(
          t
              .update(
                  _geo(box: const Rect.fromLTWH(0.0, 0.0, 1.0, 0.95)),
                  _goodQ)
              .state,
          DetectionState.faceTooLarge);
      expect(t.update(_geo(yaw: 40), _goodQ).state,
          DetectionState.faceAngleInvalid);
      expect(t.update(_geo(roll: -35), _goodQ).state,
          DetectionState.faceAngleInvalid);
    });
    test('dark / bright / blurry quality gates', () {
      final t = EyeTracker();
      expect(
          t
              .update(
                  _geo(),
                  const FrameQuality(
                      meanLuminance: 20, blurVariance: 60,
                      overexposedFraction: 0, width: 1, height: 1))
              .state,
          DetectionState.imageTooDark);
      expect(
          t
              .update(
                  _geo(),
                  const FrameQuality(
                      meanLuminance: 230, blurVariance: 60,
                      overexposedFraction: 0, width: 1, height: 1))
              .state,
          DetectionState.imageTooBright);
      expect(
          t
              .update(
                  _geo(),
                  const FrameQuality(
                      meanLuminance: 120, blurVariance: 2,
                      overexposedFraction: 0, width: 1, height: 1))
              .state,
          DetectionState.imageTooBlurry);
    });
    test('missing eyes with loss budget -> unstable keeps stale', () {
      final t = EyeTracker();
      for (var i = 0; i < 5; i++) {
        t.update(_geo(), _goodQ);
      }
      final s = t.update(_geo(noLeft: true, noRight: true), _goodQ);
      expect(s.state, DetectionState.trackingUnstable);
      expect(s.positionsStale, true);
      expect(s.smoothLeft, isNotNull);
      expect(s.locked, false);
    });
    test('loss beyond budget -> unavailable, no invented coords', () {
      final t = EyeTracker(
          config: const EyeTrackerConfig(maxLostFrames: 2));
      for (var i = 0; i < 5; i++) {
        t.update(_geo(), _goodQ);
      }
      t.update(_geo(noLeft: true, noRight: true), _goodQ);
      t.update(_geo(noLeft: true, noRight: true), _goodQ);
      final s = t.update(_geo(noLeft: true, noRight: true), _goodQ);
      expect(s.state, DetectionState.bothEyesUnavailable);
    });
    test('single missing eye names the side', () {
      final t = EyeTracker();
      expect(t.update(_geo(noLeft: true), _goodQ).state,
          DetectionState.leftEyeUnavailable);
      expect(t.update(_geo(noRight: true), _goodQ).state,
          DetectionState.rightEyeUnavailable);
    });
    test('closed eyes still ready-positioned but not open', () {
      final t = EyeTracker();
      EyeStatus? s;
      for (var i = 0; i < 5; i++) {
        s = t.update(_geo(lOpen: 0.1, rOpen: 0.1), _goodQ);
      }
      expect(s!.ready, true);
      expect(s.eyesOpen, false);
      expect(s.meetsNeed(AnalyzerNeed.blink, t.config), false);
    });
    test('smoothing converges toward observations', () {
      final t = EyeTracker();
      t.update(_geo(l: const EyePoint(0.4, 0.4)), _goodQ);
      final s = t.update(_geo(l: const EyePoint(0.6, 0.4)), _goodQ);
      expect(s.smoothLeft!.x, closeTo(0.5, 1e-9));
    });
    test('analyzer needs differ honestly', () {
      final t = EyeTracker();
      EyeStatus? s;
      for (var i = 0; i < 5; i++) {
        s = t.update(_geo(), _goodQ);
      }
      expect(s!.meetsNeed(AnalyzerNeed.facialAsymmetry, t.config), true);
      expect(s.meetsNeed(AnalyzerNeed.eyelid, t.config), true);
      expect(s.meetsNeed(AnalyzerNeed.pupilSymmetry, t.config), true);
      expect(
          s.meetsNeed(AnalyzerNeed.sharpStill, t.config,
              stillSharp: false),
          false);
      expect(
          s.meetsNeed(AnalyzerNeed.sharpStill, t.config, stillSharp: true),
          true);
    });
    test('unstable frame still meets face-level need', () {
      final t = EyeTracker();
      for (var i = 0; i < 5; i++) {
        t.update(_geo(), _goodQ);
      }
      final s = t.update(_geo(noLeft: true, noRight: true), _goodQ);
      expect(s.meetsNeed(AnalyzerNeed.facialAsymmetry, t.config), true);
      expect(s.meetsNeed(AnalyzerNeed.pupilSymmetry, t.config), false);
    });
    test('still-space geometry tracks like stream geometry', () {      // Snapshot stills report upright still-space boxes; the tracker
      // treats them identically (normalized space is space-agnostic).
      final t = EyeTracker();
      EyeStatus? s;
      for (var i = 0; i < 5; i++) {
        s = t.update(
            _geo(
              box: const Rect.fromLTWH(0.25, 0.1, 0.5, 0.6),
            ),
            _goodQ);
      }
      expect(s!.ready, true);
      expect(s.locked, true);
      expect(s.smoothLeft, isNotNull);
    });
    test('multiple faces refuse with named state, never measure', () {
      final t = EyeTracker();
      for (var i = 0; i < 5; i++) {
        t.update(_geo(), _goodQ);
      }
      final multi = EyeGeometry(
        faceFound: true,
        faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
        leftEye: const EyePoint(0.42, 0.38),
        rightEye: const EyePoint(0.58, 0.38),
        imageWidth: 720,
        imageHeight: 1280,
        faceCount: 2,
      );
      final s = t.update(multi, _goodQ);
      expect(s.state, DetectionState.multipleFaces);
      expect(s.locked, false);
      expect(
          s.meetsNeed(AnalyzerNeed.facialAsymmetry, t.config), false);
      expect(detectionStateKey(s.state), 'multipleFaces');
    });
  });

  group('pitchDeg plumbing (headEulerAngleX, NaN-safe)', () {
    EyeGeometry geoPitch(double pitch) => EyeGeometry(
          faceFound: true,
          faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
          leftEye: const EyePoint(0.42, 0.38),
          rightEye: const EyePoint(0.58, 0.38),
          yawDeg: 0,
          rollDeg: 0,
          pitchDeg: pitch,
          leftOpenProb: 0.9,
          rightOpenProb: 0.9,
          imageWidth: 720,
          imageHeight: 1280,
        );

    test('EyeGeometry defaults to pitch 0 and stays const-constructible', () {
      const legacy = EyeGeometry(faceFound: false);
      expect(legacy.pitchDeg, 0);
      expect(legacy.hasPitch, true);
      expect(legacy.safePitchDeg, 0);
      // Existing positional/named call sites keep working.
      expect(_geo().pitchDeg, 0);
    });

    test('NaN/infinite pitch is NaN-safe (collapses to 0 + invalid)', () {
      const nanGeo = EyeGeometry(faceFound: true, pitchDeg: double.nan);
      expect(nanGeo.hasPitch, false);
      expect(nanGeo.safePitchDeg, 0);
      const infGeo =
          EyeGeometry(faceFound: true, pitchDeg: double.infinity);
      expect(infGeo.hasPitch, false);
      expect(infGeo.safePitchDeg, 0);
      const finiteGeo = EyeGeometry(faceFound: true, pitchDeg: 12.5);
      expect(finiteGeo.hasPitch, true);
      expect(finiteGeo.safePitchDeg, 12.5);
    });

    test('tracker threads finite pitch into EyeStatus with pitchValid', () {
      final t = EyeTracker();
      final s = t.update(geoPitch(10), _goodQ);
      expect(s.pitchDeg, 10);
      expect(s.pitchValid, true);
      expect(t.pitchValid, true);
      expect(t.lastPitchDeg, 10);
    });

    test('tracker maps NaN pitch to 0 + invalid without crashing', () {
      final t = EyeTracker();
      final s = t.update(geoPitch(double.nan), _goodQ);
      expect(s.pitchDeg, 0);
      expect(s.pitchValid, false);
      expect(t.pitchValid, false);
      expect(t.lastPitchDeg, 0);
      // NaN pitch never blocks positioning itself.
      expect(s.state, DetectionState.ready);
    });

    test('missing frames hold pitch inside budget, reset past it', () {
      final t = EyeTracker();
      t.update(geoPitch(10), _goodQ);
      expect(t.pitchValid, true);
      // Inside the loss budget: held (M6), not cleared.
      t.update(const EyeGeometry(faceFound: false), _goodQ);
      expect(t.pitchValid, true);
      expect(t.lastPitchDeg, 10);
      // Past the budget: reset clears pitch validity.
      for (var i = 0; i < 6; i++) {
        t.update(const EyeGeometry(faceFound: false), _goodQ);
      }
      expect(t.pitchValid, false);
      expect(t.lastPitchDeg, 0);
    });

    test('EyeStatus equality/hash include pitchDeg + pitchValid', () {
      const a = EyeStatus(
        state: DetectionState.ready,
        leftLocated: true,
        rightLocated: true,
        pitchDeg: 10,
        pitchValid: true,
      );
      const b = EyeStatus(
        state: DetectionState.ready,
        leftLocated: true,
        rightLocated: true,
        pitchDeg: 10,
        pitchValid: true,
      );
      const c = EyeStatus(
        state: DetectionState.ready,
        leftLocated: true,
        rightLocated: true,
        pitchDeg: 11,
        pitchValid: true,
      );
      const d = EyeStatus(
        state: DetectionState.ready,
        leftLocated: true,
        rightLocated: true,
        pitchDeg: 10,
        pitchValid: false,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, false);
      expect(a == d, false);
      // Legacy default (unknown pitch) stays constructible.
      const legacy = EyeStatus(state: DetectionState.faceNotFound);
      expect(legacy.pitchDeg, 0);
      expect(legacy.pitchValid, false);
    });
  });

  group('eyelid pitchGate in meetsNeed', () {
    EyeStatus located({required double pitch, required bool valid}) =>
        EyeStatus(
          state: DetectionState.ready,
          smoothLeft: const EyePoint(0.42, 0.38),
          smoothRight: const EyePoint(0.58, 0.38),
          leftLocated: true,
          rightLocated: true,
          eyesOpen: true,
          faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
          yawDeg: 0,
          faceFraction: 0.4,
          pitchDeg: pitch,
          pitchValid: valid,
        );

    test('unknown pitch falls back to legacy eyes-located behavior', () {
      const cfg = EyeTrackerConfig();
      // Even a large stored pitch is ignored when invalid (unknown).
      expect(
          located(pitch: 45, valid: false)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          true);
      expect(
          located(pitch: 0, valid: false)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          true);
    });

    test('unlocated eyes never meet eyelid need, even without pitch', () {
      const cfg = EyeTrackerConfig();
      const s = EyeStatus(
        state: DetectionState.trackingUnstable,
        leftLocated: false,
        rightLocated: false,
        pitchDeg: 0,
        pitchValid: false,
      );
      expect(s.meetsNeed(AnalyzerNeed.eyelid, cfg), false);
    });

    test('frontal pitch passes, tilted pitch fails (boundary 20)', () {
      const cfg = EyeTrackerConfig();
      expect(
          located(pitch: 0, valid: true)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          true);
      expect(
          located(pitch: 20, valid: true)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          true);
      expect(
          located(pitch: -20, valid: true)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          true);
      expect(
          located(pitch: 20.1, valid: true)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          false);
      expect(
          located(pitch: 25, valid: true)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          false);
      expect(
          located(pitch: -25, valid: true)
              .meetsNeed(AnalyzerNeed.eyelid, cfg),
          false);
    });

    test('tracker integration: tilted frame fails eyelid need', () {
      EyeGeometry geoPitch(double pitch) => EyeGeometry(
            faceFound: true,
            faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
            leftEye: const EyePoint(0.42, 0.38),
            rightEye: const EyePoint(0.58, 0.38),
            pitchDeg: pitch,
            leftOpenProb: 0.9,
            rightOpenProb: 0.9,
            imageWidth: 720,
            imageHeight: 1280,
          );
      final t = EyeTracker();
      final frontal = t.update(geoPitch(10), _goodQ);
      expect(
          frontal.meetsNeed(AnalyzerNeed.eyelid, t.config), true);
      final tilted = t.update(geoPitch(25), _goodQ);
      expect(tilted.pitchValid, true);
      expect(
          tilted.meetsNeed(AnalyzerNeed.eyelid, t.config), false);
      // Other needs are unaffected by the eyelid pitch gate.
      expect(
          tilted.meetsNeed(AnalyzerNeed.rednessPixels, t.config), true);
    });

    test('tracker integration: NaN pitch falls back to located=true', () {
      EyeGeometry geoPitch(double pitch) => EyeGeometry(
            faceFound: true,
            faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
            leftEye: const EyePoint(0.42, 0.38),
            rightEye: const EyePoint(0.58, 0.38),
            pitchDeg: pitch,
            leftOpenProb: 0.9,
            rightOpenProb: 0.9,
            imageWidth: 720,
            imageHeight: 1280,
          );
      final t = EyeTracker();
      final s = t.update(geoPitch(double.nan), _goodQ);
      expect(s.pitchValid, false);
      expect(s.meetsNeed(AnalyzerNeed.eyelid, t.config), true);
    });
  });

  group('M6 face-missing loss budget', () {
    EyeStatus lock(EyeTracker t) {
      var s = const EyeStatus(state: DetectionState.faceNotFound);
      for (var i = 0; i < 5; i++) {
        s = t.update(_geo(), _goodQ);
      }
      expect(s.locked, true);
      return s;
    }

    test('single dropped frame holds stale positions, keeps window', () {
      final t = EyeTracker();
      final locked = lock(t);
      final held = t.update(
          const EyeGeometry(faceFound: false), _goodQ);
      expect(held.state, DetectionState.trackingUnstable);
      expect(held.positionsStale, true);
      expect(held.locked, false);
      expect(held.smoothLeft, locked.smoothLeft);
      // Next fresh frame re-locks immediately (window preserved).
      final relocked = t.update(_geo(), _goodQ);
      expect(relocked.locked, true);
      expect(relocked.positionsStale, false);
    });

    test('null geometry holds the same way', () {
      final t = EyeTracker();
      lock(t);
      final held = t.update(null, _goodQ);
      expect(held.state, DetectionState.trackingUnstable);
      expect(held.positionsStale, true);
    });

    test('budget exhaustion resets to faceNotFound', () {
      final t = EyeTracker();
      lock(t);
      EyeStatus s = const EyeStatus(state: DetectionState.ready);
      for (var i = 0; i < 6; i++) {
        s = t.update(const EyeGeometry(faceFound: false), _goodQ);
      }
      expect(s.state, DetectionState.faceNotFound);
      expect(s.smoothLeft, isNull);
      // Full 5-frame window required again after reset.
      var r = t.update(_geo(), _goodQ);
      expect(r.locked, false);
    });
  });

  group('qualityVerdict mirrors the tracker gates', () {
    const c = EyeTrackerConfig();
    FrameQuality q(double lum, double blur, {double over = 0}) =>
        FrameQuality(meanLuminance: lum, blurVariance: blur, overexposedFraction: over, width: 240, height: 360);
    test('unknown before any real sample', () {
      expect(qualityVerdict(const FrameQuality.unknown(), c), 'unknown');
    });
    test('dark / bright / blurry / good', () {
      expect(qualityVerdict(q(20, 900), c), 'tooDark');
      expect(qualityVerdict(q(230, 900), c), 'tooBright');
      expect(qualityVerdict(q(150, 900, over: 0.5), c), 'tooBright');
      expect(qualityVerdict(q(150, 3), c), 'tooBlurry');
      expect(qualityVerdict(q(197, 900), c), 'good');
    });
    test('dark wins over blur (gate order)', () {
      expect(qualityVerdict(q(20, 1), c), 'tooDark');
    });
  });

  group('uprightNormToSensorNorm (pre-rotated rung fold-back)', () {
    // Forward maps (sensor -> upright), the exact inverse of the rung
    // pre-rotation; the fix must invert each one precisely.
    EyePoint fwd(EyePoint p, int rot) {
      switch (rot) {
        case 90:
          return EyePoint(1 - p.y, p.x);
        case 180:
          return EyePoint(1 - p.x, 1 - p.y);
        case 270:
          return EyePoint(p.y, 1 - p.x);
        default:
          return p;
      }
    }

    test('rot 0 is identity', () {
      const p = EyePoint(0.3, 0.7);
      final q = EyeCoords.uprightNormToSensorNorm(p, 0);
      expect(q.x, p.x);
      expect(q.y, p.y);
    });
    test('known pair: upright (0.5, 0.4) rot270 -> sensor (0.6, 0.5)',
        () {
      final q = EyeCoords.uprightNormToSensorNorm(
          const EyePoint(0.5, 0.4), 270);
      expect(q.x, closeTo(0.6, 1e-9));
      expect(q.y, closeTo(0.5, 1e-9));
    });
    test('forward-then-back is identity on every rotation', () {
      const pts = [
        EyePoint(0.5, 0.4),
        EyePoint(0.1, 0.9),
        EyePoint(0.83, 0.07),
      ];
      for (final rot in [90, 180, 270]) {
        for (final p in pts) {
          final back = EyeCoords.uprightNormToSensorNorm(
              fwd(p, rot), rot);
          expect(back.x, closeTo(p.x, 1e-9));
          expect(back.y, closeTo(p.y, 1e-9));
        }
      }
    });
    test('centered face stays centered on every rotation', () {
      for (final rot in [0, 90, 180, 270]) {
        final q = EyeCoords.uprightNormToSensorNorm(
            const EyePoint(0.5, 0.5), rot);
        expect(q.x, closeTo(0.5, 1e-9));
        expect(q.y, closeTo(0.5, 1e-9));
      }
    });
    test('negative rotation normalizes (-90 == 270)', () {
      final a = EyeCoords.uprightNormToSensorNorm(
          const EyePoint(0.2, 0.8), -90);
      final b = EyeCoords.uprightNormToSensorNorm(
          const EyePoint(0.2, 0.8), 270);
      expect(a.x, closeTo(b.x, 1e-9));
      expect(a.y, closeTo(b.y, 1e-9));
    });
    test('box fold-back preserves area and stays in range', () {
      final box =
          const Rect.fromLTRB(0.3, 0.2, 0.7, 0.6);
      final folded =
          EyeCoords.uprightNormBoxToSensorNorm(box, 270);
      expect(folded.left, closeTo(0.4, 1e-9));
      expect(folded.top, closeTo(0.3, 1e-9));
      expect(folded.right, closeTo(0.8, 1e-9));
      expect(folded.bottom, closeTo(0.7, 1e-9));
      expect(folded.left >= 0 && folded.top >= 0, true);
      expect(folded.right <= 1 && folded.bottom <= 1, true);
    });
  });
}

