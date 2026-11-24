// Research workspace analysis tabs: Devices, Lighting, Subjects,
// Measurements, Repeatability, Comparison, Failure Analysis, Export.
//
// All tables derive from recorded trials. Groups with no data render an
// honest empty state — never placeholder numbers.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/evidence/evidence_repository.dart';
import '../../../core/localization/dev_strings.dart';
import '../../../features/catalog/detection_catalog.dart';
import '../../../core/validation/analyzer_registry.dart';
import '../../../core/validation/device_info.dart';
import '../../../core/validation/experiment_models.dart';
import '../../../core/validation/export.dart';
import '../../../core/validation/statistics.dart';
import '../../../core/validation/validation_repository.dart';
import '../../widgets/common.dart';
import 'analyzer_info_screen.dart';
import 'dev_widgets.dart';

DevStrings _s(BuildContext context) => DevStrings(
    Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en');

// ---------- Devices ----------

class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});
  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  List<DeviceProfile> profiles = [];
  Map<String, int> trialCounts = {};
  bool loading = true;
  final _label = TextEditingController();
  final _camera = TextEditingController(text: 'front');
  final _resolution = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _label.dispose();
    _camera.dispose();
    _resolution.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<ValidationRepository>();
    profiles = await repo.listDeviceProfiles();
    trialCounts = {};
    for (final p in profiles) {
      trialCounts[p.deviceLabel] =
          (await repo.queryTrials(deviceLabel: p.deviceLabel)).length;
    }
    // Also count device labels seen in trials without a profile.
    final all = await repo.queryTrials();
    for (final t in all) {
      final d = t.deviceLabel ?? 'unspecified';
      trialCounts[d] = (trialCounts[d] ?? 0) + 0;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SafetyBanner(
          text: 'Instruments, not people. Device labels are anonymous (Device A, B, C…). '
              'No personal information is collected.'),
      const SizedBox(height: 8),
      if (profiles.isEmpty && trialCounts.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet))),
      for (final p in profiles)
        Card(
          child: ListTile(
            title: Text(p.deviceLabel),
            subtitle: Text(
                '${p.manufacturer ?? '—'} ${p.model ?? ''}\n'
                '${p.osVersion ?? '—'} • runtime ${p.runtimeVersion ?? '—'}\n'
                'camera ${p.camera ?? '—'} • ${p.resolution ?? '—'} • '
                '${trialCounts[p.deviceLabel] ?? 0} trials'),
          ),
        ),
      const SectionTitle('Register this instrument'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Anonymous label (e.g. Device A)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _camera,
                decoration: const InputDecoration(
                    labelText: 'Camera (front / rear)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _resolution,
                decoration: const InputDecoration(
                    labelText: 'Resolution (e.g. 1280×720)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                if (_label.text.trim().isEmpty) return;
                final size = MediaQuery.of(context).size;
                final snap = await collectDeviceProfile(
                  deviceLabel: _label.text.trim(),
                  camera: _camera.text.trim(),
                  resolution: _resolution.text.trim().isEmpty
                      ? null
                      : _resolution.text.trim(),
                  orientation:
                      MediaQuery.of(context).orientation.name,
                  screenWidthPx: size.width.toInt(),
                  screenHeightPx: size.height.toInt(),
                );
                if (context.mounted) {
                  await context
                      .read<ValidationRepository>()
                      .upsertDeviceProfile(snap);
                  setState(() => loading = true);
                  _load();
                }
              },
              child: Text(_s(context).recordInstrumentProfile),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ---------- Lighting ----------

class LightingTab extends StatefulWidget {
  const LightingTab({super.key});
  @override
  State<LightingTab> createState() => _LightingTabState();
}

class _LightingTabState extends State<LightingTab> {
  List<Trial> trials = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    trials = await context.read<ValidationRepository>().queryTrials();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (trials.isEmpty) {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(s.noDataYet)))
          ]);
    }
    // Group by testType, then lighting.
    final byTest = <String, Map<String, List<Trial>>>{};
    for (final t in trials) {
      final tt = t.testType ?? 'unspecified';
      final li = t.lightingLevel ?? 'unspecified';
      (byTest[tt] ??= {})[li] ??= [];
      byTest[tt]![li]!.add(t);
    }
    final luxValues = [
      for (final t in trials)
        if (t.lux != null) t.lux!
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SafetyBanner(
          text: 'Lighting → measurement → variance → failure rate. '
              'Levels are experiment labels (optionally with meter lux), not standards.'),
      if (luxValues.isNotEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    'Meter lux recorded: ${luxValues.length} trials, '
                    'range ${luxValues.reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}–'
                    '${luxValues.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)} lx'))),
      for (final entry in byTest.entries) ...[
        SectionTitle(entry.key),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final le in entry.value.entries)
                    Builder(builder: (_) {
                      final unable = le.value
                          .where((t) =>
                              t.status == TrialStatus.unable)
                          .length;
                      final rate =
                          unableRate(unable, le.value.length);
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(
                              child: Text(s.lightingLabel(le.key))),
                          Text(
                              'n=${le.value.length} • unable ${rate == null ? '—' : '${(rate * 100).toStringAsFixed(1)}%'}'),
                        ]),
                      );
                    }),
                ]),
          ),
        ),
      ],
    ]);
  }
}

