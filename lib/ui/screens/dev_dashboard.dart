// Research Validation workspace (hidden from normal user navigation).
//
// Route-only (/dev): no links from Home, Screening, Vision, History, Learn,
// About, or Emergency. Additionally gated by an explicit research-mode
// switch (OFF by default) with informed acknowledgment. This is an
// engineering tool for measurement validity, repeatability, robustness,
// failure detection, and reproducibility — never a clinical dashboard.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/data/settings_repository.dart';
import '../../core/localization/dev_strings.dart';
import '../../core/validation/analyzer_registry.dart';
import '../../core/validation/experiment_models.dart';
import '../../core/validation/statistics.dart';
import '../../core/validation/validation_repository.dart';
import '../widgets/common.dart';
import 'dev/analyzer_info_screen.dart';
import 'dev/dev_analysis_tabs.dart';
import 'dev/dev_widgets.dart';
import 'dev/risk_tab.dart';
import 'dev/experiment_detail_screen.dart';

class DevDashboard extends StatefulWidget {
  const DevDashboard({super.key});
  @override
  State<DevDashboard> createState() => _DevDashboardState();
}

class _DevDashboardState extends State<DevDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 13, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final appLang =
        Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    final s = DevStrings(appLang);
    if (!settings.researchMode) return _gate(context, s);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.researchValidation),
        bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [
              Tab(text: s.overview),
              Tab(text: s.experiments),
              Tab(text: s.devices),
              Tab(text: s.lighting),
              Tab(text: s.subjects),
              Tab(text: s.measurements),
              Tab(text: s.repeatability),
              Tab(text: s.comparison),
              Tab(text: s.failures),
              Tab(text: s.export),
              Tab(text: s.evidenceAudit),
              Tab(text: s.fairness),
              Tab(text: s.riskTab),
            ]),
      ),
      body: TabBarView(controller: _tabs, children: const [
        _OverviewTab(),
        _ExperimentsTab(),
        DevicesTab(),
        LightingTab(),
        SubjectsTab(),
        MeasurementsTab(),
        RepeatabilityTab(),
        ComparisonTab(),
        FailuresTab(),
        ExportTab(),
        EvidenceAuditTab(),
        FairnessTab(),
        RiskTab(),
      ]),
    );
  }

  Widget _gate(BuildContext context, DevStrings s) {
    var ack = false;
    return Scaffold(
      appBar: AppBar(title: Text(s.researchTools)),
      body: StatefulBuilder(
        builder: (context, setState) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SafetyBanner(
                  text: 'Research tools are hidden by default and produce no diagnoses.'),
              const SizedBox(height: 12),
              Text(s.researchGateBody),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(s.researchConsent,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: ack,
                onChanged: (v) => setState(() => ack = v ?? false),
                title: Text(s.saveResearchCaptureBody
                    .split('.')
                    .first),
                subtitle: Text(s.researchGateBody),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              FilledButton(
                onPressed: ack
                    ? () async {
                        await context
                            .read<SettingsRepository>()
                            .setResearchMode(true);
                      }
                    : null,
                child: Text(s.iUnderstand),
              ),
            ]),
      ),
    );
  }
}

// ---------- Overview ----------

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  int experiments = 0;
  int accepted = 0;
  int rejected = 0;
  int unable = 0;
  Set<String> versions = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ValidationRepository>();
    final exps = await repo.listExperiments();
    final trials = await repo.queryTrials();
    experiments = exps.length;
    accepted =
        trials.where((t) => t.status == TrialStatus.accepted).length;
    rejected =
        trials.where((t) => t.status == TrialStatus.rejected).length;
    unable = trials.where((t) => t.status == TrialStatus.unable).length;
    versions = {for (final e in exps) '${e.testType} ${e.analyzerVersion}'};
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'ar'
            : 'en');
    if (loading) return const Center(child: CircularProgressIndicator());
    final rate = unableRate(unable, accepted + rejected + unable);
    return ListView(padding: const EdgeInsets.all(16), children: [
      SafetyBanner(
          text: '${s.internalOnly}\n${s.measurementEvaluation}'),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Research questions',
                    style:
                        Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                    '• Can the camera reliably detect the eye?\n'
                    '• Can measurements be repeated?\n'
                    '• How much does lighting affect redness?\n'
                    '• How much does device choice affect color?\n'
                    '• How repeatable is visual-acuity testing?\n'
                    '• How often does QualityGate correctly reject unusable captures?\n'
                    '• How stable are facial landmark measurements?'),
              ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow('Experiments', '$experiments'),
                StatRow('Trials accepted', '$accepted'),
                StatRow('Trials rejected', '$rejected'),
                StatRow('Trials unable', '$unable'),
                StatRow(
                    s.unableRate,
                    rate == null
                        ? '— (no trials)'
                        : '${(rate * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 6),
                Text(
                    'Analyzer versions in use: ${versions.isEmpty ? '—' : versions.join(', ')}',
                    style:
                        Theme.of(context).textTheme.bodySmall),
              ]),
        ),
      ),
      const SizedBox(height: 8),
      const AnalyzerCardsEntry(),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: const Icon(Icons.face_outlined),
          title: Text(s.faceTest),
          subtitle: Text(s.faceTestBody),
          trailing: const NavChevron(),
          onTap: () => Navigator.pushNamed(context, '/face-test'),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: const Icon(Icons.remove_red_eye_outlined),
          title: Text(s.eyeDebug),
          subtitle: Text(s.eyeDebugBody),
          trailing: const NavChevron(),
          onTap: () => Navigator.pushNamed(context, '/eye-debug'),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: const Icon(Icons.devices_outlined),
          title: Text(s.compatLabBtn),
          subtitle: Text(s.compatLabTitle),
          trailing: const NavChevron(),
          onTap: () => Navigator.pushNamed(context, '/compat-lab'),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: const Icon(Icons.videocam_outlined),
          title: Text(s.vcTitle),
          subtitle: Text(s.vcBody),
          trailing: const NavChevron(),
          onTap: () => Navigator.pushNamed(context, '/vision-core'),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: const Icon(Icons.science_outlined),
          title: const Text('Analyzer cards'),
          subtitle: Text(
              '${AnalyzerRegistry.all.length} modules documented'),
          trailing: const NavChevron(),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AnalyzerInfoScreen())),
        ),
      ),
    ]);
  }
}

