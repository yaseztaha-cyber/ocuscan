// Analyzer transparency registry (v0.2).
//
// Every screening measurement documents: input, features, output, quality
// requirements, failure conditions, known limitations, and algorithm version.
// Validation results are always associated with the version recorded here.
// Experimental modules are explicitly flagged — they must never appear more
// reliable than validated components.

class AnalyzerInfo {
  /// Stable research key, also used as Experiment.testType.
  final String key;
  /// User-facing analyzer name (matches Analyzer.testName where applicable).
  final String title;

  /// Algorithm version, e.g. 'v1'. Recorded on every experiment.
  final String version;
  final String input;
  final String features;
  final String output;
  final List<String> qualityRequirements;
  final List<String> failureConditions;
  final List<String> knownLimitations;

  /// True when the module is experimental / not validated. The UI marks
  /// these prominently and the report generator labels them as such.
  final bool experimental;

  /// Provenance of the decision threshold shown on methodology cards.
  /// Defaults to the prototype label; literature-backed thresholds cite
  /// their source explicitly.
  final String thresholdBasis;

  const AnalyzerInfo({
    required this.key,
    required this.title,
    required this.version,
    required this.input,
    required this.features,
    required this.output,
    required this.qualityRequirements,
    required this.failureConditions,
    required this.knownLimitations,
    this.experimental = false,
    this.thresholdBasis =
        'Prototype engineering threshold — not a clinical diagnostic threshold.',
  });

  String get versionLabel => '$key $version';
}

