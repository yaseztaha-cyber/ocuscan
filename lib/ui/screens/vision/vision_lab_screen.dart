import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/data/history_repository.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/evidence/evidence_repository.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/models/screening_result.dart';
import '../../../core/utils/device_label.dart';
import '../../../core/validation/analyzer_registry.dart';
import '../../../features/vision/display_metrics.dart';
import '../../../features/vision_lab/vision_logic.dart';
import '../../../main.dart';
import '../../widgets/common.dart';

// Vision Lab: interactive screening tests. Each eye separately, randomized,
// no zoom (textScale fixed to 1 within tests), display conditions recorded.

/// Persist a vision-test outcome as a history ScreeningResult (measurements
/// only). Respects the history-enabled switch; never stores images.
/// Findings follow screening semantics: measurements are recorded, flags
/// only where the test defines explicit criteria, unable where the test's
/// own calibration requirements are unmet.
Future<void> persistVisionResult(
  BuildContext context, {
  required String testName,
  required String measurement,
  required ResultCategory finding,
  required String findingLabel,
  required List<String> limitations,
  required String recommendedAction,
  required String whyFlagged,
  ImageQuality quality = ImageQuality.medium,
  // Explicit trend columns (v6): tested eye + whether conditions were
  // verified at persist time. Defaults keep old behavior (unspecified).
  String eye = '',
  bool conditionsVerified = false,
  // Measurement trace (§9): vision tests use display + operator, never
  // ML Kit — so the model stays empty (honest) by default.
  String engine = 'vision-display',
  String protocol = kVisionProtocolVersion,
}) async {
  final settings = context.read<SettingsRepository>();
  if (!settings.historyEnabled) return;
  final repo = context.read<HistoryRepository>();
  final profileId = context.read<AppState>().profileId;
  String evidenceVersion = '';
  try {
    evidenceVersion = (await EvidenceRepository.load()).dbVersion;
  } catch (_) {}
  String device = '';
  try {
    device = await localDeviceLabel();
  } catch (_) {}
  await repo.insert(ScreeningResult(
    testName: testName,
    measurement: measurement,
    measurementUnit: '',
    imageQuality: quality,
    confidence: Confidence.low,
    finding: finding,
    findingLabel: findingLabel,
    possibleAssociations: const [],
    limitations: limitations,
    recommendedAction: recommendedAction,
    whyFlagged: whyFlagged,
    timestamp: DateTime.now(),
    hardware: '',
    deviceLabel: device,
    algorithmVersion: AnalyzerRegistry.versionForTestName(testName),
    evidenceVersion: evidenceVersion,
    profileId: profileId,
    eye: eye,
    conditionsVerified: conditionsVerified,
    protocolVersion: protocol,
    engine: engine,
  ));
}
class VisionLabScreen extends StatefulWidget {
  const VisionLabScreen({super.key});
  @override
  State<VisionLabScreen> createState() => _VisionLabScreenState();
}

class _VisionLabScreenState extends State<VisionLabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final Set<String> _done = {};
  String? _retestSetup;
  bool _retestApplied = false;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 7, vsync: this); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_retestApplied) return;
    _retestApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final tab = args['tab'];
      if (tab is int && tab >= 0 && tab < 7) {
        _tabs.index = tab;
      }
      final setup = args['setup'];
      if (setup is String && setup.isNotEmpty) {
        _retestSetup = setup;
      }
    }
  }

  void _markDone(String key) {
    if (_done.add(key) && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final tests = [
      ('distance', s.visionTabDistance, s.visionDuration2min),
      ('near', s.visionTabNear, s.visionDuration1min),
      ('color', s.visionTabColor, s.visionDuration2min),
      ('contrast', s.visionTabContrast, s.visionDuration2min),
      ('central', s.visionTabCentral, s.visionDuration2min),
      ('peripheral', s.visionTabPeripheral, s.visionDuration3min),
      ('cover', s.visionTabCover, s.visionDuration2min),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.visionLabTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: s.testCatalogTooltip,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(s.visionCatalogTitle),
                content: SingleChildScrollView(
                  child: Text(s.visionCatalogBody),
                ),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      child: Text(s.close)),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: [
          Tab(text: s.visionTabDistance),
          Tab(text: s.visionTabNear),
          Tab(text: s.visionTabColor),
          Tab(text: s.visionTabContrast),
          Tab(text: s.visionTabCentral),
          Tab(text: s.visionTabPeripheral),
          Tab(text: s.visionTabCover),
        ]),
      ),
      body: Column(children: [
        if (_retestSetup != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            color: const Color(0xFFEDF5F4),
            child: Text(s.retestBanner(_retestSetup!),
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _DistanceAcuity(onDone: _markDone),
            _NearAcuity(onDone: _markDone),
            _ColorTest(onDone: _markDone),
            _ContrastTest(onDone: _markDone),
            _CentralTest(onDone: _markDone),
            _PeripheralTest(onDone: _markDone),
            _CoverTest(onDone: _markDone),
          ]),
        ),
      ]),
      // Layout: the index bar hides while the keyboard is open so the
      // answer field + submit can never be squeezed off-screen.
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
              child: ExpansionTile(
          leading: const Icon(Icons.list_outlined),
          title: Text(s.visionIndexTitle,
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(s.visionIndexSubtitle,
              style: Theme.of(context).textTheme.bodySmall),
          children: [
            for (var i = 0; i < tests.length; i++)
              ListTile(
                dense: true,
                leading: Icon(
                    _done.contains(tests[i].$1)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _done.contains(tests[i].$1)
                        ? const Color(0xFF0A5E5D)
                        : const Color(0xFF3F4E4E),
                    size: 20),
                title: Text(tests[i].$2),
                trailing: Text(
                    '${tests[i].$3} • ${_done.contains(tests[i].$1) ? s.visionStatusDone : s.visionStatusReady}',
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: () => setState(() => _tabs.index = i),
              ),
          ],
              ),
            ),
    );
  }
}

class _EyeSelector extends StatelessWidget {
  final String eye;
  final ValueChanged<String>? onChanged;
  const _EyeSelector({required this.eye, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'right', label: Text(s.eyeRightLabel)),
        ButtonSegment(value: 'left', label: Text(s.eyeLeftLabel)),
        ButtonSegment(value: 'both', label: Text(s.eyeBothLabel)),
      ],
      selected: {eye},
      onSelectionChanged:
          onChanged == null ? null : (st) => onChanged!(st.first),
    );
  }
}

/// Compact per-test calibration statement: required distance, screen
/// condition, lighting requirement, eye tested, and calibration status.
/// Where the device cannot guarantee the physical assumptions, the status
/// warns instead of pretending.
class _CalibrationHeader extends StatelessWidget {
  final String distance;
  final String screen;
  final String lighting;
  final String eye;
  final String status;
  const _CalibrationHeader({
    required this.distance,
    required this.screen,
    required this.lighting,
    required this.eye,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.calibStatusLine(status),
                  style: t.titleMedium),
              const SizedBox(height: 4),
              Text(s.calibDistanceLine(distance), style: t.bodySmall),
              Text(s.calibScreenLine(screen), style: t.bodySmall),
              Text(s.calibLightingLine(lighting), style: t.bodySmall),
              Text(s.calibEyeLine(eye), style: t.bodySmall),
            ]),
      ),
    );
  }
}

/// Compact visual preview identifying each vision test at a glance
/// (optotype, lines, dots, fade steps, grid, cross, halves) — not generic
/// icon cards. Purely illustrative; the test below does the measuring.
enum _TestVisualKind {
  distance,
  near,
  color,
  contrast,
  central,
  peripheral,
  cover
}

