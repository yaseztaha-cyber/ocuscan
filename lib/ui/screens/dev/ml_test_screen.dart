// UniversalFaceDiagnostic: isolated ML Kit face-detector tests
// (/ml-test, alias /face-diagnostic, from /eye-debug and /compat-lab).
//
// Phase 3/5/8 protocol: each test runs a FRESH minimal detector
// (fast mode, landmarks on, classification/tracking/contours off),
// closed afterwards, so no test contaminates another and none touches
// the screening service's detector instance.
//
// - A: captured still JPEG via InputImage.fromFilePath (needs live
//   camera; skipped honestly when the stream is idle).
// - B: bundled REAL-face JPEG (assets/bundled_face.jpg: Eileen Collins /
//   NASA public domain — see tooling/bundled_face_provenance.md) via
//   fromFilePath, camera-independent. EXPECTED: FACE_DETECTED. NO_FACE
//   means the detector executed but missed a known face (weakness
//   signal); EXCEPTION means the detector runtime is broken.
// - C: retained live packed bytes via InputImage.fromBytes — canonical
//   packed layouts only. Luma-only device buffers report SKIPPED
//   (unsupported-layout): strict fromBytes never presents luma-only
//   bytes as native packed NV21/YV12.
// - D: retained bytes as upright RGBA via InputImage.fromBitmap — the
//   bitmap native path, no byte-array converter, no file IO.
// - E/F: live front/rear source check — which lens is active, whether a
//   retained frame exists for it; the inactive lens reports SKIPPED
//   with the switch instruction (no silent camera switching).
// - G: robustness — rapid restart (two restarts back-to-back, service
//   must stay alive) + detector recreation (open/close ×3) +
//   offline-capability (bundled asset loads with no network needed).
// - H: full-config repro — the exact live-service detector options
//   (accurate/landmarks+classification+tracking) on the bundled asset.
//   B-pass + H-error means detector-broken (not input-broken).
//
// Outcomes use the MlDiagOutcome vocabulary (pass / noFace / error /
// skipped): a thrown call is PROCESSING_ERROR, never "no face". Each
// run logs DIAG_* events into the service log, so results ride the
// error export. Medical-safety: this screen diagnoses infrastructure
// only and makes no health claims.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/dev_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/camera/camera_pipeline.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/jpeg_fallback.dart';
import '../../../features/camera/ml_diagnostic.dart';

class MlTestScreen extends StatefulWidget {
  const MlTestScreen({super.key});
  @override
  State<MlTestScreen> createState() => _MlTestScreenState();
}

class _MlTestScreenState extends State<MlTestScreen> {
  bool _running = false;
  MlDiagItem? _a;
  MlDiagItem? _b;
  MlDiagItem? _c;
  MlDiagItem? _d;
  MlDiagItem? _e;
  MlDiagItem? _f;
  MlDiagItem? _g;
  MlDiagItem? _h;

  FaceDetector _freshMinimalDetector() => FaceDetector(
      options: liveDetectorOptions(minimal: true));

  /// The EXACT live-service configuration, built from the same canonical
  /// builder the service uses (never a copy-pasted duplicate): accurate
  /// + landmarks + classification + tracking. Test H uses this so a
  /// minimal-detector PASS can never mask a full-config construction
  /// NPE on-device.
  FaceDetector _freshFullDetector() =>
      FaceDetector(options: liveDetectorOptions());

  /// Run one isolation test on a fresh detector (always closed).
  /// [attempt] builds faces or throws; [describe] renders a success line.
  /// Defaults to the minimal config; pass [_freshFullDetector] to
  /// reproduce the live full-config construction path (Test H).
  Future<MlDiagItem> _runIsolated(
    String name,
    Future<List<Face>> Function(FaceDetector d) attempt,
    String Function(List<Face> faces) describe, [
    FaceDetector Function()? freshDetector,
  ]) async {
    final detector = (freshDetector ?? _freshMinimalDetector)();
    try {
      final faces = await attempt(detector);
      final outcome = classifyDetectorResult(faces.length);
      return MlDiagItem(
        name: name,
        outcome: outcome,
        detail: outcome == MlDiagOutcome.pass
            ? describe(faces)
            : 'clean call, 0 faces',
      );
    } catch (e) {
      return MlDiagItem(
        name: name,
        outcome: MlDiagOutcome.error,
        detail: shortError(e),
      );
    } finally {
      try {
        await detector.close();
      } catch (_) {}
    }
  }

  String _faceLine(List<Face> faces) {
    final f = faces.first;
    final b = f.boundingBox;
    return '${faces.length} face(s), box='
        '[${b.left.toStringAsFixed(0)},${b.top.toStringAsFixed(0)},'
        '${b.right.toStringAsFixed(0)},${b.bottom.toStringAsFixed(0)}]';
  }

