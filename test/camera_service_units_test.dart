// CameraService unit tests (no device, no plugin): fresh-instance
// defaults, fast-tier flag behavior, health snapshot pass-through,
// and diagnostic-export structure. Anything touching the controller,
// channels, or detectors stays in widget/device tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/camera/camera_pipeline.dart'
    show CameraStage;
import 'package:ocuscan/features/camera/camera_service.dart';
import 'package:ocuscan/features/vision/vision_engine_manager.dart';

void main() {
  group('fresh service defaults', () {
    test('readiness and counters start idle', () {
      final cam = CameraService();
      expect(cam.ready, false);
      expect(cam.framesReceived, 0);
      expect(cam.framesProcessed, 0);
      expect(cam.framesDropped, 0);
      expect(cam.mlGeneration, 0);
      expect(cam.analysisBlocked, false);
      expect(cam.nativeStarting, false);
      expect(cam.isMirrored, true);
    });

    test('latency split and census start at zero/unknown', () {
      final cam = CameraService();
      expect(cam.lastLatencyMs, 0);
      expect(cam.lastConvertMs, 0);
      expect(cam.lastInferMs, 0);
      expect(cam.meanLatencyMs, 0);
      expect(cam.facesDetectedTotal, 0);
      expect(cam.locksAchievedTotal, 0);
      expect(cam.throughputRatio, -1);
      expect(cam.mlInputLabel, '');
      expect(cam.hitRateLine, 'none yet');
      expect(cam.qualityVerdictLabel, 'unknown');
      expect(cam.detectorTier, 'accurate');
      expect(cam.preferFastTier, false);
      expect(cam.cameraInfo, 'camera: not initialized');
    });
  });

  group('fast-tier experiment flag', () {
    test('toggle flips the flag, tier stays accurate without rebuild',
        () {
      final cam = CameraService();
      cam.setPreferFastTier(true);
      expect(cam.preferFastTier, true);
      // No detector was built, so the live tier is still accurate;
      // the flag takes effect on the next _ensureDetector build.
      expect(cam.detectorTier, 'accurate');
      cam.setPreferFastTier(true);
      expect(cam.preferFastTier, true);
      cam.setPreferFastTier(false);
      expect(cam.preferFastTier, false);
    });
  });

  group('health snapshot pass-through', () {
    test('idle snapshot reports no camera, zero throughput', () {
      final cam = CameraService();
      final snap = cam.healthSnapshot;
      expect(snap.framesProcessed, 0);
      expect(snap.framesReceived, 0);
      expect(snap.meanLatencyMs, 0);
      expect(snap.cameraUp, false);
      expect(
          classifyEngineHealth(snap), EngineClassification.unavailable);
    });
  });

  group('diagnostic export structure', () {
    test('fresh export carries every section with honest unknowns',
        () {
      final cam = CameraService();
      final r = cam.diagnosticReport(
        appVersion: 'test',
        deviceModel: 'TestDevice',
        osVersion: 'TestOS 1',
      );
      expect(r['appVersion'], 'test');
      for (final k in [
        'device',
        'camera',
        'startup',
        'frames',
        'tracking',
        'detection',
        'adaptation',
        'thresholds',
        'analyzers',
        'events'
      ]) {
        expect(r.containsKey(k), true, reason: 'missing section $k');
      }
      final frames = r['frames']! as Map<String, Object?>;
      expect(frames['received'], 0);
      expect(frames['throughputRatio'], -1);
      expect(frames['mlMap'], '');
      final detection = r['detection']! as Map<String, Object?>;
      expect(detection['tier'], 'accurate');
      expect(detection['facesDetected'], 0);
      expect(detection['locksAchieved'], 0);
      expect(detection['quality'], 'unknown');
      expect(detection['generations'], isEmpty);
      final tracking = r['tracking']! as Map<String, Object?>;
      expect(tracking['locked'], false);
      expect(tracking['frameLogTail'], isEmpty);
    });

    test('debug stage is reflected in export', () {
      final cam = CameraService()
        ..debugSetStage(CameraStage.mlDegraded, 'unit');
      final r = cam.diagnosticReport(
        appVersion: 'test',
        deviceModel: 'TestDevice',
        osVersion: 'TestOS 1',
      );
      final startup = r['startup']! as Map<String, Object?>;
      expect(startup['stage'], 'mlDegraded');
      expect(startup['stageDetail'], 'unit');
    });
  });
}