class _TestVisual extends StatelessWidget {
  final _TestVisualKind kind;
  const _TestVisual(this.kind);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5F4),
        border: Border.all(color: const Color(0xFFE2E8E6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: _glyph(),
    );
  }

  Widget _glyph() {
    switch (kind) {
      case _TestVisualKind.distance:
        return const Text('E',
            style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A5E5D)));
      case _TestVisualKind.near:
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 120, height: 8, color: const Color(0xFF0A5E5D)),
          const SizedBox(height: 5),
          Container(width: 90, height: 6, color: const Color(0xFF0E7C7B)),
          const SizedBox(height: 5),
          Container(width: 60, height: 5, color: const Color(0xFF7FD1C0)),
        ]);
      case _TestVisualKind.color:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final c in [
            const Color(0xFF7A9B6D),
            const Color(0xFF8A7FA8),
            const Color(0xFF6D94A8)
          ])
            Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration:
                    BoxDecoration(color: c, shape: BoxShape.circle)),
        ]);
      case _TestVisualKind.contrast:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final a in [1.0, 0.6, 0.35, 0.15])
            Container(
                width: 30,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.black.withValues(alpha: a)),
        ]);
      case _TestVisualKind.central:
        return SizedBox(
          width: 66,
          height: 66,
          child: GridView.count(
            crossAxisCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 9; i++)
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF0E7C7B), width: 0.8),
                      color: i == 4
                          ? const Color(0xFF0A5E5D)
                          : Colors.white),
                ),
            ],
          ),
        );
      case _TestVisualKind.peripheral:
        return const Stack(alignment: Alignment.center, children: [
          Text('+', style: TextStyle(fontSize: 40)),
          Positioned(
              right: 6,
              child: Icon(Icons.fiber_manual_record, size: 14)),
        ]);
      case _TestVisualKind.cover:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 34,
              height: 44,
              decoration: const BoxDecoration(
                  color: Color(0xFF0A5E5D),
                  borderRadius: BorderRadiusDirectional.only(
                      topStart: Radius.circular(22),
                      bottomStart: Radius.circular(22)))),
          Container(
              width: 34,
              height: 44,
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF0A5E5D)),
                  borderRadius: const BorderRadiusDirectional.only(
                      topEnd: Radius.circular(22),
                      bottomEnd: Radius.circular(22)))),
        ]);
    }
  }
}

/// Pre-test instruction card (§40): purpose, time, distance, environment,
/// eye configuration, calibration — then Begin. No test starts immediately.
class _TestIntro extends StatelessWidget {
  final String purpose;
  final String time;
  final String distance;
  final String environment;
  final String eyes;
  final String calibration;
  final VoidCallback onBegin;
  const _TestIntro({
    required this.purpose,
    required this.time,
    required this.distance,
    required this.environment,
    required this.eyes,
    required this.calibration,
    required this.onBegin,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    // Layout: label flexes instead of a fixed 110px column so long
    // Arabic labels at large text scales cannot overflow (layout audit).
    Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 2,
              child: Text(k,
                  style: t.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text(v, style: t.bodyMedium)),
        ]));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(s.introPurpose, purpose),
              row(s.introTime, time),
              row(s.introDistance, distance),
              row(s.introEnvironment, environment),
              row(s.introEyes, eyes),
              row(s.introCalibration, calibration),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: onBegin, child: Text(s.beginTest)),
            ]),
      ),
    );
  }
}

/// Consistent vision result structure (§42): test, result, conditions,
/// reliability, limitation, next step (+ research sequence where kept).
class _VisionResultCard extends StatelessWidget {
  final String test;
  final String result;
  final String conditions;
  final String reliability;
  final String limitation;
  final String nextStep;
  final String? sequence;
  const _VisionResultCard({
    required this.test,
    required this.result,
    required this.conditions,
    required this.reliability,
    required this.limitation,
    required this.nextStep,
    this.sequence,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    Widget section(String h, String v) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h,
                  style: t.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              const SizedBox(height: 2),
              Text(v, style: t.bodyMedium),
            ]));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.resTest, style: t.bodySmall),
              Text(test, style: t.titleLarge),
              section(s.resResult, result),
              section(s.resConditions, conditions),
              section(s.resReliability, reliability),
              section(s.resLimitation, limitation),
              section(s.resNextStep, nextStep),
              if (sequence != null)
                section(s.resSequence, sequence!),
            ]),
      ),
    );
  }
}

class _DistanceAcuity extends StatefulWidget {
  final ValueChanged<String>? onDone;
  const _DistanceAcuity({this.onDone});
  @override
  State<_DistanceAcuity> createState() => _DistanceAcuityState();
}

class _DistanceAcuityState extends State<_DistanceAcuity> {
  String eye = 'right';
  bool started = false;
  // Distance + brightness are attested SEPARATELY: the whole test's
  // validity rests on distance, so one conflated checkbox is unsafe.
  // `calibrated` stays the single gate read by _saveDistance.
  bool _distOk = false;
  bool _brightOk = false;
  bool get calibrated => _distOk && _brightOk;
  // Per-eye staircase runs: queue depends on the eye selector.
  List<String> _queue = const ['right'];
  int _eyePos = 0;
  Staircase _stairs = Staircase(level: 4, max: acuityLevels.length - 1);
  Optotype _opt = const Optotype('E', 0);
  Map<String, String> _thresholds = {};
  Map<String, String> _sequences = {};
  bool _done = false;
  // Physical display density for true optotype sizing. Null until the
  // platform channel answers; invalid metrics fall back to approximate
  // sizing and are labeled uncalibrated (never silently treated as true).
  DisplayMetrics? _display;
  // Credit-card calibration (best source when set): logical px per mm
  // measured by matching an on-screen box to a real 85.6 mm card.
  double? _cardPxPerMm;
  double _cardBoxPx = 220;
  bool _showCardCal = false;

  @override
  void initState() {
    super.initState();
    _opt = VisionLogic.directionOptotypes(1).first;
    fetchDisplayMetrics().then((m) {
      if (mounted) setState(() => _display = m);
    });
  }

  /// Physical-pixel stroke width (letter height / 5) for the current
  /// level. Levels whose strokes fall below ~2 physical px cannot be
  /// truly rendered on this display (V2 pixel-limit cap).
  double _strokePhysicalPx(double devicePixelRatio) =>
      _letterSizePx(devicePixelRatio) / 5 * devicePixelRatio;

  /// Logical-pixel letter height for the current staircase level at the
  /// nominal 3 m test distance. Source priority: credit-card calibration
  /// (end-to-end true) → measured display density → legacy approximate
  /// ramp (labeled uncalibrated by callers).
  double _letterSizePx(double devicePixelRatio) {
    final arcMin = acuityLevels[_stairs.level].letterSizeArcMin;
    final card = _cardPxPerMm;
    if (card != null && card > 0) {
      final mm = CardCalibration.mmForArcMin(arcMin, 3000);
      final px = CardCalibration.logicalPxForMm(mm, card);
      if (px > 0) return px;
    }
    final d = _display;
    if (d != null && d.valid) {
      final px = d.logicalPixelsForArcMin(
        arcMin: arcMin,
        distanceMm: 3000,
        devicePixelRatio: devicePixelRatio,
      );
      if (px > 0) return px;
    }
    return (34 - _stairs.level * 3.2).clamp(10, 40).toDouble();
  }

  void _begin() {
    setState(() {
      started = true;
      _queue = eye == 'both' ? const ['right', 'left'] : [eye];
      _eyePos = 0;
      _stairs = Staircase(level: 4, max: acuityLevels.length - 1);
      _opt = VisionLogic.directionOptotypes(1).first;
      _thresholds = {};
      _sequences = {};
      _done = false;
    });
  }

  void _restart() {
    setState(() {
      started = false;
      _done = false;
      _thresholds = {};
      _sequences = {};
    });
  }

  String get _currentEye => _queue[_eyePos.clamp(0, _queue.length - 1)];

