// Stream-path regression tests: adversarial device inputs for the
// camera-stream conversion path.
//
// Field symptom: on a physical Android device the stream delivered ~711
// frames with 0 processed and climbing per-frame errors. The conversion
// path (_onImage in lib/features/camera/camera_service.dart) runs pure
// helpers from camera_pipeline.dart (refineLayout, expectedMlLength, ...)
// and eye_tracking.dart (EyeCoords.sampleYPlane); these tests pin those
// helpers on hostile inputs so any fix for that symptom is guarded.
//
// AcquisitionAdapter + ConfigHitRates are covered in
// test/camera_pipeline_test.dart and intentionally NOT duplicated here.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/camera/camera_pipeline.dart';
import 'package:ocuscan/features/camera/eye_tracking.dart';

void main() {
  group('refineLayout adversarial inputs (never throws, honest kinds)', () {
    test('empty planeLengths with planeCount>0 -> unknown', () {
      for (final n in <int>[1, 2, 3, 4]) {
        final l = refineLayout(
          planeCount: n,
          planeLengths: const <int>[],
          width: 640,
          height: 480,
          formatGroupName: 'nv21',
        );
        expect(l.kind, FrameLayoutKind.unknown, reason: 'planeCount=$n');
        expect(l.usePlanes, isEmpty, reason: 'planeCount=$n');
      }
    });

    test('planeLengths shorter than planeCount: indices stay < planeCount', () {
      const w = 640;
      const h = 480;
      final yLen = w * h;
      final cases = <({int n, List<int> lens, String group})>[
        (n: 3, lens: <int>[yLen], group: 'nv21'), // len 1 < 3
        (
          n: 3,
          lens: <int>[yLen, yLen ~/ 4],
          group: 'nv21'
        ), // len 2 < 3, small chroma
        (
          n: 3,
          lens: <int>[yLen, yLen ~/ 2],
          group: 'nv21'
        ), // len 2 < 3, full chroma
        (n: 4, lens: <int>[yLen, yLen ~/ 2], group: 'yuv420'), // len 2 < 4
        (n: 2, lens: <int>[yLen], group: 'nv21'), // len 1 < 2
        (n: 5, lens: <int>[yLen, 10, 10], group: 'yuv420'), // len 3 < 5
      ];
      for (final c in cases) {
        final l = refineLayout(
          planeCount: c.n,
          planeLengths: c.lens,
          width: w,
          height: h,
          formatGroupName: c.group,
        );
        for (final i in l.usePlanes) {
          expect(i, greaterThanOrEqualTo(0),
              reason: 'n=${c.n} lens=${c.lens}');
          expect(i, lessThan(c.n),
              reason: 'n=${c.n} lens=${c.lens} usePlanes=${l.usePlanes}');
        }
      }
    });

    test('single-element planeLengths', () {
      // Single real plane -> bgra using plane 0 (healthy path).
      final bgra = refineLayout(
        planeCount: 1,
        planeLengths: <int>[640 * 480 * 4],
        width: 640,
        height: 480,
        formatGroupName: 'bgra8888',
      );
      expect(bgra.kind, FrameLayoutKind.bgra);
      expect(bgra.usePlanes, <int>[0]);
      // Declared multi-plane frames with a single observed length still
      // resolve without throwing; indices stay inside planeCount.
      for (final n in <int>[2, 3]) {
        final l = refineLayout(
          planeCount: n,
          planeLengths: <int>[640 * 480],
          width: 640,
          height: 480,
          formatGroupName: 'nv21',
        );
        for (final i in l.usePlanes) {
          expect(i, lessThan(n),
              reason: 'planeCount=$n kind=${l.kind} usePlanes=${l.usePlanes}');
        }
      }
    });

    test('huge/zero widths never throw; indices bounded', () {
      const dims = <List<int>>[
        <int>[0, 480],
        <int>[640, 0],
        <int>[0, 0],
        <int>[1 << 20, 1 << 20],
        <int>[100000, 100],
        <int>[1, 1],
      ];
      for (final d in dims) {
        final w = d[0];
        final h = d[1];
        for (final n in <int>[2, 3]) {
          final l = refineLayout(
            planeCount: n,
            planeLengths: <int>[w * h, (w * h) ~/ 2, 0],
            width: w,
            height: h,
            formatGroupName: 'nv21',
          );
          for (final i in l.usePlanes) {
            expect(i, greaterThanOrEqualTo(0), reason: '${w}x$h n=$n');
            expect(i, lessThan(n),
                reason: '${w}x$h n=$n usePlanes=${l.usePlanes}');
          }
        }
      }
    });
  });

  group('refineLayout usePlanes indices bounded (property-style)', () {
    test('all indices < planeCount across synthetic layouts', () {
      const groups = <String>[
        'nv21',
        'yuv420',
        'bgra8888',
        'jpeg',
        'unknown-group'
      ];
      var checked = 0;
      for (final n in <int>[1, 2, 3, 4, 5]) {
        for (final w in <int>[0, 1, 320, 640, 1280]) {
          for (final h in <int>[0, 1, 240, 480, 720]) {
            final yLen = w * h;
            final patterns = <List<int>>[
              <int>[],
              <int>[yLen],
              <int>[yLen, yLen ~/ 2],
              <int>[yLen, yLen ~/ 4, yLen ~/ 4],
              <int>[yLen, yLen ~/ 2, 0],
              <int>[0, 0, 0],
              <int>[1],
            ];
            for (final lens in patterns) {
              for (final g in groups) {
                final l = refineLayout(
                  planeCount: n,
                  planeLengths: lens,
                  width: w,
                  height: h,
                  formatGroupName: g,
                );
                for (final i in l.usePlanes) {
                  expect(i >= 0 && i < n, isTrue,
                      reason: 'n=$n ${w}x$h lens=$lens group=$g '
                          'usePlanes=${l.usePlanes}');
                }
                checked++;
              }
            }
          }
        }
      }
      // The sweep actually ran (5*5*5*7*5 combos).
      expect(checked, 4375);
    });
  });

  group('expectedMlLength truncation boundary', () {
    // Truncation rule (camera_service.dart _onImage): a concatenated buffer
    // with bytes.length < minLen is corrupt and must NOT reach ML Kit, where
    // minLen = width*height*4 for bgra, else width*height*3~/2.
    // These tests pin the boundary: exact-minimum accepted, one-byte-short
    // rejected.
    int minLenFor({required FrameLayoutKind kind, required int w, required int h}) =>
        kind == FrameLayoutKind.bgra ? w * h * 4 : w * h * 3 ~/ 2;

    test('nv21 tight: expected == service minimum; exact passes, one short fails',
        () {
      const w = 640;
      const h = 480;
      final e = expectedMlLength(
        kind: FrameLayoutKind.nv21Interleaved,
        width: w,
        height: h,
        bytesPerRow: w,
      );
      final minLen = minLenFor(
          kind: FrameLayoutKind.nv21Interleaved, w: w, h: h);
      // Tight stride: stride-aware length agrees with the service rule.
      expect(e, minLen);
      expect(e < minLen, isFalse,
          reason: 'exact-minimum buffer is accepted, not truncated');
      expect(e - 1 < minLen, isTrue,
          reason: 'one-byte-short buffer is rejected as truncated');
    });

    test('bgra: expected == service minimum; exact passes, one short fails',
        () {
      const w = 64;
      const h = 48;
      final e = expectedMlLength(
        kind: FrameLayoutKind.bgra,
        width: w,
        height: h,
        bytesPerRow: w,
      );
      final minLen =
          minLenFor(kind: FrameLayoutKind.bgra, w: w, h: h);
      expect(e, minLen);
      expect(e < minLen, isFalse);
      expect(e - 1 < minLen, isTrue);
    });

    test('yv12 tight: expected == service minimum', () {
      const w = 640;
      const h = 480;
      final e = expectedMlLength(
        kind: FrameLayoutKind.yv12Planar,
        width: w,
        height: h,
        bytesPerRow: w,
      );
      expect(e, w * h * 3 ~/ 2);
    });

    test('padded stride: stride-aware length exceeds the tight service minimum',
        () {
      // With row padding the true layout length is larger than w*h*3/2, so
      // the service rule is lenient vs the full padded length. Pinned here
      // so a future strictness fix updates this test deliberately.
      const w = 1280;
      const h = 720;
      const stride = 1344;
      final e = expectedMlLength(
        kind: FrameLayoutKind.nv21Interleaved,
        width: w,
        height: h,
        bytesPerRow: stride,
      );
      expect(e, stride * h + stride * (h ~/ 2));
      expect(e, greaterThan(w * h * 3 ~/ 2));
    });

    test('unknown -> -1 sentinel (never a valid minimum)', () {
      expect(
          expectedMlLength(
            kind: FrameLayoutKind.unknown,
            width: 640,
            height: 480,
            bytesPerRow: 640,
          ),
          -1);
    });
  });

  group('sampleYPlane never throws on hostile inputs', () {
    test('bytesPerRow==0 returns unknown', () {
      final q = EyeCoords.sampleYPlane(
          List<int>.filled(256, 128), 16, 16, 0);
      expect(q.width, 0);
      expect(q.height, 0);
    });

    test('width==0 returns unknown', () {
      final q = EyeCoords.sampleYPlane(
          List<int>.filled(256, 128), 0, 16, 16);
      expect(q.width, 0);
    });

    test('truncated yBytes returns unknown or a value, never throws', () {
      FrameQuality? q;
      expect(
          () => q = EyeCoords.sampleYPlane(
              <int>[1, 2, 3], 640, 480, 640),
          returnsNormally);
      expect(q, isNotNull);
      // Either the unknown sentinel or a best-effort value is acceptable;
      // the frame must survive sampling.
      expect(q!.meanLuminance, isA<double>());
    });

    test('stride<width returns unknown or a value, never throws', () {
      FrameQuality? q;
      expect(
          () => q = EyeCoords.sampleYPlane(
              List<int>.filled(4096, 128), 64, 64, 16),
          returnsNormally);
      expect(q, isNotNull);
      expect(q!.meanLuminance, isA<double>());
    });

    test('empty yBytes returns unknown', () {
      final q = EyeCoords.sampleYPlane(const <int>[], 64, 64, 64);
      expect(q.width, 0);
      expect(q.height, 0);
    });

    test('sane plane still yields sane stats (control)', () {
      final q = EyeCoords.sampleYPlane(
          List<int>.filled(64 * 64, 200), 64, 64, 64);
      expect(q.meanLuminance, closeTo(200, 1e-6));
      expect(q.width, 64);
      expect(q.height, 64);
    });
  });

  group('StartupWatchdog documents firstFrameAt placement', () {
    test(
        'stream started + frames flowing at camera level + first frame NEVER set '
        '+ time passing -> timeout', () {
      // evaluate() takes NO framesReceived input: only firstFrameReceived
      // matters. firstFrameAt is assigned in _onImage only AFTER conversion,
      // truncation and InputImage build succeed, so a device delivering
      // hundreds of frames with 0 processed (conversion stall) still trips
      // the startup watchdog here instead of hanging in "waiting" forever.
      const w = StartupWatchdog(timeout: Duration(seconds: 8));
      final startedAt = DateTime(2026, 5, 1, 12, 0, 0);
      expect(
          w.evaluate(
            streamStarted: true,
            firstFrameReceived: false,
            startedAt: startedAt,
            now: startedAt.add(const Duration(seconds: 30)),
          ),
          StartupState.timeout);
    });

    test('timeout boundary is strict: exactly at deadline still waits', () {
      const w = StartupWatchdog(timeout: Duration(seconds: 8));
      final startedAt = DateTime(2026, 5, 1, 12, 0, 0);
      expect(
          w.evaluate(
            streamStarted: true,
            firstFrameReceived: false,
            startedAt: startedAt,
            now: startedAt.add(const Duration(seconds: 8)),
          ),
          StartupState.waiting);
      expect(
          w.evaluate(
            streamStarted: true,
            firstFrameReceived: false,
            startedAt: startedAt,
            now: startedAt
                .add(const Duration(seconds: 8, milliseconds: 1)),
          ),
          StartupState.timeout);
    });
  });

  group('RecoveryLadder monotonic and bounded', () {    test(
        'actionFor is non-decreasing with stuckSeconds and ends at offerContinueUnable',
        () {
      const ladder = RecoveryLadder();
      var prev = RecoveryAction.none;
      var s = -50;
      while (s <= 200000) {
        final a = ladder.actionFor(stuckSeconds: s);
        expect(a.index, greaterThanOrEqualTo(prev.index),
            reason: 'stuckSeconds=$s went ${prev.name} -> ${a.name}');
        prev = a;
        // Dense near the escalation thresholds, sparse far out.
        s += s < 500 ? 1 : 7919;
      }
      expect(prev, RecoveryAction.offerContinueUnable);
    });

    test('terminal action never loops back, even for extreme inputs', () {
      const ladder = RecoveryLadder();
      for (final s in <int>[120, 121, 1000, 1 << 30, 1 << 62]) {
        expect(ladder.actionFor(stuckSeconds: s),
            RecoveryAction.offerContinueUnable,
            reason: 'stuckSeconds=$s');
      }
    });
  });

  group('pipeline stage semantics (why pills use previewAlive)', () {
    test('previewUp is true only for live-preview stages', () {
      for (final s in <CameraStage>[
        CameraStage.previewReady,
        CameraStage.streamStarting,
        CameraStage.firstFrame,
        CameraStage.processing,
      ]) {
        expect(previewUp(s), isTrue, reason: s.name);
      }
    });

    test(
        'failure stages with a live preview read false from previewUp '
        '(documents the pill bug class)', () {
      // A device can hold a live preview texture while analysis fails
      // (conversion/ml/stream/no-first-frame). previewUp answers false
      // here, so the CAMERA pill and checklist camera/preview rows must
      // read controller liveness (previewAlive), never previewUp —
      // otherwise a working preview shows as dead while its own failure
      // panel is already explaining the analysis problem.
      for (final s in <CameraStage>[
        CameraStage.idle,
        CameraStage.requestingPermission,
        CameraStage.initializing,
        CameraStage.switching,
        CameraStage.permissionDenied,
        CameraStage.initFailed,
        CameraStage.streamFailed,
        CameraStage.noFirstFrame,
        CameraStage.conversionFailed,
        CameraStage.mlDegraded,
      ]) {
        expect(previewUp(s), isFalse, reason: s.name);
      }
    });

    test('zero dims -> unknown AND empty usePlanes (no vacuous pass)', () {
      // A bounded-indices loop over an empty usePlanes passes vacuously,
      // so pin emptiness explicitly: degenerate frames must not claim a
      // usable layout.
      for (final d in <List<int>>[
        <int>[0, 480],
        <int>[640, 0],
        <int>[0, 0],
      ]) {
        for (final n in <int>[1, 2, 3, 4]) {
          final l = refineLayout(
            planeCount: n,
            planeLengths: <int>[d[0] * d[1], (d[0] * d[1]) ~/ 2],
            width: d[0],
            height: d[1],
            formatGroupName: 'nv21',
          );
          expect(l.kind, FrameLayoutKind.unknown,
              reason: '${d[0]}x${d[1]} n=$n');
          expect(l.usePlanes, isEmpty,
              reason: '${d[0]}x${d[1]} n=$n');
        }
      }
    });
  });
}
