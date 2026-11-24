// Eyes stage assembly (screening step 2 of 5): camera source selector,
// pipeline checklist (permission/camera/preview/eye-detection as separate
// truths), startup watchdog panel, the live eye-positioning view, rear
// assisted mode, and the bounded recovery ladder. The Continue gate itself
// stays in the flow (real lock required); the recovery panel offers an
// explicit, honest "continue without lock" escape that downstream modules
// record as unable-to-assess.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/camera/camera_pipeline.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/eye_tracking.dart';
import '../../../features/camera/image_source.dart';
import '../../../main.dart';
import 'eye_positioning.dart';

class EyeStageView extends StatefulWidget {
  final VoidCallback onSkipLock;
  final VoidCallback onSnapshot;
  const EyeStageView(
      {super.key, required this.onSkipLock, required this.onSnapshot});

  @override
  State<EyeStageView> createState() => _EyeStageViewState();
}

class _EyeStageViewState extends State<EyeStageView> {
  DateTime _since = DateTime.now();
  Timer? _tick;
  String _sourceSel = 'best';
  bool _autoResetDone = false;
  bool _autoResetNote = false;
  int _attempts = 0;
  static const _ladder = RecoveryLadder();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Record an observed startup timeout as an explicit stage here
      // (timer context, never during build) so the UI names it instead
      // of generic "starting".
      try {
        final cam = context.read<CameraService>();
        if (cam.startupWatchdogState() == StartupState.timeout) {
          cam.noteWatchdogTimeout();
        }
      } catch (_) {}
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _resetStageClock() {
    _since = DateTime.now();
    _autoResetDone = false;
    _autoResetNote = false;
  }

  Future<void> _selectSource(CameraService cam, String sel) async {
    setState(() => _sourceSel = sel);
    final ImageSource target;
    if (sel == 'rear') {
      target = RearCameraSource();
    } else if (sel == 'front') {
      target = FrontCameraSource();
    } else {
      final rec = cam.recommendFor(TestCameraNeed.selfGuided);
      target = imageSourceForCode(rec.code);
    }
    _resetStageClock();
    await cam.switchSource(target);
  }