class AnalyzerRegistry {
  static const List<AnalyzerInfo> all = [
    AnalyzerInfo(
      key: 'facial_asymmetry',
      title: 'Facial movement symmetry',
      version: 'v1',
      input: 'Guided-expression face frames (neutral, smile, eyebrow raise, eye closure, cheek puff)',
      features: 'Left/right movement amplitude per region; normalized difference; landmark quality',
      output: 'Relative movement asymmetry per region (no diagnosis)',
      qualityRequirements: ['Frontal face', 'Both eyes visible', 'Adequate sharpness', 'Stable lighting'],
      failureConditions: ['Head yaw beyond tolerance', 'Partial occlusion', 'Motion blur'],
      knownLimitations: ['Cannot determine the cause of asymmetry', 'Single-session camera tracking is approximate', 'Not a facial-nerve assessment'],
    ),
    AnalyzerInfo(
      key: 'eyelid',
      title: 'Eyelid position',
      version: 'v2',
      input: 'ML Kit left/right eye-openness probabilities from a frontal, locked frame; no millimeter lid-distance measurement',
      features: 'Left/right openness; probability asymmetry; unknown/closed-eye refusal',
      output: 'Relative eyelid-opening asymmetry (not a ptosis diagnosis)',
      qualityRequirements: ['Straight-ahead gaze', 'Both eyes open and visible', 'Even lighting'],
      failureConditions: ['Off-axis gaze', 'Brow shadow', 'Glasses glare', 'Unknown openness', 'Closed eyes'],
      knownLimitations: ['No disease threshold in this build', 'Brow position and gaze affect the estimate', 'Probability difference is not a lid distance in millimeters'],
    ),
    AnalyzerInfo(
      key: 'eye_alignment',
      title: 'Eye alignment',
      version: 'v1',
      input: 'Observer-reported cover/uncover judgments (the phone does not track gaze in this build)',
      features: 'Per-phase observer ratings after timed dwells; no landmark-shift estimate',
      output: 'Observer report only — no alignment estimate (not a strabismus diagnosis)',
      qualityRequirements: ['Stable fixation on target', 'Head stabilized', 'Timed dwell per phase'],
      failureConditions: ['Head movement', 'Skipped dwell', 'Poor fixation'],
      knownLimitations: ['Observer-reported, not camera-tracked', 'Cannot replace clinician cover testing'],
    ),
    AnalyzerInfo(
      key: 'pupil',
      title: 'Pupil symmetry',
      version: 'v1',
      input: 'Multi-frame eye images in stable lighting',
      features: 'Left/right visible pupil area per frame; frame validity flags; inter-frame consistency',
      output: 'Relative pupil-size asymmetry index (never millimeters without calibration)',
      qualityRequirements: ['Both pupils simultaneously visible', 'Stable lighting', 'Adequate sharpness'],
      failureConditions: ['Reflections', 'Occlusion', 'Motion', 'Poor segmentation', 'Lighting change mid-capture'],
      knownLimitations: ['Cannot determine the cause of asymmetry', 'Single frames are never used alone'],
    ),
    AnalyzerInfo(
      key: 'pupil_response',
      title: 'Pupil light response',
      version: 'v1',
      input: 'Time series of pupil appearance under a controlled light step',
      features: 'Baseline, response slope, recovery, left/right comparison',
      output: 'Relative response pattern (module disabled unless stimulus is safe and reproducible)',
      qualityRequirements: ['Controlled safe stimulus', 'Stable fixation', 'Stable exposure'],
      failureConditions: ['Unsafe or irreproducible stimulus (module disables itself)', 'Exposure drift'],
      knownLimitations: ['Phone illumination is not a clinical light source', 'Cannot determine a neurological cause'],
      experimental: true,
    ),
    AnalyzerInfo(
      key: 'surface_growth',
      title: 'Ocular surface',
      version: 'v1',
      input: 'Sharp close-up eye-surface frames',
      features: 'Segmentation mask; model confidence; image quality; shape cues',
      output: 'Screening flag for visible surface-growth appearance (no severity grade)',
      qualityRequirements: ['Sharp close-up', 'Eyes open', 'No strong reflections'],
      failureConditions: ['Low segmentation confidence', 'Motion blur', 'Reflections'],
      knownLimitations: ['Experimental model not validated', 'Cannot establish a diagnosis', 'Severity is not graded'],
      experimental: true,
    ),
    AnalyzerInfo(
      key: 'redness',
      title: 'Eye redness',
      version: 'v2',
      input: 'Landmark-centered left/right eye-region ROI pixels; not segmented sclera',
      features: 'ROI mean redness per eye; ROI red-dominant fraction; exposure/color-cast confidence proxy',
      output: 'Eye-region redness proxy and distribution (never a cause; not a segmented scleral measurement)',
      qualityRequirements: ['Neutral white lighting', 'Correct white balance', 'Sharp capture', 'Both eye landmarks detected'],
      failureConditions: ['Colored ambient light', 'Wrong white balance', 'Low resolution', 'Missing eye landmarks', 'Low color confidence'],
      knownLimitations: ['Values are not transferable across phones without testing', 'Redness alone cannot identify a cause', 'ROI includes eyelids, lashes, iris, and neighboring skin'],
    ),
    AnalyzerInfo(
      key: 'scleral',
      title: 'Scleral color',
      version: 'v1',
      input: 'Sclera-region pixels after lighting-calibration workflow',
      features: 'Lighting check; exposure; color environment; calibration verdict',
      output: 'Scleral-color screening only when calibration is valid; otherwise unable-to-assess',
      qualityRequirements: ['Valid lighting calibration', 'Neutral light', 'Reference target when available'],
      failureConditions: ['Invalid calibration (forces unable-to-assess)', 'Warm/colored light', 'Auto-white-balance drift'],
      knownLimitations: ['Extremely sensitive to lighting and camera processing', 'Cannot diagnose systemic conditions'],
    ),
    AnalyzerInfo(
      key: 'corneal',
      title: 'Corneal clarity',
      version: 'v1',
      input: 'Close-up corneal-region frames',
      features: 'Cloudiness cues; segmentation confidence',
      output: 'Conservative screening flag only',
      qualityRequirements: ['Sharp close-up', 'Controlled reflections'],
      failureConditions: ['Low segmentation confidence', 'Reflections obscuring the cornea'],
      knownLimitations: ['Experimental: not clinically validated', 'Ordinary phone photography has major limits for corneal detail'],
      experimental: true,
    ),
    AnalyzerInfo(
      key: 'lens',
      title: 'Lens clarity (experimental)',
      version: 'v1',
      input: 'Guided close-up capture protocol frames',
      features: 'Opacity cues; capture-support score',
      output: 'Screening flag only under supported capture; otherwise unable-to-assess',
      qualityRequirements: ['Guided close-up protocol', 'High-quality capture'],
      failureConditions: ['Unsupported capture method (forces unable-to-assess)'],
      knownLimitations: ['Experimental: not clinically validated', 'Front camera is not a slit lamp'],
      experimental: true,
    ),
    AnalyzerInfo(
      key: 'blink',
      title: 'Blink pattern',
      version: 'v1',
      input: 'Short frontal video, both eyes visible',
      features: 'Blink frequency; completeness; symmetry; duration',
      output: 'Blinking-pattern description (never a dry-eye diagnosis)',
      qualityRequirements: ['Stable frontal video', 'Continuous eye visibility'],
      failureConditions: ['Face leaves frame', 'Low frame rate', 'Tracking loss'],
      knownLimitations: ['Cannot diagnose dry-eye disease from blinking alone'],
    ),
    AnalyzerInfo(
      key: 'nystagmus',
      title: 'Eye movement stability',
      version: 'v1',
      input: 'Gaze time series during fixation',
      features: 'Oscillation frequency; amplitude; sustained-window check; tracking confidence',
      output: 'Screening flag for sustained periodic oscillation, else unable-to-assess when indeterminate',
      qualityRequirements: ['Stabilized head', 'Continuous gaze lock', 'Adequate clip length'],
      failureConditions: ['Tracking confidence below threshold', 'Short clip', 'Distraction/saccades'],
      knownLimitations: ['Cannot determine the cause', 'Brief endpoint movement can resemble oscillation'],
    ),
    AnalyzerInfo(
      key: 'va_distance',
      title: 'Distance visual acuity',
      version: 'v1',
      input: 'Guided optotype responses at configured test distance',
      features: 'Per-level correct count; configured vs measured distance; brightness',
      output: 'Screening acuity level (not a prescription)',
      qualityRequirements: ['Configured test distance', 'Full brightness', 'One eye covered'],
      failureConditions: ['Uncalibrated distance', 'Screen zoom enabled', 'Wrong viewing distance'],
      knownLimitations: ['Configured test distance is not a clinically standardized distance unless evidence supports it'],
    ),
    AnalyzerInfo(
      key: 'va_near',
      title: 'Near visual acuity',
      version: 'v1',
      input: 'Guided near-text responses at ~40 cm',
      features: 'Smallest readable size per eye; hold distance',
      output: 'Near-vision screening level (not a prescription)',
      qualityRequirements: ['Specified hold distance', 'Adequate lighting'],
      failureConditions: ['Wrong hold distance', 'Glare on screen'],
      knownLimitations: ['Cannot infer a glasses prescription'],
    ),
    AnalyzerInfo(
      key: 'color',
      title: 'Color vision',
      version: 'v1',
      input: 'Responses to original generated color-discrimination plates',
      features: 'Per-axis error pattern (original stimuli; no copyrighted plates)',
      output: 'Screening suggestion for further assessment (never a specific disorder)',
      qualityRequirements: ['Full brightness', 'Night mode and filters off', 'Neutral ambient light'],
      failureConditions: ['Night mode on', 'Blue-light filter on', 'Low brightness'],
      knownLimitations: ['Display-dependent; not transferable across devices without testing'],
    ),
    AnalyzerInfo(
      key: 'contrast',
      title: 'Contrast sensitivity',
      version: 'v1',
      input: 'Faint-pattern detection responses at descending contrast',
      features: 'Threshold level; brightness; ambient lighting; screen settings; device',
      output: 'Contrast threshold under recorded conditions (no invented norms)',
      qualityRequirements: ['Recorded brightness and distance', 'Stable ambient light'],
      failureConditions: ['Changed display settings mid-test', 'Glare'],
      knownLimitations: ['No normative ranges for uncalibrated displays'],
    ),
    AnalyzerInfo(
      key: 'amsler',
      title: 'Central vision (Amsler-style)',
      version: 'v1',
      input: 'Self-reported grid distortion marks per eye',
      features: 'Distortion location; distortion type; eye; repeat result',
      output: 'Distortion report for repeatability/usability research (never an AMD finding)',
      qualityRequirements: ['One eye covered', 'Correct viewing distance', 'Fixation on center'],
      failureConditions: ['Both eyes open', 'Wrong distance'],
      knownLimitations: ['Subjective; measures repeatability and usability of the screening, not retinal state'],
    ),
    AnalyzerInfo(
      key: 'peripheral',
      title: 'Peripheral visual field',
      version: 'v1',
      input: 'Stimulus-response trials per region and eye',
      features: 'Stimulus location; response; reaction time; misses; false positives/negatives; repeatability',
      output: 'Screening deficit suggestion (never a perimeter result)',
      qualityRequirements: ['Central fixation maintained', 'Dark quiet room', 'Per-eye testing'],
      failureConditions: ['Fixation loss', 'Distraction', 'Screen too small for eccentricity'],
      knownLimitations: ['Screening experiment, not a perimeter replacement'],
    ),
    AnalyzerInfo(
      key: 'cover',
      title: 'Cover test',
      version: 'v1',
      input: 'Camera-tracked eye position across cover states',
      features: 'Eye; cover state; movement; direction; magnitude; confidence; tracking visualization',
      output: 'Observed movement description (never a diagnosis)',
      qualityRequirements: ['Stable head', 'Cooperative cover sequence', 'Gaze lock'],
      failureConditions: ['Head movement', 'Incomplete cover', 'Tracking loss'],
      knownLimitations: ['Phone tracking is approximate'],
    ),
  ];