// ---------- Experiments ----------

class _ExperimentsTab extends StatefulWidget {
  const _ExperimentsTab();
  @override
  State<_ExperimentsTab> createState() => _ExperimentsTabState();
}

class _ExperimentsTabState extends State<_ExperimentsTab> {
  List<Experiment> experiments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    experiments =
        await context.read<ValidationRepository>().listExperiments();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'ar'
            : 'en');
    if (loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: experiments.isEmpty
          ? ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.noDataYet)))
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: experiments.length,
              itemBuilder: (_, i) {
                final e = experiments[i];
                return Card(
                  child: ListTile(
                    title: Text(e.name),
                    subtitle: Text(
                        '${e.testType} ${e.analyzerVersion} • ${e.deviceLabel} • '
                        '${s.lightingLabel(e.lightingLevel)} • ${e.subjectId}'),
                    trailing:
                        const NavChevron(),
                    onTap: () async {
                      final changed = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ExperimentDetailScreen(
                                      experimentId: e.id!)));
                      if (changed == true) {
                        setState(() => loading = true);
                        _load();
                      }
                    },
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<bool>(
              context: context,
              builder: (_) => const _NewExperimentDialog());
          if (created == true) {
            setState(() => loading = true);
            _load();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(s.newExperiment),
      ),
    );
  }
}

class _NewExperimentDialog extends StatefulWidget {
  const _NewExperimentDialog();
  @override
  State<_NewExperimentDialog> createState() =>
      _NewExperimentDialogState();
}

