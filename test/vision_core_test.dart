// Phase 1A vision-core tests: bundled real-face asset contract,
// VisionSession lifecycle rules, and validated result mapping.
// No camera, no plugins — pure file/model checks.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/vision/face_detection_engine.dart';
import 'package:ocuscan/features/vision/vision_session.dart';

/// JPEG dimensions via SOF0/SOF2 scan (no image dependency).
List<int>? _jpegDims(List<int> bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return null;
  }
  var i = 2;
  while (i + 8 < bytes.length) {
    if (bytes[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = bytes[i + 1];
    if (marker == 0xD8 ||
        marker == 0xD9 ||
        (marker >= 0xD0 && marker <= 0xD7) ||
        marker == 0x01) {
      i += 2;
      continue;
    }
    final len = (bytes[i + 2] << 8) | bytes[i + 3];
    if (marker == 0xC0 || marker == 0xC2) {
      final h = (bytes[i + 5] << 8) | bytes[i + 6];
      final w = (bytes[i + 7] << 8) | bytes[i + 8];
      return [w, h];
    }
    i += 2 + len;
  }
  return null;
}

FaceObservation _obs({bool found = false, MlErrorClass? error}) =>
    FaceObservation(
      faceFound: found,
      imageWidth: 512,
      imageHeight: 512,
      rotationDeg: 0,
      mirrored: false,
      meanLuminance: 120,
      engineId: 'test',
      generation: 1,
      error: error,
    );

void main() {
  group('bundled real-face asset (TEST A oracle)', () {
    test('exists, is JPEG, is 512x512', () {
      final f = File('assets/bundled_face.jpg');
      expect(f.existsSync(), true, reason: 'asset missing from repo');
      final bytes = f.readAsBytesSync();
      expect(bytes.sublist(0, 2), [0xFF, 0xD8]);
      expect(bytes.length, greaterThan(10000));
      expect(_jpegDims(bytes), [512, 512]);
    });
    test('synthetic oracle is gone', () {
      expect(File('assets/test_face.jpg').existsSync(), false);
      expect(File('tooling/gen_test_face.dart').existsSync(), false);
    });
  });

  group('VisionSession lifecycle (§10)', () {
    test('fresh session processes nothing until ready', () {
      const s = VisionSession(sessionId: 't');
      expect(s.canProcess, false);
      expect(s.detectorGeneration, 0);
      expect(s.ownsGeneration(0), true);
      expect(s.ownsGeneration(1), false);
    });
    test('ready camera + ready detector + idle allows one inference', () {
      // withCamera/withDetector return new instances; chain on result:
      final ready = const VisionSession(sessionId: 't')
          .withCamera(VisionCameraState.ready)
          .withDetector(VisionDetectorState.ready);
      expect(ready.canProcess, true);
      final busy = ready.markInference(true);
      expect(busy.canProcess, false);
      expect(busy.markInference(false).canProcess, true);
    });
    test('close and invalidate forbid processing (idempotent)', () {
      final ready = const VisionSession(sessionId: 't')
          .withCamera(VisionCameraState.ready)
          .withDetector(VisionDetectorState.ready);
      expect(ready.close().canProcess, false);
      expect(ready.close().close().canProcess, false);
      expect(ready.invalidate().canProcess, false);
    });
    test('nextGeneration bumps token and clears in-flight', () {
      final s = const VisionSession(sessionId: 't')
          .withCamera(VisionCameraState.ready)
          .withDetector(VisionDetectorState.ready)
          .markInference(true)
          .nextGeneration();
      expect(s.detectorGeneration, 1);
      expect(s.ownsGeneration(0), false);
      expect(s.ownsGeneration(1), true);
      expect(s.activeInference, false);
    });
    test('touchFrame stamps without unlocking processing', () {
      final at = DateTime.utc(2026, 1, 1);
      final s =
          const VisionSession(sessionId: 't').touchFrame(at);
      expect(s.lastFrameAt, at);
      expect(s.canProcess, false);
    });
  });

  group('visionFaceStatus (§14 validated contract)', () {
    test('clean call with faces / without faces', () {
      expect(visionFaceStatus(_obs(found: true)),
          VisionFaceStatus.faceFound);
      expect(
          visionFaceStatus(_obs()), VisionFaceStatus.noFace);
    });
    test('thrown calls are never noFace', () {
      expect(
          visionFaceStatus(
              _obs(error: MlErrorClass.processingError)),
          VisionFaceStatus.processingError);
      expect(
          visionFaceStatus(_obs(error: MlErrorClass.cameraError)),
          VisionFaceStatus.processingError);
      expect(
          visionFaceStatus(
              _obs(error: MlErrorClass.modelUnavailable)),
          VisionFaceStatus.processingError);
      expect(
          visionFaceStatus(_obs(error: MlErrorClass.permissionDenied)),
          VisionFaceStatus.processingError);
    });
    test('classified errors keep their status', () {
      expect(
          visionFaceStatus(
              _obs(error: MlErrorClass.engineUnavailable)),
          VisionFaceStatus.engineUnavailable);
      expect(
          visionFaceStatus(_obs(error: MlErrorClass.invalidFrame)),
          VisionFaceStatus.invalidFrame);
    });
  });
}
