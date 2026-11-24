// Camera service: live preview + on-device face detection (ML Kit).
// v0.3.3 physical-device pipeline: explicit stage machine, observed ML
// input layout, recorded errors, FPS counters, front/rear sources.
// (Part 1: state, stages, init/switch/restart lifecycle.)

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/localization/app_strings.dart';
import '../../core/validation/analyzer_registry.dart';
import '../vision/face_detection_engine.dart';
import '../vision/native_face_engine.dart';
import '../vision/vision_engine_manager.dart';
import 'camera_pipeline.dart';
import 'eye_tracking.dart';
import 'frame_validator.dart';
import 'ml_diagnostic.dart';
import 'image_source.dart';
import 'jpeg_fallback.dart';

/// Camera permission outcome for explicit pre-flight checks.
enum CameraPermission { granted, denied, permanentlyDenied }

/// Request camera permission explicitly (instead of relying on the camera
/// plugin's implicit prompt) so denial states get clear UX, including a
/// route to system settings when permanently denied. Returns granted on
/// platforms without a permission API (web/test fallbacks).
Future<CameraPermission> ensureCameraPermission() async {
  try {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      return CameraPermission.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermission.permanentlyDenied;
    }
    return CameraPermission.denied;
  } catch (_) {
    return CameraPermission.granted;
  }
}

/// Explain a camera failure with a settings shortcut when appropriate.
/// Shows nothing and returns false when permission was granted but the
/// camera still failed (callers already surface [CameraService.error]).
Future<bool> explainCameraIssue(
  BuildContext context,
  CameraPermission permission,
  String? detail,
) async {
  if (permission == CameraPermission.granted) return false;
  final s = AppStrings(
      Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en');
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(s.cameraUnavailableTitle),
      content: Text(permission == CameraPermission.permanentlyDenied
          ? s.cameraBlockedBody
          : s.cameraDeniedBody(detail ?? s.cameraDeniedDefault)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.notNow)),
        if (permission == CameraPermission.permanentlyDenied)
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.openSettings)),
      ],
    ),
  );
  if (openSettings == true) {
    try {
      await openAppSettings();
    } catch (_) {}
  }
  return true;
}

/// Legacy compact frame (kept for compatibility). New code should use
/// [CameraService.eyeStatus], which carries geometry + diagnostic state.
class FaceFrame {
  final bool faceFound;
  final bool bothEyesOpen;
  final double yawDeg;
  final double faceFraction;
  final bool centered;
  final double leftEyeOpenProb;
  final double rightEyeOpenProb;

  /// Raw openness probabilities (-1 when the detector did not report them).
  /// The convenience probabilities above preserve legacy behavior by mapping
  /// unknown to closed; sampling must use these raw values instead.
  final double leftEyeOpenRaw;
  final double rightEyeOpenRaw;
  const FaceFrame({
    required this.faceFound, required this.bothEyesOpen, required this.yawDeg,
    required this.faceFraction, required this.centered,
    required this.leftEyeOpenProb, required this.rightEyeOpenProb,
    this.leftEyeOpenRaw = -1,
    this.rightEyeOpenRaw = -1,
  });
}

/// Per-detector-generation inference stats (research-only, export).
class _GenStats {
  final String tier;
  int frames = 0;
  double sumMs = 0;
  _GenStats(this.tier);
}

/// One entry of the research-only frame log (ring buffer, not user-facing).
class FrameLogEntry {
  final DateTime time;
  final int width;
  final int height;
  final int rotationDeg;
  final int sensorOrientation;
  final bool mirrored;
  final String state;
  final String box;
  final String eyes;
  final double luminance;
  final double blur;
  final String mlFormat;
  // End-to-end ms for this frame's inference (conversion + ML Kit).
  // 0 = predates the split (never written by new code).
  final double latencyMs;
  const FrameLogEntry({
    required this.time, required this.width, required this.height,
    required this.rotationDeg, required this.sensorOrientation,
    required this.mirrored, required this.state, required this.box,
    required this.eyes, required this.luminance, required this.blur,
    this.mlFormat = 'nv21',
    this.latencyMs = 0,
  });

  @override
  String toString() =>
      '${time.toIso8601String().substring(11, 23)} ${width}x$height '
      'rot$rotationDeg sensor$sensorOrientation ${mirrored ? 'mirror' : 'direct'} '
      '$state box[$box] eyes[$eyes] lum${luminance.toStringAsFixed(0)} '
      'blur${blur.toStringAsFixed(1)} ml[$mlFormat ${latencyMs.toStringAsFixed(0)}ms]';
}

/// Recorded camera/ML failure. Shown in full only in /dev; normal UI maps
/// it to safe state text.
class CameraError {
  final DateTime time;
  final String stage;
  final String type;
  final String message;
  final String? stack;
  const CameraError({
    required this.time, required this.stage, required this.type,
    required this.message, this.stack,
  });

  @override
  String toString() => '${time.toIso8601String().substring(11, 23)} '
      '[$stage] $type: $message';
}

/// One failed face-detection attempt (research-only). No images recorded.
class FaceFailEntry {
  final DateTime time;
  final int frameIndex;
  final int width;
  final int height;
  final String format;
  final int rotationDeg;
  final double luminance;
  final double blur;
  final String? error;
  const FaceFailEntry({
    required this.time, required this.frameIndex, required this.width,
    required this.height, required this.format, required this.rotationDeg,
    required this.luminance, required this.blur, this.error,
  });

  @override
  String toString() {
    final err = error == null
        ? ' no-face'
        : ' ERR ${error!.length > 300 ? '${error!.substring(0, 300)}…' : error!}';
    return '${time.toIso8601String().substring(11, 23)} #$frameIndex '
        '${width}x$height $format rot$rotationDeg '
        'lum${luminance.toStringAsFixed(0)} blur${blur.toStringAsFixed(1)}$err';
  }
}

/// Timestamped pipeline event for /dev + diagnostic export. Never carries
/// image data or personal data.
class CameraEvent {
  final DateTime time;
  final String code;
  final String detail;
  const CameraEvent(this.time, this.code, this.detail);