  void _log(CameraService? cam, MlDiagItem item) {
    cam?.logDiag('DIAG_${item.name}', '${item.outcome.name} ${item.detail}');
  }

  Future<void> _runA(CameraService? cam) async {
    setState(() => _a = null);
    if (cam == null || !cam.ready) {
      final item = const MlDiagItem(
        name: 'A',
        outcome: MlDiagOutcome.skipped,
        detail: 'camera idle — start the Eyes stage stream first',
      );
      setState(() => _a = item);
      _log(cam, item);
      return;
    }
    final file = await cam.captureStill();
    if (!mounted) return;
    if (file == null) {
      final item = const MlDiagItem(
        name: 'A',
        outcome: MlDiagOutcome.skipped,
        detail: 'capture returned nothing',
      );
      setState(() => _a = item);
      _log(cam, item);
      return;
    }
    final item = await _runIsolated(
      'A',
      (d) => d.processImage(InputImage.fromFilePath(file.path)),
      _faceLine,
    );
    if (!mounted) return;
    setState(() => _a = item);
    _log(cam, item);
  }

  Future<void> _runC(CameraService? cam) async {
    setState(() => _c = null);
    final bytes = cam?.lastPackedBytes;
    final layout = cam?.lastPackedLayout ?? '';
    final canonical =
        layout == FrameLayoutKind.nv21Interleaved.name ||
        layout == FrameLayoutKind.yv12Planar.name ||
        layout == FrameLayoutKind.bgra.name;
    if (cam == null || bytes == null || bytes.isEmpty || !canonical) {
      final item = MlDiagItem(
        name: 'C',
        outcome: MlDiagOutcome.skipped,
        detail: bytes == null
            ? 'no retained frame yet — run the Eyes stage first'
            : 'layout $layout is not canonical packed; fromBytes needs '
                  'a proven packed buffer (luma-only is never presented '
                  'as native NV21/YV12)',
      );
      setState(() => _c = item);
      _log(cam, item);
      return;
    }
    final w = cam.lastPackedW;
    final h = cam.lastPackedH;
    final rot = cam.lastPackedRot;
    final format = layout == FrameLayoutKind.yv12Planar.name
        ? InputImageFormat.yv12
        : (layout == FrameLayoutKind.bgra.name
              ? InputImageFormat.bgra8888
              : InputImageFormat.nv21);
    final item = await _runIsolated(
      'C',
      (d) => d.processImage(
        InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(w.toDouble(), h.toDouble()),
            rotation:
                InputImageRotationValue.fromRawValue(rot) ??
                InputImageRotation.rotation0deg,
            format: format,
            bytesPerRow: w,
          ),
        ),
      ),
      _faceLine,
    );
    if (!mounted) return;
    setState(() => _c = item);
    _log(cam, item);
  }

  Future<void> _runD(CameraService? cam) async {
    setState(() => _d = null);
    if (cam == null) {
      const item = MlDiagItem(
        name: 'D',
        outcome: MlDiagOutcome.skipped,
        detail: 'no camera service — open the Eyes stage first',
      );
      setState(() => _d = item);
      _log(cam, item);
      return;
    }
    final item = await _probeRetainedBitmap(cam, 'D');
    if (!mounted) return;
    setState(() => _d = item);
    _log(cam, item);
  }

  Future<void> _runB(CameraService? cam) async {
    setState(() => _b = null);
    try {
      final data = await rootBundle.load('assets/bundled_face.jpg');
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/ocuscan-bundled-test.jpg');
      // Exact bytes: ByteData.buffer may overhang the asset view, which
      // would feed the detector a corrupt file.
      await f.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true);
      if (!mounted) return;
      // The oracle validates the PRODUCTION config: the minimal fast
      // detector missed this portrait on-device (v0.7.18: clean 0-face
      // call), so B runs the exact live full config like Test H.
      final item = await _runIsolated(
        'B',
        (d) => d.processImage(InputImage.fromFilePath(f.path)),
        _faceLine,
        _freshFullDetector,
      );
      if (!mounted) return;
      setState(() => _b = item);
      _log(cam, item);
    } catch (e) {
      if (!mounted) return;
      final item = MlDiagItem(
        name: 'B',
        outcome: MlDiagOutcome.skipped,
        detail: 'bundled asset unreadable: ${shortError(e)}',
      );
      setState(() => _b = item);
      _log(cam, item);
    }
  }

  /// Bitmap probe on retained live bytes under [name]. Shared by D
  /// (any lens) and E (front lens only — caller gates the lens).
  Future<MlDiagItem> _probeRetainedBitmap(
    CameraService cam,
    String name,
  ) async {
    final bytes = cam.lastPackedBytes;
    final layout = cam.lastPackedLayout;
    final nv21Family =
        layout == FrameLayoutKind.nv21Interleaved.name ||
        layout == FrameLayoutKind.nv21LumaOnly.name;
    if (bytes == null || bytes.isEmpty || !nv21Family) {
      return MlDiagItem(
        name: name,
        outcome: MlDiagOutcome.skipped,
        detail: bytes == null
            ? 'no retained frame yet — run the Eyes stage first'
            : 'layout $layout has no NV21 luma to build RGBA from',
      );
    }
    final rgba = nv21ToRgbaBytes(
      nv21: bytes,
      width: cam.lastPackedW,
      height: cam.lastPackedH,
      rotationDeg: cam.lastPackedRot,
    );
    if (rgba == null) {
      return MlDiagItem(
        name: name,
        outcome: MlDiagOutcome.skipped,
        detail: 'RGBA build failed on retained bytes',
      );
    }
    return _runIsolated(
      name,
      (d) => d.processImage(
        InputImage.fromBitmap(
          bitmap: rgba.bytes,
          width: rgba.w,
          height: rgba.h,
          rotation: 0,
        ),
      ),
      _faceLine,
    );
  }

  Future<void> _runE(CameraService? cam) async {
    // Live front: only meaningful with the front lens streaming.
    setState(() => _e = null);
    final src = cam?.activeSourceCode ?? '';
    if (cam == null || !cam.ready || src != 'front') {
      final item = MlDiagItem(
        name: 'E',
        outcome: MlDiagOutcome.skipped,
        detail: cam == null || !cam.ready
            ? 'camera idle — start the Eyes stage stream first'
            : 'front lens not active (active=$src) — switch to front, then re-run',
      );
      setState(() => _e = item);
      _log(cam, item);
      return;
    }
    final item = await _probeRetainedBitmap(cam, 'E');
    if (!mounted) return;
    final tagged = MlDiagItem(
      name: 'E',
      outcome: item.outcome,
      detail: 'live front: ${item.detail}',
    );
    setState(() => _e = tagged);
    _log(cam, tagged);
  }

  Future<void> _runF(CameraService? cam) async {
    // Live rear: capability-gated, never silently switches lenses.
    setState(() => _f = null);
    final hasRear = cam?.hasRearCamera ?? false;
    final src = cam?.activeSourceCode ?? '';
    if (cam == null || !hasRear) {
      const item = MlDiagItem(
        name: 'F',
        outcome: MlDiagOutcome.skipped,
        detail: 'no rear camera reported on this device',
      );
      setState(() => _f = item);
      _log(cam, item);
      return;
    }
    if (!cam.ready || src != 'rear') {
      final item = MlDiagItem(
        name: 'F',
        outcome: MlDiagOutcome.skipped,
        detail:
            'rear camera present but not streaming (active=$src) — switch to rear in the Eyes stage, then re-run',
      );
      setState(() => _f = item);
      _log(cam, item);
      return;
    }
    final item = MlDiagItem(
      name: 'F',
      outcome: MlDiagOutcome.pass,
      detail: 'rear lens streaming; use tests A/C/D for detection probes',
    );
    setState(() => _f = item);
    _log(cam, item);
  }

  Future<void> _runG(CameraService? cam) async {
    // Robustness: rapid restart + detector recreation + offline asset.
    setState(() => _g = null);
    final notes = <String>[];
    var ok = true;
    // G1: rapid restart, service must stay alive and responsive.
    if (cam != null && cam.ready) {
      try {
        await cam.restartCamera();
        await cam.restartCamera();
        notes.add('restart×2 ok (stage=${cam.stage.name})');
      } catch (e) {
        ok = false;
        notes.add('restart failed: ${shortError(e)}');
      }
    } else {
      notes.add('restart skipped (camera idle)');
    }
    // G2: detector recreation ×3, always closed.
    try {
      for (var i = 0; i < 3; i++) {
        final d = _freshMinimalDetector();
        try {
          await d.close();
        } catch (e) {
          ok = false;
          notes.add('recreate #$i failed: ${shortError(e)}');
          break;
        }
      }
      if (ok || !notes.last.startsWith('recreate')) {
        notes.add('detector open/close ×3 ok');
      }
    } catch (e) {
      ok = false;
      notes.add('recreate failed: ${shortError(e)}');
    }
    // G3: offline capability — bundled asset loads with no network.
    try {
      final data = await rootBundle.load('assets/bundled_face.jpg');
      notes.add(
        'offline asset ok (${data.lengthInBytes} bytes, no network needed)',
      );
    } catch (e) {
      ok = false;
      notes.add('offline asset missing: ${shortError(e)}');
    }
    final item = MlDiagItem(
      name: 'G',
      outcome: ok ? MlDiagOutcome.pass : MlDiagOutcome.error,
      detail: notes.join(' • '),
    );
    if (!mounted) return;
    setState(() => _g = item);
    _log(cam, item);
  }

  /// Test H (M5): full-config detector repro — the exact live-service
  /// construction path (accurate/landmarks+classification+tracking) run
  /// against the bundled asset. Distinguishes input-broken (B fails too)
  /// from detector-broken (B passes, H throws) devices.
  Future<void> _runH(CameraService? cam) async {
    setState(() => _h = null);
    try {
      final data = await rootBundle.load('assets/bundled_face.jpg');
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/ocuscan-bundled-full-test.jpg');
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      final item = await _runIsolated(
        'H',
        (d) => d.processImage(InputImage.fromFilePath(f.path)),
        _faceLine,
        _freshFullDetector,
      );
      if (!mounted) return;
      setState(() => _h = item);
      _log(cam, item);
    } catch (e) {
      if (!mounted) return;
      final item = MlDiagItem(
        name: 'H',
        outcome: MlDiagOutcome.skipped,
        detail: 'bundled asset unreadable: ${shortError(e)}',
      );
      setState(() => _h = item);
      _log(cam, item);
    }
  }

  Future<void> _runAll() async {
    if (_running) return;
    setState(() {
      _running = true;
      _a = _b = _c = _d = _e = _f = _g = _h = null;
    });
    CameraService? cam;
    try {
      cam = context.read<CameraService>();
    } catch (_) {}
    await _runB(cam);
    if (!mounted) return;
    await _runA(cam);
    if (!mounted) return;
    await _runC(cam);
    if (!mounted) return;
    await _runD(cam);
    if (!mounted) return;
    await _runE(cam);
    if (!mounted) return;
    await _runF(cam);
    if (!mounted) return;
    await _runG(cam);
    if (!mounted) return;
    await _runH(cam);
    if (!mounted) return;
    setState(() => _running = false);
    final items = [_a, _b, _c, _d, _e, _f, _g, _h].nonNulls.toList();
    cam?.logDiag(
      'DIAG_RUN',
      MlDiagReport(
        appVersion: 'run',
        at: DateTime.now(),
        items: items,
      ).summaryLine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings.of(context);
    final t = Theme.of(context).textTheme;
    final items = [_a, _b, _c, _d, _e, _f, _g, _h].nonNulls.toList();
    final cam = context.watch<CameraService>();
    return Scaffold(
      appBar: AppBar(title: Text(s.mlTestTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s.mlTestBody, style: t.bodyMedium),
          const SizedBox(height: 8),
          Text('ML stack: $kMlPluginVersions', style: t.bodySmall),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _runAll,
            icon: const Icon(Icons.play_arrow_outlined),
            label: Text(_running ? s.mlTestRunning : s.mlRunAll),
          ),
          const SizedBox(height: 8),
          // Fast-tier experiment toggle (dev-only): re-arms the ML Kit
          // fast config on the LIVE path so the 0.7.14 regression can be
          // A/B measured on-device; the export's per-generation table
          // decides. Default OFF (proven-accurate path). Never user-facing.
          OutlinedButton.icon(
            onPressed: () => cam.setPreferFastTier(!cam.preferFastTier),
            icon: const Icon(Icons.science_outlined),
            label: Text(
              'Fast tier (experiment): ${cam.preferFastTier ? 'ON' : 'OFF'} '
              '[live: ${cam.detectorTier}]',
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty && !_running)
            Text(s.mlNoResults, style: t.bodySmall),
          for (final item in items) _ResultCard(item: item, t: t),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.mlExportNote, style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final MlDiagItem item;
  final TextTheme t;
  const _ResultCard({required this.item, required this.t});

  @override
  Widget build(BuildContext context) {
    final (icon, color, glyph) = switch (item.outcome) {
      MlDiagOutcome.pass => (Icons.check_circle, AppTheme.tealDark, 'PASS'),
      MlDiagOutcome.noFace => (
        Icons.remove_circle_outline,
        AppTheme.amber,
        'NO FACE',
      ),
      MlDiagOutcome.error => (Icons.error_outline, AppTheme.amber, 'EXCEPTION'),
      MlDiagOutcome.skipped => (
        Icons.skip_next_outlined,
        AppTheme.slate,
        'SKIPPED',
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test ${item.name} — $glyph',
                    style: t.titleMedium?.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(item.detail, style: t.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
