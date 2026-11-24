// Guided camera examination, v0.3.2: five stages with an explicit
// eye-positioning stage (face -> position -> eyes -> stabilize -> ready).
// Pipeline per feature:
// INPUT -> QUALITY CONTROL -> MEASUREMENT -> ALGORITHM -> UNCERTAINTY ->
// SCREENING FINDING -> LIMITATION -> ACTION.
// LOW quality never produces a confident result; unmeasured modules report
// unable-to-assess instead of guessing.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../../core/models/screening_result.dart';
import '../../../core/pipeline/quality_gate.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/device_label.dart';
import '../../../core/validation/analyzer_registry.dart';
import '../../../core/data/history_repository.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/evidence/evidence_repository.dart';
import '../../../core/localization/app_strings.dart';
import '../../../features/camera/camera_pipeline.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/camera/eye_tracking.dart';
import '../../../features/analyzers/facial_movement.dart';
import '../../../features/vision/face_detection_engine.dart';
import '../../../features/analyzers/eyelid.dart';
import '../../../features/analyzers/pupil_response.dart';
import '../../../features/analyzers/redness.dart';
import '../../../features/analyzers/scleral.dart';
import '../../../features/analyzers/blink.dart';
import '../../../main.dart';
import '../../widgets/common.dart';
import 'eye_stage.dart';
import 'snapshot_scan_view.dart';

class ScreeningFlow extends StatefulWidget {
  const ScreeningFlow({super.key});
  @override
  State<ScreeningFlow> createState() => _ScreeningFlowState();
}

/// Build a quality-gate input from a still image's OWN detected geometry
/// — never a stale live frame. Openness, centering, angle, and face
/// fraction all come from the same still the pixel stats came from.
/// Unknown openness (-1) is permissive (matches the tracker);
/// measured-closed eyes count as not-visible, and obstruction is only
/// claimed when closure was actually measured, never inferred from
/// unknown. Pure and unit-tested.
QualityInput stillQualityInput(EyeGeometry geo, ImageStats stats) {
  final openL = geo.leftOpenProb;
  final openR = geo.rightOpenProb;
  final located = geo.faceFound &&
      geo.faceCount == 1 &&
      geo.leftEye != null &&
      geo.rightEye != null;
  final openOk =
      (openL < 0 || openL > 0.35) && (openR < 0 || openR > 0.35);
  final box = geo.faceBox;
  final centered = box != null &&
      (((box.left + box.right) / 2) - 0.5).abs() < 0.12;
  return QualityInput(
    stats: stats,
    bothEyesVisible: located && openOk,
    faceCentered: centered,
    faceAngleDeg: geo.yawDeg,
    faceBoxFraction: geo.faceFraction,
    eyesObstructed: located &&
        openL >= 0 &&
        openR >= 0 &&
        !(openL > 0.35 && openR > 0.35),
    strongBacklight: false,
    coloredAmbientLight: false,
  );
}

class _ScreeningFlowState extends State<ScreeningFlow> {
  int step = 0;
  bool cameraOk = false;
  bool capturing = false;
  // Practice cover exercise skipped (no measurement depends on it).
  bool _coverSkipped = false;
  // Explicit LOW-quality acknowledgment before Summary (S6 ack-gate).
  bool _lowAck = false;
  String? error;
  ImageStats? stillStats;
  QualityVerdict? verdict;
  List<ScreeningResult> results = [];
  EyeRegionSample? _leftEyeSample;
  EyeRegionSample? _rightEyeSample;
  double _eyeColorConfidence = 0.0;
  final List<CaptureAttempt> _captureAttempts = [];
  bool _persisted = false;
  // Expression sampling: record measured per-eye openness, head yaw, and
  // timing at each prompt. Missing sides stay missing; they are never
  // synthesized from the measured side.
  final Map<String, ExpressionSample> expressionSamples = {};
  final List<double> blinkSeries = [];
  // Snapshot fallback (§13): still-image scan when live analysis fails.
  // Temporal modules stay unavailable; the summary is labeled accordingly.
  bool _snapshotMode = false;
  SnapshotData? _snapData;
  // Set once the eye stage achieves a real lock: facial-movement analysis
  // additionally requires that the face was actually positioned.
  bool _faceWasPositioned = false;

