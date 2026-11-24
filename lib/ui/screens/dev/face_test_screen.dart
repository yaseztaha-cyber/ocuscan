// Research-only Face Detection Test (/face-test): the minimal viable
// path — camera → real image → ML Kit → face count → face box.
// No EyeTracker, no QualityGate, no lock logic, no analyzer. If THIS
// cannot see a face, the problem is below the OcuScan analyzer layer
// (stream format, conversion, metadata, ML setup, device behavior).
// Raw ML Kit boxes are overlaid unmodified (mapped only for display).

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/dev_strings.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/eye_tracking.dart';
import '../../../features/camera/image_source.dart';
import '../../widgets/common.dart';

class FaceTestScreen extends StatefulWidget {
  const FaceTestScreen({super.key});
  @override
  State<FaceTestScreen> createState() => _FaceTestScreenState();
}

class _FaceTestScreenState extends State<FaceTestScreen> {
  CameraService? _camRef;
  String _sourceSel = 'front';
  String? _error;

  @override
  void initState() {
    super.initState();
    _camRef = context.read<CameraService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _camRef?.release();
    super.dispose();
  }

  Future<void> _init() async {
    final cam = _camRef;
    if (cam == null || !mounted) return;
    final ok = await cam.prepare(
        source: _sourceSel == 'rear'
            ? RearCameraSource()
            : FrontCameraSource());
    if (!mounted) return;
    if (!ok &&
        cam.lastPermission != null &&
        cam.lastPermission != CameraPermission.granted) {
      await explainCameraIssue(context, cam.lastPermission!, null);
      if (!mounted) return;
    }
    setState(() => _error = ok ? null : (cam.error ?? 'init failed'));
  }

  Future<void> _select(String sel) async {
    setState(() => _sourceSel = sel);
    final cam = _camRef;
    if (cam == null) return;
    await cam.switchSource(
        sel == 'rear' ? RearCameraSource() : FrontCameraSource());
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings.of(context);
    final t = Theme.of(context).textTheme;
    final cam = context.watch<CameraService>();
    final n = cam.lastFaceCount;
    final pass = n > 0;
    return Scaffold(
      appBar: AppBar(title: Text(s.faceTest)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SafetyBanner(text: s.faceTestBody),
        const SizedBox(height: 10),
        Row(children: [
          Text(s.camSourceLabel, style: t.titleMedium),
          const SizedBox(width: 10),
          Expanded(
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'front', label: Text(s.camSourceFront)),
                ButtonSegment(
                    value: 'rear', label: Text(s.camSourceRear)),
              ],
              selected: {_sourceSel},
              onSelectionChanged: (v) => _select(v.first),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (_error != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(s.cameraErrorLine(_error!)))),
        _FacePreview(cam: cam),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.faceCountLine(n),
                      style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800)),
                  Text(pass ? s.faceTestPass : s.faceTestFail,
                      style: t.titleMedium?.copyWith(
                          color: pass
                              ? const Color(0xFF0A5E5D)
                              : const Color(0xFF334242))),
                  const SizedBox(height: 8),
                  Text(
                      'box: ${cam.lastFaceBoxes.isEmpty ? '—' : cam.lastFaceBoxes.map((b) => 'x${b.left.toStringAsFixed(2)} y${b.top.toStringAsFixed(2)} w${b.width.toStringAsFixed(2)} h${b.height.toStringAsFixed(2)}').join(' | ')}',
                      style: t.bodySmall),
                  Text(
                      'rotation: ${cam.lastRotationDeg}°  image: ${cam.lastFrameSize.width.toInt()}x${cam.lastFrameSize.height.toInt()}  ml: ${cam.lastMlFormat}',
                      style: t.bodySmall),
                  Text(
                      'fps: ${cam.arrivalFps.toStringAsFixed(1)} in / ${cam.processingFps.toStringAsFixed(1)} proc  frames: ${cam.framesReceived}',
                      style: t.bodySmall),
                  Text(
                      'ml ready: ${cam.mlReady ? 'yes' : 'no'}  stage: ${cam.stage.name}',
                      style: t.bodySmall),
                  if (cam.lastError != null)
                    Text(
                        'last error [${cam.lastError!.stage}] ${cam.lastError!.type}: ${cam.lastError!.message.length > 200 ? '${cam.lastError!.message.substring(0, 200)}…' : cam.lastError!.message}',
                        style: t.bodySmall),
                ]),
          ),
        ),
      ]),
    );
  }
}

/// Live preview with RAW ML Kit boxes (no tracker math, no smoothing).
/// An absent box with count 0 is the truth — never a static guide passed
/// off as detection.
class _FacePreview extends StatelessWidget {
  final CameraService cam;
  const _FacePreview({required this.cam});

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
              child: LayoutBuilder(builder: (context, constraints) {
                final box = Size(
                    constraints.maxWidth, constraints.maxHeight);
                return CustomPaint(
                  size: box,
                  painter: _RawFacePainter(
                    boxes: cam.lastFaceBoxes,
                    rawSize:
                        raw.width > 0 ? raw : const Size(1280, 720),
                    rotationDeg: rot,
                    mirrored: cam.isMirrored,
                    boxSize: box,
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RawFacePainter extends CustomPainter {
  final List<Rect> boxes;
  final Size rawSize;
  final int rotationDeg;
  final bool mirrored;
  final Size boxSize;
  _RawFacePainter({
    required this.boxes,
    required this.rawSize,
    required this.rotationDeg,
    required this.mirrored,
    required this.boxSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;
    for (final b in boxes) {
      final p1 = EyeCoords.imageToPreview(
          raw: Offset(b.left, b.top),
          rawSize: rawSize,
          rotationDeg: rotationDeg,
          mirrored: mirrored,
          previewSize: boxSize);
      final p2 = EyeCoords.imageToPreview(
          raw: Offset(b.right, b.bottom),
          rawSize: rawSize,
          rotationDeg: rotationDeg,
          mirrored: mirrored,
          previewSize: boxSize);
      canvas.drawRect(Rect.fromPoints(p1, p2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RawFacePainter old) =>
      old.boxes != boxes || old.boxSize != boxSize;
}