  static AnalyzerInfo? forKey(String key) {
    for (final a in all) {
      if (a.key == key) return a;
    }
    return null;
  }

  /// Map a v1 Analyzer.testName to its registry key.
  static String? keyForTestName(String testName) {
    const map = {
      'Facial movement symmetry': 'facial_asymmetry',
      'Eyelid position': 'eyelid',
      'Eye alignment': 'eye_alignment',
      'Pupil symmetry': 'pupil',
      'Pupil light response': 'pupil_response',
      'Ocular surface': 'surface_growth',
      'Eye redness': 'redness',
      'Scleral color': 'scleral',
      'Corneal clarity': 'corneal',
      'Lens clarity (experimental)': 'lens',
      'Blink pattern': 'blink',
      'Eye movement stability': 'nystagmus',
    };
    return map[testName];
  }

  static String versionForTestName(String testName) =>
      forKey(keyForTestName(testName) ?? '')?.version ?? 'v1';

  /// Modality requirements per analyzer key (§26, §52): cameras, eyes,
  /// temporal data, source. If hardware is not suitable, the UI reports
  /// the test unavailable under current conditions instead of guessing.
  static const Map<String, Map<String, String>> modalityRequirements = {
    'facial_asymmetry': {
      'camera': 'front (guided expressions)',
      'eyes': 'both visible',
      'temporal': 'none (instant samples)',
      'source': 'camera',
    },
    'eyelid': {
      'camera': 'front',
      'eyes': 'both visible',
      'temporal': 'none',
      'source': 'camera',
    },
    'eye_alignment': {
      'camera': 'front (cover sequence)',
      'eyes': 'both, sequential cover',
      'temporal': 'sequence (not tracked in this build)',
      'source': 'camera',
    },
    'pupil': {
      'camera': 'front or rear',
      'eyes': 'both segmented',
      'temporal': 'multi-frame (currently unavailable)',
      'source': 'camera',
    },
    'pupil_response': {
      'camera': 'front + controlled safe stimulus (absent)',
      'eyes': 'both',
      'temporal': 'stimulus-locked series',
      'source': 'camera',
    },
    'surface_growth': {
      'camera': 'rear close-up preferred',
      'eyes': 'target eye open',
      'temporal': 'none',
      'source': 'camera',
    },
    'redness': {
      'camera': 'front or rear',
      'eyes': 'both detected eye landmarks',
      'temporal': 'none',
      'source': 'camera',
    },
    'scleral': {
      'camera': 'front or rear + passed color calibration',
      'eyes': 'either',
      'temporal': 'none',
      'source': 'camera',
    },
    'corneal': {
      'camera': 'rear close-up preferred',
      'eyes': 'target eye open',
      'temporal': 'none',
      'source': 'camera',
    },
    'lens': {
      'camera': 'supported close-up method (absent)',
      'eyes': 'target eye',
      'temporal': 'none',
      'source': 'camera',
    },
    'blink': {
      'camera': 'front',
      'eyes': 'tracked openness series (30+ samples)',
      'temporal': 'series required',
      'source': 'camera',
    },
    'nystagmus': {
      'camera': 'front + gaze tracking (absent)',
      'eyes': 'both tracked',
      'temporal': 'series required',
      'source': 'camera',
    },
    'va_distance': {
      'camera': 'none (display test)',
      'eyes': 'one at a time, other covered',
      'temporal': 'staircase sequence',
      'source': 'operator answers + display',
    },
    'va_near': {
      'camera': 'none (display test)',
      'eyes': 'one at a time at ~40 cm',
      'temporal': 'none',
      'source': 'operator answers + display',
    },
    'color': {
      'camera': 'none (display test)',
      'eyes': 'both, night mode + filters OFF',
      'temporal': 'none',
      'source': 'operator answers + display',
    },
    'contrast': {
      'camera': 'none (display test)',
      'eyes': 'either, recorded brightness + ~1 m',
      'temporal': 'staircase sequence',
      'source': 'operator answers + display',
    },
    'amsler': {
      'camera': 'none (display test)',
      'eyes': 'one at a time, central fixation',
      'temporal': 'none',
      'source': 'self-reported distortion map',
    },
    'peripheral': {
      'camera': 'none (display test)',
      'eyes': 'opposite eye fixates, operator-paced flashes',
      'temporal': 'flash sequence + catch trials',
      'source': 'operator answers + display',
    },
    'cover': {
      'camera': 'front (observer watches, phone does not track gaze)',
      'eyes': 'both, sequential cover',
      'temporal': 'dwell per phase (observer-reported)',
      'source': 'observer judgment',
    },
  };

