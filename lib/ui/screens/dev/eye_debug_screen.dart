// Research-only Eye Tracking Debug (/eye-debug, from /dev Overview).
//
// Answers: is the model failing to detect the eyes, or are detected eyes
// transformed incorrectly? Shows the live camera with the reported
// geometry overlaid, the frame pipeline stage by stage (raw -> quality ->
// face box -> landmarks -> crops -> analyzer input), live thresholds, a
// still inspector (capture -> detect in still space -> overlay), and the
// frame log. Stills are deleted on exit. Never linked from consumer UI.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/dev_strings.dart';
import '../../../core/validation/experiment_models.dart';
import '../../../core/validation/validation_repository.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/eye_tracking.dart';
import '../../../main.dart';
import '../../widgets/common.dart';
import '../../widgets/eye_overlay.dart';

class EyeDebugScreen extends StatefulWidget {
  const EyeDebugScreen({super.key});
  @override
  State<EyeDebugScreen> createState() => _EyeDebugScreenState();
}

class _EyeDebugScreenState extends State<EyeDebugScreen> {
  CameraService? _camRef;
  String? _error;
  String? _stillPath;
  EyeGeometry? _stillGeo;
  Size _stillSize = Size.zero;
  Uint8List? _diagGray;
  int _diagW = 0;
  int _diagH = 0;
  int _diagRot = 0;
  String? _stillTestResult;
  List<String> _firstFramePaths = [];
  final Map<String, String> _camTests = {};

  @override
  void initState() {
    super.initState();
    _camRef = context.read<CameraService>();
    _camRef?.retainMlPreview = true;
    // Defer past the first frame: prepare() notifies listeners, which is
    // illegal synchronously inside initState (build phase).
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _camRef?.retainMlPreview = false;
    _camRef?.release();
    _deleteStill();
    super.dispose();
  }

  Future<void> _init() async {
    final cam = _camRef;
    if (cam == null) return;
    final ok = await cam.prepare();
    if (!mounted) return;
    if (!ok &&
        cam.lastPermission != null &&
        cam.lastPermission != CameraPermission.granted) {
      await explainCameraIssue(context, cam.lastPermission!, null);
      if (!mounted) return;
    }
    setState(() => _error = ok ? null : (cam.error ?? 'init failed'));
  }

  Future<void> _deleteStill() async {
    final p = _stillPath;
    _stillPath = null;
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
  }

