// Experiment report (research summary, not clinical validation).
//
// Shows exactly what the experiment section requires: experiment identity,
// device, trial counts, accepted/rejected split, descriptive statistics,
// unable-to-assess rate, conditions, and notes — followed by CSV/JSON export.
// Every number comes from recorded trials; empty experiments report emptiness.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/dev_strings.dart';
import '../../../core/validation/analyzer_registry.dart';
import '../../../core/validation/experiment_models.dart';
import '../../../core/validation/export.dart';
import '../../../core/validation/statistics.dart';
import '../../../core/validation/validation_repository.dart';
import '../../widgets/common.dart';
import 'dev_widgets.dart';

class ReportScreen extends StatefulWidget {
  final Experiment experiment;
  const ReportScreen({super.key, required this.experiment});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Trial> trials = [];
  bool loading = true;
  String? exportPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    trials = await context
        .read<ValidationRepository>()
        .trialsForExperiment(widget.experiment.id!);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final appLang =
        Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    final s = DevStrings(appLang);
    final e = widget.experiment;
    final info = AnalyzerRegistry.forKey(e.testType);
    return Scaffold(
      appBar: AppBar(title: Text(s.experimentReport)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _body(s, e, info),
    );
  }

  Widget _body(DevStrings s, Experiment e, AnalyzerInfo? info) {
    final values = [
      for (final t in trials)
        if (t.status == TrialStatus.accepted) t.value
    ].whereType<double>().toList();
    final stats = describe(values);
    final unable =
        trials.where((t) => t.status == TrialStatus.unable).length;
    final rejected =
        trials.where((t) => t.status == TrialStatus.rejected).length;
    final rate = unableRate(unable, trials.length);
    final unit = trials.isNotEmpty ? trials.first.unit : '';

    return ListView(padding: const EdgeInsets.all(16), children: [
      SafetyBanner(text: s.reportBanner),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.reportExperimentLine(e.name),
                style: Theme.of(context).textTheme.titleLarge),
            Text(s.reportTestLine('${info?.title ?? e.testType} ${e.analyzerVersion}')),
            Text(s.reportDeviceLine('${e.deviceLabel} (${e.camera})')),
            Text(s.reportTrialsLine(trials.length)),
            Text(s.reportAcceptedLine(trials.length - unable - rejected)),
            Text(s.reportRejectedLine(rejected)),
            Text(s.reportUnableLine(unable,
                rate == null ? '' : ' (${(rate * 100).toStringAsFixed(1)}%)')),
            if (stats != null) ...[
              Text(s.reportMeanLine(
                  '${stats.mean.toStringAsFixed(3)} $unit (n=${stats.n})')),
              Text(s.reportSdLine(stats.sd == null
                  ? '— (n < 2)'
                  : '${stats.sd!.toStringAsFixed(3)} $unit')),
            ],
            Text(s.reportConditionsLine(
                '${s.lightingLabel(e.lightingLevel)}${e.lux == null ? '' : ' ${e.lux} lx'} • '
                'dist ${e.targetDistanceCm?.toStringAsFixed(0) ?? '—'} cm • '
                'angle ${e.headAngleDeg?.toStringAsFixed(0) ?? '—'}° • ${e.subjectId}')),
            Text(s.reportNotesLine(
                (e.environmentalNotes.isEmpty && e.operatorNotes.isEmpty) ? '—' : '${e.environmentalNotes} ${e.operatorNotes}')),
          ]),
        ),
      ),
      if (stats != null) ...[
        const SizedBox(height: 8),
        StatsCard(stats: stats, unit: unit, s: s),
      ] else ...[
        const SizedBox(height: 8),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet))),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: trials.isEmpty ? null : () => _export(s, false),
            icon: const Icon(Icons.table_view_outlined),
            label: Text(s.exportCsv),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: trials.isEmpty ? null : () => _export(s, true),
            icon: const Icon(Icons.data_object_outlined),
            label: Text(s.exportJson),
          ),
        ),
      ]),
      if (exportPath != null) ...[
        const SizedBox(height: 8),
        SafetyBanner(
            text: 'Exported measurements to:\n$exportPath\n'
                'Research measurements only — no images, no identity.'),
      ],
      const SizedBox(height: 8),
      const SafetyBanner(
          text: 'Raw research captures (if enabled) stay on this device and are never part of exports.'),
    ]);
  }

  Future<void> _export(DevStrings s, bool json) async {
    final repo = context.read<ValidationRepository>();
    final rows =
        await repo.exportRows(experimentId: widget.experiment.id);
    final content = json ? trialsToJson(rows) : trialsToCsv(rows);
    final path = await writeExportFile(content, json ? 'json' : 'csv');
    if (mounted) setState(() => exportPath = path);
    await shareExportFile(path);
  }
}