  @override
  Widget build(BuildContext context) {
    final cam = context.watch<CameraService>();
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    final locked = cam.eyeStatus?.locked ?? false;
    final stuckSec = locked
        ? 0
        : DateTime.now().difference(_since).inSeconds;
    final action =
        locked ? RecoveryAction.none : _ladder.actionFor(stuckSeconds: stuckSec);

    // Attempt 1 is automatic (once): restart the tracker, say so honestly.
    if (action == RecoveryAction.autoResetTracker && !_autoResetDone) {
      _autoResetDone = true;
      _autoResetNote = true;
      cam.tracker.reset();
    }

    final isRear = cam.activeSourceCode == 'rear';
    final rec = cam.recommendFor(TestCameraNeed.selfGuided);
    final watchdog = cam.startupWatchdogState();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Camera selector: Front / Rear / Best for this test.
      // Layout: the leading label flexes so Arabic segment labels on
      // narrow screens cannot push the control off the trailing edge.
      Row(children: [
        Flexible(
          child: Text(s.camSourceLabel, style: t.titleMedium),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'front', label: Text(s.camSourceFront)),
              ButtonSegment(value: 'rear', label: Text(s.camSourceRear)),
              ButtonSegment(value: 'best', label: Text(s.camSourceBest)),
            ],
            selected: {_sourceSel},
            onSelectionChanged: (v) => _selectSource(cam, v.first),
          ),
        ),
      ]),
      if (_sourceSel == 'best') ...[
        const SizedBox(height: 4),
        Text(
            s.camRecommended(rec.reasons.isEmpty
                ? rec.code
                : rec.reasons.first),
            style: t.bodySmall),
      ],
      const SizedBox(height: 10),
      _PipelineChecklist(cam: cam, s: s, t: t),
      const SizedBox(height: 8),
      _StatusPills(cam: cam, s: s),
      // Watchdog: no first frame within timeout -> exact failed stage.
      if (watchdog == StartupState.timeout) ...[
        const SizedBox(height: 10),
        _WatchdogPanel(s: s, t: t),
      ],
      // Analysis dead (blocked ladder OR mlDegraded stage, which the
      // native ENGINE_UNAVAILABLE branch sets without error counters) ->
      // say so with retry + snapshot escape, stay usable.
      if (cam.analysisBlocked ||
          cam.stage == CameraStage.mlDegraded) ...[
        const SizedBox(height: 10),
        _AnalysisTroublePanel(s: s, t: t, onSnapshot: widget.onSnapshot),
      ],
      // Permission denied is sticky: the one-shot startup dialog cannot
      // be recalled, so a persistent panel re-arms the prompt (Retry)
      // and the system-settings path (audit). No dead banner.
      if (cam.stage == CameraStage.permissionDenied) ...[
        const SizedBox(height: 10),
        _PermissionPanel(s: s, t: t),
      ],
      const SizedBox(height: 10),
      if (isRear) ...[
        _RearAssistPanel(status: cam.eyeStatus, s: s, t: t),
        const SizedBox(height: 10),
      ],
      const EyePositioningView(),
      if (_autoResetNote) ...[
        const SizedBox(height: 8),
        Text(s.recoveryAutoNote, style: t.bodySmall),
      ],
      // Stuck clock: name the wait early so the user never assumes
      // a freeze, and offer help well before the 30 s recovery panel.
      if (!locked && stuckSec >= 15) ...[
        const SizedBox(height: 8),
        Text(s.eyeTryingLine(stuckSec), style: t.bodySmall),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/camera-help'),
          icon: const Icon(Icons.help_outline),
          label: Text(s.cameraHelpBtn),
        ),
      ],
      if (action.index >= RecoveryAction.showPanel.index && !locked) ...[
        const SizedBox(height: 10),
        _RecoveryPanel(
          s: s,
          t: t,
          attempts: _attempts,
          offerRestart: action.index >= RecoveryAction.offerRestart.index,
          offerUnable:
              action.index >= RecoveryAction.offerContinueUnable.index,
          onTryAgain: () {
            setState(() {
              _attempts++;
              _resetStageClock();
            });
            cam.tracker.reset();
          },
          onRestart: () async {
            setState(() => _attempts++);
            _resetStageClock();
            await cam.restartCamera();
          },
          onSkipLock: widget.onSkipLock,
        ),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/camera-help'),
        icon: const Icon(Icons.help_outline),
        label: Text(s.cameraHelpBtn),
      ),
    ]);
  }
}

/// Compact status pills (§55): CAMERA / LIGHTING / FACE / EYES / LOCK
/// from real runtime values. Text + glyph, never color alone.
class _StatusPills extends StatelessWidget {
  final CameraService cam;
  final AppStrings s;
  const _StatusPills({required this.cam, required this.s});

