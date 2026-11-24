// Snapshot fallback scan (v0.3.4 §13, §35-37): when the live pipeline
// cannot analyze on a device, the user may explicitly switch to a
// still-image scan. Real camera capture + real ML analysis; temporal
// modules stay unavailable and the summary is labeled as still-image
// screening. Never auto-switches: the recovery panel offers it, the user
// chooses it, and can go back to live analysis.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/eye_tracking.dart';
import '../../../main.dart';
import '../../widgets/common.dart';
import '../../widgets/eye_overlay.dart';

class SnapshotData {
  final String path;
  final EyeGeometry geo;
  final int width;
  final int height;
  const SnapshotData(
      {required this.path,
      required this.geo,
      required this.width,
      required this.height});
}

class SnapshotScanView extends StatefulWidget {
  final ValueChanged<SnapshotData> onDone;
  final VoidCallback onBackToLive;
  const SnapshotScanView(
      {super.key, required this.onDone, required this.onBackToLive});

  @override
  State<SnapshotScanView> createState() => _SnapshotScanViewState();
}

class _SnapshotScanViewState extends State<SnapshotScanView> {
  bool _working = false;
  String? _path;
  EyeGeometry? _geo;
  int _w = 0;
  int _h = 0;
  bool _noFace = false;

  Future<void> _capture() async {
    final cam = context.read<CameraService>();
    if (!cam.ready) return;
    setState(() {
      _working = true;
      _noFace = false;
      _geo = null;
    });
    try {
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
        final codec =
            await ui.instantiateImageCodec(data);
        final frame = await codec.getNextFrame();
        size = Size(frame.image.width.toDouble(),
            frame.image.height.toDouble());
        frame.image.dispose();
      } catch (_) {}
      // Drop the previous still (privacy: one file at a time).
      if (_path != null && _path != file.path) {
        try {
          await File(_path!).delete();
        } catch (_) {}
      }
      setState(() {
        _path = file.path;
        _geo = geo;
        _w = size.width.toInt();
        _h = size.height.toInt();
        _noFace = geo == null || !geo.faceFound;
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    // Snapshot stills are transient: delete on exit (analysis inputs were
    // already extracted into measurements by the flow).
    final p = _path;
    if (p != null) {
      try {
        File(p).delete();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    final cam = context.watch<CameraService>();
    final hasGeo = _geo != null && _geo!.faceFound;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OcuSpace.lg),
        decoration: BoxDecoration(
          color: AppTheme.tealTint,
          border: Border.all(color: AppTheme.tealDark),
          borderRadius: BorderRadius.circular(OcuRadii.md),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.snapTitle,
                  style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.tealDark)),
              const SizedBox(height: 4),
              Text(s.snapBody, style: t.bodyMedium),
            ]),
      ),
      const SizedBox(height: 10),
      if (_path == null) ...[
        // Still capture is a plugin-path capability; the native engine
        // owns its camera exclusively. Disabled with the reason stated
        // (v0.7.21 audit) — never a dead button that flashes and dies.
        FilledButton.icon(
          onPressed: (!_working &&
                  cam.ready &&
                  cam.nativePreviewTextureId == null)
              ? _capture
              : null,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(_working ? s.snapProcessing : s.snapCapture),
        ),
        if (cam.nativePreviewTextureId != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(s.snapNativeUnsupported, style: t.bodySmall),
          ),
      ]
      else ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(OcuRadii.md),
          child: AspectRatio(
            aspectRatio:
                (_w > 0 && _h > 0 ? _w / _h : 3 / 4).clamp(0.4, 1.2),
            child: Stack(children: [
              Positioned.fill(
                  child: Image.file(File(_path!), fit: BoxFit.cover)),
              if (hasGeo)
                IgnorePointer(
                  child: EyeOverlay(
                    status: EyeStatus(
                      state: DetectionState.ready,
                      smoothLeft: _geo!.leftEye,
                      smoothRight: _geo!.rightEye,
                      leftLocated: _geo!.leftEye != null,
                      rightLocated: _geo!.rightEye != null,
                      eyesOpen: true,
                      faceBox: _geo!.faceBox,
                      yawDeg: _geo!.yawDeg,
                      faceFraction: _geo!.faceFraction,
                    ),
                    rawSize: _w > 0
                        ? Size(_w.toDouble(), _h.toDouble())
                        : const Size(640, 480),
                    rotationDeg: 0,
                    mirrored: false,
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            _noFace
                ? s.snapNoFace
                : (hasGeo ? s.snapFaceOk : s.snapProcessing),
            style: t.bodyMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(
              onPressed: _working ? null : _capture,
              child: Text(s.snapRetake)),
          if (hasGeo)
            FilledButton(
                onPressed: () => widget.onDone(SnapshotData(
                    path: _path!,
                    geo: _geo!,
                    width: _w,
                    height: _h)),
                child: Text(s.snapUse)),
        ]),
      ],
      const SizedBox(height: 10),
      TextButton(
          onPressed: widget.onBackToLive, child: Text(s.snapBack)),
      const SizedBox(height: 6),
      SafetyBanner(text: s.snapModeBanner),
    ]);
  }
}