// ---------- Subjects ----------

class SubjectsTab extends StatefulWidget {
  const SubjectsTab({super.key});
  @override
  State<SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<SubjectsTab> {
  Map<String, List<Trial>> bySubject = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trials =
        await context.read<ValidationRepository>().queryTrials();
    bySubject = {};
    for (final t in trials) {
      final k = (t.subjectId?.isEmpty ?? true)
          ? 'unspecified'
          : t.subjectId!;
      (bySubject[k] ??= []).add(t);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SafetyBanner(
          text: 'Anonymous research identifiers only (R001, R002…). Never require names. '
              'A subject ID identifies a test session, not a person.'),
      const SizedBox(height: 8),
      if (bySubject.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet))),
      for (final e in bySubject.entries)
        Card(
          child: ListTile(
            title: Text(e.key),
            subtitle: Text(
                '${e.value.length} trials • ${(e.value.map((t) => t.testType ?? '?').toSet()).join(', ')}'),
          ),
        ),
    ]);
  }
}

// ---------- Measurements ----------

class MeasurementsTab extends StatefulWidget {
  const MeasurementsTab({super.key});
  @override
  State<MeasurementsTab> createState() => _MeasurementsTabState();
}

class _MeasurementsTabState extends State<MeasurementsTab> {
  String? testType;
  List<Trial> trials = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    trials = await context
        .read<ValidationRepository>()
        .queryTrials(testType: testType);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final keys = AnalyzerRegistry.all.map((a) => a.key).toList();
    final values = [
      for (final t in trials)
        if (t.status == TrialStatus.accepted) t.value
    ].whereType<double>().toList();
    final stats = describe(values);
    final unit = trials.isNotEmpty ? trials.first.unit : '';
    return ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
          initialValue: testType,
          items: [
            DropdownMenuItem(
                value: null, child: Text(_s(context).allTests)),
            for (final k in keys)
              DropdownMenuItem(value: k, child: Text(k)),
          ],
          onChanged: (v) {
            setState(() {
              testType = v;
              loading = true;
            });
            _load();
          },
          decoration: const InputDecoration(
              labelText: 'Test type', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else if (stats == null)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet)))
      else ...[
        StatsCard(stats: stats, unit: unit, s: s),
        const SizedBox(height: 8),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: HistogramBars(values: values))),
      ],
    ]);
  }
}

// ---------- Repeatability ----------

class RepeatabilityTab extends StatefulWidget {
  const RepeatabilityTab({super.key});
  @override
  State<RepeatabilityTab> createState() => _RepeatabilityTabState();
}