  void _answer(bool right) {
    _stairs.respond(right);
    if (_stairs.done) {
      final label = acuityLevels[_stairs.threshold].label;
      final seq = _stairs.sequence;
      final finishedEye = _currentEye;
      final resultText =
          'Measured visual acuity ($finishedEye eye): $label. Screening measurement, not a prescription and not a diagnosis.';
      _thresholds[finishedEye] = label;
      _sequences[finishedEye] = seq;
      _saveDistance(resultText, label, finishedEye, seq);
      if (_eyePos < _queue.length - 1) {
        setState(() {
          _eyePos++;
          _stairs = Staircase(level: 4, max: acuityLevels.length - 1);
          _opt = VisionLogic.directionOptotypes(1).first;
        });
      } else {
        widget.onDone?.call('distance');
        setState(() => _done = true);
      }
    } else {
      setState(() {
        _opt = VisionLogic.directionOptotypes(1).first;
      });
    }
  }

  void _saveDistance(
      String resultText, String level, String forEye, String seq) {
    final s = AppStrings(context.read<AppState>().lang);
    final displayNote = _cardPxPerMm != null
        ? s.cardCalibratedNote
        : ((_display?.valid ?? false)
            ? s.visionDisplayMeasured(_display!.ydpi)
            : s.visionDisplayUncalibrated);
    // V2 pixel-limit cap: finer-than-display levels are unable, never
    // silently up-sampled into a passing-looking result.
    if (_strokePhysicalPx(MediaQuery.devicePixelRatioOf(context)) < 2.0) {
      persistVisionResult(
        context,
        testName: 'Distance visual acuity',
        eye: forEye,
        conditionsVerified: false,
        measurement: '$level ($forEye eye); $displayNote',
        finding: ResultCategory.unableToAssess,
        findingLabel: 'Unable to assess reliably',
        limitations: const [
          'Finest levels exceed this display’s true rendering ability.',
        ],
        recommendedAction:
            'Repeat on a higher-density display or at a verified setup.',
        whyFlagged: '$resultText Sequence: $seq',
        quality: ImageQuality.low,
      );
      return;
    }
    if (!calibrated) {
      persistVisionResult(
        context,
        testName: 'Distance visual acuity',
        eye: forEye,
        conditionsVerified: false,
        measurement: '$level ($forEye eye), distance uncalibrated; $displayNote',
        finding: ResultCategory.unableToAssess,
        findingLabel: 'Unable to assess reliably',
        limitations: const [
          'Test distance was not verified at 3 m.',
          'Repeat with the operator checklist confirmed.',
        ],
        recommendedAction:
            'Repeat with the phone at 3 m and full brightness.',
        whyFlagged: '$resultText Sequence: $seq',
        quality: ImageQuality.low,
      );
      return;
    }
    persistVisionResult(
      context,
      testName: 'Distance visual acuity',
      eye: forEye,
      conditionsVerified: calibrated,
      measurement: '$level ($forEye eye) at 3 m, full brightness; $displayNote',
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'Measured visual acuity (screening)',
      limitations: const [
        'Screening measurement, not a prescription and not a diagnosis.',
        'Distance verified by operator checklist only.',
      ],
      recommendedAction:
          'Repeat per eye with calibrated distance. Consider a full eye examination for reduced acuity.',
      whyFlagged: '$resultText Sequence: $seq',
      quality: ImageQuality.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    // Real system check OUTSIDE the locked subtree: any OS text scaling
    // invalidates optotype sizing.
    final sysScale =
        MediaQuery.of(context).textScaler.scale(14) / 14;
    final scaleOk = (sysScale - 1.0).abs() < 0.01;
    final level = acuityLevels[_stairs.level];
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = _letterSizePx(dpr);
    // V2 pixel-limit cap: strokes below ~2 physical px are aliased art,
    // not a testable level.
    final beyondDisplay = _strokePhysicalPx(dpr) < 2.0;
    final displayNote = _cardPxPerMm != null
        ? s.cardCalibratedNote
        : ((_display?.valid ?? false)
            ? s.visionDisplayMeasured(_display!.ydpi)
            : s.visionDisplayUncalibrated);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        SafetyBanner(text: s.distanceBanner),
        const SizedBox(height: 10),
        const _TestVisual(_TestVisualKind.distance),
        const SizedBox(height: 10),
        if (!started) ...[
          _TestIntro(
            purpose: s.distIntroPurpose,
            time: s.visionDuration2min,
            distance: s.distanceDistValue,
            environment: s.distanceLightValue,
            eyes: s.eyeBothLabel,
            calibration: s.distIntroCalib,
            onBegin: _begin,
          ),
        ] else if (_done) ...[
          _VisionResultCard(
            test: s.visionTabDistance,
            result: _thresholds.entries
                .map((e) =>
                    'Measured visual acuity (${e.key} eye): ${e.value}. Screening measurement, not a prescription and not a diagnosis.')
                .join('\n'),
            conditions:
                '${s.distanceDistValue} • ${s.distanceScreenValue} • ${s.distanceLightValue} • $displayNote',
            reliability: calibrated
                ? s.distanceCalibOn
                : s.distanceCalibOff,
            limitation: calibrated
                ? 'Screening measurement, not a prescription and not a diagnosis.'
                : 'Test distance was not verified at 3 m.',
            nextStep: calibrated
                ? 'Repeat per eye with calibrated distance. Consider a full eye examination for reduced acuity.'
                : 'Repeat with the phone at 3 m and full brightness.',
            sequence: _sequences.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: _restart, child: Text(s.restartTest)),
        ] else ...[
          _EyeSelector(
              eye: eye,
              onChanged: (v) => setState(() {
                    eye = v;
                    started = false;
                    _done = false;
                  })),
          const SizedBox(height: 8),
          CheckboxListTile(
              value: _distOk,
              onChanged: (v) =>
                  setState(() => _distOk = v ?? false),
              title: Text(s.distanceCheckDist),
              controlAffinity: ListTileControlAffinity.leading),
          CheckboxListTile(
              value: _brightOk,
              onChanged: (v) =>
                  setState(() => _brightOk = v ?? false),
              title: Text(s.distanceCheckBright),
              controlAffinity: ListTileControlAffinity.leading),
          if (!calibrated)
            SafetyBanner(text: s.distanceUncalibratedWarn),
          if (!scaleOk) SafetyBanner(text: s.textScaleWarn),
          const SizedBox(height: 8),
          _CalibrationHeader(
            distance: s.distanceDistValue,
            screen: s.distanceScreenValue,
            lighting: s.distanceLightValue,
            eye: s.eyeName(_currentEye),
            status: calibrated ? s.distanceCalibOn : s.distanceCalibOff,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _showCardCal = !_showCardCal),
            icon: const Icon(Icons.credit_card_outlined),
            label: Text(s.cardCalTitle),
          ),
          if (_showCardCal) ...[
            const SizedBox(height: 8),
            Text(s.cardCalBody, style: t.bodySmall),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: _cardBoxPx,
                height: _cardBoxPx *
                    CardCalibration.cardHeightMm /
                    CardCalibration.cardWidthMm,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFF0A5E5D), width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(s.cardCalBoxLine(_cardBoxPx),
                textAlign: TextAlign.center, style: t.bodySmall),
            Slider(
              value: _cardBoxPx,
              min: 120,
              max: 420,
              divisions: 300,
              label: s.cardCalBoxLine(_cardBoxPx),
              onChanged: (v) => setState(() => _cardBoxPx = v),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(
                onPressed: () {
                  final ppm =
                      CardCalibration.pxPerMm(_cardBoxPx);
                  if (ppm > 0) {
                    setState(() {
                      _cardPxPerMm = ppm;
                      _showCardCal = false;
                    });
                  }
                },
                child: Text(s.cardCalUse),
              ),
              if (_cardPxPerMm != null)
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _cardPxPerMm = null),
                  child: Text(s.cardCalClear),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          Center(child: Text(s.eyeName(_currentEye), style: t.titleMedium)),
          Center(
              // Tumbling optotype: the rotation IS the question, so the
              // letter renders rotated (E/C limbs point the answer way).
              child: RotatedBox(
                  quarterTurns: _opt.rotationDeg ~/ 90,
                  child: Text(_opt.symbol,
                      style: TextStyle(
                          fontSize: size * 2,
                          fontWeight: FontWeight.w800)))),
          Center(
              child: Text(
                  '${level.label} • ${s.staircaseProgress(_stairs.history.length, _stairs.reversals)}',
                  style: t.bodySmall)),
          if (beyondDisplay) ...[
            const SizedBox(height: 6),
            SafetyBanner(text: s.visionBeyondDisplay),
          ],
          Center(
              child: Text(s.tumblingHint, style: t.bodySmall)),
          const SizedBox(height: 12),
          // Forced choice (V1): which way do the limbs point? Direction
          // arrows are language-neutral. This measures recognition, not
          // self-reported detection. Full-width row (not a wrap) keeps
          // every target tappable on small screens and in tests.
          Row(children: [
            // Direction buttons driven by the pinned truth table in
            // VisionLogic.directionArrow (a previous inline mapping was
            // rotated 90° off and scored correct answers wrong).
            for (final deg in const [0, 90, 180, 270])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FilledButton(
                      onPressed: () =>
                          _answer(deg == _opt.rotationDeg),
                      child: Text(
                          VisionLogic.directionArrow(deg),
                          style: const TextStyle(fontSize: 22))),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _NearAcuity extends StatefulWidget {
  final ValueChanged<String>? onDone;
  const _NearAcuity({this.onDone});
  @override
  State<_NearAcuity> createState() => _NearAcuityState();
}

class _NearAcuityState extends State<_NearAcuity> {
  String eye = 'right';
  int sizeIdx = 2;
  static const sizes = [18.0, 15.0, 12.0, 10.0, 8.0];
  bool started = false;
  String? result;
  DisplayMetrics? _display;

  @override
  void initState() {
    super.initState();
    fetchDisplayMetrics().then((m) {
      if (mounted) setState(() => _display = m);
    });
  }

  /// True letter height in mm from measured density, or -1 when the
  /// display is unmeasured (V4: points mean different mm per phone).
  double _letterMm(double logicalPx, double devicePixelRatio) {
    final d = _display;
    if (d == null || !d.valid) return -1;
    return logicalPx * devicePixelRatio / d.ydpi * 25.4;
  }
  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return ListView(padding: const EdgeInsets.all(20), children: [
      SafetyBanner(text: s.nearBanner),
      const SizedBox(height: 10),
      const _TestVisual(_TestVisualKind.near),
      const SizedBox(height: 10),
      if (!started)
        _TestIntro(
          purpose: s.nearIntroPurpose,
          time: s.visionDuration1min,
          distance: s.nearDistValue,
          environment: s.nearLightValue,
          eyes: s.eyeBothLabel,
          calibration: s.nearStatusValue,
          onBegin: () => setState(() => started = true),
        )
      else if (result != null) ...[
        _VisionResultCard(
          test: s.visionTabNear,
          result: result!,
          conditions:
              '${s.nearDistValue} • ${s.distanceScreenValue} • ${s.nearLightValue} • ${s.eyeName(eye)}',
          reliability: s.nearStatusValue,
          limitation:
              'Screening measurement, not a prescription and not a diagnosis. Hold distance maintained by operator only.',
          nextStep:
              'Repeat per eye at the stated distance. Do not infer a glasses prescription.',
        ),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: () => setState(() {
                  started = false;
                  result = null;
                  sizeIdx = 2;
                }),
            child: Text(s.restartTest)),
      ] else ...[
        _CalibrationHeader(
          distance: s.nearDistValue,
          screen: s.distanceScreenValue,
          lighting: s.nearLightValue,
          eye: s.eyeName(eye),
          status: s.nearStatusValue,
        ),
        const SizedBox(height: 10),
        _EyeSelector(
            eye: eye,
            onChanged: (v) => setState(() {
                  eye = v;
                  sizeIdx = 2;
                })),
        const SizedBox(height: 12),
        Text('The quick brown fox jumps over the lazy dog 1234567890',
          style: TextStyle(fontSize: sizes[sizeIdx])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => setState(() =>
                      sizeIdx = (sizeIdx + 1).clamp(0, sizes.length - 1)),
                  child: Text(s.nearTooSmall))),
          const SizedBox(width: 8),
          Expanded(
              child: FilledButton(
                  onPressed: () {
                    final mm = _letterMm(sizes[sizeIdx],
                        MediaQuery.devicePixelRatioOf(context));
                    final sizeNote = mm > 0
                        ? 'true ~${mm.toStringAsFixed(1)} mm letters'
                        : 'display unmeasured: sizes approximate';
                    final text =
                        'Near-vision screening ($eye eye): comfortable at ${sizes[sizeIdx].toStringAsFixed(0)} pt ($sizeNote) at ~40 cm. Screening only.';
                    setState(() => result = text);
                    persistVisionResult(
                      context,
                      testName: 'Near visual acuity',
                      eye: eye,
                      measurement:
                          '${sizes[sizeIdx].toStringAsFixed(0)} pt comfortable ($eye eye) at ~40 cm; $sizeNote',
                      finding: ResultCategory.noObviousAbnormality,
                      findingLabel: 'Measured near vision (screening)',
                      limitations: const [
                        'Screening measurement, not a prescription and not a diagnosis.',
                        'Hold distance maintained by operator only.',
                      ],
                      recommendedAction:
                          'Repeat per eye at the stated distance. Do not infer a glasses prescription.',
                      whyFlagged: text,
                    );
                    widget.onDone?.call('near');
                  },
                  child: Text(s.nearCanRead))),
        ]),
      ],
    ]);
  }
}

