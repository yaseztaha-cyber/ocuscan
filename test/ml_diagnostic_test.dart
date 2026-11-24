// Isolated ML diagnostic model tests: outcome vocabulary, one-line
// errors, report envelope. No plugins, no camera.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/camera/ml_diagnostic.dart';

void main() {
  group('classifyDetectorResult keeps error/no-face apart', () {
    test('null count (threw) -> error, never no-face', () {
      expect(classifyDetectorResult(null), MlDiagOutcome.error);
    });
    test('zero faces -> noFace', () {
      expect(classifyDetectorResult(0), MlDiagOutcome.noFace);
    });
    test('faces found -> pass', () {
      expect(classifyDetectorResult(1), MlDiagOutcome.pass);
      expect(classifyDetectorResult(3), MlDiagOutcome.pass);
    });
  });

  group('shortError is one line and capped', () {
    test('multiline stack collapses to first line', () {
      const e =
          'PlatformException(error, boom\n\tat a.b(c:1)\n\tat d.e(f:2)';
      final s = shortError(e);
      expect(s.contains('\n'), false);
      expect(s.contains('\t'), false);
      expect(s.startsWith('PlatformException(error, boom'), true);
    });
    test('long errors cap with ellipsis', () {
      final s = shortError('x' * 500, 100);
      expect(s.length, 101);
      expect(s.endsWith('…'), true);
    });
    test('short errors pass through', () {
      expect(shortError('plain failure'), 'plain failure');
    });
  });

  group('MlDiagReport envelope', () {
    test('toJson carries versions, time, items; summary rolls up', () {
      final r = MlDiagReport(
        appVersion: '0.7.7+15',
        at: DateTime(2026, 9, 29, 12, 0, 0),
        items: const [
          MlDiagItem(name: 'A', outcome: MlDiagOutcome.pass, detail: '1 face'),
          MlDiagItem(
              name: 'B',
              outcome: MlDiagOutcome.skipped,
              detail: 'no asset'),
          MlDiagItem(
              name: 'C',
              outcome: MlDiagOutcome.error,
              detail: 'PlatformException'),
        ],
      );
      final j = r.toJson();
      expect(j['format'], 'ocuscan-ml-diagnostic');
      expect(j['ocuscan_version'], '0.7.7+15');
      expect((j['ml_stack'] as String).contains('face_detection'), true);
      expect((j['items'] as List).length, 3);
      expect(r.summaryLine, 'A:pass B:skipped C:error');
    });
  });

  group('MlHealth state machine (detector-health truth)', () {
    test('healthy below the degraded gate', () {
      expect(mlHealthFor(consecutiveErrors: 0, framesProcessed: 0),
          MlHealth.healthy);
      expect(mlHealthFor(consecutiveErrors: 2, framesProcessed: 0),
          MlHealth.healthy);
      // Frames flowing with a couple of transient errors stays healthy.
      expect(mlHealthFor(consecutiveErrors: 2, framesProcessed: 40),
          MlHealth.healthy);
    });
    test('degraded at >=3 consecutive errors', () {
      expect(mlHealthFor(consecutiveErrors: 3, framesProcessed: 0),
          MlHealth.degraded);
      expect(mlHealthFor(consecutiveErrors: 9, framesProcessed: 0),
          MlHealth.degraded);
      // Errors with some frames processed: degraded, never down.
      expect(mlHealthFor(consecutiveErrors: 10, framesProcessed: 1),
          MlHealth.degraded);
      expect(mlHealthFor(consecutiveErrors: 500, framesProcessed: 7),
          MlHealth.degraded);
    });
    test('down at >=10 consecutive errors with zero processed', () {
      expect(mlHealthFor(consecutiveErrors: 10, framesProcessed: 0),
          MlHealth.down);
      expect(mlHealthFor(consecutiveErrors: 25, framesProcessed: 0),
          MlHealth.down);
      // The OPPO CPH2121 field shape: endless NPE, nothing processed.
      expect(mlHealthFor(consecutiveErrors: 200, framesProcessed: 0),
          MlHealth.down);
    });
    test('negative counters clamp to healthy (never crash)', () {
      expect(mlHealthFor(consecutiveErrors: -5, framesProcessed: -1),
          MlHealth.healthy);
    });
    test('threshold constants are explicit', () {
      expect(kMlDegradedAfterErrors, 3);
      expect(kMlDownAfterErrors, 10);
    });
    test('describe() names the state and both counts', () {
      expect(
          MlHealth.down
              .describe(consecutiveErrors: 12, framesProcessed: 0),
          'down: 12 consecutive ML errors, 0 frames processed');
      expect(
          MlHealth.degraded
              .describe(consecutiveErrors: 5, framesProcessed: 3),
          contains('degraded'));
      expect(
          MlHealth.degraded
              .describe(consecutiveErrors: 5, framesProcessed: 3),
          allOf(contains('5'), contains('3')));
      expect(
          MlHealth.healthy
              .describe(consecutiveErrors: 0, framesProcessed: 41),
          contains('healthy'));
    });
  });

  group('MlHealth display mapping stays honest', () {
    test('health codes never reuse pass/noFace words', () {
      for (final h in MlHealth.values) {
        final label = mlHealthDisplayName(h);
        expect(label, h.name);
        expect(label.contains('pass'), false);
        expect(label.contains('noFace'), false);
      }
      expect(mlHealthDisplayName(MlHealth.healthy), 'healthy');
      expect(mlHealthDisplayName(MlHealth.degraded), 'degraded');
      expect(mlHealthDisplayName(MlHealth.down), 'down');
    });
    test('MlDiagOutcome vocabulary untouched (error still distinct)', () {
      // Regression pin: detector threw (null) must never read as no-face.
      expect(classifyDetectorResult(null), MlDiagOutcome.error);
      expect(classifyDetectorResult(null) == MlDiagOutcome.noFace, false);
    });
  });
}