  @override
  Widget build(BuildContext context) {
    final st = cam.eyeStatus;
    final lum = cam.lastQuality.meanLuminance;
    final pills = [
      // Preview truth is independent of analysis: the CAMERA pill answers
      // "is the preview texture alive", never "did analysis succeed".
      // Failure stages (conversion/ml/stream) are reported by their own
      // panels below, not by dimming the camera pill.
      // A bound-but-mute native session is starting, not ready.
      (s.pillCamera, cam.previewAlive && !cam.nativeStarting),
      // Analysis pill: preview-alive is NOT analysis-alive. A dead
      // detector with a live preview must read failed here (audit).
      (s.pillAnalysis,
          !(cam.analysisBlocked || cam.stage == CameraStage.mlDegraded)),
      // Mirrors QualityGate (45..210): pills must not contradict verdicts.
      (s.pillLighting, lum > 45 && lum < 210),
      (s.pillFace, st?.faceBox != null),
      (s.pillEyes, st?.eyesLocated ?? false),
      (s.pillLock, st?.locked ?? false),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in pills)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: p.$2 ? AppTheme.tealTint : AppTheme.slateTint,
              border: Border.all(
                  color: p.$2 ? AppTheme.tealDark : AppTheme.slate),
              borderRadius: BorderRadius.circular(OcuRadii.pill),
            ),
            child: Text('${p.$1} ${p.$2 ? '✓' : '…'}',
                style: TextStyle(
                    color: p.$2 ? AppTheme.tealDark : AppTheme.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}

/// Pipeline truth table: each stage independent. Never collapses to one
/// generic state; never color-only (glyph + label).
class _PipelineChecklist extends StatelessWidget {
  final CameraService cam;
  final AppStrings s;
  final TextTheme t;
  const _PipelineChecklist(
      {required this.cam, required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    final stage = cam.stage;
    final denied = stage == CameraStage.permissionDenied;
    final failed = stage == CameraStage.initFailed;
    final permOk = ![
      CameraStage.idle,
      CameraStage.requestingPermission,
      CameraStage.permissionDenied
    ].contains(stage);
    // Camera/preview rows answer "is the preview texture alive"
    // (controller initialized), independent of analysis failure stages.
    // Analysis failures surface in their own panels + tech details.
    final camOk = cam.previewAlive && !cam.nativeStarting;
    final eye = cam.eyeStatus;
    // Analysis death fails the detection row even with a live preview
    // (audit): pending dots during mlDegraded lied about the state.
    final analysisDead =
        cam.analysisBlocked || cam.stage == CameraStage.mlDegraded;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          _row(s.camStepPermission, denied ? 2 : (permOk ? 0 : 1)),
          _row(s.camStepCamera, failed ? 2 : (camOk ? 0 : 1)),
          _row(s.camStepPreview, failed ? 2 : (camOk ? 0 : 1)),
          _row(s.camStepEyeDetection,
              analysisDead ? 2 : (eye == null ? 1 : (eye.locked ? 0 : (eye.ready ? 1 : 1)))),
        ]),
      ),
    );
  }

  Widget _row(String label, int state) {
    // 0 ok, 1 pending/active, 2 failed.
    final icon = state == 0
        ? Icons.check_circle
        : (state == 2 ? Icons.error_outline : Icons.radio_button_unchecked);
    final color = state == 0
        ? AppTheme.tealDark
        : (state == 2 ? AppTheme.amber : AppTheme.slate);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: t.bodyMedium)),
        if (state == 2)
          Text('✗', style: t.bodyMedium?.copyWith(color: color))
        else if (state == 0)
          Text('✓', style: t.bodyMedium?.copyWith(color: color)),
      ]),
    );
  }
}

class _WatchdogPanel extends StatelessWidget {
  final AppStrings s;
  final TextTheme t;
  const _WatchdogPanel({required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    final cam = context.read<CameraService>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OcuSpace.lg),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        border: Border.all(color: AppTheme.amber),
        borderRadius: BorderRadius.circular(OcuRadii.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.streamTimeoutTitle, style: t.titleMedium),
        const SizedBox(height: 4),
        // Honest variant: when frames ARE arriving, never claim "no first
        // frame arrived" — the stall is in analysis, named below.
        Text(
            cam.framesReceived > 0
                ? s.streamStalledBody
                : s.streamTimeoutBody,
            style: t.bodyMedium),
        const SizedBox(height: 4),
        Text(s.watchdogFramesLine(cam.framesReceived),
            style: t.bodySmall),
        Text(s.watchdogRetryNote, style: t.bodySmall),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(
              onPressed: () => cam.retryWithFallback(),
              child: Text(s.retryAnalysis)),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/camera-help'),
            icon: const Icon(Icons.help_outline),
            label: Text(s.cameraHelpBtn),
          ),
        ]),
        const SizedBox(height: 6),
        _TechDetailsWrap(s: s, t: t),
      ]),
    );
  }
}

/// Persistent permission-denied panel: re-asks via prepare() (the only
/// path that re-prompts) and offers system settings for blocked access.
/// Rendered whenever the stage is permissionDenied so dismissal of the
/// one-shot dialog never strands the user.
class _PermissionPanel extends StatelessWidget {
  final AppStrings s;
  final TextTheme t;
  const _PermissionPanel({required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    final cam = context.read<CameraService>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OcuSpace.lg),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        border: Border.all(color: AppTheme.amber),
        borderRadius: BorderRadius.circular(OcuRadii.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.permissionPanelTitle, style: t.titleMedium),
        const SizedBox(height: 4),
        Text(s.permissionPanelBody, style: t.bodyMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(
              onPressed: () => cam.prepare(),
              child: Text(s.retryPermission)),
          OutlinedButton(
              onPressed: () => cam.openSystemSettings(),
              child: Text(s.openSettings)),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/camera-help'),
            icon: const Icon(Icons.help_outline),
            label: Text(s.cameraHelpBtn),
          ),
        ]),
      ]),
    );
  }
}

