// Staged eye-positioning view.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/eye_tracking.dart';
import '../../../main.dart';
import '../../widgets/common.dart';
import '../../widgets/eye_overlay.dart';

int eyeStageIndex(DetectionState s, bool locked) {
  switch (s) {
    case DetectionState.faceNotFound:
      return 0;
    case DetectionState.multipleFaces:
      return 0;
    case DetectionState.faceTooSmall:
    case DetectionState.faceTooLarge:
    case DetectionState.faceAngleInvalid:
    case DetectionState.imageTooDark:
    case DetectionState.imageTooBright:
    case DetectionState.imageTooBlurry:
      return 1;
    case DetectionState.leftEyeUnavailable:
    case DetectionState.rightEyeUnavailable:
    case DetectionState.bothEyesUnavailable:
      return 2;
    case DetectionState.trackingUnstable:
      return 3;
    case DetectionState.ready:
      return locked ? 4 : 3;
  }
}

class EyePositioningView extends StatefulWidget {
  const EyePositioningView({super.key});
  @override
  State<EyePositioningView> createState() => _EyePositioningViewState();
}

class _EyePositioningViewState extends State<EyePositioningView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced-motion access (§71): static lock ring instead of pulsing.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = context.watch<CameraService>();
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    final status = cam.eyeStatus;    final state = status?.state ?? DetectionState.faceNotFound;
    final locked = status?.locked ?? false;
    final stage = eyeStageIndex(state, locked);
    final key = detectionStateKey(state);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.eyesHint, style: t.bodyLarge),
      const SizedBox(height: OcuSpace.md),
      _PreviewBox(cam: cam, locked: locked, pulse: _pulse),
      const SizedBox(height: OcuSpace.md),
      _StageStrip(stage: stage, s: s, t: t),
      const SizedBox(height: OcuSpace.md),
      _GuidanceCard(
          title: s.eyeGuideTitle(key),
          body: s.eyeGuideBody(key),
          locked: locked),
      if (status != null && status.ready && !locked) ...[
        const SizedBox(height: OcuSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(OcuRadii.pill),
          child: LinearProgressIndicator(
            value: status.stableFrames / 5,
            minHeight: 8,
            backgroundColor: AppTheme.line,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.tealDark),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: Text(s.stabilizingProgress(status.stableFrames, 5),
              style: t.bodySmall),
        ),
      ],
      const SizedBox(height: OcuSpace.sm),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Chip(
            label: s.chipLighting,
            ok: _lightingOk(cam),
            okText: s.chipGood,
            badText: s.chipCheck),
        _Chip(
            label: s.chipPosition,
            ok: _positionOk(status),
            okText: s.chipReady,
            badText: s.chipAdjust),
        _Chip(
            label: s.chipEyes,
            ok: status?.eyesLocated ?? false,
            okText: s.chipVisible,
            badText: s.chipHidden),
      ]),
      const SizedBox(height: OcuSpace.sm),
      Text(
          status == null
              ? s.startingCamera
              : status.faceBox == null
                  ? s.noFaceYet
                  : s.faceLiveLine(status.yawDeg, status.centeredX),
          style: t.bodySmall),
    ]);
  }

  // Mirrors QualityGate (45..210) so the guide never contradicts
  // the later verdict on the same face.
  bool _lightingOk(CameraService cam) =>
      cam.lastQuality.meanLuminance > 45 &&
      cam.lastQuality.meanLuminance < 210;

  bool _positionOk(EyeStatus? status) =>
      status != null &&
      status.faceBox != null &&
      status.faceFraction >= 0.22 &&
      status.faceFraction <= 0.88 &&
      status.yawDeg.abs() <= 28;
}