  Future<void> _captureInspect() async {
    final cam = _camRef;
    if (cam == null || !cam.ready) return;
    await _deleteStill();
    if (!mounted) return;
    setState(() {
      _stillGeo = null;
    });
    final file = await cam.captureStill();
    if (file == null || !mounted) return;
    final geo = await cam.analyzeStill(file.path);
    if (!mounted) {
      try {
        await File(file.path).delete();
      } catch (_) {}
      return;
    }
    Size size = Size.zero;
    try {
      final data = await File(file.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      size = Size(
          frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
    } catch (_) {}
    setState(() {
      _stillPath = file.path;
      _stillGeo = geo;
      _stillSize = size;
      _stillTestResult = geo == null
          ? 'still=ok image=ok ml=FAIL (detector error)'
          : (geo.faceFound
              ? 'still=ok image=ok ml=ok faces=1'
              : 'still=ok image=ok ml=ok faces=0');
    });
  }

  /// Research-only diagnostic frame (§17): snapshot the retained ML-input
  /// grayscale bytes plus a still, so the creator can compare original vs
  /// converted ML input vs rotation-corrected view vs analyzer crops.
  Future<void> _saveDiagnosticFrame() async {
    final cam = _camRef;
    if (cam == null || !cam.ready) return;
    final gray = cam.lastMlGray;
    if (gray == null || !mounted) return;
    setState(() {
      _diagGray = Uint8List.fromList(gray);
      _diagW = cam.lastMlGrayW;
      _diagH = cam.lastMlGrayH;
      _diagRot = cam.lastMlGrayRot;
    });
    await _captureInspect();
  }

  Uint8List? _renderMlGray() {
    final g = _diagGray;
    if (g == null || _diagW <= 0 || _diagH <= 0) return null;
    try {
      if (g.length < _diagW * _diagH) return null;
      final im = img.Image(width: _diagW, height: _diagH);
      var k = 0;
      for (var y = 0; y < _diagH; y++) {
        for (var x = 0; x < _diagW; x++) {
          final v = g[k++];
          im.setPixelRgb(x, y, v, v, v);
        }
      }
      final up = img.copyRotate(im, angle: _diagRot.toDouble());
      return Uint8List.fromList(img.encodeJpg(up, quality: 70));
    } catch (_) {
      return null;
    }
  }

  /// Camera self-tests (§41): each performs a real check, no placeholders.
  Future<void> _runCamTest(String kind) async {
    final cam = _camRef;
    if (cam == null || !mounted) return;
    String result;
    switch (kind) {
      case 'preview':
        // Preview is renderable from either engine: the plugin
        // controller on the Dart path, the native texture under
        // native-primary (v0.7.18 read native sessions as FAIL).
        result = (cam.ready &&
                (cam.controller != null ||
                    cam.nativePreviewTextureId != null))
            ? 'PASS'
            : 'FAIL';
        break;
      case 'first':
        result = cam.firstFrameAt != null
            ? 'PASS ${cam.lastFrameSize.width.toInt()}x${cam.lastFrameSize.height.toInt()}'
            : 'FAIL none yet';
        break;
      case 'still':
        final f = await cam.captureStill();
        if (f == null) {
          result = 'FAIL capture null';
        } else {
          try {
            final bytes = await File(f.path).readAsBytes();
            result = 'PASS ${bytes.length} bytes';
          } catch (e) {
            result = 'FAIL $e';
          }
          try {
            await File(f.path).delete();
          } catch (_) {}
        }
        break;
      case 'face':
        result = !cam.mlReady
            ? 'FAIL detector never returned'
            : (cam.lastFaceCount > 0
                ? 'PASS ${cam.lastFaceCount}'
                : 'FAIL 0 faces');
        break;
      case 'eye':
        final st = cam.eyeStatus;
        result = (st != null && st.eyesLocated)
            ? 'PASS locked=${st.locked}'
            : 'FAIL ${st == null ? 'no-frame' : detectionStateKey(st.state)}';
        break;
      default:
        result = 'FAIL unknown';
    }
    if (!mounted) return;
    setState(() => _camTests[kind] = result);
  }

  /// Save First Frame (§8): persist the rendered ML-input view + the still
  /// for manual inspection. Explicit per-press action, local-only, with an
  /// explicit delete. Never automatic. Temp-dir only (never documents):
  /// the OS may reclaim them and backups exclude them.
  Future<void> _saveFirstFrameFiles() async {
    final jpg = _renderMlGray();
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final paths = <String>[];
      if (jpg != null) {
        final ml = File('${dir.path}/ocuscan-ml-input-$ts.jpg');
        await ml.writeAsBytes(jpg);
        paths.add(ml.path);
      }
      if (_stillPath != null) {
        final still = File(
            '${dir.path}/ocuscan-still-$ts.jpg');
        await still.writeAsBytes(await File(_stillPath!).readAsBytes());
        paths.add(still.path);
      }
      if (!mounted) return;
      setState(() => _firstFramePaths = paths);
      if (mounted && paths.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DevStrings.of(context).firstFrameSaved)));
      }
    } catch (_) {}
  }

  Future<void> _exportReport() async {
    final cam = _camRef;
    if (cam == null || !mounted) return;
    String model = 'unknown';
    String os = 'unknown';
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      model = info.model;
      os = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
    } catch (_) {}
    final report = cam.diagnosticReport(
        appVersion: kOcuScanVersion,
        deviceModel: model,
        osVersion: os);
    try {
      // Temp-dir: shared immediately, then stale. Never documents.
      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/ocuscan-diagnostic-${DateTime.now().millisecondsSinceEpoch}.json');
      await f.writeAsString(
          const JsonEncoder.withIndent('  ').convert(report));
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
          files: [XFile(f.path)], text: 'OcuScan diagnostic report'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DevStrings.of(context).diagnosticsExported)));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings.of(context);
    final t = Theme.of(context).textTheme;
    final cam = context.watch<CameraService>();
    final status = cam.eyeStatus;
    return Scaffold(
      appBar: AppBar(title: Text(s.eyeDebug)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SafetyBanner(text: s.eyeDebugBody),
        const SizedBox(height: 10),
        if (_error != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(s.cameraErrorLine(_error!)))),
        if (cam.ready &&
            (cam.controller != null ||
                cam.nativePreviewTextureId != null))
          _LivePreview(cam: cam)
        else
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(s.cameraStarting))),
        const SizedBox(height: 10),
        _CameraHealth(cam: cam, t: t, s: s),
        const SizedBox(height: 10),
        _PipelineCard(cam: cam, status: status, t: t, s: s),
        const SizedBox(height: 10),
        _FrameInspector(cam: cam, t: t, s: s),
        const SizedBox(height: 10),
        _ThresholdsCard(cam: cam, t: t, s: s),
        const SizedBox(height: 10),
        _DeviceReport(t: t, s: s, cam: cam),
        const SizedBox(height: 10),
        _CameraCompare(t: t, s: s),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: _captureInspect,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(s.captureStillInspect)),
          OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/ml-test'),
              icon: const Icon(Icons.science_outlined),
              label: Text(s.mlTestBtn)),
          OutlinedButton.icon(
              onPressed: () => _camRef?.restartCamera(),
              icon: const Icon(Icons.refresh_outlined),
              label: Text(s.restartCameraDev)),
          OutlinedButton.icon(
              onPressed: _exportReport,
              icon: const Icon(Icons.ios_share),
              label: Text(s.exportDiagnostics)),
        ]),
        const SizedBox(height: 8),
        Text(s.stillDeletedNote, style: t.bodySmall),
        const SizedBox(height: 8),
        _StillInspector(
            path: _stillPath, geo: _stillGeo, size: _stillSize, t: t, s: s),
        if (_stillTestResult != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.stillFaceTestTitle, style: t.titleMedium),
                    const SizedBox(height: 4),
                    Text(_stillTestResult!, style: t.bodyMedium),
                  ]),
            ),
          ),
        ],
        const SizedBox(height: 10),
        FilledButton.icon(
            onPressed: _saveDiagnosticFrame,
            icon: const Icon(Icons.bug_report_outlined),
            label: Text(s.saveDiagnosticFrame)),
        const SizedBox(height: 8),
        _MlInputView(jpg: _renderMlGray(), t: t, s: s),
        if (_diagGray != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _diagGray = null;
                });
                _deleteStill();
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(s.deleteDiagnosticFrame)),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: _saveFirstFrameFiles,
            icon: const Icon(Icons.save_alt_outlined),
            label: Text(s.saveFirstFrame)),
        if (_firstFramePaths.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final p in _firstFramePaths) Text(p, style: t.bodySmall),
        ],
        const SizedBox(height: 10),
        Text(s.frameLogTitle, style: t.titleMedium),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cam.cameraInfo, style: t.bodySmall),
                  const SizedBox(height: 6),
                  for (final e in cam.frameLog.reversed.take(15))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(e.toString(),
                          style: t.bodySmall?.copyWith(
                              fontFamily: 'monospace', fontSize: 11)),
                    ),
                ]),
          ),
        ),
        const SizedBox(height: 10),
        Text(s.diagTimelineTitle, style: t.titleMedium),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cam.events.isEmpty)
                    Text(s.diagNoFrame, style: t.bodySmall)
                  else
                    for (final e in cam.events.reversed.take(20))
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 1),
                        child: Text(e.toString(),
                            style: t.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11)),
                      ),
                ]),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in [
            ('preview', s.testPreviewBtn),
            ('first', s.testFirstFrameBtn),
            ('still', s.testStillBtn),
            ('face', s.testFaceBtn),
            ('eye', s.testEyeBtn),
          ])
            OutlinedButton(
              onPressed: () => _runCamTest(entry.$1),
              child: Text(
                  '${entry.$2}: ${_camTests[entry.$1] ?? s.camTestIdle}'),
            ),
        ]),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.logcatTitle, style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text(s.logcatBody, style: t.bodySmall),
                ]),
          ),
        ),
      ]),
    );
  }
}

