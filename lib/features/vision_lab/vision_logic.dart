// Vision Lab shared logic: optotypes, acuity levels, color/contrast sets.
// All tests are interactive and randomized; no zoom allowed (handled in UI).

import 'dart:math';

class Optotype {
  final String symbol; // E, C, letters
  final int rotationDeg; // for tumbling-E: 0/90/180/270
  const Optotype(this.symbol, this.rotationDeg);
}

class AcuityLevel {
  final String label; // e.g. 6/60
  final double logMAR;
  final double letterSizeArcMin;
  const AcuityLevel(this.label, this.logMAR, this.letterSizeArcMin);
}

// Standard-ish progression (screening, not a certified chart).
const List<AcuityLevel> acuityLevels = [
  AcuityLevel('6/60', 1.0, 50),
  AcuityLevel('6/36', 0.78, 30),
  AcuityLevel('6/24', 0.6, 20),
  AcuityLevel('6/18', 0.48, 15),
  AcuityLevel('6/12', 0.3, 10),
  AcuityLevel('6/9', 0.18, 7.5),
  AcuityLevel('6/6', 0.0, 5),
  AcuityLevel('6/5', -0.08, 4),
];

/// Protocol version stamped on vision-test measurement traces (§9).
const String kVisionProtocolVersion = 'vision-v1';

class VisionLogic {
  static final Random _r = Random();

  static List<Optotype> randomizedOptotypes(int count) {
    const symbols = ['E', 'C', 'F', 'P', 'T', 'O', 'Z'];
    return List.generate(count, (_) {
      final s = symbols[_r.nextInt(symbols.length)];
      final rot = [0, 90, 180, 270][_r.nextInt(4)];
      return Optotype(s, rot);
    });
  }

  /// Forced-choice direction optotypes: tumbling-E/C ONLY, where rotation
  /// is the answer (up/right/down/left limbs). Other letters have no
  /// meaningful rotation, so a direction task must never use them.
  static List<Optotype> directionOptotypes(int count) {
    const symbols = ['E', 'C'];
    return List.generate(count, (_) {
      final s = symbols[_r.nextInt(symbols.length)];
      final rot = [0, 90, 180, 270][_r.nextInt(4)];
      return Optotype(s, rot);
    });
  }

  /// Displayed limb direction for a rotation, given that an unrotated
  /// E/C points RIGHT and RotatedBox turns CLOCKWISE:
  /// 0 → right, 90 → down, 180 → left, 270 → up. Unknown rotations
  /// return '?' (never guessed).
  static String directionArrow(int rotationDeg) {
    switch (((rotationDeg % 360) + 360) % 360) {
      case 0:
        return '→';
      case 90:
        return '↓';
      case 180:
        return '←';
      case 270:
        return '↑';
      default:
        return '?';
    }
  }

  /// Next-level rule: 3/5 correct to pass a level (conservative).
  static bool levelPassed(int correct, int shown) => correct * 5 >= shown * 3;

  // --- Color vision: generated (non-copyrighted) confusion-axis triplets.
  // Each plate: target digit-shape vs background along protan/deutan/tritan axes.
  static Map<String, dynamic> colorPlate(int index) {
    // Deterministic pseudo-plate set (12 plates + 1 demo).
    const axes = ['protan', 'deutan', 'tritan', 'protan', 'deutan', 'tritan', 'protan', 'deutan', 'tritan', 'protan', 'deutan', 'tritan'];
    const answers = ['7', '3', '5', '2', '8', '6', '4', '9', '1', '7', '3', '5'];
    final axis = axes[index % axes.length];
    final answer = answers[index % answers.length];
    return {'axis': axis, 'answer': answer, 'plate': index};
  }

  // --- Contrast: Weber fractions descending.
  static const List<double> contrastSteps = [0.9, 0.6, 0.4, 0.25, 0.15, 0.08, 0.04, 0.02];

  // --- Peripheral field: 8 regions.
  static const List<String> fieldRegions = [
    'upper', 'upper-right', 'right', 'lower-right',
    'lower', 'lower-left', 'left', 'upper-left',
  ];