class _PreviewBox extends StatelessWidget {
  final CameraService cam;
  final bool locked;
  final AnimationController pulse;
  const _PreviewBox(
      {required this.cam, required this.locked, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    // Exact-aspect preview box so cover-fit mapping has no crop ambiguity.
    // The aspect is exact (never clamped): overlay markers are mapped
    // onto this same box, and any clamp would misalign them on wide
    // (rear/landscape) frames while the texture keeps its true shape.
    final raw = cam.lastFrameSize;
    final rot = cam.lastRotationDeg;
    final aspect = EyeCoords.uprightAspect(raw, rot);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(OcuRadii.lg),
        border:
            Border.all(color: locked ? AppTheme.teal : AppTheme.line, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OcuRadii.lg - 2),
        child: AspectRatio(
          aspectRatio: aspect,
          child: LayoutBuilder(builder: (context, constraints) {
            // Preview source follows the active engine: the native
            // CameraX session renders into its own texture (the plugin
            // controller is released while native owns the camera),
            // otherwise the plugin CameraPreview is shown as before.
            final nativeTex = cam.nativePreviewTextureId;
            return Stack(children: [
              if (nativeTex != null)
                NativePreviewTexture(
                  textureId: nativeTex,
                  rotationDeg: rot,
                  mirrored: cam.isMirrored,
                )
              else if (cam.ready && cam.controller != null)
                CameraPreview(cam.controller!)
              else
                Center(
                    child: Text(
                        cam.switching
                            ? s.switchingCamera
                            : s.cameraUnavailableFlow,
                        textAlign: TextAlign.center,
                        style: t.bodySmall
                            ?.copyWith(color: Colors.white))),
              const IgnorePointer(child: _FaceGuideFrame()),
              IgnorePointer(
                // The pulse animation only drives repaints while locked
                // (the expanding ring). Unlocked, a stopped listenable
                // means the overlay rebuilds only when the status itself
                // changes — no 60fps rebuild storm on idle frames.
                child: AnimatedBuilder(
                  animation: locked
                      ? pulse
                      : const AlwaysStoppedAnimation<double>(0),
                  builder: (context, _) => EyeOverlay(
                    status: cam.eyeStatus,
                    rawSize: raw,
                    rotationDeg: rot,
                    mirrored: cam.isMirrored,
                    locked: locked,
                    pulse: locked ? pulse.value : 0,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Text(s.keepEyesInGuide,
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4)
                        ])),
              ),
              if (locked)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  // A11y: lock transitions are status messages — announced
                  // to screen readers via a live region.
                  child: Semantics(
                    liveRegion: true,
                    child: Text(s.lockOn,
                        textAlign: TextAlign.center,
                        style: t.labelLarge?.copyWith(
                            color: const Color(0xFF7FD1C0),
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4)
                            ])),
                  ),
                ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _FaceGuideFrame extends StatelessWidget {
  const _FaceGuideFrame();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.62,
        heightFactor: 0.72,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 2),
            borderRadius: BorderRadius.circular(90),
          ),
          child: const Align(
            alignment: Alignment(0, -0.25),
            child: _EyeLine(),
          ),
        ),
      ),
    );
  }
}

class _EyeLine extends StatelessWidget {
  const _EyeLine();
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 2,
        color: Colors.white38,
        margin: const EdgeInsets.symmetric(horizontal: 18));
  }
}

class _StageStrip extends StatelessWidget {
  final int stage;
  final AppStrings s;
  final TextTheme t;
  const _StageStrip({required this.stage, required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    final labels = [
      s.eyeStageFace,
      s.eyeStagePosition,
      s.eyeStageEyes,
      s.eyeStageStabilize,
      s.eyeStageReady,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i < stage
                      ? AppTheme.tealDark
                      : i == stage
                          ? AppTheme.teal
                          : AppTheme.line,
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(
                      fontWeight:
                          i == stage ? FontWeight.w700 : FontWeight.w400,
                      color: i <= stage ? AppTheme.tealDark : AppTheme.slate)),
            ]),
          ),
          if (i < labels.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  final String title;
  final String body;
  final bool locked;
  const _GuidanceCard(
      {required this.title, required this.body, required this.locked});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = locked ? AppTheme.tealDark : AppTheme.amber;
    final bg = locked ? AppTheme.tealTint : AppTheme.amberTint;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(OcuSpace.lg),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(OcuRadii.md),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedScale(
          scale: locked ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Icon(
              locked ? Icons.check_circle : Icons.face_retouching_natural,
              color: color,
              size: 28),
        ),
        const SizedBox(width: OcuSpace.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium?.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(body, style: t.bodyMedium),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool ok;
  final String okText;
  final String badText;
  const _Chip(
      {required this.label,
      required this.ok,
      required this.okText,
      required this.badText});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppTheme.tealDark : AppTheme.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(OcuRadii.pill),
      ),
      child: Text('$label ${ok ? okText : badText}',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