class _RepeatabilityTabState extends State<RepeatabilityTab> {
  List<Experiment> experiments = [];
  int? expA;
  int? expB;
  List<Trial> trialsA = [];
  List<Trial> trialsB = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadExps();
  }

  Future<void> _loadExps() async {
    experiments =
        await context.read<ValidationRepository>().listExperiments();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadPair() async {
    final repo = context.read<ValidationRepository>();
    trialsA = expA == null ? [] : await repo.trialsForExperiment(expA!);
    trialsB = expB == null ? [] : await repo.trialsForExperiment(expB!);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (experiments.isEmpty) {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(s.noDataYet)))
          ]);
    }
    Experiment? byId(int? id) {
      for (final e in experiments) {
        if (e.id == id) return e;
      }
      return null;
    }

    final a = byId(expA);
    final b = byId(expB);
    final valsA = [
      for (final t in trialsA)
        if (t.status == TrialStatus.accepted) t.value
    ].whereType<double>().toList();
    final valsB = [
      for (final t in trialsB)
        if (t.status == TrialStatus.accepted) t.value
    ].whereType<double>().toList();
    // Test-retest pairing: ordered accepted values, paired by index up to
    // the shorter series. Method is stated, not hidden.
    final n = valsA.length < valsB.length ? valsA.length : valsB.length;
    final pairs = [for (var i = 0; i < n; i++) (valsA[i], valsB[i])];
    final agr = agreement(pairs);
    final versionMismatch = a != null &&
        b != null &&
        (a.testType != b.testType ||
            a.analyzerVersion != b.analyzerVersion);

    Widget expDropdown(int? value, ValueChanged<int?> onChanged,
        String label) {
      return DropdownButtonFormField<int>(
          initialValue: value,
          items: [
            for (final e in experiments)
              DropdownMenuItem(
                  value: e.id,
                  child: Text('${e.name} (${e.testType} ${e.analyzerVersion})',
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            onChanged(v);
            _loadPair();
          },
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      const SafetyBanner(
          text: 'Repeat Screening: run the same test in Session 1 and Session 2, then compare. '
              'Pairs below are ordered accepted values matched by index — appropriate only for same-protocol repeats.'),
      const SizedBox(height: 8),
      expDropdown(expA, (v) => setState(() => expA = v), 'Session 1'),
      const SizedBox(height: 8),
      expDropdown(expB, (v) => setState(() => expB = v), 'Session 2'),
      const SizedBox(height: 8),
      if (versionMismatch)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border:
                  Border.all(color: const Color(0xFF9A6B00)),
              borderRadius: BorderRadius.circular(10)),
          child: const Text(
              'Warning: the two sessions use different test types or analyzer versions. '
              'Do not compare incompatible versions without stating the difference.'),
        ),
      if (a != null) ...[
        SectionTitle('Session 1: ${a.name}'),
        if (describe(valsA) != null)
          StatsCard(
              stats: describe(valsA)!,
              unit: trialsA.isNotEmpty ? trialsA.first.unit : '',
              s: s)
        else
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(s.noDataYet))),
        TrialValueTable(values: [for (final t in trialsA) t.value]),
      ],
      if (agr != null) ...[
        const SectionTitle('Test-retest comparison'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InsufficientBanner(n: agr.n, s: s),
                  StatRow('pairs', '${agr.n}'),
                  StatRow('mean |diff|', fmt(agr.meanAbsDiff)),
                  StatRow('bias (mean diff)', fmt(agr.meanDiff)),
                  StatRow(
                      'SD of diff',
                      agr.sdDiff == null
                          ? '— (n < 2)'
                          : fmt(agr.sdDiff!)),
                  StatRow(
                      'mean relative diff',
                      agr.meanRelDiff == null
                          ? '—'
                          : '${(agr.meanRelDiff! * 100).toStringAsFixed(1)}%'),
                ]),
          ),
        ),
      ],
    ]);
  }
}

// ---------- Comparison ----------

class ComparisonTab extends StatefulWidget {
  const ComparisonTab({super.key});
  @override
  State<ComparisonTab> createState() => _ComparisonTabState();
}