/// Research-only camera health panel (§4): every row is live runtime
/// state. Preview and image-stream health are reported independently.
class _CameraHealth extends StatelessWidget {
  final CameraService cam;
  final TextTheme t;
  final DevStrings s;
  const _CameraHealth(
      {required this.cam, required this.t, required this.s});

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(ok ? '✓ ' : '✗ ',
              style: t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ok
                      ? const Color(0xFF0A5E5D)
                      : const Color(0xFF9A6B00))),
          Expanded(child: Text(k, style: t.bodyMedium)),
          Text(v,
              style:
                  t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]));
    // Engine-aware: under native-primary there is no plugin
    // controller by design — the native texture is the preview.
    final native = cam.nativePreviewTextureId != null;
    final previewOk =
        (cam.ready && cam.controller != null) || native;
    final streamOk = cam.framesReceived > 0;
    final age = cam.lastFrameAgeMs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.cameraHealthTitle, style: t.titleMedium),
              const SizedBox(height: 6),
              row('permission',
                  cam.lastPermission?.name ?? 'unknown', true),
              row('controller', previewOk ? 'ready' : 'not ready',
                  previewOk),
              row('preview', previewOk ? 'RUNNING' : 'not running',
                  previewOk),
              row('image stream',
                  streamOk ? 'RUNNING' : 'no frames yet', streamOk),
              row('frames received', '${cam.framesReceived}',
                  streamOk),
              row('frames processed', '${cam.framesProcessed}',
                  cam.framesProcessed > 0),
              row('last frame',
                  age < 0 ? 'none yet' : '${age}ms ago', age >= 0),
              row('size',
                  '${cam.lastFrameSize.width.toInt()}x${cam.lastFrameSize.height.toInt()}',
                  cam.lastFrameSize.width > 0),
              row('format',
                  '${cam.lastMlFormat} planes=${cam.lastPlaneCount}',
                  cam.lastPlaneCount > 0),
              row('rotation', '${cam.lastRotationDeg}°', true),
              row('lens', cam.activeSourceCode, true),
              row('engine',
                  '${cam.displayEngineId.name} ${cam.detectorTier}', true),
              row('face detector',
                  cam.mlReady ? 'initialized' : 'no result yet',
                  cam.mlReady),
              row('last face count', '${cam.lastFaceCount}',
                  cam.lastFaceCount > 0),
              row('eyes located',
                  cam.eyeStatus == null
                      ? 'no frame yet'
                      : (cam.eyeStatus!.eyesLocated ? 'yes' : 'no'),
                  cam.eyeStatus?.eyesLocated ?? false),
              row('lock',
                  cam.eyeStatus?.locked == true ? 'YES' : '—',
                  cam.eyeStatus?.locked ?? false),
            ]),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  final CameraService cam;
  const _LivePreview({required this.cam});

  @override
  Widget build(BuildContext context) {
    final raw = cam.lastFrameSize;
    final rot = cam.lastRotationDeg;
    final uprightW = (rot == 90 || rot == 270) ? raw.height : raw.width;
    final uprightH = (rot == 90 || rot == 270) ? raw.width : raw.height;
    final aspect =
        (uprightW > 0 && uprightH > 0) ? uprightW / uprightH : 3 / 4;
    return Container(
      decoration: BoxDecoration(
          color: Colors.black, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: aspect.clamp(0.4, 1.2),
          child: Stack(children: [
            if (cam.controller != null)
              CameraPreview(cam.controller!)
            else if (cam.nativePreviewTextureId != null)
              NativePreviewTexture(
                textureId: cam.nativePreviewTextureId!,
                rotationDeg: rot,
                mirrored: cam.isMirrored,
              ),
            IgnorePointer(
              child: EyeOverlay(
                status: cam.eyeStatus,
                rawSize: raw,
                rotationDeg: rot,
                mirrored: cam.isMirrored,
                locked: cam.eyeStatus?.locked ?? false,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  final CameraService cam;
  final EyeStatus? status;
  final TextTheme t;
  final DevStrings s;
  const _PipelineCard(
      {required this.cam,
      required this.status,
      required this.t,
      required this.s});

  @override
  Widget build(BuildContext context) {
    final st = status;
    final q = cam.lastQuality;
    Widget line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: t.bodyMedium)),
          Expanded(
              child: Text(v,
                  style: t.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
        ]));
    String pt(EyePoint? p, int w, int h) => p == null
        ? 'none'
        : '${(p.x * w).toStringAsFixed(0)},${(p.y * h).toStringAsFixed(0)}';
    final w = cam.lastFrameSize.width.toInt();
    final h = cam.lastFrameSize.height.toInt();
    final cfg = cam.tracker.config;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.pipelineTitle, style: t.titleMedium),
              const SizedBox(height: 6),
              line('1 raw frame',
                  '${w}x$h rot${cam.lastRotationDeg} mirror=${cam.isMirrored}'),
              line('2 quality',
                  'lum${q.meanLuminance.toStringAsFixed(0)} blur${q.blurVariance.toStringAsFixed(1)} over${(q.overexposedFraction * 100).toStringAsFixed(1)}%'),
              line('3 face box',
                  st?.faceBox == null
                      ? 'none'
                      : 'L${(st!.faceBox!.left * w).toStringAsFixed(0)} T${(st.faceBox!.top * h).toStringAsFixed(0)} '
                          'R${(st.faceBox!.right * w).toStringAsFixed(0)} B${(st.faceBox!.bottom * h).toStringAsFixed(0)}'),
              line('4 landmarks',
                  'L[${pt(st?.smoothLeft, w, h)}] R[${pt(st?.smoothRight, w, h)}]${st?.positionsStale == true ? ' STALE' : ''}'),
              line('5 eye crops',
                  st?.smoothLeft == null
                      ? 'none'
                      : EyeCoords.eyeRegion(st!.smoothLeft!, 0.16)
                          .toString()),
              line('6 analyzer input',
                  'face:${st?.meetsNeed(AnalyzerNeed.facialAsymmetry, cfg) ?? false} '
                  'lid:${st?.meetsNeed(AnalyzerNeed.eyelid, cfg) ?? false} '
                  'pupil:${st?.meetsNeed(AnalyzerNeed.pupilSymmetry, cfg) ?? false} '
                  'blink:${st?.meetsNeed(AnalyzerNeed.blink, cfg) ?? false}'),
              line('state',
                  '${st == null ? 'no-frame' : detectionStateKey(st.state)} stable=${st?.stableFrames ?? 0} locked=${st?.locked ?? false}'),
            ]),
      ),
    );
  }
}