class _ColorTest extends StatefulWidget {
  final ValueChanged<String>? onDone;
  const _ColorTest({this.onDone});
  @override
  State<_ColorTest> createState() => _ColorTestState();
}

class _ColorTestState extends State<_ColorTest> {
  bool started = false;
  // Display preflight: generated plates are meaningless with night mode
  // or color filters on. Both must be confirmed OFF before _begin runs,
  // and the confirmations are stored in the persisted measurement.
  bool _nightOff = false;
  bool _filtersOff = false;
  bool _prefWarn = false;
  int level = 0; // 0 easy, 1 medium, 2 hard
  List<int> order = const [0, 1, 2, 3];
  int pos = 0;
  int errors = 0;
  final Map<String, int> levelErrors = {};
  final Map<String, int> axisErrors = {};
  int seed = 0;
  String? result;
  String _resultText = '';
  final TextEditingController _c = TextEditingController();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  static const _digitAlpha = [1.0, 0.8, 0.6];

  void _begin() {
    if (!(_nightOff && _filtersOff)) {
      setState(() => _prefWarn = true);
      return;
    }
    final s = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _prefWarn = false;
      started = true;
      level = 0;
      seed = s;
      order = seededShuffle(const [0, 1, 2, 3], s);
      pos = 0;
      errors = 0;
      levelErrors.clear();
      axisErrors.clear();
      result = null;
    });
  }

  void _restart() {
    setState(() {
      started = false;
      result = null;
    });
  }

  int get _plateIndex => level * 4 + order[pos.clamp(0, 3)];

  void _submit(AppStrings s) {
    final p = VisionLogic.colorPlate(_plateIndex);
    final ans = _c.text.trim();
    if (ans != p['answer']) {
      errors++;
      final lv = s.colorLevelLabel(level);
      levelErrors[lv] = (levelErrors[lv] ?? 0) + 1;
      axisErrors[p['axis'] as String] =
          (axisErrors[p['axis'] as String] ?? 0) + 1;
    }
    _c.clear();
    if (pos < 3) {
      setState(() => pos++);
    } else if (level < 2) {
      setState(() {
        level++;
        order = seededShuffle(const [0, 1, 2, 3], seed + level * 7919);
        pos = 0;
      });
    } else {
      final flagged = errors > 2;
      final breakdown =
          'by level: $levelErrors; by axis: $axisErrors; order seed: $seed';
      final text = flagged
          ? 'Color discrimination result suggests further assessment may be useful (errors: $errors/12, $breakdown). Not a diagnosis of a specific color-vision disorder.'
          : 'No obvious color discrimination abnormality detected in this screening.';
      setState(() {
        result = text;
        _resultText = text;
      });
      persistVisionResult(
        context,
        testName: 'Color vision',
        eye: 'both',
        conditionsVerified: _nightOff && _filtersOff,
        measurement:
            '$errors/12 plates missed ($breakdown; generated plates, full brightness, night mode OFF + filters OFF operator-confirmed)',
        finding: flagged
            ? ResultCategory.possibleFinding
            : ResultCategory.noObviousAbnormality,
        findingLabel: flagged
            ? 'Color discrimination result suggests further assessment'
            : 'No obvious color discrimination abnormality (screening)',
        limitations: const [
          'Generated plates; not standardized plates.',
          'Display, brightness, and filters influence results.',
        ],
        recommendedAction: flagged
            ? 'Repeat with verified display conditions. Consider formal color-vision testing.'
            : 'No further action needed from this test.',
        whyFlagged: text,
      );
      widget.onDone?.call('color');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return ListView(padding: const EdgeInsets.all(20), children: [
      SafetyBanner(text: s.colorBanner),
      const SizedBox(height: 10),
      const _TestVisual(_TestVisualKind.color),
      const SizedBox(height: 10),
      if (!started) ...[
        _TestIntro(
          purpose: s.colorIntroPurpose,
          time: s.visionDuration2min,
          distance: s.colorDistValue,
          environment: s.colorLightValue,
          eyes: s.colorEyeValue,
          calibration: s.colorStatusValue,
          onBegin: _begin,
        ),
        CheckboxListTile(
          value: _nightOff,
          onChanged: (v) => setState(() => _nightOff = v ?? false),
          title: Text(s.colorCheckNight),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _filtersOff,
          onChanged: (v) => setState(() => _filtersOff = v ?? false),
          title: Text(s.colorCheckFilters),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_prefWarn)
          SafetyBanner(text: s.colorStatusValue),
      ]
      else if (result != null) ...[
        _VisionResultCard(
          test: s.visionTabColor,
          result: _resultText,
          conditions:
              '${s.colorDistValue} • ${s.colorScreenValue} • ${s.colorLightValue}',
          reliability: s.colorStatusValue,
          limitation:
              'Generated plates; not standardized plates. Display, brightness, and filters influence results.',
          nextStep: errors > 2
              ? 'Repeat with verified display conditions. Consider formal color-vision testing.'
              : 'No further action needed from this test.',
          sequence:
              '${s.colorScoreLine(errors, 12)} • ${s.colorLevelLabel(0)}:${levelErrors[s.colorLevelLabel(0)] ?? 0} '
              '${s.colorLevelLabel(1)}:${levelErrors[s.colorLevelLabel(1)] ?? 0} '
              '${s.colorLevelLabel(2)}:${levelErrors[s.colorLevelLabel(2)] ?? 0}',
        ),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: _restart, child: Text(s.restartTest)),
      ] else
        _colorRound(s),
    ]);
  }

  Widget _colorRound(AppStrings s) {
    final p = VisionLogic.colorPlate(_plateIndex);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CalibrationHeader(
        distance: s.colorDistValue,
        screen: s.colorScreenValue,
        lighting: s.colorLightValue,
        eye: s.colorEyeValue,
        status: s.colorStatusValue,
      ),
      const SizedBox(height: 10),
      SafetyBanner(text: s.colorBrightnessWarn),
      const SizedBox(height: 10),
      Text(
          '${s.colorLevelLabel(level)} • ${s.plateLine(pos + 1, '${p['axis']}')}',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Container(
        height: 180, alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8E6)), borderRadius: BorderRadius.circular(10),
          color: _axisColor(p['axis'] as String),
        ),
        child: Text('${p['answer']}',
            style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: Colors.white
                    .withValues(alpha: _digitAlpha[level]))),
      ),
      const SizedBox(height: 8),
      Text(s.colorPrompt),
      TextField(controller: _c, keyboardType: TextInputType.text, inputFormatters: [LengthLimitingTextInputFormatter(2)],
        decoration: InputDecoration(border: const OutlineInputBorder(), hintText: s.colorHint)),
      const SizedBox(height: 8),
      FilledButton(
          onPressed: () => _submit(s),
          child: Text(pos < 3 || level < 2 ? s.nextPlate : s.finish)),
    ]);
  }

  Color _axisColor(String axis) {
    switch (axis) {
      case 'protan': return const Color(0xFF7A9B6D);
      case 'deutan': return const Color(0xFF8A7FA8);
      default: return const Color(0xFF6D94A8);
    }
  }
}

