// Vision core diagnostic (/dev/vision-core, Phase 1A Part 3).
//
// Three INDEPENDENT tests, always in order A -> B -> C, each on a fresh
// minimal detector (fast, landmarks on, classification/tracking/contours
// off) closed afterwards — except C, which drives the native CameraX
// engine through its own lifecycle and stops it afterwards.
//
// - TEST A: bundled REAL human face (assets/bundled_face.jpg — Eileen
//   Collins / NASA public domain, see tooling/bundled_face_provenance.md)
//   via InputImage.fromFilePath. No camera involved. EXPECTED:
//   FACE_DETECTED.
// - TEST B: still JPEG captured from the device camera right now, via
//   InputImage.fromFilePath. Skipped honestly when the camera is idle.
// - TEST C: live front-camera stream through NativeFaceEngine
//   (CameraX ImageAnalysis + native ML Kit), up to 12 s. First
//   faceFound observation wins; a classified error is PROCESSING_ERROR;
//   silence for the whole window is NO_FACE with the window noted.
//
// Vocabulary (never conflated):
// - FACE_DETECTED: engine ran, >= 1 face (box shown).
// - NO_FACE: engine ran clean, zero faces (or silent window for C).
// - PROCESSING_ERROR: the call threw — the engine is broken, NOT "no
//   face". Detail carries the short error; stacks ride the error export
//   via DIAG_VC_* log lines.
// - SKIPPED: harness-level, preconditions unmet (camera idle, asset
//   unreadable) — the detector never ran, so this is neither a pass
//   nor a failure of the engine.
//
// Medical-safety: infrastructure diagnosis only, no health claims.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/dev_strings.dart';
import '../../../features/camera/camera_pipeline.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/ml_diagnostic.dart';
import '../../../features/vision/face_detection_engine.dart';
import '../../../features/vision/native_face_engine.dart';
import '../../../features/vision/vision_session.dart';

class VisionCoreScreen extends StatefulWidget {
  const VisionCoreScreen({super.key});
  @override
  State<VisionCoreScreen> createState() => _VisionCoreScreenState();
}

class _VcResult {
  final String name;
  final VisionFaceStatus status;
  final String detail;
  final int elapsedMs;
  const _VcResult(this.name, this.status, this.detail, this.elapsedMs);
}

class _VisionCoreScreenState extends State<VisionCoreScreen> {
  bool _running = false;
  _VcResult? _a;
  _VcResult? _b;
  _VcResult? _c;

  /// Production full config from the canonical builder the live service
  /// uses (never a duplicate): oracle probes run this, never minimal —
  /// the fast detector missed the bundled portrait on-device (v0.7.18:
  /// clean 0-face call).
  FaceDetector _freshFullDetector() =>
      FaceDetector(options: liveDetectorOptions());

  String _boxLine(List<Face> faces) {
    final b = faces.first.boundingBox;
    return '${faces.length} face(s), box='
        '[${b.left.toStringAsFixed(0)},${b.top.toStringAsFixed(0)},'
        '${b.right.toStringAsFixed(0)},${b.bottom.toStringAsFixed(0)}]';
  }

  void _log(CameraService? cam, _VcResult r) {
    cam?.logDiag('DIAG_VC_${r.name}',
        '${r.status.name} ${r.detail} (${r.elapsedMs}ms)');
  }