class _NewExperimentDialogState extends State<_NewExperimentDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _device = TextEditingController(text: 'Device A');
  final _subject = TextEditingController(text: 'R001');
  final _lux = TextEditingController();
  final _env = TextEditingController();
  final _op = TextEditingController();
  final _distNote = TextEditingController();
  String testType = 'pupil';
  String camera = 'front';
  double? distance;
  String lighting = 'controlled';
  double? headAngle;
  String? skinTone;
  String? eyeColor;
  String? eyewear;
  String? ageGroup;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _device.dispose();
    _subject.dispose();
    _lux.dispose();
    _env.dispose();
    _op.dispose();
    _distNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'ar'
            : 'en');
    final info = AnalyzerRegistry.forKey(testType);
    return AlertDialog(
      title: Text(s.newExperiment),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: InputDecoration(
                    labelText: s.expNameLabel,
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: testType,
                items: [
                  for (final a in AnalyzerRegistry.all)
                    DropdownMenuItem(
                        value: a.key,
                        child: Text('${a.title} ${a.version}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) =>
                    setState(() => testType = v ?? testType),
                decoration: InputDecoration(
                    labelText: s.expMeasurementLabel,
                    border: OutlineInputBorder())),
            if (info?.experimental == true) ...[
              const SizedBox(height: 4),
              Text('⚠ ${s.experimentalBadge}',
                  style: const TextStyle(
                      color: Color(0xFF9A6B00),
                      fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 8),
            TextField(
                controller: _device,
                decoration: InputDecoration(
                    labelText: s.expDeviceLabel,
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: camera,
                items: const [
                  DropdownMenuItem(
                      value: 'front', child: Text('front')),
                  DropdownMenuItem(
                      value: 'rear', child: Text('rear')),
                ],
                onChanged: (v) =>
                    setState(() => camera = v ?? camera),
                decoration: InputDecoration(
                    labelText: s.expCameraLabel,
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<double>(
                initialValue: distance,
                items: const [
                  DropdownMenuItem(
                      value: null,
                      child: Text('Unspecified')),
                  DropdownMenuItem(
                      value: 20, child: Text('20 cm')),
                  DropdownMenuItem(
                      value: 30, child: Text('30 cm')),
                  DropdownMenuItem(
                      value: 40, child: Text('40 cm')),
                  DropdownMenuItem(
                      value: 50, child: Text('50 cm')),
                  DropdownMenuItem(
                      value: 60, child: Text('60 cm')),
                ],
                onChanged: (v) =>
                    setState(() => distance = v),
                decoration: InputDecoration(
                    labelText: s.expDistanceLabel,
                    border: OutlineInputBorder())),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.configuredVsClinical,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: lighting,
                items: [
                  for (final l in LightingLevels.all)
                    DropdownMenuItem(
                        value: l,
                        child: Text(s.lightingLabel(l))),
                ],
                onChanged: (v) =>
                    setState(() => lighting = v ?? lighting),
                decoration: InputDecoration(
                    labelText: s.expLightingLabel,
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _lux,
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true),
                decoration: InputDecoration(
                    labelText: s.expLuxLabel,
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<double>(
                initialValue: headAngle,
                items: const [
                  DropdownMenuItem(
                      value: null,
                      child: Text('Unspecified')),
                  DropdownMenuItem(
                      value: 0, child: Text('0°')),
                  DropdownMenuItem(
                      value: 5, child: Text('5°')),
                  DropdownMenuItem(
                      value: 10, child: Text('10°')),
                  DropdownMenuItem(
                      value: 15, child: Text('15°')),
                  DropdownMenuItem(
                      value: 20, child: Text('20°')),
                ],
                onChanged: (v) =>
                    setState(() => headAngle = v),
                decoration: InputDecoration(
                    labelText: s.expHeadAngleLabel,
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _subject,
                decoration: InputDecoration(
                    labelText: s.expSubjectLabel,
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Text('Fairness dimensions (optional, local-only labels)',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
                initialValue: skinTone,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Unspecified')),
                  for (final v in FairnessDimensions.skinTones)
                    DropdownMenuItem(value: v, child: Text('Tone $v')),
                ],
                onChanged: (v) =>
                    setState(() => skinTone = v),
                decoration: InputDecoration(
                    labelText: s.fairnessLabel('skinTone'),
                    border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: eyeColor,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Unspecified')),
                  for (final v in FairnessDimensions.eyeColors)
                    DropdownMenuItem(
                        value: v,
                        child: Text(s.fairnessValue('eyeColor', v))),
                ],
                onChanged: (v) =>
                    setState(() => eyeColor = v),
                decoration: InputDecoration(
                    labelText: s.fairnessLabel('eyeColor'),
                    border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: eyewear,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Unspecified')),
                  for (final v in FairnessDimensions.eyewear)
                    DropdownMenuItem(
                        value: v,
                        child: Text(s.fairnessValue('eyewear', v))),
                ],
                onChanged: (v) =>
                    setState(() => eyewear = v),
                decoration: InputDecoration(
                    labelText: s.fairnessLabel('eyewear'),
                    border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: ageGroup,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Unspecified')),
                  for (final v in FairnessDimensions.ageGroups)
                    DropdownMenuItem(
                        value: v,
                        child: Text(s.fairnessValue('ageGroup', v))),
                ],
                onChanged: (v) =>
                    setState(() => ageGroup = v),
                decoration: InputDecoration(
                    labelText: s.fairnessLabel('ageGroup'),
                    border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _desc,
                decoration: InputDecoration(
                    labelText: s.expDescLabel,
                    border: OutlineInputBorder())),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel)),
        FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              final infoNow =
                  AnalyzerRegistry.forKey(testType);
              await context
                  .read<ValidationRepository>()
                  .createExperiment(Experiment(
                    name: _name.text.trim(),
                    description: _desc.text.trim(),
                    testType: testType,
                    deviceLabel: _device.text.trim().isEmpty
                        ? 'Device A'
                        : _device.text.trim(),
                    camera: camera,
                    targetDistanceCm: distance,
                    distanceNote: _distNote.text.trim().isEmpty
                        ? null
                        : _distNote.text.trim(),
                    lightingLevel: lighting,
                    lux: double.tryParse(_lux.text.trim()),
                    headAngleDeg: headAngle,
                    subjectId:
                        _subject.text.trim().isEmpty
                            ? 'R001'
                            : _subject.text.trim(),
                    environmentalNotes: _env.text.trim(),
                    operatorNotes: _op.text.trim(),
                    analyzerVersion:
                        '$testType ${infoNow?.version ?? 'v1'}',
                    createdAt: DateTime.now(),
                    skinTone: skinTone,
                    eyeColor: eyeColor,
                    eyewear: eyewear,
                    ageGroup: ageGroup,
                  ));
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: Text(s.create)),
      ],
    );
  }
}