class _ThresholdsCard extends StatelessWidget {
  final CameraService cam;
  final TextTheme t;
  final DevStrings s;
  const _ThresholdsCard(
      {required this.cam, required this.t, required this.s});

  @override
  Widget build(BuildContext context) {
    final c = cam.tracker.config;
    final q = cam.lastQuality;
    Widget line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: t.bodyMedium)),
          Text(v,
              style:
                  t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.thresholdsTitle, style: t.titleMedium),
              const SizedBox(height: 6),
              line('face fraction', '[${c.minFaceFraction}, ${c.maxFaceFraction}]'),
              line('max yaw/roll', '${c.maxYawDeg}° / ${c.maxRollDeg}°'),
              line('min open prob', '${c.minOpenProb}'),
              line('dark < / bright >',
                  '${c.darkLuminance} / ${c.brightLuminance} (live ${q.meanLuminance.toStringAsFixed(0)})'),
              line('min blur variance',
                  '${c.minBlurVariance} (live ${q.blurVariance.toStringAsFixed(1)})'),
              line('stability window', '${c.stableFramesRequired} frames'),
              line('loss budget', '${c.maxLostFrames} frames'),
            ]),
      ),
    );
  }
}

class _StillInspector extends StatelessWidget {
  final String? path;
  final EyeGeometry? geo;
  final Size size;
  final TextTheme t;
  final DevStrings s;
  const _StillInspector(
      {required this.path,
      required this.geo,
      required this.size,
      required this.t,
      required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.stillInspectorTitle, style: t.titleMedium),
              const SizedBox(height: 8),
              if (path == null)
                Text(s.noStillYet, style: t.bodyMedium)
              else ...[
                AspectRatio(
                  aspectRatio: size.width > 0 && size.height > 0
                      ? (size.width / size.height).clamp(0.4, 1.2)
                      : 3 / 4,
                  child: Stack(children: [
                    Positioned.fill(
                        child: Image.file(File(path!),
                            fit: BoxFit.cover)),
                    if (geo != null && geo!.faceFound)
                      IgnorePointer(
                        child: EyeOverlay(
                          status: EyeStatus(
                            state: DetectionState.ready,
                            smoothLeft: geo!.leftEye,
                            smoothRight: geo!.rightEye,
                            leftLocated: geo!.leftEye != null,
                            rightLocated: geo!.rightEye != null,
                            eyesOpen: true,
                            faceBox: geo!.faceBox,
                            yawDeg: geo!.yawDeg,
                            faceFraction: geo!.faceFraction,
                          ),
                          rawSize: size.width > 0 ? size : const Size(640, 480),
                          rotationDeg: 0,
                          mirrored: false,
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(
                    geo == null
                        ? 'detection failed'
                        : geo!.faceFound
                            ? 'face yaw ${geo!.yawDeg.toStringAsFixed(1)}° roll ${geo!.rollDeg.toStringAsFixed(1)}° '
                                'track#${geo!.trackingId ?? '–'} still ${size.width.toInt()}x${size.height.toInt()}'
                            : 'no face in still',
                    style: t.bodySmall),
              ],
            ]),
      ),
    );
  }
}

/// Research-only frame inspector (v0.3.3): proves valid frames arrive
/// before anyone debugs ML Kit. All values are live runtime data.
class _FrameInspector extends StatelessWidget {
  final CameraService cam;
  final TextTheme t;
  final DevStrings s;
  const _FrameInspector(
      {required this.cam, required this.t, required this.s});

