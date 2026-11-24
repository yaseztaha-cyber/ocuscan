// v0.3.3 camera pipeline tests: stage helpers, ML format choice from
// observed layout, watchdog evaluation, recovery ladder bounds,
// best-camera decision, anatomical side safety. No plugins required.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/camera/camera_pipeline.dart';

void main() {
  group('stage helpers', () {
    test('preview vs analysis separation', () {
      expect(previewUp(CameraStage.previewReady), true);
      expect(previewUp(CameraStage.streamStarting), true);
      expect(previewUp(CameraStage.processing), true);
      expect(previewUp(CameraStage.initializing), false);
      expect(previewUp(CameraStage.permissionDenied), false);
      expect(analysisFlowing(CameraStage.processing), true);
      expect(analysisFlowing(CameraStage.firstFrame), true);
      expect(analysisFlowing(CameraStage.previewReady), false);
      expect(analysisFlowing(CameraStage.streamStarting), false);
      // A working preview with dead analysis reads exactly that way.
      expect(previewUp(CameraStage.previewReady), true);
      expect(analysisFlowing(CameraStage.previewReady), false);
    });
  });

  group('chooseMlFormat observes layout', () {
    test('two planes -> nv21', () {
      expect(
          chooseMlFormat(planeCount: 2, formatGroupName: 'nv21'),
          MlDeclaredFormat.nv21);
    });
    test('three planes -> yv12 best-effort (never assumed nv21)', () {
      expect(
          chooseMlFormat(planeCount: 3, formatGroupName: 'nv21'),
          MlDeclaredFormat.yv12);
      expect(
          chooseMlFormat(planeCount: 4, formatGroupName: 'yuv420'),
          MlDeclaredFormat.yv12);
    });
    test('single plane -> bgra8888', () {
      expect(
          chooseMlFormat(planeCount: 1, formatGroupName: 'bgra8888'),
          MlDeclaredFormat.bgra8888);
    });
    test('zero planes -> unsupported (honest, not corrupt)', () {
      expect(
          chooseMlFormat(planeCount: 0, formatGroupName: 'nv21'),
          MlDeclaredFormat.unsupported);
    });
  });

  group('StartupWatchdog', () {
    const w = StartupWatchdog(timeout: Duration(seconds: 8));
    test('ok once first frame arrives', () {
      expect(
          w.evaluate(
              streamStarted: true,
              firstFrameReceived: true,
              startedAt: DateTime(2026, 1, 1),
              now: DateTime(2026, 1, 1, 0, 0, 30)),
          StartupState.ok);
    });
    test('waiting inside timeout', () {
      expect(
          w.evaluate(
              streamStarted: true,
              firstFrameReceived: false,
              startedAt: DateTime(2026, 1, 1),
              now: DateTime(2026, 1, 1, 0, 0, 5)),
          StartupState.waiting);
    });
    test('timeout after deadline', () {
      expect(
          w.evaluate(
              streamStarted: true,
              firstFrameReceived: false,
              startedAt: DateTime(2026, 1, 1),
              now: DateTime(2026, 1, 1, 0, 0, 9)),
          StartupState.timeout);
    });
    test('idle before stream start', () {
      expect(
          w.evaluate(
              streamStarted: false,
              firstFrameReceived: false,
              startedAt: null,
              now: DateTime(2026, 1, 1)),
          StartupState.idle);
    });
  });

  group('RecoveryLadder bounds the loop', () {
    const ladder = RecoveryLadder();
    test('escalates with stuck time', () {
      expect(ladder.actionFor(stuckSeconds: 0), RecoveryAction.none);
      expect(
          ladder.actionFor(stuckSeconds: 15), RecoveryAction.autoResetTracker);
      expect(ladder.actionFor(stuckSeconds: 30), RecoveryAction.showPanel);
      expect(
          ladder.actionFor(stuckSeconds: 60), RecoveryAction.offerRestart);
      expect(ladder.actionFor(stuckSeconds: 120),
          RecoveryAction.offerContinueUnable);
      expect(ladder.actionFor(stuckSeconds: 9999),
          RecoveryAction.offerContinueUnable);
    });
  });

  group('recommendCamera technical reasons only', () {
    const front = CameraCapabilities(
        code: 'front',
        lensDirection: 'front',
        sensorOrientation: 270,
        name: 'front-cam',
        previewWidth: 720,
        previewHeight: 1280);
    const rear = CameraCapabilities(
        code: 'rear',
        lensDirection: 'back',
        sensorOrientation: 90,
        name: 'rear-cam',
        previewWidth: 1920,
        previewHeight: 1080);
    test('self-guided prefers front with stated reason', () {
      final d = recommendCamera(
          need: TestCameraNeed.selfGuided, available: [front, rear]);
      expect(d.code, 'front');
      expect(d.reasons.isNotEmpty, true);
      expect(d.reasons.join(' ').contains('diagnos'), false);
      expect(d.reasons.join(' ').contains('accura'), false);
    });
    test('high-detail prefers higher measured resolution', () {
      final d = recommendCamera(
          need: TestCameraNeed.highDetail, available: [front, rear]);
      expect(d.code, 'rear');
      expect(d.reasons.join(' '), contains('resolution'));
    });
    test('high-detail without measurements stays honest', () {
      const rearUnknown = CameraCapabilities(
          code: 'rear',
          lensDirection: 'back',
          sensorOrientation: 90,
          name: 'rear-cam');
      final d = recommendCamera(
          need: TestCameraNeed.highDetail,
          available: [front, rearUnknown]);
      expect(d.code, 'rear');
      expect(d.reasons.join(' '), contains('not yet measured'));
    });
    test('empty list defaults to front explicitly', () {
      final d = recommendCamera(
          need: TestCameraNeed.selfGuided, available: []);
      expect(d.code, 'front');
    });
    test('single camera returns it', () {
      expect(
          recommendCamera(
                  need: TestCameraNeed.highDetail, available: [front])
              .code,
          'front');
    });
  });

  group('anatomical side safety', () {
    test('mirrored selfie: subject left appears right', () {
      expect(subjectLeftOnScreenLeft(mirrored: true), false);
    });
    test('rear/direct: subject left appears left', () {
      expect(subjectLeftOnScreenLeft(mirrored: false), true);
    });
  });

  group('stream fallback chain', () {
    test('preferred quality first, widest compatibility last', () {
      expect(streamFallbackChain.first, StreamConfig.mediumNv21);
      expect(streamFallbackChain.last, StreamConfig.lowYuv420);
      expect(streamFallbackChain.toSet().length,
          streamFallbackChain.length);
    });
  });

  group('streamLooksDead', () {
    final t0 = DateTime(2026, 1, 1);
    test('healthy stream is not dead', () {
      expect(
          streamLooksDead(
              ready: true,
              streamActive: true,
              framesReceived: 120,
              streamStartedAt: t0,
              lastFrameAgeMs: 200,
              now: t0.add(const Duration(seconds: 30))),
          false);
    });
    test('not-ready or inactive never counts as dead', () {
      expect(
          streamLooksDead(
              ready: false,
              streamActive: true,
              framesReceived: 0,
              streamStartedAt: t0,
              lastFrameAgeMs: -1,
              now: t0.add(const Duration(minutes: 5))),
          false);
      expect(
          streamLooksDead(
              ready: true,
              streamActive: false,
              framesReceived: 0,
              streamStartedAt: t0,
              lastFrameAgeMs: -1,
              now: t0.add(const Duration(minutes: 5))),
          false);
    });
    test('silent stream with zero frames is dead after 10 s', () {
      expect(
          streamLooksDead(
              ready: true,
              streamActive: true,
              framesReceived: 0,
              streamStartedAt: t0,
              lastFrameAgeMs: -1,
              now: t0.add(const Duration(seconds: 9))),
          false);
      expect(
          streamLooksDead(
              ready: true,
              streamActive: true,
              framesReceived: 0,
              streamStartedAt: t0,
              lastFrameAgeMs: -1,
              now: t0.add(const Duration(seconds: 11))),
          true);
    });
    test('stalled stream after frames is dead after 15 s silence', () {
      expect(
          streamLooksDead(
              ready: true,
              streamActive: true,
              framesReceived: 50,
              streamStartedAt: t0,
              lastFrameAgeMs: 14000,
              now: t0.add(const Duration(minutes: 2))),
          false);
      expect(
          streamLooksDead(
              ready: true,
              streamActive: true,
              framesReceived: 50,
              streamStartedAt: t0,
              lastFrameAgeMs: 16000,
              now: t0.add(const Duration(minutes: 2))),
          true);
    });
  });

  group('refineLayout inspects plane sizes', () {
    test('two planes -> nv21 using both', () {
      final l = refineLayout(
          planeCount: 2,
          planeLengths: [921600, 460800],
          width: 1280,
          height: 720,
          formatGroupName: 'nv21');
      expect(l.kind, FrameLayoutKind.nv21Interleaved);
      expect(l.usePlanes, [0, 1]);
      expect(l.mlFormatName, 'nv21');
    });
    test('three planes with full-width chroma -> nv21 in disguise', () {
      final l = refineLayout(
          planeCount: 3,
          planeLengths: [921600, 460800, 0],
          width: 1280,
          height: 720,
          formatGroupName: 'nv21');
      expect(l.kind, FrameLayoutKind.nv21Interleaved);
      expect(l.usePlanes, [0, 1]);
    });
    test('three small chroma planes -> yv12 planar Y+V+U', () {
      final l = refineLayout(
          planeCount: 3,
          planeLengths: [921600, 230400, 230400],
          width: 1280,
          height: 720,
          formatGroupName: 'yuv420');
      expect(l.kind, FrameLayoutKind.yv12Planar);
      expect(l.usePlanes, [0, 2, 1]);
      expect(l.mlFormatName, 'yv12');
    });
    test('zero planes -> unknown, never guessed', () {
      final l = refineLayout(
          planeCount: 0,
          planeLengths: [],
          width: 1280,
          height: 720,
          formatGroupName: 'nv21');
      expect(l.kind, FrameLayoutKind.unknown);
      expect(l.usePlanes, isEmpty);
    });
    test('single plane -> bgra', () {
      final l = refineLayout(
          planeCount: 1,
          planeLengths: [3686400],
          width: 1280,
          height: 720,
          formatGroupName: 'bgra8888');
      expect(l.kind, FrameLayoutKind.bgra);
    });
    test('single plane jpeg is never mislabeled bgra', () {
      // A full-size JPEG buffer must stay unsupported and loud, even
      // though its length matches a BGRA frame.
      final l = refineLayout(
          planeCount: 1,
          planeLengths: [1280 * 720 * 4],
          width: 1280,
          height: 720,
          formatGroupName: 'jpeg');
      expect(l.kind, FrameLayoutKind.unknown);
      expect(l.usePlanes, isEmpty);
    });
    test('single pre-packed nv21 plane is usable', () {
      // Some plugins deliver already-concatenated NV21 in one plane.
      const w = 640, h = 480;
      final l = refineLayout(
          planeCount: 1,
          planeLengths: [w * h * 3 ~/ 2],
          width: w,
          height: h,
          formatGroupName: 'nv21');
      expect(l.kind, FrameLayoutKind.nv21Interleaved);
      expect(l.usePlanes, [0]);
    });
    test('single short plane stays unsupported', () {
      final l = refineLayout(
          planeCount: 1,
          planeLengths: [100],
          width: 640,
          height: 480,
          formatGroupName: 'bgra8888');
      expect(l.kind, FrameLayoutKind.unknown);
      expect(l.usePlanes, isEmpty);
    });
  });

  group('expectedMlLength validates buffers', () {    test('nv21 tight 1280x720', () {
      expect(
          expectedMlLength(
              kind: FrameLayoutKind.nv21Interleaved,
              width: 1280,
              height: 720,
              bytesPerRow: 1280),
          1280 * 720 * 3 ~/ 2);
    });
    test('nv21 with padded stride accounts padding', () {
      expect(
          expectedMlLength(
              kind: FrameLayoutKind.nv21Interleaved,
              width: 1280,
              height: 720,
              bytesPerRow: 1344),
          1344 * 720 + 1344 * 360);
    });
    test('yv12 planar tight', () {
      expect(
          expectedMlLength(
              kind: FrameLayoutKind.yv12Planar,
              width: 640,
              height: 480,
              bytesPerRow: 640),
          640 * 480 + 320 * 240 * 2);
    });
    test('unknown -> -1 sentinel', () {
      expect(
          expectedMlLength(
              kind: FrameLayoutKind.unknown,
              width: 640,
              height: 480,
              bytesPerRow: 640),
          -1);
    });
    test('stride padding flag', () {
      expect(strideHasPadding(bytesPerRow: 1280, width: 1280), false);
      expect(strideHasPadding(bytesPerRow: 1344, width: 1280), true);
    });
  });

  group('AcquisitionAdapter escalation rule', () {
    const adapter = AcquisitionAdapter(escalateAfterFrames: 150);
    test('no escalation without a long faceless run', () {
      expect(
          adapter.shouldEscalate(
              consecutiveFacelessProcessed: 0,
              alreadyEscalated: false),
          false);
      expect(
          adapter.shouldEscalate(
              consecutiveFacelessProcessed: 149,
              alreadyEscalated: false),
          false);
    });
    test('escalates once after the run, never twice', () {
      expect(
          adapter.shouldEscalate(
              consecutiveFacelessProcessed: 150,
              alreadyEscalated: false),
          true);
      expect(
          adapter.shouldEscalate(
              consecutiveFacelessProcessed: 9999,
              alreadyEscalated: true),
          false);
    });
  });

  group('ConfigHitRates accumulate real rates', () {
    test('records frames and faces per config', () {
      final h = ConfigHitRates();
      expect(h.rate('medium/nv21'), -1);
      for (var i = 0; i < 10; i++) {
        h.record('medium/nv21', faceFound: i < 3);
      }
      expect(h.rate('medium/nv21'), closeTo(0.3, 1e-9));
      h.record('low/nv21', faceFound: false);
      expect(h.rate('low/nv21'), 0);
      expect(h.summary()['medium/nv21'], contains('3/10'));
    });
    test('clear resets', () {
      final h = ConfigHitRates();
      h.record('medium/nv21', faceFound: true);
      h.clear();
      expect(h.rate('medium/nv21'), -1);
    });
  });

  group('tightPackFrame strips padding', () {
    List<int> plane(int stride, int rows, int fill) => [
          for (var r = 0; r < rows; r++) ...[
            for (var i = 0; i < stride; i++) fill,
          ]
        ];

    test('nv21 tight passthrough-equivalent', () {
      const w = 8, h = 4;
      final y = plane(8, 4, 100);
      final vu = plane(8, 2, 150);
      final out = tightPackFrame(
          planes: [
            PlaneBytes(bytes: y, bytesPerRow: 8),
            PlaneBytes(bytes: vu, bytesPerRow: 8),
          ],
          width: w,
          height: h,
          kind: FrameLayoutKind.nv21Interleaved);
      expect(out, isNotNull);
      expect(out!.length, w * h * 3 ~/ 2);
      expect(out.sublist(0, 4), [100, 100, 100, 100]);
      expect(out.sublist(w * h, w * h + 2), [150, 150]);
    });

    test('nv21 padded stride stripped exactly', () {
      const w = 8, h = 4;
      List<int> paddedRow(int stride, int real, int fill, int pad) => [
            for (var i = 0; i < real; i++) fill,
            for (var i = real; i < stride; i++) pad,
          ];
      final y = [
        for (var r = 0; r < h; r++) ...paddedRow(12, 8, 100, 0),
      ];
      final vu = [
        for (var r = 0; r < h ~/ 2; r++) ...paddedRow(12, 8, 150, 0),
      ];
      final out = tightPackFrame(
          planes: [
            PlaneBytes(bytes: y, bytesPerRow: 12),
            PlaneBytes(bytes: vu, bytesPerRow: 12),
          ],
          width: w,
          height: h,
          kind: FrameLayoutKind.nv21Interleaved);
      expect(out, isNotNull);
      expect(out!.length, w * h * 3 ~/ 2);
      expect(out.contains(0), false);
      expect(out.sublist(0, w), List.filled(w, 100));
    });

    test('truncated plane returns null, never partial', () {
      final out = tightPackFrame(
          planes: [
            PlaneBytes(bytes: List.filled(10, 1), bytesPerRow: 8),
            PlaneBytes(bytes: List.filled(10, 2), bytesPerRow: 8),
          ],
          width: 8,
          height: 4,
          kind: FrameLayoutKind.nv21Interleaved);
      expect(out, isNull);
    });

    test('yv12 planar padded', () {
      const w = 8, h = 4;
      List<int> pad(int stride, int real, int rows, int fill) => [
            for (var r = 0; r < rows; r++) ...[
              for (var i = 0; i < real; i++) fill,
              for (var i = real; i < stride; i++) 0,
            ]
          ];
      final out = tightPackFrame(
          planes: [
            PlaneBytes(bytes: pad(10, 8, 4, 100), bytesPerRow: 10),
            PlaneBytes(bytes: pad(6, 4, 2, 150), bytesPerRow: 6),
            PlaneBytes(bytes: pad(6, 4, 2, 200), bytesPerRow: 6),
          ],
          width: w,
          height: h,
          kind: FrameLayoutKind.yv12Planar);
      expect(out, isNotNull);
      expect(out!.length, w * h + 2 * (w ~/ 2) * (h ~/ 2));
      expect(out[w * h], 200);
      expect(out[w * h + (w ~/ 2) * (h ~/ 2)], 150);
    });

    test('degenerate inputs return null', () {
      expect(
          tightPackFrame(
              planes: [], width: 8, height: 4,
              kind: FrameLayoutKind.nv21Interleaved),
          isNull);
      expect(
          tightPackFrame(
              planes: [
                PlaneBytes(bytes: [1], bytesPerRow: 0),
              ],
              width: 8,
              height: 4,
              kind: FrameLayoutKind.nv21Interleaved),
          isNull);
      expect(
          tightPackFrame(
              planes: [
                PlaneBytes(bytes: [1], bytesPerRow: 8),
              ],
              width: 0,
              height: 4,
              kind: FrameLayoutKind.nv21Interleaved),
          isNull);
      expect(
          tightPackFrame(
              planes: [],
              width: 8,
              height: 4,
              kind: FrameLayoutKind.unknown),
          isNull);
    });

    test('refineLayout rejects zero dimensions', () {
      final l = refineLayout(
          planeCount: 3,
          planeLengths: [10, 10, 10],
          width: 0,
          height: 4,
          formatGroupName: 'nv21');
      expect(l.kind, FrameLayoutKind.unknown);
    });

    test('bgra pixel-unit stride passes through whole', () {
      // Same field case at pack level: complete buffer + stride label in
      // pixels -> whole-buffer passthrough, content preserved.
      const w = 8, h = 4;
      final bytes = List<int>.generate(w * h * 4, (i) => i % 251);
      final out = tightPackFrame(
          planes: [PlaneBytes(bytes: bytes, bytesPerRow: w)],
          width: w,
          height: h,
          kind: FrameLayoutKind.bgra);
      expect(out, isNotNull);
      expect(out!.length, w * h * 4);
      expect(out, bytes);
    });

    test('bgra short plane returns null, never partial', () {
      const w = 8, h = 4;
      expect(
          tightPackFrame(
              planes: [
                PlaneBytes(
                    bytes: List.filled(w * h, 1), bytesPerRow: w),
              ],
              width: w,
              height: h,
              kind: FrameLayoutKind.bgra),
          isNull);
    });
  });

  group('isTightLayout fast path', () {
    test('tight nv21 passes through', () {
      const w = 8, h = 4;
      expect(
          isTightLayout(
              kind: FrameLayoutKind.nv21Interleaved,
              planes: [
                PlaneBytes(
                    bytes: List.filled(w * h, 1), bytesPerRow: w),
                PlaneBytes(
                    bytes: List.filled(w * (h ~/ 2), 2),
                    bytesPerRow: w),
              ],
              width: w,
              height: h),
          true);
    });
    test('padded stride forces packing', () {
      const w = 8, h = 4;
      expect(
          isTightLayout(
              kind: FrameLayoutKind.nv21Interleaved,
              planes: [
                PlaneBytes(
                    bytes: List.filled(12 * h, 1), bytesPerRow: 12),
                PlaneBytes(
                    bytes: List.filled(12 * (h ~/ 2), 2),
                    bytesPerRow: 12),
              ],
              width: w,
              height: h),
          false);
    });
    test('short planes force packing', () {
      expect(
          isTightLayout(
              kind: FrameLayoutKind.nv21Interleaved,
              planes: [
                PlaneBytes(bytes: List.filled(10, 1), bytesPerRow: 8),
                PlaneBytes(bytes: List.filled(10, 2), bytesPerRow: 8),
              ],
              width: 8,
              height: 4),
          false);
    });
    test('unknown never tight', () {
      expect(
          isTightLayout(
              kind: FrameLayoutKind.unknown,
              planes: [],
              width: 8,
              height: 4),
          false);
    });
    test('bgra pixel-unit stride (bytesPerRow==width) is tight', () {
      // Field case: 720x480 BGRA, 1 plane, stride label 720 (pixels, not
      // bytes). The complete w*h*4 buffer is valid ML input; the label's
      // units must not route it to row-wise packing (which fails loudly).
      const w = 16, h = 8;
      expect(
          isTightLayout(
              kind: FrameLayoutKind.bgra,
              planes: [
                PlaneBytes(
                    bytes: List.filled(w * h * 4, 7),
                    bytesPerRow: w),
              ],
              width: w,
              height: h),
          true);
    });
    test('bgra short plane is not tight', () {
      const w = 16, h = 8;
      expect(
          isTightLayout(
              kind: FrameLayoutKind.bgra,
              planes: [
                PlaneBytes(
                    bytes: List.filled(w * h, 7), bytesPerRow: w),
              ],
              width: w,
              height: h),
          false);
    });
    test('nv21 pixel-unit chroma labels are tight by completeness', () {
      // Cross-device variant: Y plane byte-tight, chroma stride labeled
      // in pixels (w/2 with bytesPerPixel 2). Canonical total length
      // means plain concatenation is the valid packed buffer.
      const w = 16, h = 8;
      expect(
          isTightLayout(
              kind: FrameLayoutKind.nv21Interleaved,
              planes: [
                PlaneBytes(
                    bytes: List.filled(w * h, 1), bytesPerRow: w),
                PlaneBytes(
                    bytes: List.filled(w * (h ~/ 2), 2),
                    bytesPerRow: w ~/ 2,
                    bytesPerPixel: 2),
              ],
              width: w,
              height: h),
          true);
    });
    test('yv12 canonical total with odd labels is tight', () {
      const w = 16, h = 8;
      final q = (w ~/ 2) * (h ~/ 2);
      expect(
          isTightLayout(
              kind: FrameLayoutKind.yv12Planar,
              planes: [
                PlaneBytes(
                    bytes: List.filled(w * h, 1), bytesPerRow: 999),
                PlaneBytes(
                    bytes: List.filled(q, 2), bytesPerRow: 999),
                PlaneBytes(
                    bytes: List.filled(q, 3), bytesPerRow: 999),
              ],
              width: w,
              height: h),
          true);
    });
    test('nv21 padded total still forces packing', () {
      // Longer-than-canonical buffers keep the row-wise path: padding
      // must be stripped, never concatenated.
      const w = 8, h = 4;
      expect(
          isTightLayout(
              kind: FrameLayoutKind.nv21Interleaved,
              planes: [
                PlaneBytes(
                    bytes: List.filled(12 * h, 1), bytesPerRow: 12),
                PlaneBytes(
                    bytes: List.filled(12 * (h ~/ 2), 2),
                    bytesPerRow: 12),
              ],
              width: w,
              height: h),
          false);
    });
  });

  group('effectiveByteStride unwraps pixel units', () {    test('pixel-unit label with bytesPerPixel resolves to byte stride',
        () {
      const p = PlaneBytes(
          bytes: [1, 2, 3], bytesPerRow: 4, bytesPerPixel: 2);
      expect(effectiveByteStride(p, 8), 8);
    });
    test('byte-unit labels pass through untouched', () {
      const p = PlaneBytes(
          bytes: [1, 2, 3], bytesPerRow: 12, bytesPerPixel: 1);
      expect(effectiveByteStride(p, 8), 12);
      const q = PlaneBytes(bytes: [1, 2, 3], bytesPerRow: 8);
      expect(effectiveByteStride(q, 8), 8);
    });
    test('mismatched product keeps the label (fails loudly downstream)',
        () {
      const p = PlaneBytes(
          bytes: [1, 2, 3], bytesPerRow: 5, bytesPerPixel: 2);
      expect(effectiveByteStride(p, 8), 5);
    });
    test('mixed byte/pixel-unit nv21 packs exactly', () {
      // Y padded in bytes, chroma labeled in pixels: row-wise packing
      // strips Y padding while stepping chroma in unwrapped units.
      const w = 8, h = 4;
      final y = [
        for (var r = 0; r < h; r++) ...[
          for (var i = 0; i < w; i++) 100,
          for (var i = w; i < 10; i++) 0,
        ]
      ];
      final vu = List.filled(w * (h ~/ 2), 150);
      final out = tightPackFrame(
          planes: [
            PlaneBytes(bytes: y, bytesPerRow: 10, bytesPerPixel: 1),
            PlaneBytes(
                bytes: vu,
                bytesPerRow: w ~/ 2,
                bytesPerPixel: 2),
          ],
          width: w,
          height: h,
          kind: FrameLayoutKind.nv21Interleaved);
      expect(out, isNotNull);
      expect(out!.length, w * h * 3 ~/ 2);
      expect(out.contains(0), false);
      expect(out.sublist(0, w), List.filled(w, 100));
      expect(out.sublist(w * h), List.filled(w * (h ~/ 2), 150));
    });
  });

  group('nv21LumaOnly synthesizes neutral chroma', () {
    test('refineLayout routes single Y plane by group', () {
      const w = 16, h = 8;
      for (final g in ['nv21', 'yuv420']) {
        final l = refineLayout(
            planeCount: 1,
            planeLengths: [w * h],
            width: w,
            height: h,
            formatGroupName: g);
        expect(l.kind, FrameLayoutKind.nv21LumaOnly,
            reason: 'group=$g');
        expect(l.usePlanes, [0]);
        expect(l.mlFormatName, 'nv21');
      }
      // Same short buffer in a bgra group is NOT luma: stays unknown.
      final b = refineLayout(
          planeCount: 1,
          planeLengths: [w * h],
          width: w,
          height: h,
          formatGroupName: 'bgra8888');
      expect(b.kind, FrameLayoutKind.unknown);
    });

    test('oversized single NV21 plane routes to luma (field case)', () {
      // Observed: 720x480 NV21, 1 plane, 541,392 bytes (padded/strided,
      // neither luma-exact nor packed-exact). Scaled replica here.
      const w = 16, h = 8;
      final l = refineLayout(
          planeCount: 1,
          planeLengths: [w * h + 57],
          width: w,
          height: h,
          formatGroupName: 'nv21');
      expect(l.kind, FrameLayoutKind.nv21LumaOnly);
      expect(l.usePlanes, [0]);
      // Below luma size stays unsupported (nothing to detect with).
      final s = refineLayout(
          planeCount: 1,
          planeLengths: [w * h - 1],
          width: w,
          height: h,
          formatGroupName: 'nv21');
      expect(s.kind, FrameLayoutKind.unknown);
      expect(s.usePlanes, isEmpty);
    });

    test('isTightLayout never passes luma-only through raw', () {
      const w = 16, h = 8;
      expect(
          isTightLayout(
              kind: FrameLayoutKind.nv21LumaOnly,
              planes: [
                PlaneBytes(
                    bytes: List.filled(w * h, 90), bytesPerRow: w),
              ],
              width: w,
              height: h),
          false);
    });

    test('packs real Y plus 128 chroma at canonical length', () {
      const w = 8, h = 4;
      final y = List<int>.generate(w * h, (i) => i % 200);
      final out = tightPackFrame(
          planes: [PlaneBytes(bytes: y, bytesPerRow: w)],
          width: w,
          height: h,
          kind: FrameLayoutKind.nv21LumaOnly);
      expect(out, isNotNull);
      expect(out!.length, w * h + w * (h ~/ 2));
      expect(out.sublist(0, w * h), y);
      expect(out.sublist(w * h).every((b) => b == 128), true);
    });

    test('padded Y still packs row-wise before synthesis', () {
      const w = 8, h = 4;
      final y = [
        for (var r = 0; r < h; r++) ...[
          for (var i = 0; i < w; i++) 60,
          for (var i = w; i < 12; i++) 0,
        ]
      ];
      final out = tightPackFrame(
          planes: [PlaneBytes(bytes: y, bytesPerRow: 12)],
          width: w,
          height: h,
          kind: FrameLayoutKind.nv21LumaOnly);
      expect(out, isNotNull);
      expect(out!.length, w * h + w * (h ~/ 2));
      expect(out.contains(0), false);
    });

    test('oversized plane with trailing junk extracts clean Y', () {
      // Replica of the 541,392-byte field frame: strided rows plus
      // trailing bytes that must be ignored, never parsed.
      const w = 8, h = 4;
      final plane = [
        for (var r = 0; r < h; r++) ...[
          for (var i = 0; i < w; i++) 60 + r,
          for (var i = w; i < 10; i++) 0,
        ],
        for (var i = 0; i < 57; i++) 7,
      ];
      final out = tightPackFrame(
          planes: [PlaneBytes(bytes: plane, bytesPerRow: 10)],
          width: w,
          height: h,
          kind: FrameLayoutKind.nv21LumaOnly);
      expect(out, isNotNull);
      expect(out!.length, w * h + w * (h ~/ 2));
      for (var r = 0; r < h; r++) {
        expect(out.sublist(r * w, r * w + w), List.filled(w, 60 + r));
      }
      expect(out.sublist(w * h).every((b) => b == 128), true);
    });

    test('short Y returns null, never partial', () {
      expect(
          tightPackFrame(
              planes: [
                PlaneBytes(bytes: List.filled(10, 1), bytesPerRow: 8),
              ],
              width: 8,
              height: 4,
              kind: FrameLayoutKind.nv21LumaOnly),
          isNull);
      expect(
          tightPackFrame(
              planes: [],
              width: 8,
              height: 4,
              kind: FrameLayoutKind.nv21LumaOnly),
          isNull);
    });
  });

  group('packLumaFallback rescues Y when chroma is unreadable', () {
    test('good Y plus garbage chroma yields canonical NV21', () {
      // The cross-device case that used to kill whole frames: Y intact,
      // chroma short with a lying stride. Luma preserved, chroma neutral.
      const w = 8, h = 4;
      final y = List<int>.generate(w * h, (i) => 50 + (i % 100));
      final out = packLumaFallback(
          planes: [
            PlaneBytes(bytes: y, bytesPerRow: w),
            PlaneBytes(bytes: List.filled(3, 9), bytesPerRow: 0),
          ],
          width: w,
          height: h);
      expect(out, isNotNull);
      expect(out!.length, w * h * 3 ~/ 2);
      expect(out.sublist(0, w * h), y);
      expect(out.sublist(w * h).every((b) => b == 128), true);
    });

    test('padded Y packs row-wise before synthesis', () {
      const w = 8, h = 4;
      final y = [
        for (var r = 0; r < h; r++) ...[
          for (var i = 0; i < w; i++) 70,
          for (var i = w; i < 11; i++) 0,
        ]
      ];
      final out = packLumaFallback(
          planes: [PlaneBytes(bytes: y, bytesPerRow: 11)],
          width: w,
          height: h);
      expect(out, isNotNull);
      expect(out!.length, w * h * 3 ~/ 2);
      expect(out.contains(0), false);
    });

    test('unreadable Y returns null (nothing honest remains)', () {
      expect(
          packLumaFallback(
              planes: [
                PlaneBytes(bytes: List.filled(5, 1), bytesPerRow: 8),
              ],
              width: 8,
              height: 4),
          isNull);
      expect(
          packLumaFallback(planes: [], width: 8, height: 4), isNull);
    });
  });

  group('absurd dimensions are refused before allocating', () {
    test('tightPackFrame huge dims return null', () {
      const w = 1 << 20, h = 1 << 20;
      expect(
          tightPackFrame(
              planes: [
                PlaneBytes(bytes: [1, 2, 3], bytesPerRow: w),
                PlaneBytes(bytes: [4, 5, 6], bytesPerRow: w),
              ],
              width: w,
              height: h,
              kind: FrameLayoutKind.nv21Interleaved),
          isNull);
    });

    test('packLumaFallback huge dims return null', () {
      expect(
          packLumaFallback(
              planes: [
                PlaneBytes(bytes: [1, 2, 3], bytesPerRow: 8),
              ],
              width: 1 << 20,
              height: 1 << 20),
          isNull);
    });

    test('4K-class frames still accepted (cap is for garbage only)', () {
      // 3840x2160 = 8.3 MP < 16 MP cap: Y-only synthesis works.
      const w = 3840, h = 2160;
      final out = packLumaFallback(
          planes: [
            PlaneBytes(bytes: List.filled(w * h, 100), bytesPerRow: w),
          ],
          width: w,
          height: h);
      expect(out, isNotNull);
      expect(out!.length, w * h + w * (h ~/ 2));
    });
  });

  group('shouldLatchFormatFallback (converter-NPE escape)', () {
    test('latches on persistent converter failure with zero analyzed', () {
      // M4: first rung fires at 5 for pure converter errors (same luma,
      // only the declaration changes), so broken devices escape sooner.
      expect(
          shouldLatchFormatFallback(
              consecMlErrors: 5,
              framesProcessed: 0,
              alreadyLatched: false,
              converterError: true),
          true);
      expect(
          shouldLatchFormatFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              alreadyLatched: false,
              converterError: true),
          true);
      expect(
          shouldLatchFormatFallback(
              consecMlErrors: 25,
              framesProcessed: 0,
              alreadyLatched: false,
              converterError: true),
          true);
    });
    test('never latches twice, early, after success, or off-converter', () {
      // Already latched -> standard mlDegraded path takes over.
      expect(
          shouldLatchFormatFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              alreadyLatched: true,
              converterError: true),
          false);
      // Below the fast first-rung gate (M4: 5, not 10).
      expect(
          shouldLatchFormatFallback(
              consecMlErrors: 4,
              framesProcessed: 0,
              alreadyLatched: false,
              converterError: true),
          false);
      // Frames flow: no declaration problem.
      expect(
          shouldLatchFormatFallback(
              consecMlErrors: 10,
              framesProcessed: 3,
              alreadyLatched: false,
              converterError: true),
          false);
      // Non-converter ML failure (e.g. model): YV12 would not help.
      expect(
          shouldLatchFormatFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              alreadyLatched: false,
              converterError: false),
          false);
    });
  });

  group('classifyMlFailure (M8 typed taxonomy)', () {
    test('converter code wins', () {
      expect(
          classifyMlFailure(
              'PlatformException(InputImageConverterError, Failed, null, null)'),
          MlFailureKind.converter);
    });
    test('obfuscated detector NPE routes to detector rung', () {
      expect(
          classifyMlFailure(
              'PlatformException(error, Attempt to invoke virtual method '
              "'java.lang.Class java.lang.Object.getClass()' on a null "
              'object reference, null, java.lang.NullPointerException: '
              'Attempt to invoke virtual method)'),
          MlFailureKind.detector);
    });
    test('anything else is unknown (keeps detector-rung eligibility)', () {
      expect(classifyMlFailure('StateError: bitmap-encode failed'),
          MlFailureKind.unknown);
      expect(classifyMlFailure(''), MlFailureKind.unknown);
    });
  });

  group('nativePrimaryDue (native-first session gate)', () {
    bool gate({
      int startAt = 0,
      bool nativeActive = false,
      bool nativeFailed = false,
      bool suppressed = false,
      bool manualDart = false,
      bool disposed = false,
    }) =>
        nativePrimaryDue(
          startAt: startAt,
          nativeActive: nativeActive,
          nativeFailed: nativeFailed,
          suppressed: suppressed,
          manualDart: manualDart,
          disposed: disposed,
        );
    test('fresh entry attempts native first', () {
      expect(gate(), true);
    });
    test('Dart-chain retries never bounce back into native', () {
      expect(gate(startAt: 1), false);
      expect(gate(startAt: 3), false);
    });
    test('active, failed, suppressed, or pinned-Dart sessions skip', () {
      expect(gate(nativeActive: true), false);
      expect(gate(nativeFailed: true), false);
      expect(gate(suppressed: true), false);
      expect(gate(manualDart: true), false);
      expect(gate(disposed: true), false);
    });
  });

  group('shouldLatchBitmapFallback (RGBA-bitmap input rung)', () {
    test('latches on persistent converter failure under YV12', () {
      expect(
          shouldLatchBitmapFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: false,
              converterError: true),
          true);
    });
    test('stays off in every other case', () {
      // YV12 rung not engaged yet: declaration fallback goes first.
      expect(
          shouldLatchBitmapFallback(
              consecMlErrors: 50,
              framesProcessed: 0,
              yv12Latched: false,
              bitmapLatched: false,
              converterError: true),
          false);
      // Already latched / below gate / flowing / non-converter.
      expect(
          shouldLatchBitmapFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: true,
              converterError: true),
          false);
      expect(
          shouldLatchBitmapFallback(
              consecMlErrors: 9,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: false,
              converterError: true),
          false);
      expect(
          shouldLatchBitmapFallback(
              consecMlErrors: 10,
              framesProcessed: 2,
              yv12Latched: true,
              bitmapLatched: false,
              converterError: true),
          false);
      expect(
          shouldLatchBitmapFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: false,
              converterError: false),
          false);
    });
  });

  group('shouldLatchDetectorFallback (minimal-detector probe)', () {
    test('latches on persistent detector-internal failure after file rung',
        () {
      expect(
          shouldLatchDetectorFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              fileLatched: true,
              bitmapLatched: false,
              detectorLatched: false,
              converterError: false,
              detectorError: true),
          true);
    });
    test('bitmap rung alone also arms the detector probe', () {
      expect(
          shouldLatchDetectorFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              fileLatched: false,
              bitmapLatched: true,
              detectorLatched: false,
              converterError: false,
              detectorError: true),
          true);
    });
    test('stays off in every other case', () {
      // No input rung engaged yet: earlier rungs go first.
      expect(
          shouldLatchDetectorFallback(
              consecMlErrors: 50,
              framesProcessed: 0,
              fileLatched: false,
              bitmapLatched: false,
              detectorLatched: false,
              converterError: false,
              detectorError: true),
          false);
      // Already minimal: mlDegraded takes over.
      expect(
          shouldLatchDetectorFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              fileLatched: true,
              bitmapLatched: false,
              detectorLatched: true,
              converterError: false,
              detectorError: true),
          false);
      // Converter-class error: declaration rungs own those.
      expect(
          shouldLatchDetectorFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              fileLatched: true,
              bitmapLatched: false,
              detectorLatched: false,
              converterError: true,
              detectorError: false),
          false);
      // Below gate / frames flowing.
      expect(
          shouldLatchDetectorFallback(
              consecMlErrors: 9,
              framesProcessed: 0,
              fileLatched: true,
              bitmapLatched: false,
              detectorLatched: false,
              converterError: false,
              detectorError: true),
          false);
      expect(
          shouldLatchDetectorFallback(
              consecMlErrors: 10,
              framesProcessed: 1,
              fileLatched: true,
              bitmapLatched: false,
              detectorLatched: false,
              converterError: false,
              detectorError: true),
          false);
    });
  });

  group('mlAttemptDue (degraded backoff)', () {    final t0 = DateTime(2026, 9, 29, 12, 0, 0);
    test('healthy pipeline always attempts', () {
      expect(
          mlAttemptDue(
              consecErrors: 0,
              framesProcessed: 0,
              now: t0,
              lastAttempt: t0),
          true);
      expect(
          mlAttemptDue(
              consecErrors: 9,
              framesProcessed: 0,
              now: t0,
              lastAttempt: t0),
          true);
      expect(
          mlAttemptDue(
              consecErrors: 500,
              framesProcessed: 3,
              now: t0,
              lastAttempt: t0),
          true);
    });
    test('degraded with no prior attempt attempts at once', () {
      expect(
          mlAttemptDue(
              consecErrors: 10,
              framesProcessed: 0,
              now: t0,
              lastAttempt: null),
          true);
    });
    test('degraded throttles inside cooldown, releases after', () {
      expect(
          mlAttemptDue(
              consecErrors: 11,
              framesProcessed: 0,
              now: t0,
              lastAttempt: t0),
          false);
      expect(
          mlAttemptDue(
              consecErrors: 11,
              framesProcessed: 0,
              now: t0.add(const Duration(seconds: 1, milliseconds: 999)),
              lastAttempt: t0),
          false);
      expect(
          mlAttemptDue(
              consecErrors: 11,
              framesProcessed: 0,
              now: t0.add(const Duration(seconds: 2)),
              lastAttempt: t0),
          true);
      expect(
          mlAttemptDue(
              consecErrors: 11,
              framesProcessed: 0,
              now: t0.add(const Duration(milliseconds: 500)),
              lastAttempt: t0,
              cooldown: const Duration(milliseconds: 500)),
          true);
    });
  });

  group('nativeFailoverDue (exactly once until re-armed)', () {
    test('fires on first terminal failure', () {
      expect(
          nativeFailoverDue(
              nativeActive: false,
              attempted: false,
              exhausted: false,
              disposed: false),
          true);
    });
    test('never refires while active, attempted, exhausted, or disposed',
        () {
      expect(
          nativeFailoverDue(
              nativeActive: true,
              attempted: true,
              exhausted: false,
              disposed: false),
          false);
      expect(
          nativeFailoverDue(
              nativeActive: false,
              attempted: true,
              exhausted: false,
              disposed: false),
          false);
      expect(
          nativeFailoverDue(
              nativeActive: false,
              attempted: false,
              exhausted: true,
              disposed: false),
          false);
      expect(
          nativeFailoverDue(
              nativeActive: false,
              attempted: false,
              exhausted: false,
              disposed: true),
          false);
    });
  });

  group('detectorRecreateDue (bounded detector-recreation policy)', () {
    final t0 = DateTime(2026, 9, 29, 12, 0, 0);
    test('fires at the down gate with zero processed and budget left', () {
      expect(
          detectorRecreateDue(
              consecutiveErrors: 10,
              framesProcessed: 0,
              now: t0,
              lastRecreateAt: null,
              recreatesSoFar: 0),
          true);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 50,
              framesProcessed: 0,
              now: t0,
              lastRecreateAt: null,
              recreatesSoFar: 2),
          true);
    });
    test('stays off below the gate or while frames flow', () {
      expect(
          detectorRecreateDue(
              consecutiveErrors: 9,
              framesProcessed: 0,
              now: t0,
              lastRecreateAt: null,
              recreatesSoFar: 0),
          false);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 0,
              framesProcessed: 0,
              now: t0,
              lastRecreateAt: null,
              recreatesSoFar: 0),
          false);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 50,
              framesProcessed: 1,
              now: t0,
              lastRecreateAt: null,
              recreatesSoFar: 0),
          false);
    });
    test('min 5 s between recreates', () {
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0,
              lastRecreateAt: t0,
              recreatesSoFar: 1),
          false);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0.add(const Duration(seconds: 4, milliseconds: 999)),
              lastRecreateAt: t0,
              recreatesSoFar: 1),
          false);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0.add(const Duration(seconds: 5)),
              lastRecreateAt: t0,
              recreatesSoFar: 1),
          true);
    });
    test('max 3 recreates per session (then never again)', () {
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0.add(const Duration(seconds: 60)),
              lastRecreateAt: t0,
              recreatesSoFar: 2),
          true);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0.add(const Duration(seconds: 60)),
              lastRecreateAt: t0,
              recreatesSoFar: 3),
          false);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 999,
              framesProcessed: 0,
              now: t0.add(const Duration(minutes: 10)),
              lastRecreateAt: t0,
              recreatesSoFar: 4),
          false);
    });
    test('negative budget never fires; custom bounds respected', () {
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0,
              lastRecreateAt: null,
              recreatesSoFar: -1),
          false);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0,
              lastRecreateAt: null,
              recreatesSoFar: 1,
              maxRecreates: 1),
          false);
      expect(
          detectorRecreateDue(
              consecutiveErrors: 12,
              framesProcessed: 0,
              now: t0.add(const Duration(seconds: 1)),
              lastRecreateAt: t0,
              recreatesSoFar: 0,
              minInterval: const Duration(seconds: 1)),
          true);
    });
    test('bounds constants are explicit', () {
      expect(kDetectorRecreateAfterErrors, 10);
      expect(kMaxDetectorRecreatesPerSession, 3);
      expect(kMinDetectorRecreateInterval, const Duration(seconds: 5));
    });
  });
}
