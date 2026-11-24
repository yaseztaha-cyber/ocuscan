// Eye-tracking core: geometry, diagnostic states, temporal stability, and
// coordinate transforms for the front-camera screening flow.
//
// Design rules (v0.3.2):
// - No invented coordinates. Smoothed positions are only kept inside a short
//   loss budget and are explicitly marked stale; beyond budget the tracker
//   reports eyes unavailable.
// - All coordinate spaces are transformed explicitly and unit-tested:
//   ML Kit returns landmarks in the RAW (unrotated, unmirrored) image buffer
//   space; the preview is upright + mirrored (front camera) + cover-fit.
// - Thresholds are documented, lenient, and analyzer-specific gating is
//   decided per module need — never one global "perfect frame" gate.
// - This file is pure Dart (dart:ui only) so every transform and the whole
//   state machine are unit-testable without plugins or a camera.

import 'dart:math' as math;
import 'dart:ui';

/// Normalized point in ML Kit RAW image space: x goes right, y goes down,
/// origin top-left, range 0..1. Raw space is never mirrored: x=0 is the
/// sensor's left edge as captured, regardless of lens or UI mirroring.
class EyePoint {
  final double x;
  final double y;
  const EyePoint(this.x, this.y);

  EyePoint lerp(EyePoint other, double t) =>
      EyePoint(x + (other.x - x) * t, y + (other.y - y) * t);

  double distanceTo(EyePoint other) =>
      math.sqrt((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y));

  @override
  bool operator ==(Object other) =>
      other is EyePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'EyePoint(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// Why the current frame is not usable, or [ready]. Ordered by the check
/// pipeline in [EyeTracker.update]: face presence → face count → image
/// quality → face geometry → eye localization → stability. The FIRST
/// failing check wins so guidance always names the actual blocking problem.
enum DetectionState {
  faceNotFound,
  multipleFaces,
  faceTooSmall,
  faceTooLarge,
  faceAngleInvalid,
  leftEyeUnavailable,
  rightEyeUnavailable,
  bothEyesUnavailable,
  imageTooDark,
  imageTooBright,
  imageTooBlurry,
  trackingUnstable,
  ready,
}

/// Localization key for user-facing guidance (resolved by AppStrings, so
/// this file stays free of UI strings).
String detectionStateKey(DetectionState s) {
  switch (s) {
    case DetectionState.faceNotFound:
      return 'faceNotFound';
    case DetectionState.multipleFaces:
      return 'multipleFaces';
    case DetectionState.faceTooSmall:
      return 'faceTooSmall';
    case DetectionState.faceTooLarge:
      return 'faceTooLarge';
    case DetectionState.faceAngleInvalid:
      return 'faceAngleInvalid';
    case DetectionState.leftEyeUnavailable:
      return 'leftEyeUnavailable';
    case DetectionState.rightEyeUnavailable:
      return 'rightEyeUnavailable';
    case DetectionState.bothEyesUnavailable:
      return 'bothEyesUnavailable';
    case DetectionState.imageTooDark:
      return 'imageTooDark';
    case DetectionState.imageTooBright:
      return 'imageTooBright';
    case DetectionState.imageTooBlurry:
      return 'imageTooBlurry';
    case DetectionState.trackingUnstable:
      return 'trackingUnstable';
    case DetectionState.ready:
      return 'ready';
  }
}

/// One detector frame, already converted to normalized raw-image space.
class EyeGeometry {
  final bool faceFound;
  final Rect? faceBox; // normalized, raw image space
  final EyePoint? leftEye; // subject's anatomical left eye
  final EyePoint? rightEye; // subject's anatomical right eye
  final double yawDeg;
  final double rollDeg;
  /// Head pitch in degrees from ML Kit headEulerAngleX (positive = tilt).
  /// Defaults to 0 (unknown/unavailable). May be NaN from the detector;
  /// use [safePitchDeg]/[hasPitch] for NaN-safe access.
  final double pitchDeg;
  final double leftOpenProb; // 0..1, -1 when unknown
  final double rightOpenProb;
  final int? trackingId;
  final int contourPoints;
  final int imageWidth;
  final int imageHeight;