  @override
  void initState() {
    super.initState();
    // Hold the service reference: BuildContext must not be used in dispose
    // (deactivated-ancestor crash), so release() is called on this handle.
    _camRef = context.read<CameraService>();
    // Defer past the first frame: prepare() notifies listeners, which is
    // illegal synchronously inside initState (build phase).
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  CameraService? _camRef;

  @override
  void dispose() {
    // Free the camera on route exit; the service re-acquires on entry.
    _camRef?.release();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cam = context.read<CameraService>();
    final ok = await cam.prepare();
    if (!mounted) return;
    if (!ok &&
        cam.lastPermission != null &&
        cam.lastPermission != CameraPermission.granted) {
      await explainCameraIssue(context, cam.lastPermission!, null);
      if (!mounted) return;
    }
    setState(() { cameraOk = ok; error = cam.error; });
  }

  QualityInput _qualityInputFromLive() {
    final cam = context.read<CameraService>();
    final f = cam.lastFrame;
    // Conservative defaults when signals missing.
    final stats = stillStats ?? const ImageStats(
      meanLuminance: 120, overexposedFraction: 0.05, underexposedFraction: 0.05,
      sharpnessVariance: 80, rednessMean: 0.36, yellownessMean: 0.05, width: 640, height: 480);
    return QualityInput(
      stats: stats,
      bothEyesVisible: f?.bothEyesOpen ?? false,
      faceCentered: f?.centered ?? false,
      faceAngleDeg: f?.yawDeg ?? 0,
      faceBoxFraction: f?.faceFraction ?? 0.4,
      eyesObstructed: (f != null && f.faceFound && !f.bothEyesOpen),
      strongBacklight: false,
      coloredAmbientLight: false,
    );
  }

  Future<void> _captureAndAnalyzePixels() async {
    setState(() => capturing = true);
    final cam = context.read<CameraService>();
    final storeImages = context.read<SettingsRepository>().storeRawImages;
    try {
      final file = await cam.captureStill();
      var analyzed = false;
      EyeGeometry? stillGeo;
      if (file != null) {
        // Analyze the same still for geometry first, so eye-region color
        // comes from detected eye landmarks rather than the whole frame.
        stillGeo = await cam.analyzeStill(file.path);
        analyzed = await _analyzePixelFile(file.path, geo: stillGeo);
        // Privacy default: delete raw capture unless user opted into storage.
        if (!storeImages) { try { await File(file.path).delete(); } catch (_) {} }
      }
      if (!mounted) return;
      // The verdict describes the STILL, so its geometry inputs come from
      // the still's own detection — never a stale live frame that may
      // show a blink the still does not contain (or vice versa).
      final stats = stillStats;
      verdict = (analyzed && stillGeo != null && stats != null)
          ? QualityGate.evaluate(stillQualityInput(stillGeo, stats))
          : QualityGate.evaluate(_qualityInputFromLive());
      _lowAck = false;
      if (analyzed) _recordCaptureAttempt(cam.activeSourceCode);
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  void _recordCaptureAttempt(String source) {
    final v = verdict;
    final stats = stillStats;
    if (v == null || stats == null) return;
    _captureAttempts.add(CaptureAttempt(
      at: DateTime.now(),
      source: source,
      width: stats.width,
      height: stats.height,
      score: v.score,
      quality: v.quality,
      issues: List<String>.of(v.issues),
    ));
    while (_captureAttempts.length > 5) {
      _captureAttempts.removeAt(0);
    }
  }

  /// Pixel analysis shared by live capture and snapshot stills: decode,
  /// downsample for performance, compute exposure/sharpness stats at the
  /// real capture resolution, then sample landmark-centered eye regions
  /// when exactly one face with both eye landmarks is available.
  Future<bool> _analyzePixelFile(String path, {EyeGeometry? geo}) async {
    final cam = context.read<CameraService>();
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      stillStats = null;
      _leftEyeSample = null;
      _rightEyeSample = null;
      _eyeColorConfidence = 0.0;
      return false;
    }
    // Downsample to max 320px for speed; resolution checks still use the
    // original decoded dimensions.
    final small = img.copyResize(decoded, width: 320);
    final rgb = <int>[];
    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        rgb.addAll([p.r.toInt(), p.g.toInt(), p.b.toInt()]);
      }
    }
    stillStats = ImageUtils.computeStats(rgb,
        width: small.width,
        height: small.height,
        stride: 4,
        actualWidth: decoded.width,
        actualHeight: decoded.height);
    _leftEyeSample = _sampleEyeRegion(
        rgb, small.width, small.height, geo?.leftEye, geo);
    _rightEyeSample = _sampleEyeRegion(
        rgb, small.width, small.height, geo?.rightEye, geo);
    final left = _leftEyeSample;
    final right = _rightEyeSample;
    final stats = stillStats;
    _eyeColorConfidence = (left != null && right != null && stats != null)
        ? ImageUtils.eyeRegionColorConfidence(
            left: left, right: right, full: stats)
        : 0.0;
    // Keep a short openness trace for blink estimation. Unknown openness
    // is skipped rather than recorded as closed.
    final f = cam.lastFrame;
    if (f != null &&
        f.leftEyeOpenRaw >= 0 &&
        f.rightEyeOpenRaw >= 0) {
      blinkSeries.add((f.leftEyeOpenRaw + f.rightEyeOpenRaw) / 2);
    }
    return true;
  }