class _ComparisonTabState extends State<ComparisonTab> {
  String testType = 'pupil';
  List<Trial> trials = [];
  List<Experiment> experiments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ValidationRepository>();
    trials = await repo.queryTrials(testType: testType);
    experiments = await repo.listExperiments();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final byDevice = <String, List<Trial>>{};
    for (final t in trials) {
      final d = t.deviceLabel ?? 'unspecified';
      (byDevice[d] ??= []).add(t);
    }
    final versions = {
      for (final e in experiments)
        if (e.testType == testType) e.analyzerVersion
    };
    return ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
          initialValue: testType,
          items: [
            for (final a in AnalyzerRegistry.all)
              DropdownMenuItem(
                  value: a.key, child: Text(a.title))
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              testType = v;
              loading = true;
            });
            _load();
          },
          decoration: const InputDecoration(
              labelText: 'Measurement', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      if (versions.length > 1)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border:
                  Border.all(color: const Color(0xFF9A6B00)),
              borderRadius: BorderRadius.circular(10)),
          child: Text(
              'Multiple analyzer versions present (${versions.join(', ')}). '
              'Version differences confound device comparison — compare within one version.'),
        ),
      const SizedBox(height: 8),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else if (byDevice.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet)))
      else
        for (final e in byDevice.entries)
          Builder(builder: (_) {
            final vals = [
              for (final t in e.value)
                if (t.status == TrialStatus.accepted) t.value
            ].whereType<double>().toList();
            final st = describe(vals);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(e.key,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium),
                      if (st == null)
                        Text(_s(context).noAcceptedValues)
                      else ...[
                        InsufficientBanner(n: st.n, s: s),
                        StatRow('n', '${st.n}'),
                        StatRow('mean', fmt(st.mean)),
                        StatRow(
                            'SD',
                            st.sd == null
                                ? '— (n < 2)'
                                : fmt(st.sd!)),
                      ],
                    ]),
              ),
            );
          }),
    ]);
  }
}

// ---------- Failure Analysis ----------

class FailuresTab extends StatefulWidget {
  const FailuresTab({super.key});
  @override
  State<FailuresTab> createState() => _FailuresTabState();
}

class _FailuresTabState extends State<FailuresTab> {
  List<Trial> trials = [];
  Map<String, int> reasons = {};
  Map<String, ({int unable, int total})> unableTest = const {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ValidationRepository>();
    trials = await repo.queryTrials();
    reasons = await repo.failureCounts();
    unableTest = await repo.unableBy('testType');
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    final accepted =
        trials.where((t) => t.status == TrialStatus.accepted).length;
    final rejected =
        trials.where((t) => t.status == TrialStatus.rejected).length;
    final unable =
        trials.where((t) => t.status == TrialStatus.unable).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SafetyBanner(
          text: 'Failure accounting from real trials. A lower unable-to-assess rate is a performance '
              'characteristic, not automatically a clinical improvement.'),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trials.length} attempted captures',
                    style:
                        Theme.of(context).textTheme.titleMedium),
                StatRow('Accepted', '$accepted'),
                StatRow('Rejected', '$rejected'),
                StatRow('Unable', '$unable'),
              ]),
        ),
      ),
      const SectionTitle('Rejection reasons'),
      if (reasons.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet)))
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final e in reasons.entries)
                StatRow(s.failureLabel(e.key), '${e.value}'),
            ]),
          ),
        ),
      const SectionTitle('Unable-to-assess by test'),
      if (unableTest.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet)))
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final e in unableTest.entries)
                StatRow(e.key,
                    '${e.value.unable} / ${e.value.total}'),
            ]),
          ),
        ),
    ]);
  }
}

// ---------- Export ----------

class ExportTab extends StatefulWidget {
  const ExportTab({super.key});
  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  List<Experiment> experiments = [];
  int? scopeExpId;
  int refCount = 0;
  String? lastPath;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ValidationRepository>();
    experiments = await repo.listExperiments();
    refCount = (await repo.listReferenceLabels()).length;
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final settings = context.watch<SettingsRepository>();
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SafetyBanner(
          text: 'Exports carry research measurements only — never raw images, never identity. '
              'Reference labels documented: see count below (future-ready interface, no bundled datasets).'),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
          initialValue: scopeExpId,
          items: [
            DropdownMenuItem(
                value: null, child: Text(_s(context).allExperiments)),
            for (final e in experiments)
              DropdownMenuItem(
                  value: e.id, child: Text(e.name)),
          ],
          onChanged: (v) => setState(() => scopeExpId = v),
          decoration: const InputDecoration(
              labelText: 'Scope', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Text(_s(context).referenceLabelsLine(refCount)),
      Text(_s(context).researchCapturesLine(settings.saveResearchCaptures)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _doExport(false),
            icon: const Icon(Icons.table_view_outlined),
            label: Text(s.exportCsv),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _doExport(true),
            icon: const Icon(Icons.data_object_outlined),
            label: Text(s.exportJson),
          ),
        ),
      ]),
      if (lastPath != null) ...[
        const SizedBox(height: 8),
        SafetyBanner(text: 'Exported to:\n$lastPath'),
      ],
    ]);
  }

  Future<void> _doExport(bool json) async {
    final repo = context.read<ValidationRepository>();
    final rows = await repo.exportRows(experimentId: scopeExpId);
    final content = json ? trialsToJson(rows) : trialsToCsv(rows);
    final path = await writeExportFile(content, json ? 'json' : 'csv');
    if (mounted) setState(() => lastPath = path);
    await shareExportFile(path);
  }
}

