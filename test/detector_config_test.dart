// ML detector-config parity: every detector in the app is built from
// the canonical liveDetectorOptions builder, and the builder's contracts
// are pinned here. FaceDetector constructs channel-free in tests (no
// processImage), so config drift — the v0.7.18 oracle-miss class — is
// caught without a device. A source grep below forbids bypassing the
// builder anywhere in lib/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:ocuscan/features/camera/camera_pipeline.dart';

void _checkFull(FaceDetectorOptions o) {
  expect(o.enableContours, false);
  expect(o.enableLandmarks, true);
  expect(o.enableClassification, true);
  expect(o.enableTracking, true);
  expect(o.performanceMode, FaceDetectorMode.accurate);
}

void main() {
  group('liveDetectorOptions contracts', () {
    test('full production config', () {
      _checkFull(liveDetectorOptions());
    });
    test('minimal fallback keeps landmarks, drops the rest', () {
      final o = liveDetectorOptions(minimal: true);
      expect(o.enableContours, false);
      expect(o.enableLandmarks, true);
      expect(o.enableClassification, false);
      expect(o.enableTracking, false);
      expect(o.performanceMode, FaceDetectorMode.fast);
    });
    test('fast experiment keeps classification, drops tracking', () {
      final o = liveDetectorOptions(fast: true);
      expect(o.enableContours, false);
      expect(o.enableLandmarks, true);
      expect(o.enableClassification, true);
      expect(o.enableTracking, false);
      expect(o.performanceMode, FaceDetectorMode.fast);
    });
    test('minimal wins over fast', () {
      final o = liveDetectorOptions(minimal: true, fast: true);
      expect(o.enableClassification, false);
      expect(o.enableTracking, false);
      expect(o.performanceMode, FaceDetectorMode.fast);
    });
  });

  group('detectors construct channel-free from the builder', () {
    test('full/minimal/fast all construct', () {
      final full =
          FaceDetector(options: liveDetectorOptions());
      final minimal =
          FaceDetector(options: liveDetectorOptions(minimal: true));
      final fast = FaceDetector(options: liveDetectorOptions(fast: true));
      _checkFull(full.options);
      expect(minimal.options.performanceMode, FaceDetectorMode.fast);
      expect(fast.options.enableClassification, true);
      expect(fast.options.enableTracking, false);
    });
  });

  group('no bypass of the canonical builder in lib/', () {
    test('FaceDetectorOptions( appears only in camera_pipeline.dart',
        () async {
      final offenders = <String>[];
      var scanned = 0;
      final root = Directory('lib');
      await for (final e in root.list(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        scanned++;
        final text = await e.readAsString();
        if (!text.contains('FaceDetectorOptions(')) continue;
        // The canonical builder definition itself.
        if (e.path.endsWith('camera_pipeline.dart')) continue;
        offenders.add(e.path);
      }
      expect(scanned, greaterThan(50),
          reason: 'scan found nothing — wrong working directory?');
      expect(offenders, isEmpty,
          reason: 'build via liveDetectorOptions instead: $offenders');
    });
  });
}