  /// One-line requirements summary for methodology cards.
  static String requirementsFor(String key) {
    final m = modalityRequirements[key];
    if (m == null) return 'Requirements undocumented for $key.';
    return 'Camera: ${m['camera']}; eyes: ${m['eyes']}; '
        'temporal: ${m['temporal']}; source: ${m['source']}.';
  }
}

/// Future/experimental research track (v0.4 capability catalog).
///
/// Deliberately SEPARATE from [AnalyzerRegistry.all] (whose size and
/// evidence linkage are pinned by tests): a track is a research
/// direction with a defined protocol shape, required inputs, and
/// hardware — never a classifier, never a diagnosis, never measured in
/// this build. Tracks appear in Learn as a capability catalog only.
class ResearchTrack {
  final String key;
  final String titleEn;
  final String titleAr;
  final String categoryEn;
  final String categoryAr;
  final String status; // EXPERIMENTAL | FUTURE
  final String tier; // evidence tier of the research precedent (C default)
  final String summaryEn;
  final String summaryAr;
  final String hardwareEn;
  final String hardwareAr;
  final String protocolEn;
  final String protocolAr;

  const ResearchTrack({
    required this.key,
    required this.titleEn,
    required this.titleAr,
    required this.categoryEn,
    required this.categoryAr,
    required this.status,
    required this.tier,
    required this.summaryEn,
    required this.summaryAr,
    required this.hardwareEn,
    required this.hardwareAr,
    required this.protocolEn,
    required this.protocolAr,
  });
}