class _AnalysisTroublePanel extends StatelessWidget {
  final AppStrings s;
  final TextTheme t;
  final VoidCallback onSnapshot;
  const _AnalysisTroublePanel(
      {required this.s, required this.t, required this.onSnapshot});

  @override
  Widget build(BuildContext context) {
    final cam = context.read<CameraService>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OcuSpace.lg),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        border: Border.all(color: AppTheme.amber),
        borderRadius: BorderRadius.circular(OcuRadii.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.analysisTroubleTitle, style: t.titleMedium),
        const SizedBox(height: 4),
        Text(s.analysisTroubleBody, style: t.bodyMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(
              onPressed: () => cam.restartCamera(),
              child: Text(s.retryAnalysis)),
          OutlinedButton(
              onPressed: onSnapshot,
              child: Text(s.useSnapshotScan)),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/camera-help'),
            icon: const Icon(Icons.help_outline),
            label: Text(s.cameraHelpBtn),
          ),
        ]),
        const SizedBox(height: 6),
        // Transparent Material: the amber Container is a DecoratedBox
        // that would otherwise hide the ExpansionTile ink (debug assert).
        _TechDetailsWrap(s: s, t: t),
      ]),
    );
  }
}

/// Transparent-Material wrapper for failure-panel tech details.
class _TechDetailsWrap extends StatelessWidget {
  final AppStrings s;
  final TextTheme t;
  const _TechDetailsWrap({required this.s, required this.t});

  @override
  Widget build(BuildContext context) => Material(
      type: MaterialType.transparency, child: _TechDetails(s: s, t: t));
}

/// Failure-only technical readout (no stack traces, ever): the exact
/// facts a remote diagnosis needs — stage, frame counts, observed frame
/// layout, and the recorded per-frame error. Shown only on failure
/// panels so normal flows stay calm.
class _TechDetails extends StatelessWidget {
  final AppStrings s;
  final TextTheme t;
  const _TechDetails({required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    final cam = context.watch<CameraService>();
    final err = cam.lastError;
    // Stage is part of the error identity: the same exception type means
    // different things in conversion vs ML vs stream, so the tech line
    // always carries both the pipeline stage and the record stage.
    final errText = err == null
        ? s.techErrorNone
        : s.techErrorLine(
            '[${cam.stage.name} / ${err.type}] ${err.message.length > 160 ? '${err.message.substring(0, 160)}…' : err.message}');
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(s.techDetails, style: t.bodySmall),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.techStageLine(cam.stage.name),
                    style: t.bodySmall),
                const SizedBox(height: 2),
                Text(
                    s.techFramesLine(
                        cam.framesReceived, cam.framesProcessed),
                    style: t.bodySmall),
                const SizedBox(height: 2),
                Text(
                    s.techFormatLine(
                        cam.lastMlFormat,
                        cam.lastPlaneCount,
                        cam.lastStride,
                        cam.lastRotationDeg,
                        cam.lastFrameW,
                        cam.lastFrameH,
                        cam.lastPlaneLengths.join(', ')),
                    style: t.bodySmall),
                const SizedBox(height: 2),
                Text(errText, style: t.bodySmall),
                const SizedBox(height: 8),
                // Export-errors: full untruncated report (messages AND
                // native stacks, frame forensics, event log) as a JSON
                // file via the share sheet — built to be sent to the
                // developer. Never images, never identity.
                OutlinedButton.icon(
                  onPressed: () => _exportErrors(context, cam, s),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(s.exportErrorsBtn),
                ),
              ]),
        ),
      ],
    );
  }

  /// Build the full error report and share it as a JSON file. Failures
  /// surface as a snackbar (strings, never silent, never a crash).
  static Future<void> _exportErrors(
      BuildContext context, CameraService cam, AppStrings s) async {
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
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/ocuscan-errors-'
          '${DateTime.now().millisecondsSinceEpoch}.json');
      await f.writeAsString(
          const JsonEncoder.withIndent('  ').convert(report));
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(
          files: [XFile(f.path)], text: s.exportErrorsShareText));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.errorsExported)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.exportFailed)));
    }
  }
}