  /// Sample one eye ROI only for a single detected face with both eye
  /// landmarks and a valid face width. Anything else returns null so color
  /// analysis reports unavailable instead of using whole-frame pixels.
  EyeRegionSample? _sampleEyeRegion(List<int> rgb, int width, int height,
      EyePoint? center, EyeGeometry? geo) {
    if (geo == null ||
        !geo.faceFound ||
        geo.faceCount != 1 ||
        center == null ||
        geo.faceBox == null) {
      return null;
    }
    final faceWidth = geo.faceBox!.right - geo.faceBox!.left;
    final sample = ImageUtils.sampleEyeRegion(
        rgb: rgb,
        width: width,
        height: height,
        centerX: center.x,
        centerY: center.y,
        faceWidth: faceWidth);
    return sample.usable ? sample : null;
  }

  /// Enter snapshot fallback explicitly (user-chosen, never automatic).
  void _enterSnapshotMode() {
    setState(() {
      _snapshotMode = true;
      _snapData = null;
    });
  }

  /// Snapshot accepted: extract pixel stats from the SAME still, build a
  /// quality verdict from snapshot inputs, and jump to Measurements.
  /// Temporal modules (movement/blink/response) stay unable with reasons.
  Future<void> _acceptSnapshot(SnapshotData snap) async {
    final analyzed = await _analyzePixelFile(snap.path, geo: snap.geo);
    if (!mounted) return;
    final g = snap.geo;
    final openL = g.leftOpenProb;
    final openR = g.rightOpenProb;
    final stats = stillStats ?? const ImageStats(
      meanLuminance: 120, overexposedFraction: 0.05, underexposedFraction: 0.05,
      sharpnessVariance: 80, rednessMean: 0.36, yellownessMean: 0.05, width: 640, height: 480);
    // Center comes from the accepted still's detected face box. Unknown
    // geometry never defaults to centered.
    final box = g.faceBox;
    final faceCentered = box != null &&
        (((box.left + box.right) / 2) - 0.5).abs() < 0.12;
    verdict = QualityGate.evaluate(QualityInput(
      stats: stats,
      bothEyesVisible: openL > 0.35 && openR > 0.35,
      faceCentered: faceCentered,
      faceAngleDeg: g.yawDeg,
      faceBoxFraction: g.faceFraction,
      eyesObstructed: false,
      strongBacklight: false,
      coloredAmbientLight: false,
    ));
    if (analyzed) _recordCaptureAttempt('snapshot');
    _lowAck = false;
    // Snapshot pre-flight (S7): a low still says so immediately with its
    // top issue instead of failing silently at Measurements.
    if (verdict!.quality == ImageQuality.low && mounted) {
      final s = AppStrings(context.read<AppState>().lang);
      final top =
          verdict!.issues.isNotEmpty ? ' — ${verdict!.issues.first}' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${s.lowQualityBanner}$top')));
    }
    setState(() {
      _snapData = snap;
      step = 3;
    });
  }

