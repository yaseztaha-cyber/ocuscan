// ScreeningResult — structured, diagnosis-free result model.
// Every test MUST populate this shape: measurement, quality, confidence,
// finding category, limitations, and recommended action.

enum ResultCategory {
  noObviousAbnormality,
  possibleFinding,
  unableToAssess,
}

extension ResultCategoryX on ResultCategory {
  String get code {
    switch (this) {
      case ResultCategory.noObviousAbnormality:
        return 'no_obvious_abnormality';
      case ResultCategory.possibleFinding:
        return 'possible_finding';
      case ResultCategory.unableToAssess:
        return 'unable_to_assess';
    }
  }

  static ResultCategory fromCode(String code) {
    switch (code) {
      case 'possible_finding':
        return ResultCategory.possibleFinding;
      case 'unable_to_assess':
        return ResultCategory.unableToAssess;
      default:
        return ResultCategory.noObviousAbnormality;
    }
  }
}

enum ImageQuality { high, medium, low }

extension ImageQualityX on ImageQuality {
  String get code => name;
  static ImageQuality fromCode(String code) {
    switch (code) {
      case 'medium':
        return ImageQuality.medium;
      case 'low':
        return ImageQuality.low;
      default:
        return ImageQuality.high;
    }
  }
}

enum Confidence { low, moderate, high }

extension ConfidenceX on Confidence {
  String get code => name;
  static Confidence fromCode(String code) {
    switch (code) {
      case 'high':
        return Confidence.high;
      case 'moderate':
        return Confidence.moderate;
      default:
        return Confidence.low;
    }
  }
}

class ScreeningResult {
  final String testName;
  final String measurement;
  final String measurementUnit;
  final ImageQuality imageQuality;
  final Confidence confidence;
  final ResultCategory finding;
  final String findingLabel;
  final List<String> possibleAssociations;
  final List<String> limitations;
  final String recommendedAction;
  final String whyFlagged;
  final DateTime timestamp;
  final Map<String, double> rawMetrics;

  /// v0.5 traceability (§49–50, §85): every result carries what produced
  /// it. All optional with empty defaults so older rows and existing
  /// constructions keep working; empty means "not recorded by that
  /// build" — never invented.
  final String uncertainty;
  final String hardware;
  final String deviceLabel;
  final String algorithmVersion;
  final String evidenceVersion;

  /// Local person profile this row belongs to ('self' default).
  /// Multi-person support is on-device only: profiles are local labels,
  /// never identities, never uploaded.
  final String profileId;

  /// Explicit eye token ('right', 'left', 'both') recorded at persist
  /// time. Empty means unspecified (old rows) — trends fall back to
  /// text parsing and stay fail-closed. Never backfilled.
  final String eye;

  /// Whether conditions were verified at persist time (operator
  /// checklist). False covers both old rows AND new unverified rows —
  /// trends treat false as unverified, never as verified.
  final bool conditionsVerified;

  /// Measurement trace (§9): which model + engine + protocol produced
  /// this row. Empty means "not recorded by that build" — never invented.
  /// modelHash stays empty until a retrievable digest exists.
  final String modelVersion;
  final String modelHash;
  final String protocolVersion;
  final String engine;

  const ScreeningResult({
    required this.testName,
    required this.measurement,
    required this.measurementUnit,
    required this.imageQuality,
    required this.confidence,
    required this.finding,
    required this.findingLabel,
    required this.possibleAssociations,
    required this.limitations,
    required this.recommendedAction,
    required this.whyFlagged,
    required this.timestamp,
    this.rawMetrics = const {},
    this.uncertainty = '',
    this.hardware = '',
    this.deviceLabel = '',
    this.algorithmVersion = '',
    this.evidenceVersion = '',
    this.profileId = 'self',
    this.eye = '',
    this.conditionsVerified = false,
    this.modelVersion = '',
    this.modelHash = '',
    this.protocolVersion = '',
    this.engine = '',
  });