  /// How many faces the detector reported this frame. The service forwards
  /// the LARGEST face's geometry; a count above 1 forces the multiple-faces
  /// state (never a silent arbitrary pick).
  final int faceCount;

  const EyeGeometry({
    required this.faceFound,
    this.faceBox,
    this.leftEye,
    this.rightEye,
    this.yawDeg = 0,
    this.rollDeg = 0,
    this.pitchDeg = 0,
    this.leftOpenProb = -1,
    this.rightOpenProb = -1,
    this.trackingId,
    this.contourPoints = 0,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.faceCount = 1,
  });

  /// NaN-safe pitch: finite values pass through, NaN/±infinite collapse
  /// to 0 (unknown/unavailable). Never throws.
  double get safePitchDeg => pitchDeg.isFinite ? pitchDeg : 0.0;

  /// True when the detector supplied a finite pitch value.
  bool get hasPitch => pitchDeg.isFinite;

  double get faceFraction =>
      faceBox == null || imageHeight <= 0 ? 0 : faceBox!.height;
}

/// Cheap luminance/sharpness summary sampled from the Y plane.
class FrameQuality {
  final double meanLuminance; // 0..255
  final double blurVariance; // Laplacian variance on coarse grid
  final double overexposedFraction; // luminance > 240
  final int width;
  final int height;

  const FrameQuality({
    required this.meanLuminance,
    required this.blurVariance,
    required this.overexposedFraction,
    required this.width,
    required this.height,
  });

  const FrameQuality.unknown()
      : meanLuminance = 120,
        blurVariance = 100,
        overexposedFraction = 0,
        width = 0,
        height = 0;
}

/// Threshold bundle. Defaults are intentionally lenient: the goal is
/// "sufficient information for the specific measurement", never a perfect
/// frame. All values are surfaced in /dev for on-device tuning.
class EyeTrackerConfig {
  final double minFaceFraction;
  final double maxFaceFraction;
  final double maxYawDeg;
  final double maxRollDeg;
  final double minOpenProb;
  final double darkLuminance;
  final double brightLuminance;
  final double brightOverexposedFraction;
  final double minBlurVariance;
  final int stableFramesRequired;
  final int maxLostFrames;
  final double smoothingAlpha;

  const EyeTrackerConfig({
    this.minFaceFraction = 0.22,
    this.maxFaceFraction = 0.88,
    this.maxYawDeg = 28,
    this.maxRollDeg = 28,
    this.minOpenProb = 0.35,
    this.darkLuminance = 38,
    this.brightLuminance = 215,
    this.brightOverexposedFraction = 0.25,
    this.minBlurVariance = 8,
    this.stableFramesRequired = 5,
    this.maxLostFrames = 5,
    this.smoothingAlpha = 0.5,
  });
}

/// Named image-quality verdict from the SAME thresholds the tracker gates
/// on below (dark → bright → blurry order, mirroring update()). 'unknown'
/// before any real sample (width 0, e.g. FrameQuality.unknown);
/// 'good' when nothing gates. Display/reporting only — gating stays in
/// update() so the verdict can never disagree with the gate.
/// Values are stable machine keys ('good', 'tooDark', 'tooBright',
/// 'tooBlurry', 'unknown'), localized at the UI layer if ever shown.
String qualityVerdict(FrameQuality q, EyeTrackerConfig c) {
  if (q.width <= 0) return 'unknown';
  if (q.meanLuminance < c.darkLuminance) return 'tooDark';
  if (q.meanLuminance > c.brightLuminance ||
      q.overexposedFraction > c.brightOverexposedFraction) {
    return 'tooBright';
  }
  if (q.blurVariance < c.minBlurVariance) return 'tooBlurry';
  return 'good';
}

/// Per-analyzer measurement needs. Quality requirements are per module:
/// e.g. pupil symmetry needs both pupils + stability, while facial
/// asymmetry only needs a positioned face box with acceptable yaw.
enum AnalyzerNeed {
  facialAsymmetry,
  eyelid,
  pupilSymmetry,
  blink,
  rednessPixels,
  sharpStill,
}

/// Tracker output for one frame.
class EyeStatus {
  final DetectionState state;
  final EyePoint? smoothLeft;
  final EyePoint? smoothRight;