class _ContrastTest extends StatefulWidget {
  final ValueChanged<String>? onDone;
  const _ContrastTest({this.onDone});
  @override
  State<_ContrastTest> createState() => _ContrastTestState();
}

class _ContrastTestState extends State<_ContrastTest> {
  bool started = false;
  late Staircase _stairs;
  String? result;
  String _resultText = '';
  String _resultSeq = '';
  // Recorded condition (V6): the threshold is condition-bound, so the
  // brightness it was measured at must travel with the result.
  double _brightness = 1.0;

  @override
  void initState() {
    super.initState();
    _stairs = Staircase(level: 3, max: VisionLogic.contrastSteps.length - 1);
  }

  void _begin() {
    setState(() {
      started = true;
      _stairs = Staircase(level: 3, max: VisionLogic.contrastSteps.length - 1);
      result = null;
    });
  }

  void _respond(bool seen) {
    _stairs.respond(seen);
    if (_stairs.done) {
      final pct =
          (VisionLogic.contrastSteps[_stairs.threshold] * 100).toStringAsFixed(0);
      final seq = _stairs.history
          .map((h) =>
              '${(VisionLogic.contrastSteps[h.$1] * 100).toStringAsFixed(0)}%${h.$2 ? '✓' : '✗'}')
          .join(' ');
      final text =
          'Contrast sensitivity screening result: threshold near $pct%. Avoid invented normal ranges on uncalibrated displays.';
      setState(() {
        result = text;
        _resultText = text;
        _resultSeq = seq;
      });
      persistVisionResult(
        context,
        testName: 'Contrast sensitivity',
        measurement:
            'Threshold near $pct% at ${(_brightness * 100).toStringAsFixed(0)}% screen brightness, ~1 m (adaptive, ${_stairs.history.length} trials)',
        finding: ResultCategory.noObviousAbnormality,
        findingLabel: 'Contrast threshold recorded (screening)',
        limitations: const [
          'No norms for uncalibrated displays.',
          'Threshold is condition-bound.',
        ],
        recommendedAction:
            'Repeat under identical recorded conditions for comparison.',
        whyFlagged: '$text Sequence: $seq',
      );
      widget.onDone?.call('contrast');
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    final c = VisionLogic.contrastSteps[_stairs.level];
    return ListView(padding: const EdgeInsets.all(20), children: [
      SafetyBanner(text: s.contrastBanner),
      const SizedBox(height: 10),
      const _TestVisual(_TestVisualKind.contrast),
      const SizedBox(height: 10),
      if (!started) ...[
        _TestIntro(
          purpose: s.contrastIntroPurpose,
          time: s.visionDuration2min,
          distance: s.contrastDistValue,
          environment: s.contrastLightValue,
          eyes: s.contrastEyeValue,
          calibration: s.contrastStatusValue,
          onBegin: _begin,
        ),
        const SizedBox(height: 8),
        Text(s.contrastBrightnessLabel, style: t.bodyMedium),
        SegmentedButton<double>(
          segments: const [
            ButtonSegment(value: 0.5, label: Text('50%')),
            ButtonSegment(value: 0.75, label: Text('75%')),
            ButtonSegment(value: 1.0, label: Text('100%')),
          ],
          selected: {_brightness},
          onSelectionChanged: (v) =>
              setState(() => _brightness = v.first),
        ),
      ]
      else if (result != null) ...[
        _VisionResultCard(
          test: s.visionTabContrast,
          result: _resultText,
          conditions:
              '${s.contrastDistValue} • ${s.contrastScreenValue} • ${s.contrastLightValue}',
          reliability: s.contrastStatusValue,
          limitation:
              'No norms for uncalibrated displays. Threshold is condition-bound.',
          nextStep:
              'Repeat under identical recorded conditions for comparison.',
          sequence: _resultSeq,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: () =>
                setState(() => started = false),
            child: Text(s.restartTest)),
      ] else ...[
        _CalibrationHeader(
          distance: s.contrastDistValue,
          screen: s.contrastScreenValue,
          lighting: s.contrastLightValue,
          eye: s.contrastEyeValue,
          status: s.contrastStatusValue,
        ),
        const SizedBox(height: 10),
        Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFFE2E8E6)),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white),
            child: Text('OcuScan',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: c)))),
        Text(
            '${s.contrastLine(c * 100, _stairs.history.length + 1, _stairs.maxTrials)} • ${s.staircaseProgress(_stairs.history.length, _stairs.reversals)}',
            style: t.bodySmall),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: () => _respond(true),
                  child: Text(s.contrastSee))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton(
                  onPressed: () => _respond(false),
                  child: Text(s.contrastCannotSee))),
        ]),
      ],
    ]);
  }
}

