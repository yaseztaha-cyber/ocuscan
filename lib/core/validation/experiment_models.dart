// Validation experiment models (v0.2 — measurement validation platform).
//
// These models describe RESEARCH CONDITIONS and MEASUREMENTS, never diagnoses.
// An Experiment groups repeated Trials of one measurement type under recorded
// conditions (device, lighting, distance, head angle, anonymous subject id).
// Statistics are computed from actually collected trials only — nothing here
// invents data.

/// Status of a single recorded trial.
enum TrialStatus {
  /// A numeric measurement was produced under acceptable quality.
  accepted,
  /// QualityGate rejected the capture before measurement.
  rejected,
  /// The analyzer reported unable-to-assess.
  unable,
}

extension TrialStatusX on TrialStatus {
  String get code {
    switch (this) {
      case TrialStatus.accepted:
        return 'accepted';
      case TrialStatus.rejected:
        return 'rejected';
      case TrialStatus.unable:
        return 'unable';
    }
  }

  static TrialStatus fromCode(String code) {
    switch (code) {
      case 'rejected':
        return TrialStatus.rejected;
      case 'unable':
        return TrialStatus.unable;
      default:
        return TrialStatus.accepted;
    }
  }
}

/// Categorized QualityGate rejection reasons for failure analysis.
enum QualityFailureCode {
  lowIllumination,
  overexposure,
  blur,
  lowResolution,
  badFaceGeometry,
  eyeNotVisible,
  other,
}

extension QualityFailureCodeX on QualityFailureCode {
  String get code {
    switch (this) {
      case QualityFailureCode.lowIllumination:
        return 'LOW_ILLUMINATION';
      case QualityFailureCode.overexposure:
        return 'OVEREXPOSURE';
      case QualityFailureCode.blur:
        return 'BLUR';
      case QualityFailureCode.lowResolution:
        return 'LOW_RESOLUTION';
      case QualityFailureCode.badFaceGeometry:
        return 'BAD_FACE_GEOMETRY';
      case QualityFailureCode.eyeNotVisible:
        return 'EYE_NOT_VISIBLE';
      case QualityFailureCode.other:
        return 'OTHER';
    }
  }

  static QualityFailureCode fromCode(String code) {
    switch (code) {
      case 'LOW_ILLUMINATION':
        return QualityFailureCode.lowIllumination;
      case 'OVEREXPOSURE':
        return QualityFailureCode.overexposure;
      case 'BLUR':
        return QualityFailureCode.blur;
      case 'LOW_RESOLUTION':
        return QualityFailureCode.lowResolution;
      case 'BAD_FACE_GEOMETRY':
        return QualityFailureCode.badFaceGeometry;
      case 'EYE_NOT_VISIBLE':
        return QualityFailureCode.eyeNotVisible;
      default:
        return QualityFailureCode.other;
    }
  }
}

/// Configured lighting levels for experiments. These are experiment labels,
/// not medical or photometric standards. A manually entered lux reading from
/// a real light meter may accompany any level.
/// Optional fairness/robustness dimensions for research experiments.
/// All values are researcher-entered labels (or null when unspecified),
/// stored locally only. Unevaluated groups are reported as "Not evaluated".
class FairnessDimensions {
  static const List<String> skinTones = [
    'I', 'II', 'III', 'IV', 'V', 'VI',
  ];
  static const List<String> eyeColors = [
    'light', 'medium', 'dark',
  ];
  static const List<String> eyewear = [
    'none', 'glasses', 'contact_lenses',
  ];
  static const List<String> ageGroups = [
    'child', 'adult', 'older_adult',
  ];

  static bool isKnownList(String key) =>
      key == 'skinTone' ||
      key == 'eyeColor' ||
      key == 'eyewear' ||
      key == 'ageGroup';
}

class LightingLevels {  static const List<String> all = [
    'very_low',
    'low',
    'moderate',
    'bright',
    'very_bright',
    'controlled',
  ];

  static bool isKnown(String v) => all.contains(v);
}

/// A research experiment: repeated trials of one measurement type under
/// documented conditions. No personal identity — subjectId is anonymous
/// (R001, R002, ...) and deviceLabel is anonymous (Device A, B, C...).
class Experiment {
  final int? id;
  final String name;
  final String description;
  final String testType; // AnalyzerRegistry key, e.g. 'pupil', 'va_distance'
  final String deviceLabel;
  final String camera; // 'front' | 'rear'
  final double? targetDistanceCm; // configured test distance (not clinical standard)
  final String? distanceNote;
  final String lightingLevel; // LightingLevels code
  final double? lux; // manual meter reading, when available
  final double? screenBrightness; // 0..1 where available
  final double? headAngleDeg; // configured head-angle step
  final String subjectId; // anonymous research id
  final String environmentalNotes;
  final String operatorNotes;
  final String analyzerVersion; // e.g. 'pupil v1'
  final DateTime createdAt;
  // Optional fairness dimensions (null = unspecified). Local-only labels.
  final String? skinTone;
  final String? eyeColor;
  final String? eyewear;
  final String? ageGroup;