  @override
  Widget build(BuildContext context) {
    Widget line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: t.bodyMedium)),
          Expanded(
              child: Text(v,
                  style: t.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
        ]));
    final q = cam.lastQuality;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.frameInspectorTitle, style: t.titleMedium),
              const SizedBox(height: 6),
              line('frames received', '${cam.framesReceived}'),
              line('frames processed', '${cam.framesProcessed}'),
              line('frames dropped', '${cam.framesDropped}'),
              line('arrival FPS',
                  cam.arrivalFps.toStringAsFixed(1)),
              line('processing FPS',
                  cam.processingFps.toStringAsFixed(1)),
              line('last latency',
                  '${cam.lastLatencyMs.toStringAsFixed(1)} ms'),
              line('last frame age',
                  cam.lastFrameAgeMs < 0
                      ? 'none yet'
                      : '${cam.lastFrameAgeMs} ms'),
              line('last frame',
                  '${cam.lastFrameSize.width.toInt()}x${cam.lastFrameSize.height.toInt()} '
                  'ml[${cam.lastMlFormat}] rot${cam.lastRotationDeg}'),
              line('luminance',
                  q.meanLuminance.toStringAsFixed(0)),
              line('sharpness',
                  q.blurVariance.toStringAsFixed(1)),
              line('ML errors (consec)',
                  '${cam.consecMlErrors}'),
              line('conversion errors (consec)',
                  '${cam.consecConvertErrors}'),
              if (cam.lastError != null) ...[
                const SizedBox(height: 4),
                Text('last error: ${cam.lastError}',
                    style: t.bodySmall),
              ],
            ]),
      ),
    );
  }
}