  /// True when positions come from history inside the loss budget (not from
  /// the current frame). Never treat stale positions as fresh measurements.
  final bool positionsStale;
  final int stableFrames;
  final bool locked;
  final bool leftLocated;
  final bool rightLocated;
  final bool eyesOpen;
  final Rect? faceBox;
  final double yawDeg;
  final double faceFraction;
  /// Measured head pitch in degrees (NaN-safe, 0 when unknown).
  final double pitchDeg;
  /// True when the tracker saw a finite pitch on the current frame.
  /// When false, pitch-gated needs fall back to pitch-blind behavior.
  final bool pitchValid;

  /// Eyelid measurement tolerates at most this much head pitch when a
  /// finite pitch was observed. Beyond it the eyelid need is not met.
  static const double eyelidMaxPitchDeg = 20.0;

  const EyeStatus({
    required this.state,
    this.smoothLeft,
    this.smoothRight,
    this.positionsStale = false,
    this.stableFrames = 0,
    this.locked = false,
    this.leftLocated = false,
    this.rightLocated = false,
    this.eyesOpen = false,
    this.faceBox,
    this.yawDeg = 0,
    this.faceFraction = 0,
    this.pitchDeg = 0,
    this.pitchValid = false,
  });

  bool get ready => state == DetectionState.ready;
  bool get eyesLocated => leftLocated && rightLocated;

  // Value equality: the overlay's shouldRepaint compares statuses across
  // frames. Identity comparison repaints every frame even when nothing
  // moved (the tracker allocates a new instance per frame); value
  // comparison repaints only on real change, plus the lock pulse.
  @override
  bool operator ==(Object other) =>
      other is EyeStatus &&
      other.state == state &&
      other.smoothLeft == smoothLeft &&
      other.smoothRight == smoothRight &&
      other.positionsStale == positionsStale &&
      other.stableFrames == stableFrames &&
      other.locked == locked &&
      other.leftLocated == leftLocated &&
      other.rightLocated == rightLocated &&
      other.eyesOpen == eyesOpen &&
      other.faceBox == faceBox &&
      other.yawDeg == yawDeg &&
      other.faceFraction == faceFraction &&
      other.pitchDeg == pitchDeg &&
      other.pitchValid == pitchValid;

  @override
  int get hashCode => Object.hash(
        state,
        smoothLeft,
        smoothRight,
        positionsStale,
        stableFrames,
        locked,
        leftLocated,
        rightLocated,
        eyesOpen,
        faceBox,
        yawDeg,
        faceFraction,
        pitchDeg,
        pitchValid,
      );

  /// Horizontal centering of the face box (legacy ±12% gate semantics).
  bool get centeredX {
    if (faceBox == null) return false;
    return ((faceBox!.left + faceBox!.right) / 2 - 0.5).abs() < 0.12;
  }