// ---------- Analyzer cards entry ----------

class AnalyzerCardsEntry extends StatelessWidget {  const AnalyzerCardsEntry({super.key});
  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.biotech_outlined),
        title: Text(s.analyzerInfo),
        subtitle: Text(
            '${AnalyzerRegistry.all.length} modules • versions • limitations'),
        trailing: const NavChevron(),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AnalyzerInfoScreen())),
      ),
    );
  }
}

// ---------- Evidence Audit ----------

/// Research-only audit over real project data: coverage, unreferenced
/// entries, identifier gaps, duplicates, stale reviews, and limited-evidence
/// modules shipped in the build. URL format is checked syntactically only
/// (offline); claim-to-citation support always needs human review.
class EvidenceAuditTab extends StatefulWidget {
  const EvidenceAuditTab({super.key});
  @override
  State<EvidenceAuditTab> createState() => _EvidenceAuditTabState();
}

class _EvidenceAuditTabState extends State<EvidenceAuditTab> {
  EvidenceRepository? repo;
  List<String> duplicateIds = [];
  List<String> orphanCapabilities = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await EvidenceRepository.load();
    // Derive ids from the loaded repo itself (same data as the bundle)
    // instead of a second raw rootBundle read, so the audit works
    // wherever the repo loader works.
    final dupes = EvidenceRepository.duplicateIds(
        r.references.map((e) => e.id).toList());
    // Catalog cross-check (§45): capabilities without curated evidence.
    // Best-effort: a catalog load failure never blocks the evidence audit.
    List<String> orphans = [];
    try {
      final catalog = await DetectionCatalog.load();
      orphans = [
        for (final c in catalog.all)
          if (c.references.isEmpty) '${c.id} (${c.implementationStatus})'
      ];
    } catch (_) {}
    if (mounted) {
      setState(() {
        repo = r;
        duplicateIds = dupes;
        orphanCapabilities = orphans;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final t = Theme.of(context).textTheme;
    if (loading || repo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = repo!;
    final coverage = r.coverageScore();
    final unref = r.entriesWithoutReferences();
    final unused = r.unreferencedReferences();
    final missingIds = r.peerReviewedMissingIdentifiers();
    final stale = r.outdatedEntries();
    final limitedShipped = r.all
        .where((e) =>
            e.implementationStatus == 'CURRENT' && e.evidenceTier == 'C')
        .toList();
    final badUrls = r.references
        .where((ref) =>
            ref.url.isNotEmpty &&
            (Uri.tryParse(ref.url)?.host.isEmpty ?? true))
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      SafetyBanner(text: s.auditExplainer),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${s.coverageScore}: ${(coverage * 100).toStringAsFixed(1)}%',
                    style: t.titleMedium),
                Text(
                    s.auditDbLine(r.dbVersion, r.lastReviewed,
                        r.all.length, r.references.length),
                    style: t.bodySmall),
                const SizedBox(height: 8),
                _line(t, s.auditUnref,
                    '${unref.length}'),
                _line(t, s.auditUnused,
                    '${unused.length}'),
                _line(t, s.auditMissingIds,
                    '${missingIds.length}'),
                _line(t, s.auditDupes,
                    '${duplicateIds.length}'),
                _line(t, s.auditBadUrls,
                    '${badUrls.length}'),
                _line(t, s.auditStale,
                    '${stale.length}'),
                _line(t, s.auditLimited,
                    '${limitedShipped.length}'),
                _line(t, s.auditOrphans,
                    '${orphanCapabilities.length}'),
              ]),
        ),
      ),
      if (unref.isNotEmpty) ...[
        SectionTitle(s.auditSecUnref),
        for (final e in unref)
          ListTile(title: Text(e.name.isEmpty ? e.id : e.name)),
      ],
      if (unused.isNotEmpty) ...[
        SectionTitle(s.auditSecUnused),
        for (final x in unused) ListTile(title: Text(x.citation)),
      ],
      if (missingIds.isNotEmpty) ...[
        SectionTitle(s.auditSecMissingIds),
        for (final x in missingIds) ListTile(title: Text(x.citation)),
      ],
      if (stale.isNotEmpty) ...[
        SectionTitle(s.auditSecStale),
        for (final e in stale)
          ListTile(
              title: Text(e.name.isEmpty ? e.id : e.name),
              subtitle: Text(s.reviewedOnLine(e.lastReviewed))),
      ],
      if (limitedShipped.isNotEmpty) ...[
        SectionTitle(s.auditSecLimited),
        Text(s.auditLimitedNote),
        for (final e in limitedShipped)
          ListTile(title: Text(e.name.isEmpty ? e.id : e.name)),
      ],
      if (orphanCapabilities.isNotEmpty) ...[
        SectionTitle(s.auditSecOrphans),
        Text(s.auditOrphansNote),
        for (final o in orphanCapabilities) ListTile(title: Text(o)),
      ],
      SectionTitle(s.auditManualTitle),
      Text(s.auditManualBody),
    ]);
  }

  Widget _line(TextTheme t, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: t.bodyMedium)),
          Text(v,
              style: t.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

// ---------- Fairness & Robustness ----------

/// Groups recorded experiments by fairness dimension. Groups with no data
/// report "Not evaluated" — equivalence is never assumed. No performance
/// claims are made here; this tab shows coverage and unable-rates only.
class FairnessTab extends StatefulWidget {
  const FairnessTab({super.key});
  @override
  State<FairnessTab> createState() => _FairnessTabState();
}

class _FairnessTabState extends State<FairnessTab> {
  List<Experiment> experiments = [];
  Map<int, List<Trial>> trialsByExp = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ValidationRepository>();
    experiments = await repo.listExperiments();
    trialsByExp = {};
    for (final e in experiments) {
      if (e.id != null) {
        trialsByExp[e.id!] = await repo.trialsForExperiment(e.id!);
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SafetyBanner(
          text:
              'Do not claim equal performance without data. Dimensions below are optional local-only labels; '
              'empty groups report Not evaluated. Do not collect dimensions participants did not agree to share.'),
      const SizedBox(height: 8),
      _dimension(s, 'skinTone', FairnessDimensions.skinTones,
          (e) => e.skinTone),
      _dimension(s, 'eyeColor', FairnessDimensions.eyeColors,
          (e) => e.eyeColor),
      _dimension(s, 'eyewear', FairnessDimensions.eyewear,
          (e) => e.eyewear),
      _dimension(s, 'ageGroup', FairnessDimensions.ageGroups,
          (e) => e.ageGroup),
    ]);
  }

  Widget _dimension(DevStrings s, String key, List<String> values,
      String? Function(Experiment) get) {
    final groups = <String, List<Experiment>>{};
    for (final e in experiments) {
      final v = get(e);
      if (v != null && v.isNotEmpty) {
        (groups[v] ??= []).add(e);
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.fairnessLabel(key),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final v in values)
            Builder(builder: (_) {
              final exps = groups[v] ?? [];
              if (exps.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(
                        child: Text(s.fairnessValue(key, v))),
                    Text(s.notEvaluated,
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                );
              }
              var trials = 0;
              var unable = 0;
              for (final e in exps) {
                for (final t
                    in trialsByExp[e.id] ?? const <Trial>[]) {
                  trials++;
                  if (t.status == TrialStatus.unable) unable++;
                }
              }
              final rate = trials == 0
                  ? '—'
                  : '${(unable / trials * 100).toStringAsFixed(1)}%';
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(
                      child: Text(s.fairnessValue(key, v))),
                  Text(
                      '${exps.length} exp • $trials trials • unable $rate'),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}