  @override
  String toString() =>
      '${time.toIso8601String().substring(11, 23)} $code $detail';
}

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  CameraDescription? _cameraDesc;
  FaceDetector? _detector;
  bool _detectorClosed = false;
  final EyeTracker tracker = EyeTracker();
  final StartupWatchdog watchdog = const StartupWatchdog();
  bool _busy = false;
  bool _streamActive = false;
  FaceFrame? lastFrame;
  EyeStatus? eyeStatus;
  String? error;
  /// Engine-aware readiness: the plugin controller on the Dart path,
  /// the live native session on the native path. Every UI gate on
  /// `ready` (screening sampling, dev probes, capture buttons) must see
  /// a bound camera regardless of which engine owns it — v0.7.18 proved
  /// native-primary sessions read "not ready" on every screen.
  bool get ready =>
      (_controller?.value.isInitialized ?? false) || _nativeActive;

  CameraController? get controller => _controller;

  /// Preview truth, independent of analysis: the controller is
  /// initialized and the preview texture exists, regardless of which
  /// (if any) failure stage the analysis pipeline sits in.
  bool get previewAlive => ready;

  // ---------- State machine ----------
  CameraStage _stage = CameraStage.idle;
  CameraStage get stage => _stage;
  String _stageDetail = '';
  String get stageDetail => _stageDetail;
  CameraError? _lastError;
  CameraError? get lastError => _lastError;

  void _setStage(CameraStage s, [String detail = '']) {
    _stage = s;
    _stageDetail = detail;
    _event('STAGE', '${s.name}${detail.isEmpty ? '' : ' $detail'}');
  }

  // ---------- Events / errors (research-only detail) ----------
  final List<CameraEvent> events = [];
  static const int eventsCap = 60;
  // Full-fidelity recent errors (with native stacks) for the export.
  final List<CameraError> errorLog = [];
  static const int errorLogCap = 10;

  void _event(String code, String detail) {
    events.add(CameraEvent(DateTime.now(), code, detail));
    if (events.length > eventsCap) {
      events.removeRange(0, events.length - eventsCap);
    }
  }

  void _recordError(String stage, Object e, [StackTrace? st]) {
    _lastError = CameraError(
      time: DateTime.now(),
      stage: stage,
      type: e.runtimeType.toString(),
      message: e.toString(),
      stack: st?.toString(),
    );
    // Bounded full-fidelity history (message AND stack): the diagnostic
    // export carries these untruncated so a native crash (e.g. ML Kit
    // converter NPE) can be diagnosed from its real stack, not the
    // 160-char UI line. No images, no personal data — errors only.
    errorLog.add(_lastError!);
    if (errorLog.length > errorLogCap) {
      errorLog.removeRange(0, errorLog.length - errorLogCap);
    }
    _event('ERROR', _lastError.toString());
  }

  // ---------- Frame counters / performance (real data only) ----------
  int framesReceived = 0;
  int framesProcessed = 0;
  int framesDropped = 0;
  int consecMlErrors = 0;
  int consecConvertErrors = 0;
  DateTime? streamStartedAt;
  DateTime? firstFrameAt;
  DateTime? _lastFrameTime;
  double lastLatencyMs = 0;
  double _fpsEma = 0;
  // Latency split for the last completed inference (ms): conversion
  // (bytes→RGBA / JPEG encode, 0 on the zero-copy bytes path) vs ML Kit
  // processImage. Added v0.7.15: the 0.7.14 regression (275ms end to end)
  // could not be attributed to conversion or inference without it.
  double lastConvertMs = 0;
  double lastInferMs = 0;
  double _latencyEma = 0;
  double get meanLatencyMs => _latencyEma;
  // Detection census (session totals): processed frames where the
  // detector returned ≥1 face, and lock acquisitions (transitions into
  // locked). Powers the Compat Lab detection summary; reset per session.
  int facesDetectedTotal = 0;
  int locksAchievedTotal = 0;
  bool _wasLocked = false;
  // ML mapping dims (what the detector actually saw): written ONLY on
  // inference completion. The arrival fields (_lastW/_lastH/_lastRotation)
  // stay sensor-space so readers never see a race between arrival and
  // completion values (v0.7.14: export showed 720x480/270° while Compat
  // Lab showed 240x360/0° — same session, different writers).
  int _mlMapW = 0;
  int _mlMapH = 0;
  int _mlMapRot = -1;
  String _mlMapKind = '';
  String get mlInputLabel => _mlMapW > 0
      ? '$_mlMapW x $_mlMapH rot$_mlMapRot $_mlMapKind'
      : '';
  // Per-generation inference stats: which tier ran, how many frames it
  // completed, total ms. The export carries the table so the next
  // tier experiment is decided by measurement, not by assumption.
  final Map<int, _GenStats> _genStats = {};
  String _lastBitmapSig = '';
  double get processingFps => _fpsEma;
  final List<DateTime> _arrivals = [];

  /// Monotonic frame counter (never resets except on release/switch).
  int frameIndex = 0;

  /// Raw face-detector output for the minimal face test (no tracker).
  int lastFaceCount = 0;
  List<Rect> lastFaceBoxes = const [];
  bool mlReady = false;
  DateTime? mlReadyAt;

  /// Failed face-detection attempts (ring, research-only, no images).
  final List<FaceFailEntry> faceFailLog = [];
  static const int faceFailCap = 20;

  double get arrivalFps {
    if (_arrivals.length < 2) return 0;
    final span = _arrivals.last.difference(_arrivals.first);
    if (span.inMilliseconds <= 0) return 0;
    return (_arrivals.length - 1) * 1000 / span.inMilliseconds;
  }

  int get lastFrameAgeMs => _lastFrameTime == null
      ? -1
      : DateTime.now().difference(_lastFrameTime!).inMilliseconds;

  // ---------- Sources / capabilities ----------
  ImageSource activeSource = FrontCameraSource();
  List<CameraDescription> _availableCams = [];
  bool switching = false;

  String get activeSourceCode => activeSource.code;

  /// Capability inventory for the Compat Lab (device-derived, never
  /// hard-coded): presence per lens, sensor orientations, last frame
  /// size label. Empty before the first camera enumeration.
  bool get hasFrontCamera => _availableCams.any(
      (c) => c.lensDirection == CameraLensDirection.front);
  bool get hasRearCamera => _availableCams.any(
      (c) => c.lensDirection == CameraLensDirection.back);
  List<int> get sensorOrientations => [
        for (final c in _availableCams) c.sensorOrientation,
      ];
  String get lastFrameSizeLabel =>
      (_lastW > 0 && _lastH > 0) ? '${_lastW}x$_lastH' : '';

  List<CameraCapabilities> get capabilities => [
        for (final c in _availableCams)
          CameraCapabilities(
            code: c.lensDirection == CameraLensDirection.front
                ? 'front'
                : (c.lensDirection == CameraLensDirection.back
                    ? 'rear'
                    : 'external'),
            lensDirection: c.lensDirection.name,
            sensorOrientation: c.sensorOrientation,
            name: c.name,
            previewWidth:
                _cameraDesc?.name == c.name ? _lastW : null,
            previewHeight:
                _cameraDesc?.name == c.name ? _lastH : null,
          ),
      ];

  BestCameraDecision recommendFor(TestCameraNeed need) =>
      recommendCamera(need: need, available: capabilities);

  /// Research-only frame log (newest last, capped).
  final List<FrameLogEntry> frameLog = [];
  static const int frameLogCap = 40;

  /// Camera facts for /dev: lens, sensor orientation, last ML Kit rotation,
  /// last image size, mirroring, stage, counters. Never shown to users.
  String get cameraInfo {
    final d = _cameraDesc;
    if (d == null) {
      // Native-primary sessions never populate _cameraDesc (no plugin
      // controller): report the live native session instead of the
      // misleading 'not initialized' (v0.7.18 export artifact).
      if (_nativeActive) {
        final s = _nativeEngine?.session;
        return 'lens=$activeSourceCode sensor=$_nativeSensorRot nativeGen=${s?.generation ?? -1} tex=${_nativeTextureId != null} '
            'stage=${_stage.name} rx=$framesReceived ok=$framesProcessed drop=$framesDropped';
      }
      return 'camera: not initialized';
    }
    final front = d.lensDirection == CameraLensDirection.front;
    return 'lens=${front ? 'front' : (d.lensDirection == CameraLensDirection.back ? 'back' : 'external')} '
        'sensor=${d.sensorOrientation} lastRot=${_lastRotation}deg '
        'lastFrame=${_lastW}x$_lastH mirrored=$front '
        'stage=${_stage.name} rx=$framesReceived ok=$framesProcessed drop=$framesDropped';
  }

  int _lastRotation = 0;
  int _lastW = 0;
  int _lastH = 0;
  FrameQuality _lastQuality = const FrameQuality.unknown();
  String _lastMlFormat = 'nv21';
  int _lastPlaneCount = 0;
  int _lastStride = 0;
  // Layout forensics (Agent-5 gap S1): persisted per frame so remote
  // triage sees exactly what the converter observed.
  int _lastPixelStride = 0;
  List<int> _lastPlaneLengths = const [];
  String _lastGroupName = '';
  String _lastLayoutKind = '';
  int _lastBytesLen = 0;
  int _lastExpectedLen = -1;

  /// When true (enabled by /dev only), retain a copy of the ML input Y
  /// bytes for the diagnostic grayscale view. One frame buffer, overwritten
  /// per processed frame; null when disabled or no frame yet.
  bool retainMlPreview = false;
  Uint8List? lastMlGray;
  int lastMlGrayW = 0;
  int lastMlGrayH = 0;
  int lastMlGrayRot = 0;

  /// Latest frame facts for overlays and /dev. All in raw-image terms;
  /// map to widgets with [EyeCoords.imageToPreview].
  int get lastRotationDeg => _lastRotation;
  Size get lastFrameSize => Size(_lastW.toDouble(), _lastH.toDouble());
  FrameQuality get lastQuality => _lastQuality;
  String get lastMlFormat => _lastMlFormat;
  int get lastPlaneCount => _lastPlaneCount;
  int get lastStride => _lastStride;
  int get lastFrameW => _lastW;
  int get lastFrameH => _lastH;
  List<int> get lastPlaneLengths => _lastPlaneLengths;
  String get lastLayoutKind => _lastLayoutKind;
  String get lastGroupName => _lastGroupName;
  // Last packed ML input for the isolation screen (Phase 3C/3D).
  Uint8List? get lastPackedBytes => _lastPackedBytes;
  int get lastPackedW => _lastPackedW;
  int get lastPackedH => _lastPackedH;
  int get lastPackedRot => _lastPackedRot;
  String get lastPackedLayout => _lastPackedLayout;
  int get mlGeneration => _mlGeneration;

  /// Named image-quality verdict for the last sampled frame, from the
  /// same thresholds the tracker gates on ('good', 'tooDark',
  /// 'tooBright', 'tooBlurry', 'unknown'). Display/reporting only.
  String get qualityVerdictLabel =>
      qualityVerdict(_lastQuality, tracker.config);

  /// Per-config face hit rates as one display line ('none yet' when the
  /// session recorded no completed inference).
  String get hitRateLine {
    final s = hitRates.summary();
    if (s.isEmpty) return 'none yet';
    return s.entries.map((e) => '${e.key}: ${e.value}').join('; ');
  }

  /// Share of analyzer arrivals that completed inference (0..1), -1 when
  /// no arrivals yet (unknown, never guessed).
  double get throughputRatio =>
      framesReceived <= 0 ? -1 : framesProcessed / framesReceived;

  /// Diagnostic event from dev tooling (ML test screen). No listener
  /// notification: the caller owns its UI refresh. Rides the error
  /// export via the events section.
  void logDiag(String code, String detail) {
    _event(code, detail);
  }
  // Last observed mirroring. The native engine reports it per
  // observation; the Dart path derives it from the lens. _cameraDesc
  // is null under native-primary, so a lens lookup would stick on true
  // (front) even for rear — v0.7.21 audit finding: rear-native
  // overlays flipped. Seeded from the active source each reset.
  bool _lastMirrored = true;
  bool get isMirrored {
    if (_nativeActive) return _lastMirrored;
    final d = _cameraDesc;
    return d == null || d.lensDirection == CameraLensDirection.front;
  }

  /// Fast-tier latch: true when the live instance runs fast mode.
  /// Always consistent with the live instance's real config; reset on
  /// session reset and minimal-fallback engagement.
  bool _detectorFast = false;

  /// Fast-tier experiment flag (dev-only, default OFF). v0.7.14 ran the
  /// fast tier automatically and CPH2121 proved it SLOWER (275ms vs
  /// ~110ms accurate, drops 61%→84%), so the default path stays
  /// accurate; /ml-test re-arms fast for on-device A/B with
  /// per-generation latency stats in the export deciding, not guessing.
  bool _preferFastTier = false;
  bool get preferFastTier => _preferFastTier;

  /// Live instance tier label for diagnostics (Compat Lab + export).
  /// The native engine reports its own path; Dart tiers below it.
  String get detectorTier {
    if (_nativeActive) return 'native';
    if (_detectorMinimal) return 'minimal';
    return _detectorFast ? 'fast-experiment' : 'accurate';
  }

  /// Dev-only fast-tier experiment toggle. Tears the detector down so
  /// the next frame builds the requested tier; the generation gate
  /// discards any in-flight result from the old tier. Never called from
  /// the user flow.
  void setPreferFastTier(bool v) {
    if (_preferFastTier == v) return;
    _preferFastTier = v;
    final old = _detector;
    _detector = null;
    _detectorClosed = true;
    try {
      old?.close().then((_) {}, onError: (_) {});
    } catch (_) {}
    _mlGeneration++;
    _event('TIER', 'preferFastTier=$v (dev experiment toggle)');
    notifyListeners();
  }

  FaceDetector _ensureDetector() {
    // Config audit (v0.4 §17): contours are OFF — nothing downstream uses
    // contour points, and they cost per-frame latency. Landmarks (eyes)
    // and classification (eye openness) are required in every tier;
    // tracking IDs are dev-display only, so the fast tier drops them.
    // Minimal fallback (v0.7.6): when the full detector NPEs persistently
    // inside ML Kit internals on-device, retry with fast mode, no
    // tracking, no classification — landmarks stay ON because eyes are
    // the measurement. Different options take a different internal path.
    final minimal = _detectorMinimal;
    // Tier selection: accurate by default (proven on-device); fast only
    // via the dev experiment toggle. Rebuilds only on tier change —
    // never per frame.
    final wantFast = !minimal && _preferFastTier;
    final d = _detector;
    if (d != null && !_detectorClosed && wantFast == _detectorFast) {
      return d;
    }
    if (d != null) {
      try {
        d.close().then((_) {}, onError: (_) {});
      } catch (_) {}
    }
    final useFast = wantFast;
    final created = FaceDetector(
      options: liveDetectorOptions(minimal: minimal, fast: useFast),
    );
    _detector = created;
    _detectorClosed = false;
    _detectorFast = useFast;
    _event('ML_INIT',
        'detector created (${minimal ? 'minimal: fast, landmarks-only' : (useFast ? 'fast-experiment: fast, landmarks+classification, no tracking' : 'accurate: accurate, landmarks+classification+tracking')}) id=${created.id}');
    return created;
  }

  /// Full preparation: permission then camera init on [activeSource].
  /// Returns true only when preview AND stream are up. The permission
  /// outcome is kept in [lastPermission] so callers can explain denial.
  CameraPermission? lastPermission;
  Future<bool> prepare({ImageSource? source}) async {
    if (source != null) activeSource = source;
    _setStage(CameraStage.requestingPermission);
    notifyListeners();
    final permission = await ensureCameraPermission();
    lastPermission = permission;
    if (permission != CameraPermission.granted) {
      _setStage(CameraStage.permissionDenied, permission.name);
      error = 'Camera permission required.';
      notifyListeners();
      return false;
    }
    return init();
  }

  Future<bool> init({ImageSource? source, int startAt = 0}) async {
    if (source != null) activeSource = source;
    // Fresh user entry re-arms native-primary (an explicit Dart pin set
    // via requestEngine still wins through the gate below).
    _nativePrimarySuppressed = false;
    _fallbackIndex = startAt;
    // Fresh entry: reset session adaptation (escalation re-arms per
    // screen session). Hit-rates accumulate across the app run.
    _escalated = false;
    _escalating = false;
    _preferHigh = false;
    _facelessProcessed = 0;
    return _initInternal(startAt: startAt);
  }

  /// One-time resolution escalation: frames flow but no face for a long
  /// run — spend more pixels once, then live with the result. Bounded,
  /// logged, never loops.
  Future<void> _escalateResolution() async {
    if (_escalating || _opRunning) {
      _event('ESCALATE_SKIP',
          'escalation skipped: another camera op in flight');
      _escalated = true;
      return;
    }
    _escalating = true;
    _opRunning = true;
    _escalated = true;
    _preferHigh = true;
    _facelessProcessed = 0;
    _event('ESCALATE',
        'persistent zero-face run with flowing frames; rebuilding once at high resolution');
    notifyListeners();
    try {
      await _disposeController();
      await Future.delayed(const Duration(milliseconds: 400));
      await _initInternal();
    } finally {
      _escalating = false;
      _opRunning = false;
    }
  }

  Future<bool> _initInternal({int startAt = 0}) async {
    if (ready && _streamActive && !switching && !_deadNow()) return true;
    if (ready && _streamActive && !switching) {
      _event('STALE_STREAM',
          'controller alive but stream silent — rebuilding instead of no-op');
      _setStage(CameraStage.initializing, 'stale stream rebuild');
      notifyListeners();
    } else {
      _setStage(
          switching ? CameraStage.switching : CameraStage.initializing);
      notifyListeners();
    }
    await _disposeController();
    _resetPipelineCounters();
    tracker.reset();
    // Native-primary (v0.7.17 architecture): the zero-copy CameraX
    // engine is offered first on every fresh entry; any start failure
    // falls through to the Dart plugin-camera chain below. Never
    // retries mid-chain, never against an explicit Dart choice or a
    // silent-native failover from this entry.
    if (nativePrimaryDue(
        startAt: startAt,
        nativeActive: _nativeActive,
        nativeFailed: _nativeFailedThisSession,
        suppressed: _nativePrimarySuppressed,
        manualDart: _manualEngineOverride == VisionEngineId.dartMlKit,
        disposed: _disposed)) {
      _event('NATIVE_PRIMARY', 'attempting zero-copy native engine first');
      if (await _startNativeEngine()) {
        return true;
      }
      _event('NATIVE_PRIMARY_FAILED',
          'native start failed; falling through to Dart plugin chain');
    }
    try {
      final cams = await availableCameras();
      _availableCams = cams;
      if (cams.isEmpty) {
        error = 'No camera found on this device.';
        _setStage(CameraStage.initFailed, 'empty camera list');
        notifyListeners();
        return false;
      }
      final wantFront = activeSource.code != 'rear';
      CameraDescription? picked;
      for (final c in cams) {
        final isFront = c.lensDirection == CameraLensDirection.front;
        if (wantFront && isFront) {
          picked = c;
          break;
        }
        if (!wantFront && c.lensDirection == CameraLensDirection.back) {
          picked = c;
          break;
        }
      }
      picked ??= cams.first;
      _cameraDesc = picked;
      _event('LENS',
          '${picked.lensDirection.name} sensor=${picked.sensorOrientation} ${picked.name}');
      // Fallback chain: some devices cannot bind the analysis stream at a
      // given resolution/format (the preview still works — separate path).
      // Try preferred quality first, widest compatibility last, and record
      // every attempt for /dev. After a resolution escalation the chain
      // starts high instead.
      Object? lastErr;
      StackTrace? lastSt;
      var sawPreview = false;
      final chain = _preferHigh ? highFirstChain : streamFallbackChain;
      for (var attempt = startAt;
          attempt < chain.length;
          attempt++) {
        final cfg = chain[attempt];
        final isHigh = cfg == StreamConfig.highNv21 ||
            cfg == StreamConfig.highYuv420;
        final res = isHigh
            ? ResolutionPreset.high
            : ((cfg == StreamConfig.mediumNv21 ||
                    cfg == StreamConfig.mediumYuv420)
                ? ResolutionPreset.medium
                : ResolutionPreset.low);
        final isNv21 = cfg == StreamConfig.mediumNv21 ||
            cfg == StreamConfig.lowNv21 ||
            cfg == StreamConfig.highNv21;
        final fmt =
            isNv21 ? ImageFormatGroup.nv21 : ImageFormatGroup.yuv420;
        try {
          _event('CONFIG_TRY',
              '${res.name}/${fmt.name} (attempt ${attempt + 1})');
          _controller = CameraController(picked, res,
              enableAudio: false, imageFormatGroup: fmt);
          await _controller!.initialize();
          sawPreview = true;
          // Preview is up here — analysis runs independently afterwards.
          _setStage(CameraStage.previewReady,
              '${picked.lensDirection.name} ${picked.sensorOrientation}');
          notifyListeners();
          _setStage(CameraStage.streamStarting);
          await _controller!.startImageStream(_onImage);
          _streamActive = true;
          streamStartedAt = DateTime.now();
          _fallbackIndex = attempt;
          _activeResName = res.name;
          _activeFmtName = fmt.name;
          _event('STREAM_STARTED',
              '${picked.lensDirection.name} ${fmt.name} ${res.name}');
          error = null;
          notifyListeners();
          return true;
        } catch (e, st) {
          lastErr = e;
          lastSt = st;
          _recordError('config-${res.name}-${fmt.name}', e, st);
          _event('CONFIG_FAIL',
              '${res.name}/${fmt.name}: ${e.runtimeType}');
          await _disposeController();
          // Fall through to the next configuration.
        }
      }
      error = 'Camera unavailable: $lastErr';
      // Preview worked but no stream config bound: that is a stream
      // failure, not a camera failure — surfaced distinctly.
      _setStage(
          sawPreview ? CameraStage.streamFailed : CameraStage.initFailed,
          'all ${streamFallbackChain.length} stream configs failed');
      if (lastErr != null) _recordError('init', lastErr, lastSt);
      notifyListeners();
      return false;
    } catch (e, st) {
      _recordError(_stage.name, e, st);
      error = 'Camera unavailable: $e';
      _setStage(CameraStage.initFailed, e.runtimeType.toString());
      await _disposeController();
      notifyListeners();
      return false;
    } finally {
      switching = false;
    }
  }

  int _fallbackIndex = 0;

  /// Adaptive acquisition state (more data over time, per device).
  final AcquisitionAdapter adapter = const AcquisitionAdapter();
  final ConfigHitRates hitRates = ConfigHitRates();
  bool _escalated = false;
  bool _escalating = false;
  bool _preferHigh = false;
  // YV12 declaration fallback (converter-NPE latch): same NV21 bytes,
  // alternate native declaration. Reset per attempt; re-latches alone.
  bool _formatFallbackYv12 = false;
  // JPEG-file fallback (third latch rung): when the byte-array converter
  // itself is broken on-device, valid pixels go through fromFilePath
  // instead (different native path). Reused temp file, upright pixels.
  bool _fileFallbackJpeg = false;
  String? _fallbackJpegPath;
  // RGBA-bitmap fallback (second latch rung, commons 0.13+ bitmap path):
  // upright RGBA through InputImage.fromBitmap — no byte-array converter,
  // no file IO. Cheaper than the file rung, so it latches first.
  bool _bitmapFallback = false;
  // Phase-6 contract: fromBytes is strict-canonical only. A luma-only
  // buffer is NEVER declared as packed NV21/YV12 to ML Kit; the first
  // such frame fast-paths straight to the RGB rung (declared once).
  bool _bitmapFastpathLogged = false;
  // Minimal-detector fallback (third rung): rebuild the detector with
  // fast mode + no tracking/classification when the full detector throws
  // persistently inside ML Kit internals. Landmarks stay on (eyes).
  bool _detectorMinimal = false;
  // Bounded detector recreation (last resort before mlDegraded): when
  // errors persist with zero processed frames, close + rebuild the
  // detector in its CURRENT config (full or minimal). Throttled to 5 s
  // and capped at 3 per session by detectorRecreateDue — a broken
  // detector keeps failing identically, so this never loops forever.
  int _detectorRecreates = 0;
  DateTime? _lastDetectorRecreateAt;
  // Last logged ML_INPUT signature (P3 diagnostic-change throttle).
  String _lastMlInputSig = '';
  // ---- Universal native engine (§2/§3/§9) ----
  // Engine hierarchy since v0.7.17: the zero-copy native CameraX engine
  // is offered FIRST on every fresh entry (nativePrimaryDue gate); the
  // Dart plugin-camera ladder is the automatic fallback (start failure
  // falls through, silent sessions fail over via the liveness guard),
  // plus a manual Compat Lab override either way.
  NativeFaceEngine? _nativeEngine;
  StreamSubscription<dynamic>? _nativeSub;
  bool _nativeActive = false;
  bool _nativeFailedThisSession = false;
  bool _nativeAttemptedThisSession = false;
  // Native-primary suppression (v0.7.17): set when the user pins the
  // Dart path or a silent native fails over mid-entry. Reset ONLY on a
  // fresh init() entry — never in _resetPipelineCounters, or a
  // guard-triggered re-init would bounce straight back into native.
  bool _nativePrimarySuppressed = false;
  // Silent-native liveness guard: one-shot timer armed on every primary
  // native start; a bound-but-mute session falls back to Dart
  // automatically. Cancelled on stop/dispose/re-arm.
  Timer? _nativeLivenessTimer;
  // Failover exhaustion: once a native attempt fails, automatic
  // failover stays off (survives re-init) so the restore→degrade→
  // failover loop can never strand the preview. Only an explicit
  // Compat Lab "Try native" re-arms it.
  bool _nativeFailoverExhausted = false;
  int? _nativeTextureId;
  int _nativeSensorRot = 0;
  VisionEngineId? _manualEngineOverride;
  // Degraded backoff timestamp: last ML attempt wall time. Cleared on
  // latch transitions so each new rung attempts immediately.
  DateTime? _lastMlAttempt;
  // Detector generation token (Phase 4 single-flight): bumped on every
  // re-init/switch/restart; async completions carrying a stale token are
  // discarded so no stale stream callback can use an old detector.
  int _mlGeneration = 0;
  bool _disposed = false;
  // Last successfully packed ML input (Phase 3C/3D isolation + bitmap
  // rung source). Zero-copy reference to the analyzed buffer plus its
  // mapping facts. Cleared per attempt; never images beyond one buffer.
  Uint8List? _lastPackedBytes;
  int _lastPackedW = 0;
  int _lastPackedH = 0;
  int _lastPackedRot = 0;
  String _lastPackedLayout = '';
  int _facelessProcessed = 0;
  String _activeResName = '';
  String _activeFmtName = '';

  /// Guard so concurrent rebuild operations (escalation, retry, restart,
  /// switch) can never overlap into torn state or double streams. A second
  /// operation while one is in flight is refused with an event, never run.
  bool _opRunning = false;

  Future<T> _guardedOp<T>(String name, Future<T> Function() body,
      {required T busyValue}) async {
    if (_opRunning) {
      _event('OP_BUSY', '$name refused: another camera op in flight');
      return busyValue;
    }
    _opRunning = true;
    try {
      return await body();
    } finally {
      _opRunning = false;
    }
  }

  /// Retry with the NEXT fallback configuration (watchdog panel action).
  /// Cycles the standard chain so repeated retries keep trying new
  /// configs (escalation state is cleared: retry means "start over").
  Future<bool> retryWithFallback() {
    return _guardedOp('retry', () async {
      _preferHigh = false;
      _fallbackIndex =
          (_fallbackIndex + 1) % streamFallbackChain.length;
      _event('RETRY_FALLBACK',
          'next config index $_fallbackIndex (${streamFallbackChain[_fallbackIndex].name})');
      await _disposeController();
      await Future.delayed(const Duration(milliseconds: 400));
      return init(startAt: _fallbackIndex);
    }, busyValue: false);
  }

  bool _deadNow() => streamLooksDead(
        ready: ready,
        streamActive: _streamActive,
        framesReceived: framesReceived,
        streamStartedAt: streamStartedAt,
        lastFrameAgeMs: lastFrameAgeMs,
        now: DateTime.now(),
      );

  /// Clean camera switch: stop stream, release controller, switch lens,
  /// re-init, then first frame + restarted analysis with cleared detection
  /// state. Exactly one controller alive at a time.
  Future<bool> switchSource(ImageSource source) {
    return _guardedOp('switch', () async {
      if (source.code == activeSource.code && ready) return true;
      // A lens switch invalidates any native session first: the native
      // engine binds a specific camera, and a stale session must never
      // survive into the new generation.
      await _stopNativeEngine();
      switching = true;
      _setStage(CameraStage.switching, 'to ${source.code}');
      notifyListeners();
      _event('SWITCH', '${activeSource.code} to ${source.code}');
      activeSource = source;
      eyeStatus = null;
      lastFrame = null;
      final ok = await init();
      if (ok) {
        _event('SWITCH_DONE', '${source.code} stream up; state cleared');
      }
      return ok;
    }, busyValue: false);
  }

  /// Hard reset: stop, dispose, wait for cleanup, recreate, restart.
  Future<bool> restartCamera() {
    return _guardedOp('restart', () async {
      _event('RESTART', 'hard reset requested');
      await _stopNativeEngine();
      await _disposeController();
      await Future.delayed(const Duration(milliseconds: 400));
      return init();
    }, busyValue: false);
  }

  void _resetPipelineCounters() {
    framesReceived = 0;
    framesProcessed = 0;
    framesDropped = 0;
    consecMlErrors = 0;
    consecConvertErrors = 0;
    streamStartedAt = null;
    firstFrameAt = null;
    _lastFrameTime = null;
    lastLatencyMs = 0;
    lastConvertMs = 0;
    lastInferMs = 0;
    _latencyEma = 0;
    _fpsEma = 0;
    facesDetectedTotal = 0;
    locksAchievedTotal = 0;
    _wasLocked = false;
    _mlMapW = 0;
    _mlMapH = 0;
    _mlMapRot = -1;
    _mlMapKind = '';
    _lastMirrored = activeSourceCode != 'rear';
    _genStats.clear();
    _lastBitmapSig = '';
    _arrivals.clear();
    _lastError = null;
    errorLog.clear();
    // Fresh attempt starts with the default declaration; the YV12
    // fallback re-latches on its own if the converter still fails.
    _formatFallbackYv12 = false;
    _bitmapFallback = false;
    _bitmapFastpathLogged = false;
    _fileFallbackJpeg = false;
    _detectorRecreates = 0;
    _lastDetectorRecreateAt = null;
    _detectorFast = false;
    _lastMlInputSig = '';
    _lastMlAttempt = null;
    // Fresh session: a new native attempt is allowed (new camera
    // generation, new detector session). Manual override stays sticky.
    _nativeAttemptedThisSession = false;
    _nativeFailedThisSession = false;
    // New generation: any in-flight async work from the previous
    // controller/detector completes stale and is discarded by token.
    _mlGeneration++;
    _lastPackedBytes = null;
    if (_detectorMinimal) {
      // Drop the minimal detector so a fresh full-config instance is
      // built on next use; a close failure never breaks re-init.
      _detectorMinimal = false;
      final old = _detector;
      _detector = null;
      _detectorClosed = true;
      try {
        old?.close().then((_) {}, onError: (_) {});
      } catch (_) {}
    }
    frameIndex = 0;
    lastFaceCount = 0;
    lastFaceBoxes = const [];
    mlReady = false;
    mlReadyAt = null;
    faceFailLog.clear();
  }

  void _logFaceFail(
      int w, int h, String format, int rot, FrameQuality q, String? err) {
    faceFailLog.add(FaceFailEntry(
      time: DateTime.now(),
      frameIndex: frameIndex,
      width: w,
      height: h,
      format: format,
      rotationDeg: rot,
      luminance: q.meanLuminance,
      blur: q.blurVariance,
      error: err,
    ));
    if (faceFailLog.length > faceFailCap) {
      faceFailLog.removeRange(0, faceFailLog.length - faceFailCap);
    }
  }

  /// Release the camera (stop stream + dispose controller) without closing
  /// the shared ML Kit detector. Screens call this on dispose so the
  /// camera is freed on route exit; [init] re-acquires on entry.
  /// Does not notify listeners: release happens during route teardown,
  /// where listener notification is unsafe. Callers read [ready] on demand.
  Future<void> release() async {
    _event('RELEASE', 'route exit');
    // Route exit frees ALL camera ownership, including a native session:
    // a stale native analyzer must never outlive the screen.
    await _stopNativeEngine();
    await _disposeController();
  }

  Future<void> _disposeController() async {
    _streamActive = false;
    final c = _controller;
    _controller = null;
    _cameraDesc = null;
    if (c == null) return;
    try {
      await c.dispose();
    } catch (e, st) {
      _recordError('dispose', e, st);
    }
  }

  int _deviceQuarterTurns() {
    try {
      final o = _controller?.value.deviceOrientation;
      switch (o) {
        case DeviceOrientation.landscapeLeft:
          return 1;
        case DeviceOrientation.portraitDown:
          return 2;
        case DeviceOrientation.landscapeRight:
          return 3;
        case DeviceOrientation.portraitUp:
        default:
          return 0;
      }
    } catch (_) {
      return 0;
    }
  }

  /// Startup watchdog state for the UI to poll (it owns its timer).
  StartupState startupWatchdogState() => watchdog.evaluate(
        streamStarted: streamStartedAt != null,
        firstFrameReceived: firstFrameAt != null,
        startedAt: streamStartedAt,
        now: DateTime.now(),
      );

  /// Record an observed watchdog timeout as an explicit stage (called by
  /// the UI when it shows the timeout panel while still pre-first-frame).
  void noteWatchdogTimeout() {
    if (firstFrameAt == null &&
        _stage != CameraStage.noFirstFrame &&
        streamStartedAt != null) {
      _setStage(CameraStage.noFirstFrame, 'watchdog 8s, no first frame');
      notifyListeners();
    }
  }

  /// Analysis health: persistent ML/conversion failure with zero processed
  /// frames means the pipeline never analyzed anything.
  bool get analysisBlocked =>
      framesProcessed == 0 &&
      (consecConvertErrors >= 5 || consecMlErrors >= 10);

  Future<void> _onImage(CameraImage image) async {
    framesReceived++;
    frameIndex++;
    final arrivalNow = DateTime.now();
    _lastFrameTime = arrivalNow;
    _arrivals.add(arrivalNow);
    if (_arrivals.length > 20) _arrivals.removeAt(0);
    // Degraded backoff (performance): with persistent failure and zero
    // analyzed frames, attempting ML on every arrival burns CPU/battery
    // (conversion copies, JPEG encode, file IO, channel, notifies) for
    // an identical failure ~7x/second. Throttled frames count received
    // + dropped and skip ALL conversion/ML work; arrival telemetry stays
    // live. Latest-frame + attempt accounting below stay unchanged.
    if (!mlAttemptDue(
        consecErrors: consecMlErrors,
        framesProcessed: framesProcessed,
        now: arrivalNow,
        lastAttempt: _lastMlAttempt)) {
      framesDropped++;
      return;
    }
    _lastMlAttempt = arrivalNow;
    // Latest-frame strategy: when the analyzer is busy, drop the obsolete
    // frame and count it — never queue, never build latency.
    if (_busy) {
      framesDropped++;
      return;
    }
    _busy = true;
    // Generation capture for the single-flight gate below.
    final mlGen = _mlGeneration;
    final t0 = DateTime.now();
    try {
      final desc = _cameraDesc;
      final front = desc == null ||
          desc.lensDirection == CameraLensDirection.front;
      final sensor = desc?.sensorOrientation ?? (front ? 270 : 90);
      final rot = EyeCoords.mlKitRotationDeg(
        sensorOrientationDeg: sensor,
        deviceOrientationQuarterTurns: _deviceQuarterTurns(),
        frontCamera: front,
      );
      _lastRotation = rot;
      _lastW = image.width;
      _lastH = image.height;
      _lastPlaneCount = image.planes.length;
      // Observe the real frame layout; never assume it. Plane COUNT
      // alone lies on some devices, so refine with plane byte sizes.
      // NOTE: planes.first is only touched AFTER the empty check below —
      // an empty plane list used to throw into the generic outer catch
      // with no counter, hiding the device completely.
      // CameraImageFormat is a class (its toString is the useless
      // "Instance of 'ImageFormat'"); the cross-platform group enum is
      // the stable name source ('nv21', 'yuv420', 'bgra8888', ...).
      final groupName = image.format.group.name;
      final planeLens = [
        for (final p in image.planes) p.bytes.length
      ];
      _lastPlaneLengths = planeLens;
      final layout = refineLayout(
        planeCount: image.planes.length,
        planeLengths: planeLens,
        width: image.width,
        height: image.height,
        formatGroupName: groupName,
      );
      _lastGroupName = groupName;
      _lastLayoutKind = layout.kind.name;
      if (image.planes.isEmpty) {
        consecConvertErrors++;
        _recordError('frame-conversion',
            StateError('empty plane list (${image.width}x${image.height}, group $groupName)'));
        if (framesProcessed == 0 && consecConvertErrors >= 5) {
          _setStage(CameraStage.conversionFailed, 'empty-planes');
          notifyListeners();
        }
        return;
      }
      _lastStride = image.planes.first.bytesPerRow;
      if (layout.kind == FrameLayoutKind.unknown) {
        consecConvertErrors++;
        _recordError('frame-conversion',
            StateError('unsupported frame: $groupName with ${image.planes.length} planes'));
        if (framesProcessed == 0 && consecConvertErrors >= 5) {
          _setStage(CameraStage.conversionFailed, groupName);
          notifyListeners();
        }
        return;
      }
      final InputImageFormat mlFormat;
      switch (layout.mlFormatName) {
        case 'yv12':
          mlFormat = InputImageFormat.yv12;
          break;
        case 'bgra8888':
          mlFormat = InputImageFormat.bgra8888;
          break;
        default:
          // Latched YV12 fallback: identical luma bytes, alternate native
          // declaration path (see shouldLatchFormatFallback). Logged in
          // ML_INPUT/FIRST_FRAME; _lastMlFormat shows the truth.
          mlFormat = _formatFallbackYv12
              ? InputImageFormat.yv12
              : InputImageFormat.nv21;
      }
      _lastMlFormat = mlFormat.name;
      // Tight packing: ML Kit on Android ignores row stride and reads
      // standard packed layouts. Padded rows MUST be stripped row by row
      // or every buffer from such a device is silently corrupt. Tight
      // planes take the zero-copy fast path; anything else is packed
      // (and a packing failure is a loud recorded error, never silence).
      final planeInputs = [
        for (final p in image.planes)
          PlaneBytes(
              bytes: p.bytes,
              bytesPerRow: p.bytesPerRow,
              bytesPerPixel: p.bytesPerPixel,
              width: p.width,
              height: p.height),
      ];
      _lastPixelStride = image.planes.isNotEmpty
          ? (image.planes.first.bytesPerPixel ?? 0)
          : 0;
      Uint8List bytes;
      var packedTight = false;
      // Luma fallback flag: set inside the pack branch when chroma is
      // unreadable but Y survives. Declared here so the logging below
      // (layout line, FIRST_FRAME, ML_INPUT) can declare the synthesis.
      var chromaFallback = false;
      if (isTightLayout(
          kind: layout.kind,
          planes: planeInputs,
          width: image.width,
          height: image.height)) {
        try {
          final buf = WriteBuffer();
          for (final i in layout.usePlanes) {
            if (i < 0 || i >= image.planes.length) {
              throw StateError(
                  'usePlanes index $i out of range (${image.planes.length} planes)');
            }
            buf.putUint8List(image.planes[i].bytes);
          }
          bytes = buf.done().buffer.asUint8List();
        } catch (e, st) {
          consecConvertErrors++;
          _recordError('frame-conversion', e, st);
          if (framesProcessed == 0 && consecConvertErrors >= 5) {
            _setStage(
                CameraStage.conversionFailed, e.runtimeType.toString());
            notifyListeners();
          }
          return;
        }
      } else {
        var packed = tightPackFrame(
            planes: planeInputs,
            width: image.width,
            height: image.height,
            kind: layout.kind);
        // Luma fallback (cross-device): Y is intact but chroma is
        // unreadable (short plane, garbage stride, odd pixelStride).
        // Face detection reads luma, so keep real Y + neutral chroma
        // rather than dropping a detectable frame. Declared in the
        // layout line and ML_INPUT event — never silent.
        if (packed == null &&
            (layout.kind == FrameLayoutKind.nv21Interleaved ||
                layout.kind == FrameLayoutKind.yv12Planar)) {
          packed = packLumaFallback(
              planes: planeInputs,
              width: image.width,
              height: image.height);
          chromaFallback = packed != null;
          if (chromaFallback) {
            _lastLayoutKind = '${layout.kind.name}+chromaFallback';
          }
        }
        if (packed == null) {
          consecConvertErrors++;
          _recordError(
              'frame-conversion',
              StateError(
                  'tight-pack failed for ${layout.mlFormatName} '
                  '(${image.width}x${image.height}, ${image.planes.length} planes, '
                  'strides ${[for (final p in image.planes) p.bytesPerRow]}, group $groupName)'));
          if (framesProcessed == 0 && consecConvertErrors >= 5) {
            _setStage(CameraStage.conversionFailed, 'tight-pack-failed');
            notifyListeners();
          }
          return;
        }
        // Zero-copy: the packer already returns a sized Uint8List; a
        // second fromList copy would duplicate ~0.5MB per frame.
        bytes = packed is Uint8List ? packed : Uint8List.fromList(packed);
        packedTight = true;
      }
      // Truncated buffers are definitely corrupt: record loudly and skip
      // instead of feeding ML Kit garbage (which yields silent zero faces).
      // The minimum matches what each layout legitimately produces —
      // including luma-only synthesis (Y + half-height neutral chroma).
      final minLen = switch (layout.kind) {
        FrameLayoutKind.bgra => image.width * image.height * 4,
        FrameLayoutKind.nv21LumaOnly =>
          image.width * image.height + image.width * (image.height ~/ 2),
        _ => image.width * image.height * 3 ~/ 2,
      };
      if (bytes.length < minLen) {
        consecConvertErrors++;
        _recordError(
            'frame-conversion',
            StateError(
                'truncated ${layout.mlFormatName} buffer: got ${bytes.length}, need >= $minLen '
                '(${image.width}x${image.height}, ${image.planes.length} planes, group $groupName)'));
        if (framesProcessed == 0 && consecConvertErrors >= 5) {
          _setStage(CameraStage.conversionFailed, 'truncated-buffer');
          notifyListeners();
        }
        return;
      }
      consecConvertErrors = 0;
      _lastBytesLen = bytes.length;
      _lastExpectedLen = expectedMlLength(
          kind: layout.kind,
          width: image.width,
          height: image.height,
          bytesPerRow: image.planes.first.bytesPerRow);
      // Retain the validated packed buffer (zero-copy reference) for the
      // isolation screen (Phase 3C/3D) and the bitmap rung source.
      _lastPackedBytes = bytes;
      _lastPackedW = image.width;
      _lastPackedH = image.height;
      _lastPackedRot = rot;
      _lastPackedLayout = layout.kind.name;
      if (retainMlPreview) {
        final yLen = image.width * image.height;
        if (bytes.length >= yLen) {
          lastMlGray = Uint8List.fromList(bytes.sublist(0, yLen));
          lastMlGrayW = image.width;
          lastMlGrayH = image.height;
          lastMlGrayRot = rot;
        }
      }
      // Tight buffers use tight stride (what ML Kit actually reads);
      // direct buffers keep the device stride as before.
      final metaStride = packedTight
          ? (layout.kind == FrameLayoutKind.bgra
              ? image.width * 4
              : image.width)
          : image.planes.first.bytesPerRow;
      final meta = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rot) ??
            InputImageRotation.rotation0deg,
        format: mlFormat,
        bytesPerRow: metaStride,
      );
      if (firstFrameAt == null) {
        firstFrameAt = DateTime.now();
        _setStage(CameraStage.firstFrame,
            '${image.width}x${image.height} ${mlFormat.name} rot$rot'
            '${chromaFallback ? ' chroma-fallback' : ''}');
        _event('FIRST_FRAME',
            '${image.width}x${image.height} planes=${image.planes.length} '
            'group=$groupName declared=${mlFormat.name} rot=$rot'
            '${chromaFallback ? ' chroma-fallback' : ''}');
      }
      // §7 image contract, log-only: structural facts are checked on
      // every frame; an invalid frame emits a machine-readable
      // FRAME_CONTRACT event but processing continues unchanged —
      // enforcement without device proof could break working devices.
      // timestampMs is unknown on the Dart path (0 = no age info, so
      // the stale-frame check is skipped by contract).
      final contract = validateFrameFacts(FrameFacts(
        width: image.width,
        height: image.height,
        planeCount: image.planes.length,
        planeLengths: [for (final p in image.planes) p.bytes.length],
        rowStrides: [for (final p in image.planes) p.bytesPerRow],
        rotationDeg: rot,
        timestampMs: 0,
        totalBytes: bytes.length,
      ));
      if (!contract.ok) {
        _event('FRAME_CONTRACT', contract.reason);
      }
      // Cheap luminance/sharpness summary from the Y plane (plane 0).
      // Sampled before ML input: both input paths and the shared failure
      // log need it. Sampling must never kill a frame: failure falls back
      // to unknown (whose neutral sentinels never gate a lock).
      FrameQuality quality;
      try {
        final yPlane = image.planes.first;
        quality = EyeCoords.sampleYPlane(yPlane.bytes, image.width,
            image.height, yPlane.bytesPerRow);
      } catch (e, st) {
        _recordError('quality-sample', e, st);
        quality = const FrameQuality.unknown();
      }
      // Mapping space for detector output + input path decision.
      // Bytes path: sensor-order buffer + rotation metadata, boxes in
      // buffer space. Bitmap/file paths: pre-rotated upright pixels,
      // boxes in upright space with rotation 0 (mapW/mapH/mapRot).
      var mapW = image.width;
      var mapH = image.height;
      var mapRot = rot;
      var preRotated = false;
      var formatName = mlFormat.name;
      // Alternate inputs apply to NV21-family bytes only (the converter
      // under test); planar YV12 / BGRA keep the bytes path.
      final nv21Family =
          layout.kind == FrameLayoutKind.nv21Interleaved ||
              layout.kind == FrameLayoutKind.nv21LumaOnly;
      // Ladder order: bitmap (cheap, direct) before file (IO). Once the
      // file rung latches it wins outright.
      final wantBitmap =
          _bitmapFallback && !_fileFallbackJpeg && nv21Family;
      final wantFile = _fileFallbackJpeg && nv21Family;
      final inputType = wantBitmap
          ? 'rgbaBitmap'
          : (wantFile ? 'jpegFile' : 'cameraBytes');
      var layoutLabel = layout.kind.name;
      if (chromaFallback) layoutLabel += '+chromaFallback';
      if (wantBitmap) layoutLabel += '+bitmapFallback';
      if (wantFile) layoutLabel += '+fileFallback';
      _lastLayoutKind = layoutLabel;
      // M1: detector CONSTRUCTION can throw synchronously (ML Kit NPE
      // inside getClient). Acquire it under the ML failure accounting so
      // a construction NPE latches the fallback ladder instead of landing
      // in the generic frame catch with no ladder progress.
      final FaceDetector detector;
      try {
        detector = _ensureDetector();
      } catch (e, st) {
        _noteMlFailure(e, st,
            w: image.width,
            h: image.height,
            formatName: formatName,
            rot: rot,
            quality: quality);
        return;
      }
      // P3: the ML_INPUT diagnostic line fired on EVERY processed frame
      // (~7 Hz), bloating the export with identical lines. Log only on
      // change of the facts that matter (format/layout/rung/rotation/
      // generation/detector); per-frame sizes still ride frameLog.
      // notifyListeners() is intentionally untouched — the live overlay
      // needs every frame.
      final inputSig =
          '${mlFormat.name}|$layoutLabel|$inputType|$rot|$_mlGeneration|${detector.id}';
      if (inputSig != _lastMlInputSig) {
        _lastMlInputSig = inputSig;
        _event('ML_INPUT',
            '${image.width}x${image.height} ${mlFormat.name} rot$rot stride=${image.planes.first.bytesPerRow} '
            'layout=$layoutLabel ${packedTight ? 'tight' : 'direct'} in=$inputType gen=$_mlGeneration det=${detector.id} bytes=${bytes.length}');
      }
      List<Face> faces;
      if (wantBitmap) {
        // Bitmap rung (commons 0.13+ bitmap path): upright RGBA through
        // InputImage.fromBitmap — no byte-array converter, no file IO.
        formatName = 'bitmap';
        try {
          final c0 = DateTime.now();
          final rgba = nv21ToRgbaBytes(
              nv21: bytes,
              width: image.width,
              height: image.height,
              rotationDeg: rot);
          lastConvertMs =
              DateTime.now().difference(c0).inMilliseconds.toDouble();
          if (rgba == null) {
            throw StateError('bitmap-encode failed '
                '(${image.width}x${image.height} ${layout.kind.name})');
          }
          mapW = rgba.w;
          mapH = rgba.h;
          mapRot = 0;
          preRotated = true;
          // RGBA facts for diagnosis (the bitmap converter rejects
          // silently-sized buffers; this line proves what was sent).
          // Change-only: a per-frame line flooded the 60-event ring and
          // evicted ML_INIT/tier evidence on long sessions.
          final bitmapSig =
              '${rgba.w}x${rgba.h}/${rgba.bytes.length}';
          if (bitmapSig != _lastBitmapSig) {
            _lastBitmapSig = bitmapSig;
            _event('BITMAP_INPUT',
                '${rgba.w}x${rgba.h} bytes=${rgba.bytes.length} '
                'from=${image.width}x${image.height}');
          }
          final i0 = DateTime.now();
          faces = await _ensureDetector().processImage(
              InputImage.fromBitmap(
                  bitmap: rgba.bytes,
                  width: rgba.w,
                  height: rgba.h,
                  rotation: 0));
          lastInferMs =
              DateTime.now().difference(i0).inMilliseconds.toDouble();
          consecMlErrors = 0;
        } catch (e, st) {
          _noteMlFailure(e, st,
              w: image.width,
              h: image.height,
              formatName: formatName,
              rot: rot,
              quality: quality);
          return;
        }
      } else if (wantFile) {
        // File fallback (see jpeg_fallback.dart): upright JPEG through a
        // reused temp file — a different native path that bypasses the
        // broken byte-array converter. Throttling is automatic: the slow
        // encode + detection holds _busy, so intervening frames drop.
        formatName = 'jpeg-file';
        try {
          final c0 = DateTime.now();
          final jpeg = nv21ToJpegBytes(
              nv21: bytes,
              width: image.width,
              height: image.height,
              rotationDeg: rot);
          if (jpeg == null) {
            throw StateError('fallback-encode failed '
                '(${image.width}x${image.height} ${layout.kind.name})');
          }
          _fallbackJpegPath ??= await _fallbackJpegFile();
          await File(_fallbackJpegPath!).writeAsBytes(jpeg, flush: true);
          lastConvertMs =
              DateTime.now().difference(c0).inMilliseconds.toDouble();
          final ud = uprightDimsFor(image.width, image.height, rot);
          mapW = ud.w;
          mapH = ud.h;
          mapRot = 0;
          preRotated = true;
          final i0 = DateTime.now();
          faces = await _ensureDetector()
              .processImage(InputImage.fromFilePath(_fallbackJpegPath!));
          lastInferMs =
              DateTime.now().difference(i0).inMilliseconds.toDouble();
          consecMlErrors = 0;
        } catch (e, st) {
          _noteMlFailure(e, st,
              w: image.width,
              h: image.height,
              formatName: formatName,
              rot: rot,
              quality: quality);
          return;
        }
      } else {
        // Strict fromBytes contract (Phase 6): luma-only buffers are
        // never presented as packed native YUV. Fast-path them to the
        // RGB bitmap rung instead of failing conversion every frame.
        if (layout.kind == FrameLayoutKind.nv21LumaOnly &&
            !_bitmapFallback) {
          _bitmapFallback = true;
          if (!_bitmapFastpathLogged) {
            _bitmapFastpathLogged = true;
            _event('BITMAP_FASTPATH',
                'luma-only frame refused by strict fromBytes; '
                'RGB bitmap rung engaged (declared, not native-packed)');
            notifyListeners();
          }
          return;
        }
        InputImage input;
        try {
          input = InputImage.fromBytes(bytes: bytes, metadata: meta);
        } catch (e, st) {
          consecConvertErrors++;
          _recordError('ml-input-build', e, st);
          if (framesProcessed == 0 && consecConvertErrors >= 5) {
            _setStage(CameraStage.conversionFailed, 'ml-input-build');
            notifyListeners();
          }
          return;
        }
        try {
          // Bytes path is zero-copy/tight: no conversion stage to time.
          lastConvertMs = 0;
          final i0 = DateTime.now();
          faces = await _ensureDetector().processImage(input);
          lastInferMs =
              DateTime.now().difference(i0).inMilliseconds.toDouble();
          consecMlErrors = 0;
        } catch (e, st) {
          _noteMlFailure(e, st,
              w: image.width,
              h: image.height,
              formatName: _lastMlFormat,
              rot: rot,
              quality: quality);
          return;
        }
      }
      // Generation + disposal gate (Phase 4 single-flight): a re-init,
      // switch, restart, or dispose during the awaits above makes this
      // completion stale — discard it so no old detector/stream result
      // can pollute the new session. Never mixes generations.
      if (mlGen != _mlGeneration || _disposed) {
        return;
      }
      // Mapping truth for diagnostics (what the detector actually saw):
      // buffer space on the bytes path, upright pixels on bitmap/file.
      // Written ONLY here (completion), never on arrival, so sensor facts
      // (_lastW/_lastH/_lastRotation) and ML facts can never race.
      _mlMapW = mapW;
      _mlMapH = mapH;
      _mlMapRot = mapRot;
      _mlMapKind = formatName;
      if (preRotated) {
        // Upright mapping truth for overlay + panels (declared via the
        // layout suffix, never silently).
        _lastMlFormat = formatName;
      }
      final EyeGeometry geo;
      // Raw detector output for the minimal face test (no tracker math).
      // Normalized by the MAPPING dims, then folded back to sensor frame
      // when the rung pre-rotated (bitmap/file): downstream (tracker,
      // overlay, logs, crops) speaks sensor space + rotation metadata,
      // never upright space (v0.7.19 double-rotation fix).
      lastFaceCount = faces.length;
      lastFaceBoxes = [
        for (final f in faces)
          () {
            final box = Rect.fromLTRB(
                f.boundingBox.left / mapW,
                f.boundingBox.top / mapH,
                f.boundingBox.right / mapW,
                f.boundingBox.bottom / mapH);
            return preRotated
                ? EyeCoords.uprightNormBoxToSensorNorm(box, rot)
                : box;
          }(),
      ];
      if (!mlReady) {
        mlReady = true;
        mlReadyAt = DateTime.now();
        _event('ML_READY', 'detector returned ${faces.length} face(s)');
      }
      // Adaptive acquisition bookkeeping: real per-config hit rates plus
      // the escalation trigger. Never blocks the frame loop.
      hitRates.record('$_activeResName/$_activeFmtName',
          faceFound: faces.isNotEmpty);
      if (faces.isEmpty) {
        _facelessProcessed++;
        if (adapter.shouldEscalate(
            consecutiveFacelessProcessed: _facelessProcessed,
            alreadyEscalated: _escalated)) {
          unawaited(_escalateResolution());
        }
      } else {
        _facelessProcessed = 0;
        facesDetectedTotal++;
      }
      if (faces.isEmpty) {
        _logFaceFail(mapW, mapH, formatName, mapRot,
            quality, null);
        geo = const EyeGeometry(faceFound: false);
      } else {
        // Multiple faces: forward the LARGEST (closest, likely the user)
        // and let the tracker refuse with a named state — never measure
        // against an arbitrary pick.
        var f = faces.first;
        if (faces.length > 1) {
          var best = -1.0;
          for (final c in faces) {
            final area = c.boundingBox.width * c.boundingBox.height;
            if (area > best) {
              best = area;
              f = c;
            }
          }
          _event('MULTI_FACE',
              '${faces.length} faces; largest forwarded, tracker holds');
        }
        final w = mapW.toDouble(), h = mapH.toDouble();
        final bb = f.boundingBox;
        // Detector positions in mapping-space pixels (buffer pixels on
        // the bytes path, upright pixels on the pre-rotated bitmap/file
        // paths), normalized then folded back to sensor frame when
        // pre-rotated (same v0.7.19 fix as lastFaceBoxes above).
        EyePoint? normPt(dynamic p) {
          if (p == null) return null;
          final q = EyePoint(p.x / w, p.y / h);
          return preRotated
              ? EyeCoords.uprightNormToSensorNorm(q, rot)
              : q;
        }
        final le = normPt(f.landmarks[FaceLandmarkType.leftEye]?.position);
        final re = normPt(f.landmarks[FaceLandmarkType.rightEye]?.position);
        var contours = 0;
        try {
          for (final c in f.contours.values) {
            contours += c?.points.length ?? 0;
          }
        } catch (_) {}
        final boxNorm = Rect.fromLTRB(
            bb.left / w, bb.top / h, bb.right / w, bb.bottom / h);
        geo = EyeGeometry(
          faceFound: true,
          faceBox: preRotated
              ? EyeCoords.uprightNormBoxToSensorNorm(boxNorm, rot)
              : boxNorm,
          leftEye: le,
          rightEye: re,
          yawDeg: (f.headEulerAngleY ?? 0).toDouble(),
          rollDeg: (f.headEulerAngleZ ?? 0).toDouble(),
          pitchDeg: (f.headEulerAngleX ?? 0).toDouble(),
          leftOpenProb: (f.leftEyeOpenProbability ?? -1).toDouble(),
          rightOpenProb: (f.rightEyeOpenProbability ?? -1).toDouble(),
          trackingId: f.trackingId,
          contourPoints: contours,
          imageWidth: mapW,
          imageHeight: mapH,
          faceCount: faces.length,
        );
      }
      _ingestTracked(
        geo: geo,
        quality: quality,
        w: image.width,
        h: image.height,
        rot: rot,
        sensor: sensor,
        front: front,
        t0: t0,
      );
      notifyListeners();
    } catch (e, st) {
      // Never crash the flow on a detector error — but record it.
      _recordError('frame', e, st);
    } finally {
      _busy = false;
    }
  }

  /// Shared post-geometry ingest for every engine (Dart ML path and
  /// native observations): tracker update, legacy frame, counters,
  /// latency, stage advance, frame log. Callers notify listeners.
  /// Exactly one inference's result is ingested per call; callers own
  /// single-flight.
  void _ingestTracked({
    required EyeGeometry geo,
    required FrameQuality quality,
    required int w,
    required int h,
    required int rot,
    required int sensor,
    required bool front,
    required DateTime t0,
  }) {
    final status = tracker.update(geo, quality);
    eyeStatus = status;
    _lastQuality = quality;
    // Legacy compact frame for existing consumers.
    final cx = geo.faceBox == null
        ? 0.5
        : (geo.faceBox!.left + geo.faceBox!.right) / 2;
    lastFrame = FaceFrame(
      faceFound: geo.faceFound,
      bothEyesOpen: status.eyesOpen,
      yawDeg: status.yawDeg,
      faceFraction: status.faceFraction,
      centered: (cx - 0.5).abs() < 0.12,
      leftEyeOpenProb:
          geo.leftOpenProb < 0 ? 0 : geo.leftOpenProb,
      rightEyeOpenProb:
          geo.rightOpenProb < 0 ? 0 : geo.rightOpenProb,
      leftEyeOpenRaw: geo.leftOpenProb,
      rightEyeOpenRaw: geo.rightOpenProb,
    );
    framesProcessed++;
    final latency =
        DateTime.now().difference(t0).inMilliseconds.toDouble();
    lastLatencyMs = latency;
    _latencyEma = _latencyEma == 0
        ? latency
        : _latencyEma * 0.9 + latency * 0.1;
    _fpsEma = _fpsEma == 0 ? 1000 / latency.clamp(1, 10000) : _fpsEma * 0.8 + (1000 / latency.clamp(1, 10000)) * 0.2;
    // Per-generation inference census for the tier experiment table.
    final gs = _genStats.putIfAbsent(
        _mlGeneration, () => _GenStats(detectorTier));
    gs.frames++;
    gs.sumMs += latency;
    // Lock acquisitions (transitions into locked), not locked frames.
    if (status.locked && !_wasLocked) locksAchievedTotal++;
    _wasLocked = status.locked;
    if (_stage == CameraStage.firstFrame) {
      _setStage(CameraStage.processing);
    }
    _logFrame(w, h, rot, sensor, front, status, geo, quality, latency);
  }

  // ---- Universal native engine attach (§2/§3/§9) ----

  /// Texture id for the Dart Texture widget while the native engine
  /// owns the camera; null when the plugin controller owns it.
  int? get nativePreviewTextureId =>
      _nativeActive ? _nativeTextureId : null;

  /// Display engine for capability UI (not a measurement claim).
  VisionEngineId get displayEngineId {
    if (_nativeActive) return VisionEngineId.nativeMlKit;
    if (ready) return VisionEngineId.dartMlKit;
    return VisionEngineId.cameraOnly;
  }

  /// Health snapshot for the capability manager + Compat Lab. The
  /// refined MlHealth machine feeds detectorDown (proven down, not
  /// merely failing) so selection stops offering a dead engine.
  VisionHealthSnapshot get healthSnapshot => VisionHealthSnapshot(
        framesProcessed: framesProcessed,
        framesReceived: framesReceived,
        meanLatencyMs: _latencyEma,
        converterFailing: consecConvertErrors >= 5,
        detectorFailing: consecMlErrors >= 10,
        cameraUp: ready || _nativeActive,
        nativeEngineFailed: _nativeFailedThisSession,
        fallbackModelPresent: false,
        detectorDown: mlHealthFor(
              consecutiveErrors: consecMlErrors,
              framesProcessed: framesProcessed,
            ) ==
            MlHealth.down,
      );

  /// True while a native session is bound but has delivered nothing yet
  /// (the silent window before first analysis or the liveness guard).
  /// UI shows a starting state during it — never ready badges (audit).
  bool get nativeStarting =>
      _nativeActive && framesProcessed == 0 && firstFrameAt == null;

  /// Testing seam: force a stage so widget tests can drive failure
  /// panels without a camera plugin. Never called from production code.
  @visibleForTesting
  void debugSetStage(CameraStage stage, [String detail = '']) {
    _setStage(stage, detail);
    notifyListeners();
  }

  /// Open the OS app-settings page so the user can re-grant a blocked
  /// permission. UI calls this from the persistent permission panel;
  /// the one-shot startup dialog cannot be recalled once dismissed.
  Future<void> openSystemSettings() async {
    _event('OPEN_SETTINGS', 'user opened system settings');
    try {
      await openAppSettings();
    } catch (e, st) {
      _recordError('open-settings', e, st);
    }
  }

  /// Manual engine request from the Compat Lab (sticky until changed).
  /// An explicit native request re-arms automatic failover (the user
  /// asked for it); anything else just stops native.
  Future<void> requestEngine(VisionEngineId id) async {
    _manualEngineOverride = id;
    // An explicit engine choice pins the primary policy with it: Dart
    // suppresses native-primary until the next fresh entry; native
    // re-arms it immediately.
    if (id == VisionEngineId.dartMlKit) {
      _nativePrimarySuppressed = true;
    } else if (id == VisionEngineId.nativeMlKit) {
      _nativePrimarySuppressed = false;
    }
    _event('ENGINE_REQUEST', id.name);
    if (id == VisionEngineId.nativeMlKit) {
      _nativeFailoverExhausted = false;
      final ok = await _startNativeEngine();
      if (!ok) await _restorePluginCamera();
    } else {
      await _stopNativeEngine();
    }
    notifyListeners();
  }

  /// Automatic failover: terminal Dart failure attempts the native
  /// engine exactly once until explicitly re-armed. Never loops, never
  /// silent. On native failure the plugin camera is RESTORED so the
  /// preview (and Dart ladder) survive the attempt.
  Future<void> _maybeFailoverToNative() async {
    if (!nativeFailoverDue(
        nativeActive: _nativeActive,
        attempted: _nativeAttemptedThisSession,
        exhausted: _nativeFailoverExhausted,
        disposed: _disposed)) {
      return;
    }
    final sel = selectEngine(
      health: EngineClassification.degraded,
      nativeAvailable: true,
      nativeFailed: _nativeFailedThisSession,
      fallbackModelPresent: false,
      manualOverride: _manualEngineOverride,
    );
    if (sel != VisionEngineId.nativeMlKit) return;
    _nativeAttemptedThisSession = true;
    _event('ENGINE_FAILOVER',
        'dart path terminal this session; attempting native engine once');
    final ok = await _startNativeEngine();
    if (ok || _disposed) return;
    _nativeFailoverExhausted = true;
    _event('ENGINE_FAILOVER_FAILED',
        'native engine unavailable; failover exhausted, restoring camera');
    notifyListeners();
    await _restorePluginCamera();
  }

  /// Restore the plugin camera stream after a failed native attempt.
  /// Best-effort: if re-init fails the app simply stays degraded with
  /// the failure recorded — never a loop (failover is exhausted).
  Future<void> _restorePluginCamera() async {
    if (_disposed || _nativeActive) return;
    _event('CAMERA_RESTORE',
        'restoring plugin stream after native failure');
    try {
      await init();
    } catch (e, st) {
      _recordError('camera-restore', e, st);
    }
  }

  /// Start the native CameraX session. The native engine owns the
  /// camera hardware, so the plugin controller is released first
  /// (preview switches to the native texture; see nativePreviewTextureId).
  /// Any failure degrades to ENGINE_UNAVAILABLE — never a crash.
  Future<bool> _startNativeEngine() async {
    if (_nativeActive) return true;
    _event('NATIVE_START', 'requesting native CameraX session');
    // M3: capture the lens BEFORE disposing the plugin controller —
    // _cameraDesc is nulled by _disposeController, which previously
    // forced every native start to front (rear retries silently
    // started front). activeSourceCode survives the dispose.
    final front = activeSourceCode != 'rear';
    try {
      await _disposeController();
      _nativeEngine ??= NativeFaceEngine();
      final session = await _nativeEngine!.startWithResult(front: front);
      _nativeTextureId = session.textureId;
      _nativeSensorRot = session.sensorRotationDegrees;
      await _nativeSub?.cancel();
      _nativeSub =
          _nativeEngine!.observations.listen(_onNativeObservation,
              onError: (Object e) {
        _recordError('native-stream', e);
      });
      _nativeActive = true;
      if (firstFrameAt == null) {
        // First-frame clock restarts for the native session; the
        // watchdog measures analysis liveness, not the transport.
        streamStartedAt = DateTime.now();
      }
      _setStage(CameraStage.processing,
          'native-mlkit gen ${session.generation}');
      // Arm here (not only at the primary hook): failover and manual
      // native sessions go equally silent without the guard (audit).
      _armNativeLivenessGuard();
      notifyListeners();
      return true;
    } catch (e, st) {
      _recordError('native-start', e, st);
      _nativeFailedThisSession = true;
      await _stopNativeEngine();
      return false;
    }
  }

  /// Silent-native liveness guard: a session that binds fine but never
  /// delivers an observation must not hang detection. One-shot and
  /// generation-aware: 10 s after a primary start with zero processed
  /// frames, stop native, suppress further primary attempts for this
  /// entry, and fall through to the Dart chain. Cancelled on
  /// stop/dispose/re-arm. Never loops: suppression survives the
  /// re-init because _resetPipelineCounters never clears it.
  void _armNativeLivenessGuard() {
    _nativeLivenessTimer?.cancel();
    final gen = _mlGeneration;
    _nativeLivenessTimer = Timer(const Duration(seconds: 10), () async {
      if (_disposed || !_nativeActive || _mlGeneration != gen) return;
      if (framesProcessed > 0 || firstFrameAt != null) return;
      _event('NATIVE_SILENT',
          'native session delivered nothing in 10s; failing over to Dart chain');
      _nativePrimarySuppressed = true;
      await _stopNativeEngine();
      await _initInternal();
    });
  }

  /// Stop the native session and release the camera back. Safe to call
  /// when idle; stale stops are ignored on both sides.
  Future<void> _stopNativeEngine() async {
    _nativeLivenessTimer?.cancel();
    _nativeLivenessTimer = null;
    _nativeActive = false;
    _nativeTextureId = null;
    try {
      await _nativeSub?.cancel();
    } catch (_) {}
    _nativeSub = null;
    try {
      await _nativeEngine?.stop();
    } catch (_) {}
  }

  /// Ingest one native observation: same tracker, same counters, same
  /// honesty rules as the Dart path. Stale generations and post-dispose
  /// deliveries are discarded.
  void _onNativeObservation(FaceObservation o) {
    if (!_nativeActive || _disposed) return;
    if (o.generation != _nativeEngine?.generation) return;
    if (o.error != null) {
      _noteNativeError(o);
      return;
    }
    framesReceived++;
    frameIndex++;
    _lastFrameTime = DateTime.now();
    _arrivals.add(DateTime.now());
    if (_arrivals.length > 20) _arrivals.removeAt(0);
    final geo = EyeGeometry(
      faceFound: o.faceFound,
      faceBox: o.faceBox,
      leftEye: o.leftEye,
      rightEye: o.rightEye,
      yawDeg: o.yawDeg,
      rollDeg: o.rollDeg,
      leftOpenProb: o.leftOpenProb,
      rightOpenProb: o.rightOpenProb,
      imageWidth: o.imageWidth,
      imageHeight: o.imageHeight,
      faceCount: o.faceCount,
    );
    // Native quality is luma + blur sampled on-device (v0.7.17: the
    // Kotlin sampler mirrors the Dart coarse-Laplacian scale, so the
    // tracker gates mean the same on both paths). overexposedFraction
    // is still unsampled natively (0, non-gating — declared, not hidden).
    final quality = FrameQuality(
      meanLuminance: o.meanLuminance.clamp(0, 255).toDouble(),
      blurVariance: o.blurVariance,
      overexposedFraction: 0,
      width: o.imageWidth,
      height: o.imageHeight,
    );
    _lastW = o.imageWidth;
    _lastH = o.imageHeight;
    _lastRotation = o.rotationDeg;
    _lastMlFormat = 'native-mlkit';
    _lastLayoutKind = 'native-mlkit';
    _lastGroupName = 'native';
    // Zero-copy path: no conversion stage; inference ms come from the
    // native observation itself. Mapping dims ride the dedicated
    // fields like every other path (never the arrival fields).
    lastConvertMs = 0;
    lastInferMs = o.latencyMs;
    _mlMapW = o.imageWidth;
    _mlMapH = o.imageHeight;
    _mlMapRot = o.rotationDeg;
    _mlMapKind = 'native-mlkit';
    _lastMirrored = o.mirrored;
    lastFaceCount = o.faceCount;
    lastFaceBoxes = o.faceBox == null ? const [] : [o.faceBox!];
    if (!mlReady) {
      mlReady = true;
      mlReadyAt = DateTime.now();
      _event('ML_READY',
          'native detector returned ${o.faceCount} face(s)');
    }
    hitRates.record(
        'native/${o.imageWidth}x${o.imageHeight}',
        faceFound: o.faceFound);
    if (o.faceFound) {
      _facelessProcessed = 0;
    } else {
      _facelessProcessed++;
      _logFaceFail(o.imageWidth, o.imageHeight, 'native-mlkit',
          o.rotationDeg, quality, null);
      // No resolution escalation in native mode: the native engine owns
      // resolution negotiation and backpressure itself.
    }
    if (firstFrameAt == null) {
      firstFrameAt = DateTime.now();
      _setStage(CameraStage.processing, 'native-mlkit first observation');
    }
    _ingestTracked(
      geo: geo,
      quality: quality,
      w: o.imageWidth,
      h: o.imageHeight,
      rot: o.rotationDeg,
      sensor: _nativeSensorRot,
      front: o.mirrored,
      t0: o.time,
    );
    notifyListeners();
  }

  /// Native observation errors: counted, recorded, and classified.
  /// ENGINE_UNAVAILABLE detaches (failed flag set, honest degrade);
  /// notifications fire on transitions only, never per-frame.
  void _noteNativeError(FaceObservation o) {
    final wasDegraded = _stage == CameraStage.mlDegraded;
    if (o.error == MlErrorClass.engineUnavailable ||
        o.error == MlErrorClass.cameraError) {
      _recordError('native-engine',
          StateError('native ${o.error!.name} (gen ${o.generation})'));
      _nativeFailedThisSession = true;
      unawaited(_stopNativeEngine());
      if (!wasDegraded) {
        _setStage(CameraStage.mlDegraded, 'native-${o.error!.name}');
        notifyListeners();
      }
      return;
    }
    consecMlErrors++;
    _recordError('native-ml',
        StateError('native ${o.error?.name ?? 'error'}'));
    if (framesProcessed == 0 && consecMlErrors >= 10 && !wasDegraded) {
      _setStage(CameraStage.mlDegraded,
          '$consecMlErrors consecutive native ML errors');
      notifyListeners();
    }
  }

  void _logFrame(int w, int h, int rot, int sensor, bool front,
      EyeStatus status, EyeGeometry geo, FrameQuality quality,
      double latencyMs) {
    String fmtPt(EyePoint? p) => p == null
        ? '--'
        : '${(p.x * w).toStringAsFixed(0)},${(p.y * h).toStringAsFixed(0)}';
    frameLog.add(FrameLogEntry(
      time: DateTime.now(),
      width: w,
      height: h,
      rotationDeg: rot,
      sensorOrientation: sensor,
      mirrored: front,
      state: detectionStateKey(status.state),
      box: geo.faceBox == null
          ? '--'
          : '${(geo.faceBox!.left * w).toStringAsFixed(0)},'
              '${(geo.faceBox!.top * h).toStringAsFixed(0)},'
              '${(geo.faceBox!.right * w).toStringAsFixed(0)},'
              '${(geo.faceBox!.bottom * h).toStringAsFixed(0)}',
      eyes: 'L[${fmtPt(status.smoothLeft)}] R[${fmtPt(status.smoothRight)}]'
          '${status.positionsStale ? ' stale' : ''}'
          '${status.locked ? ' LOCK' : ''}',
      luminance: quality.meanLuminance,
      blur: quality.blurVariance,
      mlFormat: _lastMlFormat,
      latencyMs: latencyMs,
    ));
    if (frameLog.length > frameLogCap) {
      frameLog.removeRange(0, frameLog.length - frameLogCap);
    }
  }

  /// Shared ML-failure bookkeeping for all input paths (byte array,
  /// RGBA bitmap, JPEG file): counts, records with stack, logs the face
  /// fail, then walks the fallback ladder (YV12 declaration -> RGBA
  /// bitmap -> JPEG file -> minimal detector -> mlDegraded stage).
  /// Callers return from _onImage after calling. No work after dispose.
  void _noteMlFailure(Object e, StackTrace? st,
      {required int w,
      required int h,
      required String formatName,
      required int rot,
      required FrameQuality quality}) {
    if (_disposed) return;
    consecMlErrors++;
    _recordError('ml-process', e, st);
    _logFaceFail(w, h, formatName, rot, quality, '$e');
    // M8: typed classification (converter = byte-path problem,
    // detector/unknown = inside ML Kit). Non-converter errors keep the
    // previous detector-rung eligibility; the kind is now logged.
    final kind = classifyMlFailure('$e');
    final converter = kind == MlFailureKind.converter;
    _event('ML_FAILURE_KIND',
        '${kind.name} (consec=$consecMlErrors processed=$framesProcessed)');
    if (shouldLatchFormatFallback(
        consecMlErrors: consecMlErrors,
        framesProcessed: framesProcessed,
        alreadyLatched: _formatFallbackYv12,
        converterError: converter)) {
      _formatFallbackYv12 = true;
      consecMlErrors = 0;
      _lastMlAttempt = null;
      _event('FORMAT_FALLBACK',
          'persistent converter failure on NV21 declaration; '
          'retrying identical bytes as YV12 (same luma)');
      notifyListeners();
    } else if (shouldLatchBitmapFallback(
        consecMlErrors: consecMlErrors,
        framesProcessed: framesProcessed,
        yv12Latched: _formatFallbackYv12,
        bitmapLatched: _bitmapFallback,
        converterError: converter)) {
      _bitmapFallback = true;
      consecMlErrors = 0;
      _lastMlAttempt = null;
      _event('BITMAP_FALLBACK',
          'byte-array native paths still failing; '
          'switching NV21 frames to upright RGBA-bitmap input');
      notifyListeners();
    } else if (shouldLatchFileFallback(
        consecMlErrors: consecMlErrors,
        framesProcessed: framesProcessed,
        yv12Latched: _formatFallbackYv12,
        bitmapLatched: _bitmapFallback,
        fileLatched: _fileFallbackJpeg,
        converterError: converter)) {
      _fileFallbackJpeg = true;
      consecMlErrors = 0;
      _lastMlAttempt = null;
      _event('FILE_FALLBACK',
          'bitmap path still failing; '
          'switching NV21 frames to upright JPEG-file input');
      notifyListeners();
    } else if (shouldLatchDetectorFallback(
        consecMlErrors: consecMlErrors,
        framesProcessed: framesProcessed,
        fileLatched: _fileFallbackJpeg,
        bitmapLatched: _bitmapFallback,
        detectorLatched: _detectorMinimal,
        converterError: converter,
        detectorError: !converter)) {
      _switchToMinimalDetector();
      consecMlErrors = 0;
      _lastMlAttempt = null;
      notifyListeners();
    } else if (detectorRecreateDue(
        consecutiveErrors: consecMlErrors,
        framesProcessed: framesProcessed,
        now: DateTime.now(),
        lastRecreateAt: _lastDetectorRecreateAt,
        recreatesSoFar: _detectorRecreates)) {
      _recreateDetector();
      consecMlErrors = 0;
      _lastMlAttempt = null;
      notifyListeners();
    } else if (framesProcessed == 0 && consecMlErrors >= 10) {
      _setStage(CameraStage.mlDegraded,
          '$consecMlErrors consecutive ML errors');
      notifyListeners();
      // Terminal Dart failure: the capability manager may select the
      // native engine exactly once per session (never loops).
      unawaited(_maybeFailoverToNative());
    }
  }

  /// Drop the current detector and rebuild minimal on next use (fast,
  /// landmarks-only, no tracking/classification). A close failure must
  /// never break the rebuild.
  void _switchToMinimalDetector() {
    _detectorMinimal = true;
    _detectorFast = false;
    final old = _detector;
    _detector = null;
    _detectorClosed = true;
    try {
      old?.close().then((_) {}, onError: (_) {});
    } catch (_) {}
    _event('DETECTOR_FALLBACK',
        'persistent detector-internal failure; rebuilt minimal '
        '(fast, landmarks-only, no tracking/classification)');
  }

  /// Bounded last-resort recovery: drop the current detector so the next
  /// frame rebuilds it in its CURRENT config (full or minimal — the
  /// minimal flag is untouched). A close failure never breaks the
  /// rebuild. Throttled + capped by detectorRecreateDue; a structurally
  /// broken detector keeps failing identically and falls through to the
  /// mlDegraded stage instead of looping.
  void _recreateDetector() {
    final old = _detector;
    _detector = null;
    _detectorClosed = true;
    try {
      old?.close().then((_) {}, onError: (_) {});
    } catch (_) {}
    _detectorRecreates++;
    _lastDetectorRecreateAt = DateTime.now();
    _event('DETECTOR_RECREATE',
        'persistent ML failure with zero processed frames; rebuilt '
        'detector (attempt $_detectorRecreates/$kMaxDetectorRecreatesPerSession)');
  }

  /// Reused temp file for the JPEG-file ML fallback (overwritten per
  /// attempt; no frame accumulation on disk).
  Future<String> _fallbackJpegFile() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/ocuscan-ml-fallback.jpg';
  }

  Future<XFile?> captureStill() async {
    try {
      // Still capture is a plugin-path capability (takePicture); the
      // native engine owns its camera exclusively and offers no still
      // API. Null is the honest skip (callers already handle it) —
      // never a null-dereference error.
      if (_nativeActive) return null;
      if (!ready) return null;
      await _controller!.stopImageStream();
      _streamActive = false;
      try {
        return await _controller!.takePicture();
      } finally {
        // Always resume the stream so a capture failure cannot leave a
        // black preview behind.
        try {
          if (_controller != null) {
            await _controller!.startImageStream(_onImage);
            _streamActive = true;
          }
        } catch (e, st) {
          _recordError('stream-resume', e, st);
        }
      }
    } catch (e, st) {
      _recordError('capture', e, st);
      return null;
    }
  }

  /// Research-only: run the face detector on a saved still (e.g. a capture
  /// from [captureStill]) and return geometry in the still's own upright
  /// pixel space (normalized). Still space differs from live-stream raw
  /// space (the camera plugin rotates JPEGs; the stream is raw sensor
  /// order), so overlay still results with rotation 0 / unmirrored mapping
  /// and label them as still-space. Returns null on failure, and an
  /// [EyeGeometry] with faceFound=false when no face is present.
  Future<EyeGeometry?> analyzeStill(String path) async {
    try {
      final input = InputImage.fromFilePath(path);
      final faces = await _ensureDetector().processImage(input);
      if (faces.isEmpty) return const EyeGeometry(faceFound: false);
      final f = faces.first;
      final codec = await ui.instantiateImageCodec(
          await XFile(path).readAsBytes());
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final w = img.width.toDouble(), h = img.height.toDouble();
      img.dispose();
      if (w <= 0 || h <= 0) return null;
      final bb = f.boundingBox;
      EyePoint? stillPt(dynamic p) =>
          p == null ? null : EyePoint(p.x / w, p.y / h);
      final le = stillPt(f.landmarks[FaceLandmarkType.leftEye]?.position);
      final re = stillPt(f.landmarks[FaceLandmarkType.rightEye]?.position);
      return EyeGeometry(
        faceFound: true,
        faceBox:
            Rect.fromLTRB(bb.left / w, bb.top / h, bb.right / w, bb.bottom / h),
        leftEye: le,
        rightEye: re,
        yawDeg: (f.headEulerAngleY ?? 0).toDouble(),
        rollDeg: (f.headEulerAngleZ ?? 0).toDouble(),
        pitchDeg: (f.headEulerAngleX ?? 0).toDouble(),
        leftOpenProb: (f.leftEyeOpenProbability ?? -1).toDouble(),
        rightOpenProb: (f.rightEyeOpenProbability ?? -1).toDouble(),
        trackingId: f.trackingId,
        imageWidth: w.toInt(),
        imageHeight: h.toInt(),
        faceCount: faces.length,
      );
    } catch (e, st) {
      _recordError('still-analyze', e, st);
      return null;
    }
  }

  /// Research-only diagnostic export (§45): device, camera, orientation,
  /// startup timings, frame counts, FPS, quality/stage states, ML status,
  /// lock state, algorithm versions. Never includes images.
  Map<String, Object?> diagnosticReport(
      {required String appVersion,
      required String deviceModel,
      required String osVersion}) {
    final st = eyeStatus;
    return {
      'appVersion': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'device': {'model': deviceModel, 'os': osVersion},
      'camera': {
        'source': activeSourceCode,
        'info': cameraInfo,
        'capabilities': [
          for (final c in capabilities)
            {
              'code': c.code,
              'lens': c.lensDirection,
              'sensor': c.sensorOrientation,
              'name': c.name,
              'preview': c.previewWidth != null
                  ? '${c.previewWidth}x${c.previewHeight}'
                  : null,
            }
        ],
      },
      'startup': {
        'stage': _stage.name,
        'stageDetail': _stageDetail,
        'streamStartedAt': streamStartedAt?.toIso8601String(),
        'firstFrameAt': firstFrameAt?.toIso8601String(),
        'watchdog': startupWatchdogState().name,
      },
      'frames': {
        'received': framesReceived,
        'processed': framesProcessed,
        'dropped': framesDropped,
        'arrivalFps': double.parse(arrivalFps.toStringAsFixed(1)),
        'processingFps':
            double.parse(processingFps.toStringAsFixed(1)),
        'lastLatencyMs': double.parse(lastLatencyMs.toStringAsFixed(1)),
        'lastConvertMs': double.parse(lastConvertMs.toStringAsFixed(1)),
        'lastInferMs': double.parse(lastInferMs.toStringAsFixed(1)),
        'meanLatencyMs': double.parse(_latencyEma.toStringAsFixed(1)),
        'throughputRatio': throughputRatio < 0
            ? -1
            : double.parse(throughputRatio.toStringAsFixed(3)),
        'mlMap': mlInputLabel,
        'lastFrameAgeMs': lastFrameAgeMs,
        'mlFormat': _lastMlFormat,
        'group': _lastGroupName,
        'layout': _lastLayoutKind,
        'planes': _lastPlaneCount,
        'planeLengths': _lastPlaneLengths,
        'stride': _lastStride,
        'pixelStride': _lastPixelStride,
        'bytesLen': _lastBytesLen,
        'expectedLen': _lastExpectedLen,
        'w': _lastW,
        'h': _lastH,
        'rot': _lastRotation,
        'consecMlErrors': consecMlErrors,
        'consecConvertErrors': consecConvertErrors,
      },
      'tracking': {
        'state': st == null ? 'no-frame' : detectionStateKey(st.state),
        'stableFrames': st?.stableFrames ?? 0,
        'locked': st?.locked ?? false,
        'lastError': _lastError?.toString(),
        'lastErrorStack': _lastError?.stack,
        // Untruncated error history with native stacks: the export-errors
        // report. UI lines truncate; this section never does.
        'errorLog': [
          for (final e in errorLog)
            {
              'time': e.time.toIso8601String(),
              'stage': e.stage,
              'type': e.type,
              'message': e.message,
              'stack': e.stack,
            }
        ],
        'faceFails': faceFailLog.map((e) => e.toString()).toList(),
        'frameLogTail':
            frameLog.reversed.take(10).map((e) => e.toString()).toList(),
      },
      'detection': {
        'tier': detectorTier,
        'preferFastTier': _preferFastTier,
        'mlGeneration': _mlGeneration,
        'facesDetected': facesDetectedTotal,
        'locksAchieved': locksAchievedTotal,
        'quality': qualityVerdictLabel,
        'hitRate': hitRateLine,
        'generations': [
          for (final e in _genStats.entries)
            {
              'gen': e.key,
              'tier': e.value.tier,
              'frames': e.value.frames,
              'meanLatencyMs': e.value.frames == 0
                  ? 0
                  : double.parse((e.value.sumMs / e.value.frames)
                      .toStringAsFixed(1)),
            }
        ],
      },
      'adaptation': {
        'escalated': _escalated,
        'nativePrimarySuppressed': _nativePrimarySuppressed,
        'preferHigh': _preferHigh,
        'formatFallbackYv12': _formatFallbackYv12,
        'bitmapFallback': _bitmapFallback,
        'fileFallbackJpeg': _fileFallbackJpeg,
        'detectorMinimal': _detectorMinimal,
        'mlGeneration': _mlGeneration,
        'hitRates': hitRates.summary(),
      },
      'thresholds': {
        'minFaceFraction': tracker.config.minFaceFraction,
        'maxFaceFraction': tracker.config.maxFaceFraction,
        'maxYawDeg': tracker.config.maxYawDeg,
        'stableFramesRequired': tracker.config.stableFramesRequired,
        'maxLostFrames': tracker.config.maxLostFrames,
      },
      'analyzers': {
        for (final a in AnalyzerRegistry.all) a.key: a.version,
      },
      'events': events.map((e) => e.toString()).toList(),
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _nativeLivenessTimer?.cancel();
    _nativeLivenessTimer = null;
    _controller?.dispose();
    _controller = null;
    // Best-effort native teardown alongside the Dart one: a failure
    // (including a missing platform plugin in tests) must never crash
    // route/test teardown. Unawaited by design (dispose is sync).
    unawaited(_stopNativeEngine());
    try {
      // Best-effort native teardown: a close failure (including a missing
      // platform plugin in tests) must never crash route/test teardown.
      if (_detector != null && !_detectorClosed) {
        _detectorClosed = true;
        _detector!.close().then((_) {}, onError: (_) {});
      }
    } catch (_) {}
    super.dispose();
  }
}