  /// Whether the current status satisfies a module's measurement need.
  bool meetsNeed(AnalyzerNeed need, EyeTrackerConfig c,
      {bool stillSharp = false}) {
    switch (need) {
      case AnalyzerNeed.facialAsymmetry:
        // Needs a positioned face; eye points not required.
        return faceBox != null &&
            faceFraction >= c.minFaceFraction &&
            faceFraction <= c.maxFaceFraction &&
            yawDeg.abs() <= c.maxYawDeg &&
            (state == DetectionState.ready ||
                state == DetectionState.trackingUnstable);
      case AnalyzerNeed.eyelid:
        // Pitch gate: when a finite pitch was observed, require a
        // near-frontal vertical head angle. When pitch is unknown
        // (pitchValid false, e.g. NaN from the detector), fall back to
        // the legacy eyes-located behavior rather than inventing data.
        if (!eyesLocated) return false;
        if (pitchValid && pitchDeg.abs() > eyelidMaxPitchDeg) return false;
        return true;
      case AnalyzerNeed.pupilSymmetry:
      case AnalyzerNeed.blink:
        return eyesLocated && eyesOpen && locked && !positionsStale;
      case AnalyzerNeed.rednessPixels:
        return true; // whole-frame pixel stats; gated by still quality
      case AnalyzerNeed.sharpStill:
        return stillSharp;
    }
  }
}

/// Stateful tracker: smoothing + loss budget + stability window.
class EyeTracker {
  final EyeTrackerConfig config;
  EyePoint? _smoothLeft;
  EyePoint? _smoothRight;
  int _consecReady = 0;
  int _lostFrames = 0;
  bool _hadPositions = false;
  double _lastPitchDeg = 0.0;
  bool _lastPitchValid = false;

  EyeTracker({this.config = const EyeTrackerConfig()});

  /// Last NaN-safe pitch seen (0 when unknown). Updated on every
  /// [update] that carries geometry.
  double get lastPitchDeg => _lastPitchDeg;

  /// True when the last [update] carried a finite pitch value.
  bool get pitchValid => _lastPitchValid;

  void reset() {
    _smoothLeft = null;
    _smoothRight = null;
    _consecReady = 0;
    _lostFrames = 0;
    _hadPositions = false;
    _lastPitchDeg = 0.0;
    _lastPitchValid = false;
  }