/// Evidence-driven capability catalog: research precedents exist in the
/// literature (anterior-segment phone imaging, facial-expression
/// neurology research, smartphone fundus systems), but OcuScan has NOT
/// validated any of these — they are directions with protocols, not
/// features. Statuses: EXPERIMENTAL (protocol defined, needs data +
/// validation) or FUTURE (needs hardware or architecture first).
const List<ResearchTrack> researchTracks = [
  ResearchTrack(
    key: 'facial_nerve_research',
    titleEn: 'Facial nerve weakness (research)',
    titleAr: 'ضعف العصب الوجهي (بحثي)',
    categoryEn: 'Facial / neurological research',
    categoryAr: 'بحث الوجه / العصبية',
    status: 'EXPERIMENTAL',
    tier: 'C',
    summaryEn:
        'Guided-expression symmetry protocol exists (neutral, smile, brow raise, eye closure, cheek puff). Research precedent links expression analysis to facial-nerve assessment, but OcuScan reports movement patterns only — never a palsy diagnosis.',
    summaryAr:
        'يوجد بروتوكول تماثل التعابير الموجهة (محايد، ابتسامة، رفع الحاجبين، إغلاق العينين، نفخ الخدين). تربط سوابق بحثية تحليل التعابير بتقييم العصب الوجهي، لكن OcuScan يبلغ عن أنماط الحركة فقط — وليس تشخيص شلل أبداً.',
    hardwareEn: 'Front camera, guided expressions',
    hardwareAr: 'الكاميرا الأمامية، تعابير موجهة',
    protocolEn: 'Neutral → smile → brow raise → eye closure → cheek puff; per-region amplitude + timing.',
    protocolAr: 'محايد ← ابتسامة ← رفع الحاجبين ← إغلاق العينين ← نفخ الخدين؛ السعة والتوقيت لكل منطقة.',
  ),
  ResearchTrack(
    key: 'parkinsonian_expression_research',
    titleEn: 'Parkinsonian expression dynamics (research)',
    titleAr: 'ديناميكية التعابير الباركنسونية (بحثي)',
    categoryEn: 'Facial / neurological research',
    categoryAr: 'بحث الوجه / العصبية',
    status: 'EXPERIMENTAL',
    tier: 'C',
    summaryEn:
        'Digital-biomarker literature investigates expression amplitude, speed, and reduced dynamics from general-purpose equipment. OcuScan has no validated biomarker — any future work needs multimodal data and clinical validation, never a selfie verdict.',
    summaryAr:
        'تستقصي أدبيات المؤشرات الرقمية سعة التعابير وسرعتها وديناميكيتها المنخفضة بمعدات عامة. لا يملك OcuScan مؤشراً متحققاً — وأي عمل مستقبلي يحتاج بيانات متعددة الوسائط وتحققاً سريرياً، وليس حكم سيلفي أبداً.',
    hardwareEn: 'Front camera, video sequence',
    hardwareAr: 'الكاميرا الأمامية، تسلسل فيديو',
    protocolEn: 'Repeated expression cycles; amplitude, speed, symmetry, dynamics vs prototype reference distribution.',
    protocolAr: 'دورات تعبير متكررة؛ السعة والسرعة والتماثل والديناميكية مقابل التوزيع المرجعي الأولي.',
  ),
  ResearchTrack(
    key: 'als_facial_motor_research',
    titleEn: 'Facial-motor patterns (research)',
    titleAr: 'أنماط الحركة الوجهية (بحثي)',
    categoryEn: 'Facial / neurological research',
    categoryAr: 'بحث الوجه / العصبية',
    status: 'EXPERIMENTAL',
    tier: 'C',
    summaryEn:
        'Facial movement, eye closure, and lip movement are candidate motor signals in ALS research. Output would be limited to "pattern outside the prototype reference distribution" — never an ALS finding.',
    summaryAr:
        'حركة الوجه وإغلاق العينين وحركة الشفاه إشارات حركية مرشحة في أبحاث التصلب الجانبي. يقتصر المخرج على «نمط خارج التوزيع المرجعي الأولي» — وليس اكتشاف تصلب أبداً.',
    hardwareEn: 'Front camera, video sequence',
    hardwareAr: 'الكاميرا الأمامية، تسلسل فيديو',
    protocolEn: 'Facial movement + eye closure + lip movement timing vs reference distribution.',
    protocolAr: 'توقيت حركة الوجه + إغلاق العينين + حركة الشفاه مقابل التوزيع المرجعي.',
  ),
  ResearchTrack(
    key: 'pterygium_research',
    titleEn: 'Ocular-surface growth appearance (research)',
    titleAr: 'مظهر نمو سطح العين (بحثي)',
    categoryEn: 'Ocular / anterior segment',
    categoryAr: 'العين / القطعة الأمامية',
    status: 'EXPERIMENTAL',
    tier: 'C',
    summaryEn:
        'Close-up appearance description (growth patterns, redness distribution) at phone resolution, severity never graded, causes never assigned. Anterior-segment disease models in the literature required specialized training data OcuScan does not have.',
    summaryAr:
        'وصف المظهر عن قرب (أنماط النمو وتوزيع الاحمرار) بدقة الهاتف، دون تدريج شدة أبداً ودون إسناد أسباب. تطلبت نماذج أمراض القطعة الأمامية في الأدبيات بيانات تدريب متخصصة لا يملكها OcuScan.',
    hardwareEn: 'Rear camera close-up preferred',
    hardwareAr: 'يُفضَّل التقاط قريب بالكاميرا الخلفية',
    protocolEn: 'Sharp close-up, both eyes open, controlled light; conservative appearance description only.',
    protocolAr: 'لقطة قريبة واضحة بعينين مفتوحتين وإضاءة مضبوطة؛ وصف محافظ للمظهر فقط.',
  ),
  ResearchTrack(
    key: 'corneal_opacity_research',
    titleEn: 'Corneal clarity appearance (research)',
    titleAr: 'مظهر شفافية القرنية (بحثي)',
    categoryEn: 'Ocular / anterior segment',
    categoryAr: 'العين / القطعة الأمامية',
    status: 'EXPERIMENTAL',
    tier: 'C',
    summaryEn:
        'Cloudiness cues at phone resolution, described conservatively. No opacity grading, no cause assignment, no keratitis inference.',
    summaryAr:
        'إشارات العتامة بدقة الهاتف وتُوصف بتحفظ. لا تدريج عتامة ولا إسناد سبب ولا استنتاج التهاب قرنية.',
    hardwareEn: 'Rear camera close-up, even light',
    hardwareAr: 'لقطة قريبة خلفية وإضاءة متساوية',
    protocolEn: 'Close-up clarity cues vs calibrated reference captures.',
    protocolAr: 'إشارات الوضوح عن قرب مقابل لقطات مرجعية معايَرة.',
  ),
  ResearchTrack(
    key: 'cataract_appearance_research',
    titleEn: 'Lens-opacity appearance (research)',
    titleAr: 'مظهر عتامة العدسة (بحثي)',
    categoryEn: 'Ocular / anterior segment',
    categoryAr: 'العين / القطعة الأمامية',
    status: 'EXPERIMENTAL',
    tier: 'C',
    summaryEn:
        'Lens appearance assessment needs a supported close-up capture method absent from this build. Any future output would be a referral prompt, never a cataract finding.',
    summaryAr:
        'يحتاج تقييم مظهر العدسة طريقة التقاط قريب مدعومة غائبة عن هذه النسخة. أي مخرج مستقبلي سيكون محفز إحالة لا اكتشاف ساد.',
    hardwareEn: 'Supported close-up method (absent)',
    hardwareAr: 'طريقة لقطة قريب مدعومة (غائبة)',
    protocolEn: 'Undefined until capture method exists.',
    protocolAr: 'غير محدد حتى توجد طريقة الالتقاط.',
  ),
  ResearchTrack(
    key: 'retinal_dr_future',
    titleEn: 'Diabetic retinopathy screening (future)',
    titleAr: 'فحص اعتلال الشبكية السكري (مستقبلي)',
    categoryEn: 'Retinal research',
    categoryAr: 'بحث الشبكية',
    status: 'FUTURE',
    tier: 'C',
    summaryEn:
        'Requires a calibrated retinal optical attachment with controlled illumination. Smartphone-fundus research motivates the direction; published performance never transfers to OcuScan.',
    summaryAr:
        'يتطلب ملحقاً بصرياً شبكياً معايَراً بإضاءة مضبوطة. تحفز أبحاث قاع العين بالهواتف هذا الاتجاه؛ ولا ينتقل الأداء المنشور أبداً إلى OcuScan.',
    hardwareEn: 'Rear camera + optical attachment (absent)',
    hardwareAr: 'الكاميرا الخلفية + ملحق بصري (غائب)',
    protocolEn: 'Gradable/ungradable quality gate first; analysis only after validation.',
    protocolAr: 'بوابة جودة قابلة/غير قابلة للتدريج أولاً؛ والتحليل بعد التحقق فقط.',
  ),
  ResearchTrack(
    key: 'retinal_glaucoma_future',
    titleEn: 'Glaucoma-related retinal findings (future)',
    titleAr: 'اكتشافات الشبكية المتعلقة بالزرق (مستقبلي)',
    categoryEn: 'Retinal research',
    categoryAr: 'بحث الشبكية',
    status: 'FUTURE',
    tier: 'C',
    summaryEn:
        'Optic-nerve/retinal findings need fundus optics no phone provides. Future-hardware track with its own safety review and validation.',
    summaryAr:
        'تحتاج اكتشافات العصب البصري/الشبكية بصريات قاع لا يوفرها أي هاتف. مسار عتاد مستقبلي بمراجعة سلامة وتحقق خاصين.',
    hardwareEn: 'Rear camera + optical attachment (absent)',
    hardwareAr: 'الكاميرا الخلفية + ملحق بصري (غائب)',
    protocolEn: 'Undefined until hardware exists.',
    protocolAr: 'غير محدد حتى يوجد العتاد.',
  ),
  ResearchTrack(
    key: 'retinal_amd_future',    titleEn: 'Age-related macular findings (future)',
    titleAr: 'اكتشافات البقعة المرتبطة بالعمر (مستقبلي)',
    categoryEn: 'Retinal research',
    categoryAr: 'بحث الشبكية',
    status: 'FUTURE',
    tier: 'C',
    summaryEn:
        'Macular assessment needs fundus imaging. Amsler-style distortion screening in Vision Lab is not a retinal diagnosis and never becomes one.',
    summaryAr:
        'يحتاج تقييم البقعة تصوير قاع. فحص التشوه بشبكة آسلر في مختبر النظر ليس تشخيص شبكية ولن يكون أبداً.',
    hardwareEn: 'Rear camera + optical attachment (absent)',
    hardwareAr: 'الكاميرا الخلفية + ملحق بصري (غائب)',
    protocolEn: 'Undefined until hardware exists.',
    protocolAr: 'غير محدد حتى يوجد العتاد.',
  ),
  ResearchTrack(
    key: 'dementia_behavior_research',
    titleEn: 'Dementia-related facial behavior (research)',
    titleAr: 'السلوك الوجهي المرتبط بالخرف (بحثي)',
    categoryEn: 'Facial / neurological research',
    categoryAr: 'بحث الوجه / العصبية',
    status: 'EXPERIMENTAL',
    tier: 'C',
    summaryEn:
        'Systematic reviews include dementia among conditions studied with facial-expression deep learning, but a selfie is not a cognitive assessment. Any future work needs appropriate multimodal data, consent, and validation — never a dementia finding from a photo.',
    summaryAr:
        'تدرج المراجعات المنهجية الخرف ضمن الحالات المدروسة بالتعلم العميق للتعابير، لكن السيلفي ليس تقييماً معرفياً. أي عمل مستقبلي يحتاج بيانات متعددة الوسائط مناسبة وموافقة وتحققاً — وليس اكتشاف خرف من صورة أبداً.',
    hardwareEn: 'Front camera, video sequence (future protocol)',
    hardwareAr: 'الكاميرا الأمامية، تسلسل فيديو (بروتوكول مستقبلي)',
    protocolEn: 'Undefined: requires designed protocol, consent model, and validation plan first.',
    protocolAr: 'غير محدد: يتطلب تصميم بروتوكول ونموذج موافقة وخطة تحقق أولاً.',
  ),
  ResearchTrack(
    key: 'voice_research_future',
    titleEn: 'Voice research (future modality)',
    titleAr: 'البحث الصوتي (وسيلة مستقبلية)',
    categoryEn: 'Future multimodal research',
    categoryAr: 'بحث متعدد الوسائط مستقبلي',
    status: 'FUTURE',
    tier: 'C',
    summaryEn:
        'Optional future instrument only. Requires explicit microphone consent, local processing by default, no raw audio storage by default, no voice identity recognition, and clear research status. No conclusions implemented.',
    summaryAr:
        'أداة مستقبلية اختيارية فقط. تتطلب موافقة صريحة على الميكروفون ومعالجة محلية افتراضياً وعدم تخزين صوت خام افتراضياً وعدم التعرف على هوية الصوت وحالة بحثية واضحة. لا استنتاجات منفذة.',
    hardwareEn: 'Microphone (consent-gated, absent)',
    hardwareAr: 'الميكروفون (بموافقة، غائب)',
    protocolEn: 'Undefined until consent model, privacy review, and validation plan exist.',
    protocolAr: 'غير محدد حتى يوجد نموذج موافقة ومراجعة خصوصية وخطة تحقق.',
  ),
  ResearchTrack(
    key: 'gait_research_future',
    titleEn: 'Gait research (future modality)',
    titleAr: 'بحث المشية (وسيلة مستقبلية)',
    categoryEn: 'Future multimodal research',
    categoryAr: 'بحث متعدد الوسائط مستقبلي',
    status: 'FUTURE',
    tier: 'C',
    summaryEn:
        'Phone-camera video gait analysis is a future research instrument only: explicit consent, safety warning, research-only until validated. No conclusions implemented.',
    summaryAr:
        'تحليل المشية بفيديو الهاتف أداة بحثية مستقبلية فقط: موافقة صريحة وتحذير سلامة وبحثي فقط حتى التحقق. لا استنتاجات منفذة.',
    hardwareEn: 'Rear camera video, tripod advised (future)',
    hardwareAr: 'فيديو الكاميرا الخلفية ويُنصح بحامل (مستقبلي)',
    protocolEn: 'Undefined until safety review and validation plan exist.',
    protocolAr: 'غير محدد حتى توجد مراجعة سلامة وخطة تحقق.',
  ),
  ResearchTrack(
    key: 'stereopsis_research_future',
    titleEn: 'Stereopsis / binocular coordination (future)',
    titleAr: 'الإبصار المجسم / التنسيق الثنائي (مستقبلي)',
    categoryEn: 'Visual function research',
    categoryAr: 'بحث الوظيفة البصرية',
    status: 'FUTURE',
    tier: 'C',
    summaryEn:
        'True stereopsis measurement needs controlled dichoptic presentation the phone screen cannot provide. Both-eyes acuity runs exist; no clinical stereopsis claim until a validated method exists.',
    summaryAr:
        'يحتاج قياس الإبصار المجسم الحقيقي عرضاً مزدوجاً مضبوطاً لا توفره شاشة الهاتف. توجد جولات حدة بالعينين؛ ولا ادعاء تجسيم سريري حتى توجد طريقة متحقق منها.',
    hardwareEn: 'Undefined (no validated phone method)',
    hardwareAr: 'غير محدد (لا طريقة هاتف متحقق منها)',
    protocolEn: 'Undefined until a validated phone-compatible method exists.',
    protocolAr: 'غير محدد حتى توجد طريقة متوافقة مع الهاتف ومتحقق منها.',
  ),
];