  const Experiment({
    this.id,
    required this.name,
    this.description = '',
    required this.testType,
    required this.deviceLabel,
    this.camera = 'front',
    this.targetDistanceCm,
    this.distanceNote,
    this.lightingLevel = 'controlled',
    this.lux,
    this.screenBrightness,
    this.headAngleDeg,
    required this.subjectId,
    this.environmentalNotes = '',
    this.operatorNotes = '',
    required this.analyzerVersion,
    required this.createdAt,
    this.skinTone,
    this.eyeColor,
    this.eyewear,
    this.ageGroup,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'testType': testType,
        'deviceLabel': deviceLabel,
        'camera': camera,
        'targetDistanceCm': targetDistanceCm,
        'distanceNote': distanceNote,
        'lightingLevel': lightingLevel,
        'lux': lux,
        'screenBrightness': screenBrightness,
        'headAngleDeg': headAngleDeg,
        'subjectId': subjectId,
        'environmentalNotes': environmentalNotes,
        'operatorNotes': operatorNotes,
        'analyzerVersion': analyzerVersion,
        'createdAt': createdAt.toIso8601String(),
        'skinTone': skinTone,
        'eyeColor': eyeColor,
        'eyewear': eyewear,
        'ageGroup': ageGroup,
      };

  factory Experiment.fromMap(Map<String, dynamic> m) => Experiment(
        id: m['id'] as int?,
        name: (m['name'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        testType: (m['testType'] ?? '') as String,
        deviceLabel: (m['deviceLabel'] ?? '') as String,
        camera: (m['camera'] ?? 'front') as String,
        targetDistanceCm: (m['targetDistanceCm'] as num?)?.toDouble(),
        distanceNote: m['distanceNote'] as String?,
        lightingLevel: (m['lightingLevel'] ?? 'controlled') as String,
        lux: (m['lux'] as num?)?.toDouble(),
        screenBrightness: (m['screenBrightness'] as num?)?.toDouble(),
        headAngleDeg: (m['headAngleDeg'] as num?)?.toDouble(),
        subjectId: (m['subjectId'] ?? '') as String,
        environmentalNotes: (m['environmentalNotes'] ?? '') as String,
        operatorNotes: (m['operatorNotes'] ?? '') as String,
        analyzerVersion: (m['analyzerVersion'] ?? '') as String,
        createdAt: DateTime.tryParse((m['createdAt'] ?? '') as String) ??
            DateTime.now(),
        skinTone: m['skinTone'] as String?,
        eyeColor: m['eyeColor'] as String?,
        eyewear: m['eyewear'] as String?,
        ageGroup: m['ageGroup'] as String?,
      );

  Experiment copyWith({int? id}) => Experiment(
        id: id ?? this.id,
        name: name,
        description: description,
        testType: testType,
        deviceLabel: deviceLabel,
        camera: camera,
        targetDistanceCm: targetDistanceCm,
        distanceNote: distanceNote,
        lightingLevel: lightingLevel,
        lux: lux,
        screenBrightness: screenBrightness,
        headAngleDeg: headAngleDeg,
        subjectId: subjectId,
        environmentalNotes: environmentalNotes,
        operatorNotes: operatorNotes,
        analyzerVersion: analyzerVersion,
        createdAt: createdAt,
        skinTone: skinTone,
        eyeColor: eyeColor,
        eyewear: eyewear,
        ageGroup: ageGroup,
      );
}

/// One recorded trial within an experiment.
class Trial {
  final int? id;
  final int experimentId;
  final DateTime timestamp;
  final String inputQuality; // high | medium | low
  final double? value; // numeric measurement, when produced
  final String unit;
  final String measurementLabel; // human-readable measurement text
  final String confidence; // low | moderate | high
  final TrialStatus status;
  final String? failureReason; // QualityFailureCode code or free text
  final double? referenceValue; // manually entered reference, when available
  final String? referenceMethod; // how the reference was obtained (free text)
  // Condition snapshot (denormalized from the experiment for export/grouping).
  final String? lightingLevel;
  final double? lux;
  final double? distanceCm;
  final double? headAngleDeg;
  final String? deviceLabel;
  final String? subjectId;
  final String? testType;
  final String notes;
  final bool hasCapture; // research image stored locally (never exported)
  final double? luminance;
  final double? sharpness;
  final double? exposureBadFraction;

  const Trial({
    this.id,
    required this.experimentId,
    required this.timestamp,
    required this.inputQuality,
    this.value,
    this.unit = '',
    this.measurementLabel = '',
    this.confidence = 'low',
    required this.status,
    this.failureReason,
    this.referenceValue,
    this.referenceMethod,
    this.lightingLevel,
    this.lux,
    this.distanceCm,
    this.headAngleDeg,
    this.deviceLabel,
    this.subjectId,
    this.testType,
    this.notes = '',
    this.hasCapture = false,
    this.luminance,
    this.sharpness,
    this.exposureBadFraction,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'experimentId': experimentId,
        'timestamp': timestamp.toIso8601String(),
        'inputQuality': inputQuality,
        'value': value,
        'unit': unit,
        'measurementLabel': measurementLabel,
        'confidence': confidence,
        'status': status.code,
        'failureReason': failureReason,
        'referenceValue': referenceValue,
        'referenceMethod': referenceMethod,
        'lightingLevel': lightingLevel,
        'lux': lux,
        'distanceCm': distanceCm,
        'headAngleDeg': headAngleDeg,
        'deviceLabel': deviceLabel,
        'subjectId': subjectId,
        'testType': testType,
        'notes': notes,
        'hasCapture': hasCapture ? 1 : 0,
        'luminance': luminance,
        'sharpness': sharpness,
        'exposureBadFraction': exposureBadFraction,
      };

  factory Trial.fromMap(Map<String, dynamic> m) => Trial(        id: m['id'] as int?,
        experimentId: (m['experimentId'] ?? 0) as int,
        timestamp: DateTime.tryParse((m['timestamp'] ?? '') as String) ??
            DateTime.now(),
        inputQuality: (m['inputQuality'] ?? '') as String,
        value: (m['value'] as num?)?.toDouble(),
        unit: (m['unit'] ?? '') as String,
        measurementLabel: (m['measurementLabel'] ?? '') as String,
        confidence: (m['confidence'] ?? 'low') as String,
        status: TrialStatusX.fromCode((m['status'] ?? 'accepted') as String),
        failureReason: m['failureReason'] as String?,
        referenceValue: (m['referenceValue'] as num?)?.toDouble(),
        referenceMethod: m['referenceMethod'] as String?,
        lightingLevel: m['lightingLevel'] as String?,
        lux: (m['lux'] as num?)?.toDouble(),
        distanceCm: (m['distanceCm'] as num?)?.toDouble(),
        headAngleDeg: (m['headAngleDeg'] as num?)?.toDouble(),
        deviceLabel: m['deviceLabel'] as String?,
        subjectId: m['subjectId'] as String?,
        testType: m['testType'] as String?,
        notes: (m['notes'] ?? '') as String,
        hasCapture: (m['hasCapture'] ?? 0) as int == 1,
        luminance: (m['luminance'] as num?)?.toDouble(),
        sharpness: (m['sharpness'] as num?)?.toDouble(),
        exposureBadFraction:
            (m['exposureBadFraction'] as num?)?.toDouble(),
      );

  Trial copyWith({int? id, bool? hasCapture, String? notes}) => Trial(
        id: id ?? this.id,
        experimentId: experimentId,
        timestamp: timestamp,
        inputQuality: inputQuality,
        value: value,
        unit: unit,
        measurementLabel: measurementLabel,
        confidence: confidence,
        status: status,
        failureReason: failureReason,
        referenceValue: referenceValue,
        referenceMethod: referenceMethod,
        lightingLevel: lightingLevel,
        lux: lux,
        distanceCm: distanceCm,
        headAngleDeg: headAngleDeg,
        deviceLabel: deviceLabel,
        subjectId: subjectId,
        testType: testType,
        notes: notes ?? this.notes,
        hasCapture: hasCapture ?? this.hasCapture,
        luminance: luminance,
        sharpness: sharpness,
        exposureBadFraction: exposureBadFraction,
      );
}

/// Future-ready reference label for labelled datasets (interface only).
/// No dataset is bundled, downloaded, or fabricated. Rows are created only
/// when a researcher documents a real evaluated reference.
class ReferenceLabel {
  final int? id;
  final String datasetId;
  final String sampleId;
  final String testType;
  final String referenceFinding;
  final String referenceMethod;
  final String source;

  const ReferenceLabel({
    this.id,
    required this.datasetId,
    required this.sampleId,
    required this.testType,
    required this.referenceFinding,
    required this.referenceMethod,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'datasetId': datasetId,
        'sampleId': sampleId,
        'testType': testType,
        'referenceFinding': referenceFinding,
        'referenceMethod': referenceMethod,
        'source': source,
      };

  factory ReferenceLabel.fromMap(Map<String, dynamic> m) => ReferenceLabel(
        id: m['id'] as int?,
        datasetId: (m['datasetId'] ?? '') as String,
        sampleId: (m['sampleId'] ?? '') as String,
        testType: (m['testType'] ?? '') as String,
        referenceFinding: (m['referenceFinding'] ?? '') as String,
        referenceMethod: (m['referenceMethod'] ?? '') as String,
        source: (m['source'] ?? '') as String,
      );
}

/// Anonymous device profile recorded for a research session.
/// Describes the instrument, never the person.
class DeviceProfile {
  final String deviceLabel; // anonymous: Device A, B, C...
  final String? manufacturer;
  final String? model;
  final String? osVersion;
  final String? runtimeVersion; // Dart runtime version string
  final String? camera;
  final String? resolution;
  final String? orientation;
  final int? screenWidthPx;
  final int? screenHeightPx;

  const DeviceProfile({
    required this.deviceLabel,
    this.manufacturer,
    this.model,
    this.osVersion,
    this.runtimeVersion,
    this.camera,
    this.resolution,
    this.orientation,
    this.screenWidthPx,
    this.screenHeightPx,
  });

  Map<String, dynamic> toMap() => {
        'deviceLabel': deviceLabel,
        'manufacturer': manufacturer,
        'model': model,
        'osVersion': osVersion,
        'runtimeVersion': runtimeVersion,
        'camera': camera,
        'resolution': resolution,
        'orientation': orientation,
        'screenWidthPx': screenWidthPx,
        'screenHeightPx': screenHeightPx,
      };

  factory DeviceProfile.fromMap(Map<String, dynamic> m) => DeviceProfile(
        deviceLabel: (m['deviceLabel'] ?? '') as String,
        manufacturer: m['manufacturer'] as String?,
        model: m['model'] as String?,
        osVersion: m['osVersion'] as String?,
        runtimeVersion: m['runtimeVersion'] as String?,
        camera: m['camera'] as String?,
        resolution: m['resolution'] as String?,
        orientation: m['orientation'] as String?,
        screenWidthPx: (m['screenWidthPx'] as num?)?.toInt(),
        screenHeightPx: (m['screenHeightPx'] as num?)?.toInt(),
      );
}

// ---------------------------------------------------------------------------
// Categorical agreement (Cohen's kappa, pure Dart).
//
// Compares two raters over the categorical outcomes
// accepted / rejected / unable (TrialStatus). All inputs are real paired
// ratings supplied by the caller — nothing here invents a second rating.
// A Trial on its own carries only ONE categorical outcome (status); its
// manual reference is a numeric referenceValue with no reference category,
// so kappa is NOT derivable from Trial.referenceValue presence.
//
//   n < minPairsForKappa (10)  -> band 'insufficient-data'
//   degenerate margin (Pe == 1, e.g. single-category data) -> kappa is NaN
//     and band is 'insufficient-data' (division by 1 - Pe is undefined).
// ---------------------------------------------------------------------------

/// Minimum paired ratings required before a kappa value is interpretable.
/// Below this, [kappaBand] returns 'insufficient-data' even when kappa is
/// numerically computable.
const int minPairsForKappa = 10;

/// Result of Cohen's kappa over paired categorical ratings.
class CategoricalAgreement {
  /// Number of paired ratings.
  final int n;

  /// Fraction of pairs where both raters chose the same category.
  final double observedAgreement;

  /// Chance-expected agreement from the observed marginals.
  final double expectedAgreement;

  /// (Po - Pe) / (1 - Pe). NaN when the margin is degenerate (Pe == 1).
  final double kappa;

  /// True when Pe == 1 (e.g. every rating falls in one category), so kappa
  /// is undefined.
  final bool degenerate;

  const CategoricalAgreement({
    required this.n,
    required this.observedAgreement,
    required this.expectedAgreement,
    required this.kappa,
    required this.degenerate,
  });

  /// True when kappa should not be interpreted (caller shows raw counts).
  bool get insufficientData => n < minPairsForKappa || degenerate;

  /// Guarded Landis-Koch-style band, or 'insufficient-data'.
  String get band =>
      kappaBand(kappa, n, degenerate: degenerate);
}

int _trialStatusIndex(TrialStatus s) {
  switch (s) {
    case TrialStatus.accepted:
      return 0;
    case TrialStatus.rejected:
      return 1;
    case TrialStatus.unable:
      return 2;
  }
}

/// Cohen's kappa for two raters over accepted/rejected/unable.
///
/// Returns null when there are no pairs. Throws [ArgumentError] when the
/// two lists differ in length. Pure: no I/O, no invented ratings.
CategoricalAgreement? cohensKappa(
  List<TrialStatus> raterA,
  List<TrialStatus> raterB,
) {
  if (raterA.length != raterB.length) {
    throw ArgumentError(
        'cohensKappa: rater lists differ in length '
        '(${raterA.length} vs ${raterB.length})');
  }
  final n = raterA.length;
  if (n == 0) return null;
  final rowCounts = List<int>.filled(3, 0);
  final colCounts = List<int>.filled(3, 0);
  var agree = 0;
  for (var i = 0; i < n; i++) {
    final a = _trialStatusIndex(raterA[i]);
    final b = _trialStatusIndex(raterB[i]);
    rowCounts[a]++;
    colCounts[b]++;
    if (a == b) agree++;
  }
  final observedAgreement = agree / n;
  double expectedAgreement = 0;
  for (var k = 0; k < 3; k++) {
    expectedAgreement += (rowCounts[k] / n) * (colCounts[k] / n);
  }
  final denom = 1.0 - expectedAgreement;
  if (denom.abs() < 1e-12) {
    return CategoricalAgreement(
      n: n,
      observedAgreement: observedAgreement,
      expectedAgreement: expectedAgreement,
      kappa: double.nan,
      degenerate: true,
    );
  }
  final kappa = (observedAgreement - expectedAgreement) / denom;
  return CategoricalAgreement(
    n: n,
    observedAgreement: observedAgreement,
    expectedAgreement: expectedAgreement,
    kappa: kappa,
    degenerate: false,
  );
}

/// Guarded interpretation band for a kappa value.
///
/// Returns exactly one of:
/// 'poor' | 'slight' | 'fair' | 'moderate' | 'substantial' |
/// 'almost-perfect' | 'insufficient-data'.
///
/// 'insufficient-data' is returned when [n] < [minPairsForKappa], when
/// [degenerate] is true, or when [kappa] is NaN. Thresholds follow the
/// Landis-Koch convention: <0 poor, 0-0.20 slight, 0.21-0.40 fair,
/// 0.41-0.60 moderate, 0.61-0.80 substantial, 0.81-1.00 almost-perfect.
String kappaBand(double kappa, int n, {bool degenerate = false}) {
  if (n < minPairsForKappa) return 'insufficient-data';
  if (degenerate) return 'insufficient-data';
  if (kappa.isNaN) return 'insufficient-data';
  if (kappa < 0) return 'poor';
  if (kappa <= 0.20) return 'slight';
  if (kappa <= 0.40) return 'fair';
  if (kappa <= 0.60) return 'moderate';
  if (kappa <= 0.80) return 'substantial';
  return 'almost-perfect';
}

// ---------------------------------------------------------------------------
// Observed outcome mix (pure): counts + rates of TrialStatus values actually
// recorded. Shown when kappa is inapplicable because Trial carries only one
// categorical rating (status) and no second categorical reference rating.
// ---------------------------------------------------------------------------

/// Counts and rates of observed trial statuses. Rates are null when empty.
class TrialStatusDistribution {
  final int total;
  final int accepted;
  final int rejected;
  final int unable;

  const TrialStatusDistribution({
    required this.total,
    required this.accepted,
    required this.rejected,
    required this.unable,
  });

  double? get acceptedRate => total <= 0 ? null : accepted / total;
  double? get rejectedRate => total <= 0 ? null : rejected / total;
  double? get unableRateValue => total <= 0 ? null : unable / total;
}

/// Summarizes raw status values. Pure; empty input yields zero counts.
TrialStatusDistribution summarizeStatuses(Iterable<TrialStatus> statuses) {
  var accepted = 0;
  var rejected = 0;
  var unable = 0;
  var total = 0;
  for (final s in statuses) {
    total++;
    switch (s) {
      case TrialStatus.accepted:
        accepted++;
        break;
      case TrialStatus.rejected:
        rejected++;
        break;
      case TrialStatus.unable:
        unable++;
        break;
    }
  }
  return TrialStatusDistribution(
    total: total,
    accepted: accepted,
    rejected: rejected,
    unable: unable,
  );
}

/// Convenience wrapper over loaded trials (maps each trial to its status).
TrialStatusDistribution summarizeTrialStatuses(List<Trial> trials) =>
    summarizeStatuses(trials.map((t) => t.status));