  EyeStatus update(EyeGeometry? geo, FrameQuality q) {
    final c = config;
    // 1. Face presence. M6: a single dropped ML frame no longer wipes
    // the 5-frame stability window — positions are held inside the same
    // loss budget as the eye-missing path, explicitly marked stale, and
    // only dropped (faceNotFound + reset) when the budget is exceeded.
    // UI must respect positionsStale and never treat held positions
    // as fresh measurements.
    if (geo == null || !geo.faceFound || geo.faceBox == null) {
      if (_hadPositions && _lostFrames < c.maxLostFrames) {
        _lostFrames++;
        // NOTE: _consecReady is deliberately preserved (not zeroed):
        // one dropped frame inside the loss budget must not restart the
        // 5-frame stability window. Lock itself still only ever reports
        // true on full-observation ready frames (_status hardcodes
        // locked:false), so analyzers can never see a locked stale frame.
        final holdGeo = geo ?? const EyeGeometry(faceFound: false);
        return _status(holdGeo, DetectionState.trackingUnstable,
            stale: true, located: false);
      }
      reset();
      return const EyeStatus(state: DetectionState.faceNotFound);
    }
    // Record measured pitch NaN-safely: finite values pass through,
    // NaN/±infinite collapse to 0 + invalid (unknown/unavailable).
    _lastPitchValid = geo.hasPitch;
    _lastPitchDeg = geo.safePitchDeg;
    // 2. Exactly one face: never measure against an arbitrary pick from
    // a crowd. The service forwards the largest face; the tracker still
    // refuses and names the condition.
    if (geo.faceCount > 1) {
      return _hold(geo, DetectionState.multipleFaces);
    }
    // 2. Image quality (face exists, but unusable light/blur).
    if (q.meanLuminance < c.darkLuminance) {
      return _hold(geo, DetectionState.imageTooDark);
    }
    if (q.meanLuminance > c.brightLuminance ||
        q.overexposedFraction > c.brightOverexposedFraction) {
      return _hold(geo, DetectionState.imageTooBright);
    }
    if (q.blurVariance < c.minBlurVariance) {
      return _hold(geo, DetectionState.imageTooBlurry);
    }
    // 3. Face geometry.
    final frac = geo.faceFraction;
    if (frac < c.minFaceFraction) {
      return _hold(geo, DetectionState.faceTooSmall);
    }
    if (frac > c.maxFaceFraction) {
      return _hold(geo, DetectionState.faceTooLarge);
    }
    if (geo.yawDeg.abs() > c.maxYawDeg ||
        geo.rollDeg.abs() > c.maxRollDeg) {
      return _hold(geo, DetectionState.faceAngleInvalid);
    }
    // 4. Eye localization with loss budget.
    final lNull = geo.leftEye == null;
    final rNull = geo.rightEye == null;
    if (lNull || rNull) {
      if (_hadPositions && _lostFrames < c.maxLostFrames) {
        _lostFrames++;
        _consecReady = 0;
        return _status(geo, DetectionState.trackingUnstable,
            stale: true, located: false);
      }
      _lostFrames = 0;
      _consecReady = 0;
      // Budget exceeded: drop history entirely. Never present old
      // coordinates as current — report the eyes as unavailable.
      _smoothLeft = null;
      _smoothRight = null;
      _hadPositions = false;
      if (lNull && rNull) {
        return _status(geo, DetectionState.bothEyesUnavailable,
            stale: false, located: false);
      }
      return _status(geo,
          lNull
              ? DetectionState.leftEyeUnavailable
              : DetectionState.rightEyeUnavailable,
          stale: false, located: false);
    }
    // 5. Full observation: smooth + stability window.
    _lostFrames = 0;
    final a = c.smoothingAlpha;
    _smoothLeft = _smoothLeft == null
        ? geo.leftEye
        : _smoothLeft!.lerp(geo.leftEye!, a);
    _smoothRight = _smoothRight == null
        ? geo.rightEye
        : _smoothRight!.lerp(geo.rightEye!, a);
    _hadPositions = true;
    _consecReady++;
    final locked = _consecReady >= c.stableFramesRequired;
    final open = (geo.leftOpenProb < 0 || geo.leftOpenProb >= c.minOpenProb) &&
        (geo.rightOpenProb < 0 || geo.rightOpenProb >= c.minOpenProb);
    return EyeStatus(
      state: DetectionState.ready,
      smoothLeft: _smoothLeft,
      smoothRight: _smoothRight,
      stableFrames: math.min(_consecReady, c.stableFramesRequired),
      locked: locked,
      leftLocated: true,
      rightLocated: true,
      eyesOpen: open,
      faceBox: geo.faceBox,
      yawDeg: geo.yawDeg,
      faceFraction: frac,
      pitchDeg: _lastPitchDeg,
      pitchValid: _lastPitchValid,
    );
  }

  /// Non-ready state that keeps previously smoothed positions (marked stale)
  /// so the UI can show a frozen guide instead of jumping, without ever
  /// presenting stale positions as fresh.
  EyeStatus _hold(EyeGeometry geo, DetectionState s) {
    _consecReady = 0;
    return _status(geo, s, stale: _hadPositions, located: false);
  }

  EyeStatus _status(EyeGeometry geo, DetectionState s,
      {required bool stale, required bool located}) {
    final open = (geo.leftOpenProb < 0 || geo.leftOpenProb >= config.minOpenProb) &&
        (geo.rightOpenProb < 0 || geo.rightOpenProb >= config.minOpenProb);
    return EyeStatus(
      state: s,
      smoothLeft: _smoothLeft,
      smoothRight: _smoothRight,
      positionsStale: stale,
      stableFrames: 0,
      locked: false,
      leftLocated: located && geo.leftEye != null,
      rightLocated: located && geo.rightEye != null,
      eyesOpen: open,
      faceBox: geo.faceBox,
      yawDeg: geo.yawDeg,
      faceFraction: geo.faceFraction,
      pitchDeg: _lastPitchDeg,
      pitchValid: _lastPitchValid,
    );
  }
}

/// Coordinate-space transforms. All pure functions, all unit-tested.
class EyeCoords {  /// ML Kit image rotation from camera sensor + device orientation.
  /// Standard compensation formula (matches the ML Kit vision sample):
  /// front camera adds, back camera subtracts device rotation.
  /// Returns one of 0 / 90 / 180 / 270.
  static int mlKitRotationDeg({
    required int sensorOrientationDeg,
    required int deviceOrientationQuarterTurns,
    required bool frontCamera,
  }) {
    const quarter = [0, 90, 180, 270];
    final comp = quarter[deviceOrientationQuarterTurns % 4];
    final rot = frontCamera
        ? (sensorOrientationDeg + comp) % 360
        : (sensorOrientationDeg - comp + 360) % 360;
    assert(rot % 90 == 0);
    return rot;
  }