class _CentralTest extends StatefulWidget {
  final ValueChanged<String>? onDone;
  const _CentralTest({this.onDone});
  @override
  State<_CentralTest> createState() => _CentralTestState();
}

class _CentralTestState extends State<_CentralTest> {
  String eye = 'right';
  final Set<int> marked = {};
  bool started = false;
  Map<String, List<int>> done = {};
  String? result;
  String _resultText = '';
  // Glasses on/off changes the meaning of a distortion map; recorded
  // with the result (V7 protocol lock).
  bool _glasses = false;

  void _begin() {
    setState(() {
      started = true;
      done = {};
      marked.clear();
      result = null;
    });
  }

  void _restart() {
    setState(() {
      started = false;
      done = {};
      marked.clear();
      result = null;
    });
  }

  void _submit(AppStrings s) {
    final cells = marked.toList()..sort();
    done[eye] = cells;
    if (eye == 'right') {
      // Sequential per-eye protocol: right first, then left.
      setState(() {
        eye = 'left';
        marked.clear();
      });
      return;
    }
    final parts = <String>[];
    bool flagged = false;
    for (final e in ['right', 'left']) {
      if (!done.containsKey(e)) {
        parts.add('$e eye: not tested');
        continue;
      }
      final m = done[e]!;
      if (m.isNotEmpty) flagged = true;
      parts.add(m.isEmpty
          ? 'No regions marked ($e eye)'
          : '${m.length} region(s) marked ($e eye): ${m.join(',')}');
    }
      final glassesNote =
          _glasses ? s.centralGlassesOn : s.centralGlassesOff;
      final text = flagged
          ? 'Central-vision distortion was reported during screening (${parts.join('; ')}; $glassesNote). Consider prompt professional evaluation for new persistent distortion.'
          : 'No central-vision distortion reported (right eye; left eye; $glassesNote) in this screening.';
    setState(() {
      result = text;
      _resultText = text;
    });
    persistVisionResult(
      context,
      testName: 'Central vision',
      measurement: parts.join('; '),
      finding: flagged
          ? ResultCategory.possibleFinding
          : ResultCategory.noObviousAbnormality,
      findingLabel: flagged
          ? 'Central-vision distortion was reported (screening)'
          : 'No distortion reported (screening)',
      limitations: const [
        'Self-reported; screening only — not an AMD diagnosis.',
        'Fixation and distance maintained by operator only.',
      ],
      recommendedAction: flagged
          ? 'Repeat per eye. Seek prompt evaluation for new persistent distortion.'
          : 'No further action needed from this test.',
      whyFlagged: text,
    );
    widget.onDone?.call('central');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return ListView(padding: const EdgeInsets.all(20), children: [
      SafetyBanner(text: s.centralBanner),
      const SizedBox(height: 10),
      const _TestVisual(_TestVisualKind.central),
      const SizedBox(height: 10),
      if (!started) ...[
        _TestIntro(
          purpose: s.centralIntroPurpose,
          time: s.visionDuration2min,
          distance: s.centralDistValue,
          environment: s.centralLightValue,
          eyes: s.eyeBothLabel,
          calibration: s.centralStatusValue,
          onBegin: _begin,
        ),
        CheckboxListTile(
          value: _glasses,
          onChanged: (v) => setState(() => _glasses = v ?? false),
          title: Text(s.centralGlassesCheck),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ]
      else if (result != null) ...[
        _VisionResultCard(
          test: s.visionTabCentral,
          result: _resultText,
          conditions:
              '${s.centralDistValue} • ${s.centralScreenValue} • ${s.centralLightValue} • ${_glasses ? s.centralGlassesOn : s.centralGlassesOff}',
          reliability: s.centralStatusValue,
          limitation:
              'Self-reported; screening only — not an AMD diagnosis. Fixation and distance maintained by operator only.',
          nextStep: _resultText.startsWith('No central')
              ? 'No further action needed from this test.'
              : 'Repeat per eye. Seek prompt evaluation for new persistent distortion.',
          sequence: done.entries
              .map((e) =>
                  '${e.key}: ${e.value.isEmpty ? '—' : e.value.join(',')}')
              .join('  '),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: _restart, child: Text(s.restartTest)),
      ] else ...[
        _CalibrationHeader(
          distance: s.centralDistValue,
          screen: s.centralScreenValue,
          lighting: s.centralLightValue,
          eye: s.eyeName(eye),
          status: s.centralStatusValue,
        ),
        const SizedBox(height: 10),
        // Protocol lock (V7): free eye-switching mid-run clears `marked`
        // and corrupts the per-eye maps, so the selector locks once any
        // marks exist or an eye is done. Restart to change eyes.
        _EyeSelector(
            eye: eye,
            onChanged: (marked.isNotEmpty || done.isNotEmpty)
                ? null
                : (v) => setState(() {
                      eye = v;
                      marked.clear();
                    })),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7),
          itemCount: 49,
          itemBuilder: (_, i) {
            final center = i == 24;
            final bad = marked.contains(i);
            // A11y: color alone must not carry marked state; every cell
            // is a labeled button with selected state + check icon.
            return Semantics(
              button: true,
              selected: bad,
              label: center
                  ? s.centralGridCenter
                  : s.centralGridCell(i + 1, bad),
              child: InkWell(
                onTap: () => setState(
                    () => bad ? marked.remove(i) : marked.add(i)),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFF0E7C7B), width: 0.6),
                    color: bad
                        ? const Color(0xFFF3D9A4)
                        : (center
                            ? const Color(0xFFEDF5F4)
                            : Colors.white),
                  ),
                  child: bad
                      ? const Icon(Icons.check_outlined, size: 14)
                      : center
                          ? const Icon(Icons.fiber_manual_record,
                              size: 10, color: Color(0xFF0A5E5D))
                          : null,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => setState(() => marked.clear()),
                  child: Text(s.centralReset))),
          const SizedBox(width: 8),
          Expanded(
              child: FilledButton(
                  onPressed: () => _submit(s),
                  child: Text(s.submitGrid))),
        ]),
        if (eye == 'left' && done.containsKey('right'))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(s.centralNextEye,
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    ]);
  }
}

