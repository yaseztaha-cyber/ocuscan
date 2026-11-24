import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/data/history_repository.dart';
import '../../core/evidence/evidence_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/screening_result.dart';
import '../../core/safety/safety_language.dart';
import '../../core/validation/analyzer_registry.dart';
import '../../main.dart';import '../widgets/common.dart';
import '../widgets/evidence_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> items = [];
  bool loading = true;
  String _loadedProfile = '';
  int _filter = 0; // 0 = all, 1 = possible findings, 2 = unable to assess
  String? _test; // null = all tests (D7 test picker)
  String _query = '';
  List<String> _tests = [];

  List<ScreeningResult> _visibleItems() {
    final q = _query.trim().toLowerCase();
    final typed = items.whereType<ScreeningResult>().toList();
    if (_filter == 1) {
      typed.retainWhere(
          (r) => r.finding == ResultCategory.possibleFinding);
    } else if (_filter == 2) {
      typed.retainWhere(
          (r) => r.finding == ResultCategory.unableToAssess);
    }
    if (_test != null) {
      typed.retainWhere((r) => r.testName == _test);
    }
    if (q.isNotEmpty) {
      typed.retainWhere((r) =>
          r.testName.toLowerCase().contains(q) ||
          r.measurement.toLowerCase().contains(q));
    }
    return typed;
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final profileId = context.read<AppState>().profileId;
    _loadedProfile = profileId;
    try {
      final repo = context.read<HistoryRepository>();
      items = await repo.all(profileId: profileId);
      _tests = await repo.testNames(profileId: profileId);
      if (_test != null && !_tests.contains(_test)) _test = null;
    } catch (_) {
      items = [];
      _tests = [];
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final app = context.watch<AppState>();
    final s = AppStrings(app.lang);
    if (app.profileId != _loadedProfile) {
      loading = true;
      _load();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(s.historyTitle),
        actions: [
          IconButton(
              icon: const Icon(Icons.timeline_outlined),
              tooltip: s.trendsTitle,
              onPressed: () =>
                  Navigator.pushNamed(context, '/trends')),
          IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: s.reportTitle,
              onPressed: () =>
                  Navigator.pushNamed(context, '/report')),
        ],
      ),
      body: loading
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(s.loadingEvidence),
            ]))
          : items.isEmpty
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  Text(s.historyEmptyTitle, style: t.headlineSmall),
                  const SizedBox(height: 6),
                  Text(s.historyEmptyBody),
                ])
              : ListView(padding: const EdgeInsets.all(16), children: [
                  SafetyBanner(text: s.historyTimelineNote),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                      label: Text(s.historyFilterAll),
                      selected: _filter == 0,
                      onSelected: (_) => setState(() => _filter = 0),
                    ),
                    ChoiceChip(
                      label: Text(s.historyFilterFindings),
                      selected: _filter == 1,
                      onSelected: (_) => setState(() => _filter = 1),
                    ),
                    ChoiceChip(
                      label: Text(s.historyFilterUnable),
                      selected: _filter == 2,
                      onSelected: (_) => setState(() => _filter = 2),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Layout: side-by-side only on wide screens; narrow
                  // screens (320–360dp) + large text + RTL stack instead
                  // of clipping the dropdown and search field.
                  LayoutBuilder(builder: (ctx, constraints) {
                    final wide = constraints.maxWidth > 600;
                    final dropdown = DropdownButtonFormField<String>(
                      initialValue: _test,
                      decoration: InputDecoration(
                          labelText: s.historyTestAll,
                          border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text(s.historyTestAll)),
                        for (final n in _tests)
                          DropdownMenuItem(
                              value: n, child: Text(n)),
                      ],
                      onChanged: (v) =>
                          setState(() => _test = v),
                    );
                    final search = TextField(
                      decoration: InputDecoration(
                          labelText: s.historySearchHint,
                          border: const OutlineInputBorder(),
                          prefixIcon:
                              const Icon(Icons.search_outlined)),
                      onChanged: (v) =>
                          setState(() => _query = v),
                    );
                    if (wide) {
                      return Row(children: [
                        Expanded(child: dropdown),
                        const SizedBox(width: 8),
                        Expanded(child: search),
                      ]);
                    }
                    return Column(children: [
                      dropdown,
                      const SizedBox(height: 8),
                      search,
                    ]);
                  }),
                  const SizedBox(height: 10),
                  if (_visibleItems().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(s.historyEmptyBody),
                    )
                  else
                    for (final group in _groupByDay(_visibleItems(), s))
                    ...[
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(group.$1,
                            style: t.titleMedium?.copyWith(
                                color: const Color(0xFF0A5E5D),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6)),
                      ),
                      for (final r in group.$2)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: ResultCard(
                              result: r,
                              onTap: () => _detail(r)),
                        ),
                    ],
                ]),
    );
  }

  void _detail(dynamic r) async {    final ScreeningResult result = r as ScreeningResult;
    final lang = context.read<AppState>().lang;
    final s = AppStrings(lang);
    // Code-enforced false-reassurance protection: normal results always
    // carry the does-not-rule-out notice.
    final limitations =
        result.finding == ResultCategory.noObviousAbnormality
            ? SafetyLanguage.ensureNoFindingNotice(result.limitations)
            : result.limitations;
    final evidenceId =
        EvidenceRepository.evidenceIdForTestName(result.testName);
    final version = AnalyzerRegistry.versionForTestName(result.testName);
    String? evidenceLine;
    if (evidenceId != null) {
      try {
        final repo = await EvidenceRepository.load();
        final entry = repo.lookup(evidenceId);
        if (entry != null) {
          evidenceLine = s.evidenceTierLine(s.tierLabel(entry.evidenceTier));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final sheetEvidenceId = evidenceId;
    final sheetEvidenceLine = evidenceLine;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.85,
        builder: (_, c) => ListView(controller: c, padding: const EdgeInsets.all(20), children: [
          Text(s.detailTest, style: Theme.of(context).textTheme.bodySmall),
          Text(result.testName, style: Theme.of(context).textTheme.headlineSmall),
          Text(s.analyzerLine(version, result.timestamp.toLocal().toString().substring(0, 16)),
              style: Theme.of(context).textTheme.bodySmall),
          if (sheetEvidenceLine != null) ...[
            const SizedBox(height: 2),
            Text(sheetEvidenceLine,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0A5E5D))),
          ],
          SectionTitle(s.detailMeasured),
          Text(result.measurement),
          SectionTitle(s.detailResult),
          Text(result.findingLabel),
          SectionTitle(s.detailQuality),
          Text(s.detailQualityLine(result.imageQuality.name, result.confidence.name)),
          SectionTitle(s.detailMayMean),
          Text(result.possibleAssociations.isEmpty
              ? s.detailNoAssoc
              : result.possibleAssociations.join('; ')),
          SectionTitle(s.detailCannotTell),
          for (final l in limitations) Text('• $l'),
          SectionTitle(s.detailWhyFlagged),
          Text(result.whyFlagged),
          SectionTitle(s.detailTraceTitle),
          // Provenance-gap badge (D10): pre-v4/v5 rows carry no
          // hardware/device/algorithm versions — say so explicitly so a
          // reader weights them as less comparable. Display-only.
          if (result.hardware.isEmpty &&
              result.deviceLabel.isEmpty &&
              result.algorithmVersion.isEmpty &&
              result.evidenceVersion.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(s.traceLegacyRow,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          Text(s.traceAnalyzerLine(result.algorithmVersion.isEmpty
              ? s.traceUnrecorded
              : result.algorithmVersion)),
          if (evidenceLine != null)
            Text(s.traceEvidenceDbLine(result.evidenceVersion.isEmpty
                ? s.traceUnrecorded
                : result.evidenceVersion)),
          if (result.hardware.isNotEmpty)
            Text(s.traceHardwareLine(result.hardware)),
          if (result.deviceLabel.isNotEmpty)
            Text(s.traceDeviceLine(result.deviceLabel)),
          if (result.modelVersion.isNotEmpty)
            Text(s.traceModelLine(result.modelVersion)),
          if (result.engine.isNotEmpty)
            Text(s.traceEngineLine(result.engine)),
          Text(s.traceAppLine(kOcuScanVersion)),
          SectionTitle(s.detailWhenPro),
          Text(result.recommendedAction),
          SectionTitle(s.detailReferences),
          if (sheetEvidenceId != null)
            EvidenceButton(evidenceId: sheetEvidenceId)
          else
            Text(s.detailNoEvidence),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/learn'),
            icon: const Icon(Icons.school_outlined),
            label: Text(s.learnWhyFinding),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              const visionTabs = {
                'Distance visual acuity': 0,
                'Near visual acuity': 1,
                'Color vision': 2,
                'Contrast sensitivity': 3,
                'Central vision': 4,
                'Peripheral visual field': 5,
                'Cover test': 6,
              };
              final tab = visionTabs[result.testName];
              if (tab == null) {
                Navigator.pushNamed(context, '/screening');
              } else {
                Navigator.pushNamed(context, '/vision', arguments: {
                  'tab': tab,
                  'setup':
                      '${result.testName} • ${result.measurement}',
                });
              }
            },
            icon: const Icon(Icons.refresh_outlined),
            label: Text(_isVisionTest(result.testName)
                ? s.retestButton
                : s.retestScreening),
          ),
          const SizedBox(height: 10),
          SafetyBanner(text: s.detailSafety),
        ]),
      ),
    );
  }
}

/// Vision Lab test names share the guided-retest path (tab + setup);
/// anything else retests via the screening flow.
bool _isVisionTest(String testName) => const {
      'Distance visual acuity',
      'Near visual acuity',
      'Color vision',
      'Contrast sensitivity',
      'Central vision',
      'Peripheral visual field',
      'Cover test',
    }.contains(testName);

/// Group results by calendar day (newest first) for the timeline view.
/// Month names follow the current app language.
List<(String, List<ScreeningResult>)> _groupByDay(
    List<dynamic> items, AppStrings s) {
  final map = <String, List<ScreeningResult>>{};
  for (final r in items.whereType<ScreeningResult>()) {
    final day = r.timestamp.toLocal().toString().substring(0, 10);
    (map[day] ??= []).add(r);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      (
        '${s.monthName(int.parse(d.substring(5, 7)))} ${d.substring(8, 10)}'
            .toUpperCase(),
        map[d]!
      )
  ];
}