/// Device + camera capability report (only facts the OS exposes).
class _DeviceReport extends StatefulWidget {
  final TextTheme t;
  final DevStrings s;
  final CameraService cam;
  const _DeviceReport(
      {required this.t, required this.s, required this.cam});

  @override
  State<_DeviceReport> createState() => _DeviceReportState();
}

class _DeviceReportState extends State<_DeviceReport> {
  String _model = '...';
  String _os = '...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (!mounted) return;
      setState(() {
        _model = info.model;
        _os = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _model = 'unavailable';
        _os = 'unavailable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: widget.t.bodyMedium)),
          Expanded(
              child: Text(v,
                  style: widget.t.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
        ]));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.s.deviceReportTitle,
                  style: widget.t.titleMedium),
              const SizedBox(height: 6),
              line('model', _model),
              line('os', _os),
              for (final c in widget.cam.capabilities)
                line(
                    'camera ${c.code}',
                    'lens=${c.lensDirection} sensor=${c.sensorOrientation} '
                    'preview=${c.previewWidth ?? '?'}x${c.previewHeight ?? '?'}'),
            ]),
      ),
    );
  }
}

/// Front-vs-rear comparison from REAL recorded data only: preview
/// resolution per source plus experiment counts + unable rates grouped by
/// the camera recorded on each experiment. Empty groups stay empty.
class _CameraCompare extends StatefulWidget {
  final TextTheme t;
  final DevStrings s;
  const _CameraCompare({required this.t, required this.s});