/// Rear-camera assisted mode: the user cannot see themselves, so guidance
/// is reduced to large distance + direction cues plus stable-surface help.
/// Never pretends self-testing is equally easy.
class _RearAssistPanel extends StatelessWidget {
  final EyeStatus? status;
  final AppStrings s;
  final TextTheme t;
  const _RearAssistPanel(
      {required this.status, required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    final st = status;
    String distance = s.rearNoFace;
    bool good = false;
    String? move;
    if (st?.faceBox != null) {
      final frac = st!.faceFraction;
      if (frac < 0.22) {
        distance = s.rearTooFar;
        move = s.rearMoveCloser;
      } else if (frac > 0.88) {
        distance = s.rearTooClose;
        move = s.rearMoveAway;
      } else {
        distance = s.rearGood;
        good = true;
      }
      if (!good) {
        final cx = (st.faceBox!.left + st.faceBox!.right) / 2;
        final cy = (st.faceBox!.top + st.faceBox!.bottom) / 2;
        if ((cx - 0.5).abs() > (cy - 0.5).abs()) {
          move = (move == null ? '' : '$move • ') +
              (cx < 0.5 ? s.rearMoveLeft : s.rearMoveRight);
        } else if ((cy - 0.5).abs() > 0.08) {
          move = (move == null ? '' : '$move • ') +
              (cy < 0.5 ? s.rearMoveUp : s.rearMoveDown);
        }
      }
    }
    final color = good ? AppTheme.tealDark : AppTheme.amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OcuSpace.lg),
      decoration: BoxDecoration(
        color: good ? AppTheme.tealTint : AppTheme.amberTint,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(OcuRadii.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.rearAssistTitle,
            style: t.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text(s.rearAssistBody, style: t.bodyMedium),
        const SizedBox(height: 4),
        Text(s.rearMirrorNote, style: t.bodySmall),
        const SizedBox(height: 2),
        Text(s.rearHelperNote, style: t.bodySmall),
        const SizedBox(height: 8),
        Text(distance,
            style: t.headlineSmall?.copyWith(
                color: color, fontWeight: FontWeight.w800)),
        if (move != null) ...[
          const SizedBox(height: 2),
          Text(move, style: t.titleMedium?.copyWith(color: color)),
        ],
      ]),
    );
  }
}

/// Bounded recovery ladder UI: try again, restart camera, and — only after
/// the full ladder — an explicit continue-without-lock escape. Downstream
/// modules record lock-dependent measurements as unable-to-assess.
class _RecoveryPanel extends StatelessWidget {
  final AppStrings s;
  final TextTheme t;
  final int attempts;
  final bool offerRestart;
  final bool offerUnable;
  final VoidCallback onTryAgain;
  final VoidCallback onRestart;
  final VoidCallback onSkipLock;
  const _RecoveryPanel({
    required this.s,
    required this.t,
    required this.attempts,
    required this.offerRestart,
    required this.offerUnable,
    required this.onTryAgain,
    required this.onRestart,
    required this.onSkipLock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OcuSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.amber, width: 2),
        borderRadius: BorderRadius.circular(OcuRadii.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.recoveryTitle, style: t.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: onTryAgain, child: Text(s.recoveryTryAgain)),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/camera-help'),
            icon: const Icon(Icons.help_outline),
            label: Text(s.cameraHelpBtn),
          ),
          OutlinedButton(
              onPressed: () {
                final cam = context.read<CameraService>();
                cam.switchSource(cam.activeSourceCode == 'rear'
                    ? FrontCameraSource()
                    : RearCameraSource());
              },
              child: Text(s.switchCameraBtn)),
          if (offerRestart)
            OutlinedButton(
                onPressed: onRestart, child: Text(s.restartCameraBtn)),
          if (offerUnable)
            TextButton(onPressed: onSkipLock, child: Text(s.recoveryContinueUnable)),
        ]),
        if (offerUnable) ...[
          const SizedBox(height: 6),
          Text(s.recoveryContinueNote, style: t.bodySmall),
        ],
      ]),
    );
  }
}