  Future<File?> _bundledFile() async {
    final data = await rootBundle.load('assets/bundled_face.jpg');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/ocuscan-vision-core-a.jpg');
    // Exact bytes: ByteData.buffer may overhang the asset view.
    await f.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true);
    return f;
  }

  Future<_VcResult> _runFileTest(
    String name,
    Future<File?> Function() fileOf,
    String missingDetail,
  ) async {
    final t0 = DateTime.now();
    int ms() => DateTime.now().difference(t0).inMilliseconds;
    final detector = _freshFullDetector();
    try {
      final f = await fileOf();
      if (f == null) {
        return _VcResult(name, VisionFaceStatus.skipped, missingDetail, ms());
      }
      if (!mounted) {
        return _VcResult(name, VisionFaceStatus.skipped,
            'screen left before the call finished', ms());
      }
      late final List<Face> faces;
      try {
        faces = await detector.processImage(
            InputImage.fromFilePath(f.path));
      } finally {
        try {
          await File(f.path).delete();
        } catch (_) {}
      }
      if (faces.isEmpty) {
        return _VcResult(
            name, VisionFaceStatus.noFace, 'clean call, 0 faces', ms());
      }
      return _VcResult(
          name, VisionFaceStatus.faceFound, _boxLine(faces), ms());
    } catch (e) {
      return _VcResult(
          name, VisionFaceStatus.processingError, shortError(e), ms());
    } finally {
      try {
        await detector.close();
      } catch (_) {}
    }
  }

  Future<void> _runA(CameraService? cam) async {
    setState(() => _a = null);
    final item = await _runFileTest(
        'A', _bundledFile, 'bundled asset unreadable');
    if (!mounted) return;
    setState(() => _a = item);
    _log(cam, item);
  }

  Future<void> _runB(CameraService? cam) async {
    setState(() => _b = null);
    if (cam == null || !cam.ready) {
      const item = _VcResult('B', VisionFaceStatus.skipped,
          'camera idle — start the Eyes stage stream first', 0);
      if (!mounted) return;
      setState(() => _b = item);
      _log(cam, item);
      return;
    }
    final item = await _runFileTest('B', () async {
      final file = await cam.captureStill();
      return file == null ? null : File(file.path);
    }, 'capture returned nothing');
    if (!mounted) return;
    setState(() => _b = item);
    _log(cam, item);
  }

  /// TEST C: live front stream through the native engine with its own
  /// VisionSession bookkeeping (PART 10 lifecycle, single-flight by
  /// construction: one observation stream, first result wins, then
  /// stop — never overlapping sessions).
  Future<void> _runC(CameraService? cam) async {
    setState(() => _c = null);
    final t0 = DateTime.now();
    int ms() => DateTime.now().difference(t0).inMilliseconds;
    final engine = NativeFaceEngine();
    var session = const VisionSession(sessionId: 'vision-core-C')
        .withCamera(VisionCameraState.starting)
        .withDetector(VisionDetectorState.creating);
    try {
      await engine.start(front: true);
      session = session
          .withCamera(VisionCameraState.ready)
          .withDetector(VisionDetectorState.ready)
          .nextGeneration();
      final first = await engine.observations
          .timeout(const Duration(seconds: 12))
          .first;
      session = session.touchFrame(first.time);
      final status = visionFaceStatus(first);
      final detail = status == VisionFaceStatus.faceFound
          ? 'live box='
              '[${first.faceBox?.left.toStringAsFixed(0)},'
              '${first.faceBox?.top.toStringAsFixed(0)},'
              '${first.faceBox?.right.toStringAsFixed(0)},'
              '${first.faceBox?.bottom.toStringAsFixed(0)}] '
              'gen=${first.generation}'
          : status == VisionFaceStatus.noFace
              ? 'silent 12 s window: stream alive, no face reported'
              : shortError(first.error ?? 'native observation error');
      final item = _VcResult('C', status, detail, ms());
      if (!mounted) return;
      setState(() => _c = item);
      _log(cam, item);
    } on TimeoutException {
      const item = _VcResult('C', VisionFaceStatus.noFace,
          'silent 12 s window: stream alive, no face reported', 0);
      if (!mounted) return;
      setState(() => _c = item);
      _log(cam, item);
    } catch (e) {
      final item = _VcResult(
          'C', VisionFaceStatus.processingError, shortError(e), ms());
      if (!mounted) return;
      setState(() => _c = item);
      _log(cam, item);
    } finally {
      try {
        await engine.stop();
      } catch (_) {}
      session = session.close();
    }
  }

  Future<void> _runAll() async {
    if (_running) return;
    setState(() {
      _running = true;
      _a = _b = _c = null;
    });
    CameraService? cam;
    try {
      cam = context.read<CameraService>();
    } catch (_) {}
    await _runA(cam);
    if (!mounted) return;
    await _runB(cam);
    if (!mounted) return;
    await _runC(cam);
    if (!mounted) return;
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings.of(context);
    final t = Theme.of(context).textTheme;
    final items = [_a, _b, _c].nonNulls.toList();
    return Scaffold(
      appBar: AppBar(title: Text(s.vcTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(s.vcBody, style: t.bodyMedium),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _running ? null : _runAll,
          icon: const Icon(Icons.play_arrow_outlined),
          label: Text(_running ? s.mlTestRunning : s.mlRunAll),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty && !_running)
          Text(s.mlNoResults, style: t.bodySmall),
        for (final item in items)
          Card(
            child: ListTile(
              title: Text('TEST ${item.name} — ${item.status.name}'),
              subtitle: Text(
                  '${item.detail}\n${item.elapsedMs} ms'),
            ),
          ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(s.mlExportNote, style: t.bodySmall),
        ],
      ]),
    );
  }
}