  /// Refractive-error screening is EXPERIMENTAL: only a likelihood flag.
  static String refractiveFlag(double distanceAcuityLogMAR, double nearAcuityLogMAR) {
    if (distanceAcuityLogMAR >= 0.3 && nearAcuityLogMAR <= 0.2) {
      return 'Results are consistent with possible distance refractive error. This is screening only, not a prescription.';
    }
    if (distanceAcuityLogMAR >= 0.3 && nearAcuityLogMAR >= 0.3) {
      return 'Distance and near results are both reduced; many causes are possible. Consider a full eye examination.';
    }
    return 'No specific refractive pattern suggested by this screening.';
  }
}

/// Adaptive staircase for threshold estimation (v0.4 acuity/contrast):
/// 1-down-1-up with reversal counting. Correct → one step finer;
/// wrong → one step coarser. Stops after [maxReversals] reversals or
/// [maxTrials] trials. Threshold = rounded mean of the last up-to-4
/// reversal levels. Pure logic — fully unit-tested, no UI.
class Staircase {
  int level;
  final int min;
  final int max;
  final int maxReversals;
  final int maxTrials;
  int reversals = 0;
  int? _lastDir;
  final List<int> reversalLevels = [];
  final List<(int level, bool correct)> history = [];

  Staircase({
    required this.level,
    this.min = 0,
    required this.max,
    this.maxReversals = 6,
    this.maxTrials = 24,
  });

  /// Record one trial response; advances the level.
  void respond(bool correct) {
    history.add((level, correct));
    final dir = correct ? 1 : -1;
    if (_lastDir != null && dir != _lastDir) {
      reversals++;
      reversalLevels.add(level);
    }
    _lastDir = dir;
    level = (level + dir).clamp(min, max);
  }

  bool get done =>
      reversals >= maxReversals || history.length >= maxTrials;

  /// Estimated threshold level index.
  int get threshold {
    if (reversalLevels.isEmpty) return level;
    final tail = reversalLevels.sublist(
        reversalLevels.length - (reversalLevels.length < 4 ? reversalLevels.length : 4));
    final sum = tail.fold<int>(0, (a, b) => a + b);
    return (sum / tail.length).round().clamp(min, max);
  }

  /// Compact research readout: "L3✓ L4✓ L5✗ ..." for the staircase card.
  String get sequence => history
      .map((h) => 'L${h.$1}${h.$2 ? '✓' : '✗'}')
      .join(' ');
}

/// Credit-card on-screen calibration (ISO/IEC 7810 ID-1: 85.60 x 53.98 mm).
///
/// The user resizes an on-screen box until it exactly covers a real card
/// held against the display. Pixels-per-mm then converts arc minutes at
/// ANY viewing distance into true logical pixels — no display DPI needed,
/// and immune to devices that misreport xdpi/ydpi. Pure logic, tested.
class CardCalibration {
  /// Standard ID-1 card width in mm.
  static const double cardWidthMm = 85.60;

  /// Standard ID-1 card height in mm.
  static const double cardHeightMm = 53.98;

  /// Logical pixels per mm from a user-matched box width. Returns -1
  /// when the box width is not positive (never divide by zero / garbage).
  static double pxPerMm(double boxLogicalPx, {double cardMm = cardWidthMm}) {
    if (!boxLogicalPx.isFinite ||
        !cardMm.isFinite ||
        boxLogicalPx <= 0 ||
        cardMm <= 0) {
      return -1;
    }
    return boxLogicalPx / cardMm;
  }

  /// Letter height in mm for [arcMin] arc minutes at [distanceMm].
  /// Returns -1 on invalid input.
  static double mmForArcMin(double arcMin, double distanceMm) {
    if (!arcMin.isFinite ||
        !distanceMm.isFinite ||
        arcMin <= 0 ||
        distanceMm <= 0) {
      return -1;
    }
    return 2 * distanceMm * tan((arcMin / 60) * pi / 180 / 2);
  }

  /// Logical-pixel letter height from a calibrated px-per-mm. Returns -1
  /// on invalid input.
  static double logicalPxForMm(double mm, double pxPerMm) {
    if (!mm.isFinite ||
        !pxPerMm.isFinite ||
        mm <= 0 ||
        pxPerMm <= 0) {
      return -1;
    }
    return mm * pxPerMm;
  }
}

/// Seeded Fisher-Yates shuffle so randomized orders are reproducible and
/// recorded with the result (seed stored in the measurement string).
List<T> seededShuffle<T>(List<T> items, int seed) {
  final r = Random(seed);
  final out = List<T>.of(items);
  for (var i = out.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}