  void _runAllAnalyzers() {
    final q = verdict ?? QualityGate.evaluate(_qualityInputFromLive());
    final cam = context.read<CameraService>();
    final f = cam.lastFrame;
    final status = cam.eyeStatus;
    // Snapshot stills carry their own measured openness (ML Kit runs on
    // the still); live frames use the tracker. Never filler constants.
    final snap = _snapshotMode ? _snapData?.geo : null;
    final openL = snap != null
        ? (snap.leftOpenProb < 0 ? -1.0 : snap.leftOpenProb)
        : (f?.leftEyeOpenRaw ?? -1.0);
    final openR = snap != null
        ? (snap.rightOpenProb < 0 ? -1.0 : snap.rightOpenProb)
        : (f?.rightEyeOpenRaw ?? -1.0);
    final out = <ScreeningResult>[];
    // AUDIT RULE (v0.3.1): no analyzer may receive unmeasured constants.
    // Modules without a real measured input in this build report
    // unable-to-assess with an explicit reason instead of guessing.
    ScreeningResult notMeasured(String test, String reason,
            {String measurement = 'not measured'}) =>
        ScreeningResult.unable(
          testName: test,
          imageQuality: q.quality,
          reason: reason,
          measurement: measurement,
          limitations: const [
            'This module needs a measurement this build cannot take reliably.',
            'Repeat the guided steps, or use research mode with measured inputs.',
          ],
        );
    // 1. Facial asymmetry: guided samples record measured per-eye openness
    // and timing, but this build does not track brow/mouth/cheek-region
    // displacement. The module therefore stays unable; the real openness
    // trace is retained in the measurement instead of inventing sides.
    final sampled = {'brow', 'smile', 'cheek'}
        .where((k) => expressionSamples.containsKey(k))
        .length;
    final faceOk = _faceWasPositioned ||
        (status?.meetsNeed(AnalyzerNeed.facialAsymmetry,
                cam.tracker.config) ??
            false);
    final detail = const FacialMovementAnalyzer().analyze([
      for (final k in ['brow', 'smile', 'cheek'])
        if (expressionSamples.containsKey(k)) expressionSamples[k]!,
    ]);
    final movementTrace = detail.samples.isEmpty
        ? 'no expression samples'
        : '${detail.summary} '
            '(span ${detail.spanSeconds.toStringAsFixed(1)}s)';
    if (sampled < 3) {
      out.add(notMeasured('Facial movement symmetry',
        'Only $sampled of 3 guided expressions were sampled. Complete the brow-raise, smile, and cheek-puff steps for a measurable comparison.',
        measurement: movementTrace));
    } else if (!faceOk) {
      out.add(notMeasured('Facial movement symmetry',
        'Expressions were sampled but the face was never positioned with eye lock-on, so left/right comparison has no stable frame of reference.',
        measurement: movementTrace));
    } else {
      out.add(notMeasured('Facial movement symmetry',
        'Expression holds were sampled, but brow/mouth/cheek-region displacement is not tracked in this build. Only eye openness and timing were measured, so no left/right movement comparison is available.',
        measurement: movementTrace));
    }
    // 2. Eyelid: live eye-openness classifier output is a real signal,
    // but only when a frame (or snapshot still) actually provided it.
    // Measured head pitch (0 = unknown) gates tilted captures.
    if (snap == null && f == null) {
      out.add(notMeasured('Eyelid position',
        'No camera frame ever reached the analyzer, so no eyelid-opening measurement exists.'));
    } else {
      final pitch = snap != null
          ? snap.pitchDeg
          : ((status?.pitchValid ?? false) ? status!.pitchDeg : 0.0);
      out.add(EyelidAnalyzer().analyze(
          EyelidInput(
              leftOpenness: openL,
              rightOpenness: openR,
              gazePitchDeg: pitch),
          q));
    }
    // 3. Alignment: cover-shift deltas are not tracked in this build.
    out.add(notMeasured('Eye alignment',
      'Cover/uncover eye-movement tracking is not measured in this build. The guided cover sequence runs, but no landmark-shift estimate is produced, so no alignment claim is made.'));
    // 4. Pupil: no pupil-area segmentation in this build; openness
    // probabilities cannot support asymmetry claims.
    out.add(notMeasured('Pupil symmetry',
      'Visible pupil-area segmentation is not available in this build. Multi-frame comparison needs segmented pupil regions, not openness estimates.'));
    // 5. Pupil response: disabled safely in this build.
    out.add(PupilResponseAnalyzer().analyze(
      const PupilResponseInput(hardwareSupportsSafeTest: false, leftSeries: [], rightSeries: []), q));
    // 6-10. Surface/pixel modules: redness uses landmark-centered eye-region
    // ROIs, not whole-frame color. Surface/corneal/lens need segmentation
    // models absent from this build.
    final still = stillStats;
    final leftSample = _leftEyeSample;
    final rightSample = _rightEyeSample;
    out.add(notMeasured('Ocular surface',
      'Eye-surface segmentation is not available in this build, so no growth assessment is produced.'));
    if (leftSample == null || rightSample == null) {
      out.add(notMeasured('Eye redness',
        'Detected eye landmarks were unavailable, so eye-region color was not measured. Whole-frame color is not eye redness and was not substituted.'));
    } else {
      out.add(RednessAnalyzer().analyze(RednessInput(
        leftRedness: leftSample.rednessMean,
        rightRedness: rightSample.rednessMean,
        rednessSpread: leftSample.redDominantFraction > rightSample.redDominantFraction
            ? leftSample.redDominantFraction
            : rightSample.redDominantFraction,
        whiteBalanceConfidence: _eyeColorConfidence), q));
    }
    out.add(ScleralAnalyzer().analyze(ScleralInput(
      yellowness: still?.yellownessMean ?? 0.05, calibrationPassed: false,
      warmLight: false, coloredLight: false, calibrationConfidence: 0.3), q));
    out.add(notMeasured('Corneal clarity',
      'Corneal segmentation is not available in this build, so no opacity assessment is produced.'));
    out.add(notMeasured('Lens clarity (experimental)',
      'Lens assessment needs a supported close-up capture method absent from this build.'));
    // 11-12. Temporal modules: filler series are forbidden — insufficient
    // tracked frames report unable-to-assess instead of inventing a pattern.
    if (blinkSeries.length >= 30) {
      out.add(BlinkAnalyzer().analyze(BlinkInput(openness: blinkSeries, fps: 15), q));
    } else {
      out.add(notMeasured('Blink pattern',
        'Only ${blinkSeries.length} tracked openness samples were recorded (need ≥30). Blink rate cannot be estimated from filler data.'));
    }
    out.add(notMeasured('Eye movement stability',
      'Gaze-position tracking is not available in this build, so no oscillation analysis is produced.'));
    setState(() { results = out; });
  }