  ScreeningResult copyWith({
    String? measurement,
    String? uncertainty,
    String? hardware,
    String? deviceLabel,
    String? algorithmVersion,
    String? evidenceVersion,
    String? profileId,
    String? eye,
    bool? conditionsVerified,
    String? modelVersion,
    String? modelHash,
    String? protocolVersion,
    String? engine,
  }) {
    return ScreeningResult(
      testName: testName,
      measurement: measurement ?? this.measurement,
      measurementUnit: measurementUnit,
      imageQuality: imageQuality,
      confidence: confidence,
      finding: finding,
      findingLabel: findingLabel,
      possibleAssociations: possibleAssociations,
      limitations: limitations,
      recommendedAction: recommendedAction,
      whyFlagged: whyFlagged,
      timestamp: timestamp,
      rawMetrics: rawMetrics,
      uncertainty: uncertainty ?? this.uncertainty,
      hardware: hardware ?? this.hardware,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      evidenceVersion: evidenceVersion ?? this.evidenceVersion,
      profileId: profileId ?? this.profileId,
      eye: eye ?? this.eye,
      conditionsVerified:
          conditionsVerified ?? this.conditionsVerified,
      modelVersion: modelVersion ?? this.modelVersion,
      modelHash: modelHash ?? this.modelHash,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      engine: engine ?? this.engine,
    );
  }

  Map<String, dynamic> toMap() => {
        'testName': testName,
        'measurement': measurement,
        'measurementUnit': measurementUnit,
        'imageQuality': imageQuality.code,
        'confidence': confidence.code,
        'finding': finding.code,
        'findingLabel': findingLabel,
        'possibleAssociations': possibleAssociations.join('|'),
        'limitations': limitations.join('|'),
        'recommendedAction': recommendedAction,
        'whyFlagged': whyFlagged,
        'timestamp': timestamp.toIso8601String(),
        'uncertainty': uncertainty,
        'hardware': hardware,
        'deviceLabel': deviceLabel,
        'algorithmVersion': algorithmVersion,
        'evidenceVersion': evidenceVersion,
        'profileId': profileId,
        'eye': eye,
        'conditionsVerified': conditionsVerified ? 1 : 0,
        'modelVersion': modelVersion,
        'modelHash': modelHash,
        'protocolVersion': protocolVersion,
        'engine': engine,
      };

  factory ScreeningResult.fromMap(Map<String, dynamic> m) {
    List<String> split(String? s) =>
        (s == null || s.isEmpty) ? const [] : s.split('|');
    return ScreeningResult(
      testName: m['testName'] as String,
      measurement: m['measurement'] as String,
      measurementUnit: (m['measurementUnit'] ?? '') as String,
      imageQuality:
          ImageQualityX.fromCode((m['imageQuality'] ?? 'high') as String),
      confidence: ConfidenceX.fromCode((m['confidence'] ?? 'low') as String),
      finding: ResultCategoryX.fromCode((m['finding'] ?? '') as String),
      findingLabel: (m['findingLabel'] ?? '') as String,
      possibleAssociations: split(m['possibleAssociations'] as String?),
      limitations: split(m['limitations'] as String?),
      recommendedAction: (m['recommendedAction'] ?? '') as String,
      whyFlagged: (m['whyFlagged'] ?? '') as String,
      timestamp: DateTime.tryParse((m['timestamp'] ?? '') as String) ??
          DateTime.now(),
      uncertainty: (m['uncertainty'] ?? '') as String,
      hardware: (m['hardware'] ?? '') as String,
      deviceLabel: (m['deviceLabel'] ?? '') as String,
      algorithmVersion: (m['algorithmVersion'] ?? '') as String,
      evidenceVersion: (m['evidenceVersion'] ?? '') as String,
      profileId: (m['profileId'] ?? 'self') as String,
      eye: (m['eye'] ?? '') as String,
      conditionsVerified: ((m['conditionsVerified'] ?? 0) as int) == 1,
      modelVersion: (m['modelVersion'] ?? '') as String,
      modelHash: (m['modelHash'] ?? '') as String,
      protocolVersion: (m['protocolVersion'] ?? '') as String,
      engine: (m['engine'] ?? '') as String,
    );
  }

  /// Convenience constructor for the first-class "Unable to assess" state.
  factory ScreeningResult.unable({
    required String testName,
    required ImageQuality imageQuality,
    required String reason,
    required List<String> limitations,
    String measurement = 'not measured',
  }) {
    return ScreeningResult(
      testName: testName,
      measurement: measurement,
      measurementUnit: '',
      imageQuality: imageQuality,
      confidence: Confidence.low,
      finding: ResultCategory.unableToAssess,
      findingLabel: 'Unable to assess reliably',
      possibleAssociations: const [],
      limitations: limitations,
      recommendedAction:
          'Repeat the test in good lighting with the face centered and still. '
          'Consider professional evaluation if you have symptoms.',
      whyFlagged: reason,
      timestamp: DateTime.now(),
    );
  }
}