  /// Upright preview aspect (width/height) for an exact-aspect preview
  /// box. The overlay maps with cover-fit math onto the same box, so the
  /// aspect must be EXACT — never clamped: clamping a wide (rear /
  /// landscape) frame narrows the box while the texture underneath keeps
  /// its true shape, and every marker lands off-target. Degenerate input
  /// falls back to portrait 3/4, identically for preview and overlay.
  static double uprightAspect(Size rawSize, int rotationDeg) {
    final r = ((rotationDeg % 360) + 360) % 360;
    final swap = r == 90 || r == 270;
    final w = swap ? rawSize.height : rawSize.width;
    final h = swap ? rawSize.width : rawSize.height;
    if (w <= 0 || h <= 0) return 3 / 4;
    return w / h;
  }

  /// Map a normalized RAW image point to preview-widget coordinates.
  ///
  /// - [raw]: normalized point in raw buffer space (origin top-left).
  /// - [rawSize]: raw buffer pixel size (e.g. 1280x720 sensor landscape).
  /// - [rotationDeg]: image rotation that makes the buffer upright (0/90/180/270).
  /// - [mirrored]: front-camera selfie preview is mirrored horizontally.
  /// - [previewSize]: widget size showing the preview with [BoxFit.cover].
  ///
  /// Anatomical identity is preserved: the subject's left eye maps to the
  /// side of the screen where the mirrored selfie shows it (viewer's right),
  /// exactly like a mirror — callers must NOT swap labels for RTL layouts.
  static Offset imageToPreview({
    required Offset raw,
    required Size rawSize,
    required int rotationDeg,
    required bool mirrored,
    required Size previewSize,
  }) {
    final r = ((rotationDeg % 360) + 360) % 360;
    // Raw pixel position.
    double px = raw.dx * rawSize.width;
    double py = raw.dy * rawSize.height;
    double uw = rawSize.width;
    double uh = rawSize.height;
    // Rotate into upright space.
    double ux, uy;
    switch (r) {
      case 90:
        ux = uh - py;
        uy = px;
        uw = rawSize.height;
        uh = rawSize.width;
        break;
      case 180:
        ux = uw - px;
        uy = uh - py;
        break;
      case 270:
        ux = py;
        uy = uw - px;
        uw = rawSize.height;
        uh = rawSize.width;
        break;
      default:
        ux = px;
        uy = py;
    }
    // Mirror (front selfie preview).
    if (mirrored) ux = uw - ux;
    // Cover-fit into the widget, centered (may crop).
    final scale = math.max(previewSize.width / uw, previewSize.height / uh);
    final dx = (previewSize.width - uw * scale) / 2;
    final dy = (previewSize.height - uh * scale) / 2;
    return Offset(ux * scale + dx, uy * scale + dy);
  }