  @override
  State<_CameraCompare> createState() => _CameraCompareState();
}

class _CameraCompareState extends State<_CameraCompare> {
  Map<String, int> _expCount = {};
  Map<String, int> _unableCount = {};
  Map<String, int> _trialCount = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<ValidationRepository>();
      final exps = await repo.listExperiments();
      final expCam = <int, String>{};
      final ec = <String, int>{};
      for (final e in exps) {
        final code = e.camera.toLowerCase().contains('rear')
            ? 'rear'
            : 'front';
        if (e.id != null) expCam[e.id!] = code;
        ec[code] = (ec[code] ?? 0) + 1;
      }
      final uc = <String, int>{};
      final tc = <String, int>{};
      final trials = await repo.queryTrials();
      for (final tr in trials) {
        final code = expCam[tr.experimentId] ?? 'front';
        tc[code] = (tc[code] ?? 0) + 1;
        if (tr.status == TrialStatus.unable) {
          uc[code] = (uc[code] ?? 0) + 1;
        }
      }
      if (!mounted) return;
      setState(() {
        _expCount = ec;
        _unableCount = uc;
        _trialCount = tc;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = context.watch<CameraService>();
    String prev(String code) {
      for (final c in cam.capabilities) {
        if (c.code == code && c.previewWidth != null) {
          return '${c.previewWidth}x${c.previewHeight}';
        }
      }
      return 'not measured';
    }

    Widget cell(String v, {bool head = false}) => Expanded(
            child: Text(v,
                textAlign: TextAlign.center,
                style: head
                    ? widget.t.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)
                    : widget.t.bodyMedium));
    Widget row(String k, String f, String r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: widget.t.bodySmall)),
          cell(f),
          cell(r),
        ]));
    String unablePct(String code) {
      final t = _trialCount[code] ?? 0;
      if (t == 0) return '—';
      final u = _unableCount[code] ?? 0;
      return '${(u * 100 / t).toStringAsFixed(1)}% ($u/$t)';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.s.cameraCompareTitle,
                  style: widget.t.titleMedium),
              const SizedBox(height: 6),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Row(children: [
                  const Expanded(child: SizedBox()),
                  cell('Front', head: true),
                  cell('Rear', head: true),
                ]),
                row('preview', prev('front'), prev('rear')),
                row('experiments', '${_expCount['front'] ?? 0}',
                    '${_expCount['rear'] ?? 0}'),
                row('unable rate', unablePct('front'),
                    unablePct('rear')),
              ],
            ]),
      ),
    );
  }
}

/// Rendered ML-input grayscale view (rotation-corrected) next to the
/// original still: proves preview content == analyzer content.
class _MlInputView extends StatelessWidget {
  final Uint8List? jpg;
  final TextTheme t;
  final DevStrings s;
  const _MlInputView({required this.jpg, required this.t, required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.diagMlInputView, style: t.titleMedium),
              const SizedBox(height: 8),
              if (jpg == null)
                Text(s.diagNoFrame, style: t.bodyMedium)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(jpg!, fit: BoxFit.cover),
                ),
            ]),
      ),
    );
  }
}