class _PeripheralTest extends StatefulWidget {
  final ValueChanged<String>? onDone;
  const _PeripheralTest({this.onDone});
  @override
  State<_PeripheralTest> createState() => _PeripheralTestState();
}

class _PeripheralTestState extends State<_PeripheralTest> {
  String eye = 'right';
  bool started = false;
  List<String> order = [];
  int seed = 0;
  int trial = 0;
  final Map<String, bool> seen = {};
  final Map<String, int> reactionMs = {};
  int falsePositives = 0;
  int _flashAtMs = 0;
  String? result;
  String _resultText = '';
  bool showDot = false;
  // Auto-flash arming (V8): the user presses Start, the flash fires after
  // a seeded random delay. Generation guard cancels stale timers on
  // advance/restart so a late flash can never leak into the next trial.
  bool _armed = false;
  int _flashGen = 0;
  DisplayMetrics? _display;

  @override
  void initState() {
    super.initState();
    fetchDisplayMetrics().then((m) {
      if (mounted) setState(() => _display = m);
    });
  }

  void _begin() {
    final s = DateTime.now().millisecondsSinceEpoch;
    final regions = seededShuffle(
        List<String>.of(VisionLogic.fieldRegions), s);
    // Two catch trials (no flash): answering "seen" counts as false positive.
    regions.insert(3, 'none');
    regions.insert(7, 'none');
    _flashGen++;
    setState(() {
      started = true;
      seed = s;
      order = regions;
      trial = 0;
      seen.clear();
      reactionMs.clear();
      falsePositives = 0;
      result = null;
      showDot = false;
      _armed = false;
    });
  }

  void _restart() {
    _flashGen++;
    setState(() {
      started = false;
      result = null;
      showDot = false;
      _armed = false;
    });
  }

  String get _region => order[trial % order.length];

  /// Dot diameter in logical px for a constant 26-arcmin stimulus at the
  /// nominal 60 cm arm's length (V9). Falls back to 18 px, labeled
  /// approximate in the persisted measurement.
  double _dotPx(double devicePixelRatio) {
    final d = _display;
    if (d != null && d.valid) {
      final px = d.logicalPixelsForArcMin(
          arcMin: 26, distanceMm: 600, devicePixelRatio: devicePixelRatio);
      if (px > 0) return px;
    }
    return 18;
  }

  void _armFlash() {
    final gen = ++_flashGen;
    setState(() => _armed = true);
    // Seeded 0.8–3 s delay: unpredictable to the subject, reproducible
    // in the record (seed + trial are persisted).
    final delay = 800 + (seed + trial * 997) % 2200;
    Future.delayed(Duration(milliseconds: delay), () async {
      if (!mounted || gen != _flashGen) return;
      setState(() {
        showDot = _region != 'none';
        _armed = false;
      });
      _flashAtMs = DateTime.now().millisecondsSinceEpoch;
      final hide = 400 + (seed + trial * 131) % 800;
      final hideGen = _flashGen;
      await Future.delayed(Duration(milliseconds: hide));
      if (!mounted || hideGen != _flashGen) return;
      setState(() => showDot = false);
    });
  }

  void _seen() {
    final r = _region;
    if (r == 'none') {
      // Catch trial answered seen: false positive, no reaction recorded.
      setState(() => falsePositives++);
    } else {
      seen[r] = true;
      reactionMs[r] =
          DateTime.now().millisecondsSinceEpoch - _flashAtMs;
    }
    _advance();
  }

  void _missed() {
    final r = _region;
    if (r != 'none') seen[r] = false;
    _advance();
  }

  void _advance() {
    _flashGen++;
    if (trial < order.length - 1) {
      setState(() {
        trial++;
        showDot = false;
        _armed = false;
      });
    } else {
      _savePeripheral();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      SafetyBanner(text: s.peripheralBanner),
      const SizedBox(height: 10),
      const _TestVisual(_TestVisualKind.peripheral),
      const SizedBox(height: 10),
      if (!started)
        _TestIntro(
          purpose: s.peripheralIntroPurpose,
          time: s.visionDuration3min,
          distance: s.peripheralDistValue,
          environment: s.peripheralLightValue,
          eyes: s.eyeBothLabel,
          calibration: s.peripheralStatusValue,
          onBegin: _begin,
        )
      else if (result != null) ...[
        _VisionResultCard(
          test: s.visionTabPeripheral,
          result: _resultText,
          conditions:
              '${s.peripheralDistValue} • ${s.peripheralScreenValue} • ${s.peripheralLightValue} • ${s.eyeName(eye)}',
          reliability: s.peripheralStatusValue,
          limitation:
              'Screening experiment — not a perimeter replacement. Fixation maintained by operator only.',
          nextStep: _resultText.startsWith('No peripheral')
              ? 'No further action needed from this test.'
              : 'Repeat in a dark quiet room. Consider professional visual-field testing if persistent.',
          sequence:
              'seen ${seen.values.where((v) => v).length}/${VisionLogic.fieldRegions.length} • '
              'false positives $falsePositives • '
              'order seed $seed',
        ),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: _restart, child: Text(s.restartTest)),
      ] else ...[
        _CalibrationHeader(
          distance: s.peripheralDistValue,
          screen: s.peripheralScreenValue,
          lighting: s.peripheralLightValue,
          eye: s.eyeName(eye),
          status: s.peripheralStatusValue,
        ),
        const SizedBox(height: 10),
        _EyeSelector(
            eye: eye,
            onChanged: (v) => setState(() {
                  eye = v;
                  _begin();
                })),
        const SizedBox(height: 10),
        Text(s.peripheralFixationNote, style: t.bodySmall),
        const SizedBox(height: 6),
        Container(
            height: 260,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border:
                    Border.all(color: const Color(0xFFE2E8E6)),
                borderRadius: BorderRadius.circular(10)),
            child: Stack(alignment: Alignment.center, children: [
              const Text('+', style: TextStyle(fontSize: 40)),
              if (showDot)
                Align(
                    alignment: _align(_region),
                    child: Container(
                        width: _dotPx(
                            MediaQuery.devicePixelRatioOf(context)),
                        height: _dotPx(
                            MediaQuery.devicePixelRatioOf(context)),
                        decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle))),
            ])),
        // V8: trial progress never leaks the flash region.
        Text(
            '${s.trialCountLine(trial + 1, order.length)} • ${s.reactionLine(reactionMs[_region] ?? 0)}',
            style: t.bodySmall),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: _armed ? null : _armFlash,
                  child: Text(s.periphArmFlash))),
          const SizedBox(width: 8),
          Expanded(
              child: FilledButton(
                  onPressed: _seen, child: Text(s.sawIt))),
        ]),
        TextButton(onPressed: _missed, child: Text(s.missedNext)),
      ],
    ]);
  }

  void _savePeripheral() {
    final dotNote = (_display?.valid ?? false)
        ? 'dot ~26 arcmin at ~60 cm arm\u2019s length'
        : 'dot 18 px (display unmeasured: size approximate)';
    final missed = VisionLogic.fieldRegions
        .where((r) => !(seen[r] ?? false))
        .toList();
    final meanRt = reactionMs.isEmpty
        ? 0
        : reactionMs.values.fold<int>(0, (a, b) => a + b) ~/
            reactionMs.length;
    final text = missed.isEmpty && falsePositives == 0
        ? 'No peripheral-field deficit suggested ($eye eye) in this screening.'
        : 'Possible peripheral-field deficit detected ($eye eye; missed: ${missed.isEmpty ? 'none' : missed.join(', ')}; false positives: $falsePositives; mean reaction ${meanRt}ms). Consider professional visual-field testing if persistent.';
    setState(() {
      result = text;
      _resultText = text;
      showDot = false;
    });
    persistVisionResult(
      context,
      testName: 'Peripheral visual field',
      measurement: missed.isEmpty && falsePositives == 0
          ? 'All regions seen ($eye eye), mean reaction ${meanRt}ms, 0 false positives; $dotNote'
          : 'Missed: ${missed.isEmpty ? 'none' : missed.join(', ')} ($eye eye), false positives: $falsePositives, mean reaction: ${meanRt}ms; $dotNote',
      finding: missed.isEmpty && falsePositives == 0
          ? ResultCategory.noObviousAbnormality
          : ResultCategory.possibleFinding,
      findingLabel: missed.isEmpty && falsePositives == 0
          ? 'No deficit suggested (screening)'
          : 'Possible peripheral-field deficit (screening)',
      limitations: const [
        'Screening experiment — not a perimeter replacement.',
        'Fixation maintained by operator only.',
      ],
      recommendedAction: missed.isEmpty && falsePositives == 0
          ? 'No further action needed from this test.'
          : 'Repeat in a dark quiet room. Consider professional visual-field testing if persistent.',
      whyFlagged: text,
    );
    widget.onDone?.call('peripheral');
  }

  Alignment _align(String region) {
    switch (region) {
      case 'upper':
        return Alignment.topCenter;
      case 'upper-right':
        return Alignment.topRight;
      case 'right':
        return Alignment.centerRight;
      case 'lower-right':
        return Alignment.bottomRight;
      case 'lower':
        return Alignment.bottomCenter;
      case 'lower-left':
        return Alignment.bottomLeft;
      case 'left':
        return Alignment.centerLeft;
      default:
        return Alignment.topLeft;
    }
  }
}