  /// Convert an upright-normalized detector point back to sensor-frame
  /// normalized coords. The bitmap/file input rungs pre-rotate pixels
  /// upright before ML Kit, so raw detector output lives in upright
  /// space — but the tracker, overlay, logs and analyzer crops all
  /// speak sensor frame + rotation metadata. Feeding upright coords in
  /// directly double-rotates every marker (v0.7.19: centered faces drew
  /// shifted, eyes glitched). Identity for rot 0 and for the bytes
  /// path (already sensor-frame). Pure; unit-tested.
  static EyePoint uprightNormToSensorNorm(EyePoint p, int rotationDeg) {
    final r = ((rotationDeg % 360) + 360) % 360;
    switch (r) {
      case 90:
        return EyePoint(p.y, 1 - p.x);
      case 180:
        return EyePoint(1 - p.x, 1 - p.y);
      case 270:
        return EyePoint(1 - p.y, p.x);
      default:
        return p;
    }
  }

  /// Box form of [uprightNormToSensorNorm]: both corners mapped, then
  /// re-squared (axis-aligned rotations keep boxes axis-aligned).
  static Rect uprightNormBoxToSensorNorm(Rect box, int rotationDeg) {
    final a = uprightNormToSensorNorm(
        EyePoint(box.left, box.top), rotationDeg);
    final b = uprightNormToSensorNorm(
        EyePoint(box.right, box.bottom), rotationDeg);
    return Rect.fromLTRB(
      math.min(a.x, b.x),
      math.min(a.y, b.y),
      math.max(a.x, b.x),
      math.max(a.y, b.y),
    );
  }

  /// Normalized eye-region rect around [center] with side [fraction] of the
  /// frame, clamped to [0,1]. Used for analyzer crop boxes in raw image
  /// space (NOT for JPEG stills, which the camera plugin already rotates).
  static Rect eyeRegion(EyePoint center, double fraction) {
    final h = fraction / 2;
    final l = (center.x - h).clamp(0.0, 1.0);
    final t = (center.y - h).clamp(0.0, 1.0);
    final r = (center.x + h).clamp(0.0, 1.0);
    final b = (center.y + h).clamp(0.0, 1.0);
    return Rect.fromLTRB(l, t, r, b);
  }

  /// Sample luminance stats from a Y (grayscale) plane with row stride.
  /// Pure function: unit-tested with synthetic planes.
  static FrameQuality sampleYPlane(
      List<int> yBytes, int width, int height, int bytesPerRow) {
    if (yBytes.isEmpty || width <= 0 || height <= 0 || bytesPerRow <= 0) {
      return const FrameQuality.unknown();
    }
    const stride = 16;
    double sum = 0;
    int over = 0, count = 0;
    for (int y = 0; y < height; y += stride) {
      final row = y * bytesPerRow;
      for (int x = 0; x < width; x += stride) {
        final o = row + x;
        if (o >= yBytes.length) break;
        final v = yBytes[o].toDouble();
        sum += v;
        if (v > 240) over++;
        count++;
      }
    }
    if (count == 0) return const FrameQuality.unknown();
    final mean = sum / count;
    // Coarse Laplacian variance for blur on an 8-stride grid.
    const b = 8;
    final gw = (width / b).floor();
    final gh = (height / b).floor();
    double lapSum = 0, lapSq = 0;
    int lapN = 0;
    double at(int gx, int gy) {
      final o = (gy * b) * bytesPerRow + gx * b;
      if (o < 0 || o >= yBytes.length) return mean;
      return yBytes[o].toDouble();
    }

    for (int gy = 1; gy < gh - 1; gy++) {
      for (int gx = 1; gx < gw - 1; gx++) {
        final lap = 4 * at(gx, gy) -
            at(gx - 1, gy) -
            at(gx + 1, gy) -
            at(gx, gy - 1) -
            at(gx, gy + 1);
        lapSum += lap;
        lapSq += lap * lap;
        lapN++;
      }
    }
    double variance = 0;
    if (lapN > 0) {
      final m = lapSum / lapN;
      variance = (lapSq / lapN - m * m).clamp(0.0, double.infinity);
    }
    return FrameQuality(
      meanLuminance: mean,
      blurVariance: variance,
      overexposedFraction: over / count,
      width: width,
      height: height,
    );
  }
}