  /// Persist the final summary once per flow (never on intermediate runs):
  /// back-and-forth navigation must not duplicate history records.
  /// Each row is stamped with traceability (§49/§85): algorithm version
  /// from the registry, evidence DB version, camera hardware, device.
  /// Anything unresolvable stays empty ("not recorded") — never invented.
  Future<void> _persistOnce() async {
    if (_persisted || results.isEmpty) return;
    _persisted = true;
    final histOn = context.read<SettingsRepository>().historyEnabled;
    if (!histOn) return;
    String evidenceVersion = '';
    try {
      evidenceVersion =
          (await EvidenceRepository.load()).dbVersion;
    } catch (_) {}
    String device = '';
    try {
      device = await localDeviceLabel();
    } catch (_) {}
    if (!mounted) return;
    final cam = context.read<CameraService>();
    final hardware = cam.activeSourceCode;
    final profileId = context.read<AppState>().profileId;
    // Measurement trace (§9): which engine + model + protocol produced
    // this row. Snapshot stills never touched live ML Kit.
    final engine = _snapshotMode
        ? 'snapshot-still'
        : (cam.nativePreviewTextureId != null
            ? 'native-mlkit'
            : 'dart-mlkit');
    final repo = context.read<HistoryRepository>();
    for (final r in results) {
      repo.insert(r.copyWith(
        hardware: hardware,
        deviceLabel: device,
        algorithmVersion:
            AnalyzerRegistry.versionForTestName(r.testName),
        evidenceVersion: evidenceVersion,
        profileId: profileId,
        modelVersion: kFaceDetectionModelVersion,
        protocolVersion: QualityGate.protocolVersion,
        engine: engine,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cam = context.watch<CameraService>();
    final s = AppStrings(context.watch<AppState>().lang);
    final names = [
      s.stagePosition, s.stageEyes, s.stageMovement, s.stageMeasurements, s.stageSummary
    ];
    // Record a real lock for the analyzer-specific face gate.
    if ((cam.eyeStatus?.locked ?? false) && !_faceWasPositioned) {
      _faceWasPositioned = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${s.screeningTitle} — ${names[step]}'),
        leading: IconButton(icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _StageHeader(step: step, names: names, s: s, t: t),
        const SizedBox(height: 12),
        if (error != null) SafetyBanner(text: s.cameraIssue(error!)),
        // initFailed is terminal for this entry: the banner alone strands
        // the user, so offer the same bounded retries as the eye stage
        // (next-config retry, hard restart, help) right here.
        if (error != null && cam.stage == CameraStage.initFailed) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
                onPressed: () async {
                  final ok = await cam.retryWithFallback();
                  if (!mounted) return;
                  setState(() {
                    cameraOk = ok;
                    error = cam.error;
                  });
                },
                child: Text(s.retryAnalysis)),
            OutlinedButton(
                onPressed: () async {
                  final ok = await cam.restartCamera();
                  if (!mounted) return;
                  setState(() {
                    cameraOk = ok;
                    error = cam.error;
                  });
                },
                child: Text(s.restartCameraBtn)),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/camera-help'),
              icon: const Icon(Icons.help_outline),
              label: Text(s.cameraHelpBtn),
            ),
          ]),
        ],
        _stepBody(t, cam, s),
        const SizedBox(height: 16),
        Row(children: [
          if (step > 0) Expanded(child: OutlinedButton(
            onPressed: () => setState(() => step--), child: Text(s.back))),
          if (step > 0) const SizedBox(width: 10),
          Expanded(child: FilledButton(
            onPressed: _nextEnabled(cam) ? () => _next() : null,
            child: Text(step == names.length - 1 ? s.finish : s.continueBtn),
          )),
        ]),
        if (step == 1 && !_canAdvancePastStep1(cam) && error == null) ...[
          const SizedBox(height: 8),
          Text(s.needLockToContinue,
              textAlign: TextAlign.center, style: t.bodySmall),
        ],
        if (step == 3 &&
            verdict != null &&
            verdict!.quality == ImageQuality.low &&
            !_lowAck) ...[
          const SizedBox(height: 8),
          Text(s.lowAckHint,
              textAlign: TextAlign.center, style: t.bodySmall),
        ],
        if (step == 1 && !_eyeLocked(cam) && !_manualPositionConfirmed) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showEscapeChooser(),
            icon: const Icon(Icons.help_outline),
            label: Text(s.escapeTitle),
          ),
        ],
        const SizedBox(height: 8),
        SafetyBanner(text: s.screeningSafetyNote),
      ]),
    );
  }

  bool _eyeLocked(CameraService cam) => cam.eyeStatus?.locked ?? false;

  /// Manual positioning: when automatic lock is unavailable (ML Kit
  /// failure), the user confirms positioning themselves. Vision tests
  /// and available measurements still run; lock-dependent measures
  /// report unable-to-assess. Never blocks the user, never guesses.
  bool _manualPositionConfirmed = false;

  bool _canAdvancePastStep1(CameraService cam) =>
      _eyeLocked(cam) || _manualPositionConfirmed;

  bool _nextEnabled(CameraService cam) {
    if (step == 1) return _canAdvancePastStep1(cam);
    // LOW never upgrades to confident findings downstream, but the user
    // may still continue after explicitly acknowledging it (accessibility:
    // never hard-block someone who cannot improve lighting).
    if (step == 3) {
      if (verdict == null) return false;
      if (verdict!.quality == ImageQuality.low && !_lowAck) return false;
      return true;
    }
    return true;
  }

  /// Summary sections: measured results first, then unable-to-assess with
  /// reasons — so the 1–2 real signals are never buried under a wall of
  /// identical unable cards. Each section header renders once.
  List<Widget> _summarySections(AppStrings s, TextTheme t) {
    Widget card(ScreeningResult r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ResultCard(
            result: r,
            showEvidence: true,
            evidenceId: EvidenceRepository.evidenceIdForTestName(r.testName),
          ),
        );
    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text,
              style:
                  t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        );
    final out = <Widget>[];
    final measured = results
        .where((r) => r.finding != ResultCategory.unableToAssess)
        .toList();
    final unable = results
        .where((r) => r.finding == ResultCategory.unableToAssess)
        .toList();
    if (measured.isNotEmpty) {
      out.add(header(s.summaryMeasuredTitle));
      out.addAll(measured.map(card));
    }
    if (unable.isNotEmpty) {
      out.add(const SizedBox(height: 6));
      out.add(header(s.summaryUnableTitle));
      out.addAll(unable.map(card));
    }
    return out;
  }

  /// Start over as a new screening: clears verdicts, samples, captures,
  /// and results so a repeat run never mixes measurements across runs.
  /// Persisted history rows are untouched.
  void _restartFlow() {
    setState(() {
      step = 0;
      error = null;
      _coverSkipped = false;
      _lowAck = false;
      stillStats = null;
      verdict = null;
      results = [];
      _leftEyeSample = null;
      _rightEyeSample = null;
      _eyeColorConfidence = 0.0;
      _captureAttempts.clear();
      _persisted = false;
      expressionSamples.clear();
      blinkSeries.clear();
      _snapshotMode = false;
      _snapData = null;
      _faceWasPositioned = false;
      _manualPositionConfirmed = false;
    });
  }

  /// One honest escape chooser replacing the two parallel outs (manual
  /// card vs snapshot skip): names what each path keeps and loses so the
  /// user is never surprised by unable modules at Summary.
  void _showEscapeChooser() {
    final s = AppStrings(context.read<AppState>().lang);
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(s.escapeTitle),
        content: Text(s.escapeBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dctx);
              _enterSnapshotMode();
            },
            child: Text(s.escapeSnapshot),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dctx);
              setState(() => _manualPositionConfirmed = true);
            },
            child: Text(s.escapeManual),
          ),
        ],
      ),
    );
  }

  void _next() async {
    if (step == 3 && results.isEmpty) _runAllAnalyzers();
    if (step < 4) {
      setState(() => step++);
      if (step == 4) {
        if (results.isEmpty) _runAllAnalyzers();
        _persistOnce();
      }
    } else {
      Navigator.pop(context);
    }
  }

  Widget _stepBody(TextTheme t, CameraService cam, AppStrings s) {
    final f = cam.lastFrame;
    switch (step) {
      case 0:
        final lum = cam.lastQuality.meanLuminance;
        // Thresholds mirror QualityGate (45..210): pills here must never
        // contradict the later verdict on the same face.
        final checks = <String, bool>{
          s.positionCheckLighting: lum > 45 && lum < 210,
          s.positionCheckEyes: f?.bothEyesOpen ?? false,
          s.positionCheckCentered: f?.centered ?? false,
          s.positionCheckSharp: cam.lastQuality.blurVariance > 8,
        };
        final firstBad = checks.entries
            .where((e) => !e.value)
            .map((e) => e.key)
            .toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.positionTitle, style: t.bodyLarge),
          const SizedBox(height: 12),
          if (firstBad.isNotEmpty) ...[
            SafetyBanner(text: s.positionNextStep(firstBad.first)),
            const SizedBox(height: 8),
          ],
          GuideChecklist(items: checks),
          const SizedBox(height: 12),
          Text(s.positionHint),
        ]);
      case 1:
        if (_snapshotMode) {
          return SnapshotScanView(
            onDone: (snap) => _acceptSnapshot(snap),
            onBackToLive: () => setState(() {
              _snapshotMode = false;
              _snapData = null;
            }),
          );
        }
        return EyeStageView(
          onSkipLock: () => _enterSnapshotMode(),
          onSnapshot: () => _enterSnapshotMode(),
        );
      case 2:
        // Sampling readiness mirrors the _sampleExpression reject
        // condition: disabled buttons explain themselves instead of
        // snacking a rejection the user cannot act on.
        final sampleReady = cam.ready &&
            f != null &&
            f.faceFound &&
            !(cam.eyeStatus?.positionsStale ?? true);
        const requiredKeys = ['brow', 'smile', 'cheek'];
        final missingKeys = requiredKeys
            .where((k) => !expressionSamples.containsKey(k))
            .toList();
        OutlinedButton sampleBtn(String key, String label) =>
            OutlinedButton(
                onPressed: sampleReady
                    ? () => _sampleExpression(key, cam)
                    : null,
                child: Text(label));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.movementTitle, style: t.bodyLarge),
          const SizedBox(height: 6),
          Text(s.movementHint, style: t.bodySmall),
          const SizedBox(height: 4),
          Text(s.movementMeasuredNote, style: t.bodySmall),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            sampleBtn('neutral', s.sampleNeutral),
            sampleBtn('brow', s.sampleBrow),
            sampleBtn('eyes_closed', s.sampleEyesClosed),
            sampleBtn('smile', s.sampleSmile),
            sampleBtn('cheek', s.sampleCheek),
          ]),
          const SizedBox(height: 6),
          Text(s.samplesRecorded(expressionSamples.length, f?.yawDeg ?? 0),
              style: t.bodySmall),
          if (missingKeys.isNotEmpty)
            Text(s.movementMissing(missingKeys.join(' • ')),
                style: t.bodySmall),
          if (expressionSamples.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final sample in _orderedExpressionSamples())
              Text(
                  s.expressionSampleLine(
                      sample.key,
                      (sample.leftAmplitude ?? -1) / 20 * 100,
                      (sample.rightAmplitude ?? -1) / 20 * 100,
                      sample.yawDeg),
                  style: t.bodySmall),
          ],
          const SizedBox(height: 6),
          SafetyBanner(text: s.movementSafety),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_snapshotMode) ...[
            SafetyBanner(text: s.snapModeBanner),
            const SizedBox(height: 10),
          ],
          Text(s.measureCoverTitle, style: t.bodyLarge),
          const SizedBox(height: 4),
          Text(s.measureCoverPractice, style: t.bodySmall),
          const SizedBox(height: 8),
          if (!_coverSkipped) ...[
            Container(alignment: Alignment.center, height: 120,
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8E6)), borderRadius: BorderRadius.circular(10)),
              child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFF0A5E5D), shape: BoxShape.circle))),
            const SizedBox(height: 8),
            Text(s.measureCoverHint, style: t.bodySmall),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _coverSkipped = true),
              child: Text(s.measureCoverSkip)),
          ],
          const SizedBox(height: 12),
          Text(s.measureCaptureTitle, style: t.bodyLarge),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: capturing ? null : _captureAndAnalyzePixels,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(capturing ? s.analyzing : s.captureAndCheck)),
          if (verdict != null) ...[
            const SizedBox(height: 10),
            Text(s.qualityScore(verdict!.quality.name.toUpperCase(), verdict!.score),
                style: t.titleMedium),
            for (final i in verdict!.issues) Text('• $i'),
            for (final g in verdict!.guidance) Text('→ $g', style: t.bodySmall),
            if (verdict!.quality == ImageQuality.low) ...[
              Padding(padding: const EdgeInsets.only(top: 8),
                child: SafetyBanner(text: s.lowQualityBanner)),
              CheckboxListTile(
                value: _lowAck,
                onChanged: (v) => setState(() => _lowAck = v ?? false),
                title: Text(s.lowAckLabel),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ],
          if (_captureAttempts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
                s.captureAttemptLine(
                    _captureAttempts.length,
                    _captureAttempts.length,
                    _captureAttempts.last.width,
                    _captureAttempts.last.height,
                    _captureAttempts.last.source),
                style: t.bodySmall),
            if (_captureAttempts.length > 1)
              Text(
                  s.captureDeltaLine(
                      _captureAttempts.last.score -
                          _captureAttempts[_captureAttempts.length - 2].score,
                      _captureAttempts.last.resolvedSince(_captureAttempts[
                          _captureAttempts.length - 2]).length,
                      _captureAttempts.last.introducedSince(_captureAttempts[
                          _captureAttempts.length - 2]).length),
                  style: t.bodySmall),
          ],
          if (stillStats != null) ...[
            const SizedBox(height: 8),
            Text(
                s.stillExposureLine(
                    stillStats!.sharpnessVariance,
                    stillStats!.meanLuminance,
                    stillStats!.width,
                    stillStats!.height),
                style: t.bodySmall),
            const SizedBox(height: 4),
            Text(
                _leftEyeSample != null && _rightEyeSample != null
                    ? s.eyeRegionStatsLine(
                        _leftEyeSample!.rednessMean,
                        _rightEyeSample!.rednessMean,
                        _eyeColorConfidence)
                    : s.eyeRegionsUnavailable,
                style: t.bodySmall),
          ],
          const SizedBox(height: 12),
          Text(s.pupilInfoTitle, style: t.bodyLarge),
          const SizedBox(height: 8),
          SafetyBanner(text: s.pupilDisabledNote),
          const SizedBox(height: 12),
          Text(s.surfaceCaptureTitle, style: t.bodyLarge),
        ]);
      default:
        if (results.isEmpty) {
          // Defer analysis past the current build pass: calling setState
          // synchronously during build is a framework violation.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || results.isNotEmpty) return;
            _runAllAnalyzers();
            _persistOnce();
          });
        }
        final measuredCount = results
            .where((r) => r.finding != ResultCategory.unableToAssess)
            .length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.summaryTitle, style: t.headlineSmall),
          const SizedBox(height: 4),
          Text(s.summaryNote, style: t.bodySmall),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
                s.summaryCountLine(
                    measuredCount, results.length - measuredCount),
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
          if (_snapshotMode) ...[
            const SizedBox(height: 8),
            SafetyBanner(text: s.snapModeBanner),
          ],
          const SizedBox(height: 10),
          ..._summarySections(s, t),
          if (results.any(
              (r) => r.finding == ResultCategory.possibleFinding)) ...[
            const SizedBox(height: 4),
            SafetyBanner(text: s.summaryFindingAlert),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/emergency'),
              icon: const Icon(Icons.warning_amber_outlined),
              label: Text(s.urgentSymptoms),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/history'),
              icon: const Icon(Icons.history),
              label: Text(s.summaryViewHistory),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/report'),
              icon: const Icon(Icons.ios_share),
              label: Text(s.summaryShareReport),
            ),
            OutlinedButton.icon(
              onPressed: _restartFlow,
              icon: const Icon(Icons.refresh_outlined),
              label: Text(s.summaryNewScreening),
            ),
          ]),
          const SizedBox(height: 8),
          SafetyBanner(text: s.summaryRepeat),
        ]);
    }
  }

  List<ExpressionSample> _orderedExpressionSamples() {
    final samples = expressionSamples.values.toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return samples;
  }

  void _sampleExpression(String key, CameraService cam) {
    final s = AppStrings(context.read<AppState>().lang);
    final f = cam.lastFrame;
    final status = cam.eyeStatus;
    final left = f?.leftEyeOpenRaw ?? -1;
    final right = f?.rightEyeOpenRaw ?? -1;
    if (!cam.ready ||
        f == null ||
        !f.faceFound ||
        (status?.positionsStale ?? true) ||
        left < 0 ||
        right < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.sampleRejectedKey(key))));
      return;
    }
    final now = DateTime.now();
    setState(() {
      expressionSamples[key] = ExpressionSample(
        key: key,
        amplitude: (left + right) / 2 * 20,
        leftAmplitude: left * 20,
        rightAmplitude: right * 20,
        yawDeg: f.yawDeg,
        at: now,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.sampledSidesSnack(
            key, left * 100, right * 100, f.yawDeg))));
  }
}

class _StageHeader extends StatelessWidget {
  final int step;
  final List<String> names;
  final AppStrings s;
  final TextTheme t;
  const _StageHeader(
      {required this.step, required this.names, required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.stepOf(step + 1, names.length, names[step].toUpperCase()),
          style: t.labelLarge?.copyWith(
              color: const Color(0xFF0A5E5D),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: (step + 1) / names.length),
    ]);
  }
}