class _CoverTest extends StatefulWidget {
  final ValueChanged<String>? onDone;
  const _CoverTest({this.onDone});
  @override
  State<_CoverTest> createState() => _CoverTestState();
}

class _CoverTestState extends State<_CoverTest> {
  int phase = 0;
  // Timed dwells (V10): each phase should be HELD ~10 s for dissociation.
  // Countdown is guidance with a skip (accessibility); completed dwells
  // travel with the persisted record. Generation-guarded like flashes.
  int _dwellLeft = 0;
  int _dwellGen = 0;
  final Set<int> _dwellsDone = {};
  static String _phaseCode(int phase) {
    switch (phase) {
      case 0:
        return 'center';
      case 1:
        return 'coverL';
      case 2:
        return 'uncover1';
      case 3:
        return 'coverR';
      default:
        return 'uncover2';
    }
  }

  String? movement;
  bool started = false;

  /// Start the 10 s hold countdown for the current phase. Skippable,
  /// generation-guarded, never blocks phase navigation.
  void _startDwell() {
    final gen = ++_dwellGen;
    _tickDwell(10, gen);
  }

  void _tickDwell(int left, int gen) async {
    if (gen != _dwellGen || !mounted) return;
    setState(() => _dwellLeft = left);
    if (left <= 0) {
      setState(() => _dwellsDone.add(phase));
      return;
    }
    await Future.delayed(const Duration(seconds: 1));
    _tickDwell(left - 1, gen);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return ListView(padding: const EdgeInsets.all(20), children: [
      SafetyBanner(text: s.coverBanner),
      const SizedBox(height: 10),
      const _TestVisual(_TestVisualKind.cover),
      const SizedBox(height: 10),
      if (!started)
        _TestIntro(
          purpose: s.coverIntroPurpose,
          time: s.visionDuration2min,
          distance: s.coverDistValue,
          environment: s.coverLightValue,
          eyes: s.coverEyeValue,
          calibration: s.coverStatusValue,
          onBegin: () {
            setState(() => started = true);
            _startDwell();
          },
        )
      else ...[
        _CalibrationHeader(
          distance: s.coverDistValue,
          screen: s.coverScreenValue,
          lighting: s.coverLightValue,
          eye: s.coverEyeValue,
          status: s.coverStatusValue,
        ),
        const SizedBox(height: 10),
      Text(s.coverStepLine(phase + 1, s.coverPhase(_phaseCode(phase))), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      if (_dwellLeft > 0) ...[
        Text(s.coverDwellLine(_dwellLeft),
            style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
          onPressed: () {
            _dwellGen++;
            setState(() => _dwellLeft = 0);
          },
          child: Text(s.coverDwellSkip)),
        const SizedBox(height: 4),
      ],
      const SizedBox(height: 10),
      Container(alignment: Alignment.center, height: 120,
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8E6)), borderRadius: BorderRadius.circular(10)),
        child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFF0A5E5D), shape: BoxShape.circle))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: phase > 0 ? () { _dwellGen++; setState(() { phase--; _dwellLeft = 0; }); } : null, child: Text(s.back))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(onPressed: phase < 4 ? () { setState(() => phase++); _startDwell(); } : null, child: Text(s.continueBtn))),
      ]),
      const SizedBox(height: 10),
      Text(s.coverAskMovement),
      Wrap(spacing: 8, children: [
        ChoiceChip(label: Text(s.coverNoMovement), selected: movement == 'none', onSelected: (_) => setState(() => movement = 'none')),
        ChoiceChip(label: Text(s.coverSmallShift), selected: movement == 'small', onSelected: (_) => setState(() => movement = 'small')),
        ChoiceChip(label: Text(s.coverClearMovement), selected: movement == 'clear', onSelected: (_) => setState(() => movement = 'clear')),
      ]),
      if (movement != null)
        Padding(padding: const EdgeInsets.only(top: 10),
          child: SafetyBanner(text: movement == 'none'
              ? 'Alignment stability: no movement reported in this guided step.'
              : 'Observed eye movement ($movement) during cover steps. This visualization records movement only and does not diagnose a cause. Repeat carefully; consider professional evaluation if persistent.')),
      // Save unlocks only at the final phase (V10): rating at phase 0
      // without performing the sequence is not a cover test.
      if (movement != null && phase == 4) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            final flagged = movement != 'none';
            persistVisionResult(
              context,
              testName: 'Cover test',
              measurement: 'Cover sequence observation: $movement movement (timed 10 s dwells held: ${_dwellsDone.length}/5 phases)',
              finding: flagged
                  ? ResultCategory.possibleFinding
                  : ResultCategory.noObviousAbnormality,
              findingLabel: flagged
                  ? 'Observed eye movement during cover steps (screening)'
                  : 'No movement reported (screening)',
              limitations: const [
                'Observer-reported; the phone does not track gaze.',
                'Cannot replace clinician cover testing.',
              ],
              recommendedAction: flagged
                  ? 'Repeat carefully; consider professional evaluation if persistent.'
                  : 'No further action needed from this test.',
              whyFlagged:
                  'Guided cover/uncover sequence completed with $movement movement reported.',
            );
            widget.onDone?.call('cover');
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.coverSaved)));
          },
          icon: const Icon(Icons.save_outlined),
          label: Text(s.coverSave),
        ),
      ],
      const SizedBox(height: 10),
      SafetyBanner(text: s.coverRefractiveNote),
      const SizedBox(height: 10),
      OutlinedButton(
          onPressed: () {
            _dwellGen++;
            setState(() {
              started = false;
              phase = 0;
              movement = null;
              _dwellLeft = 0;
              _dwellsDone.clear();
            });
          },
          child: Text(s.restartTest)),
      ],
    ]);
  }
}
