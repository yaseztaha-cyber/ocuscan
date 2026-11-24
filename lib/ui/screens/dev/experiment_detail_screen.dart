// Experiment detail: trials, repeatability statistics, distribution,
// unable-to-assess rate, and reference agreement — all from recorded trials.
// Empty states stay empty: nothing is shown until real trials exist.

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
import 'record_trial_screen.dart';
import 'report_screen.dart';

class ExperimentDetailScreen extends StatefulWidget {
  final int experimentId;
  const ExperimentDetailScreen({super.key, required this.experimentId});

  @override
  State<ExperimentDetailScreen> createState() =>
      _ExperimentDetailScreenState();
}

class _ExperimentDetailScreenState extends State<ExperimentDetailScreen> {
  Experiment? experiment;
  List<Trial> trials = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ValidationRepository>();
    experiment = await repo.getExperiment(widget.experimentId);
    trials = await repo.trialsForExperiment(widget.experimentId);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final appLang =
        Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    final s = DevStrings(appLang);
    final info = experiment == null
        ? null
        : AnalyzerRegistry.forKey(experiment!.testType);
    return Scaffold(
      appBar: AppBar(
          title: Text(experiment?.name ?? s.experimentFallbackTitle(widget.experimentId))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : experiment == null
              ? Center(child: Text(s.experimentNotFound))
              : _body(s, info!),
      floatingActionButton: experiment == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            RecordTrialScreen(experiment: experiment!)));
                if (changed == true) {
                  setState(() => loading = true);
                  _load();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(s.recordTrial),
            ),
    );
  }

  Widget _body(DevStrings s, AnalyzerInfo info) {
    final e = experiment!;
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
    // Honest categorical summary: Trial carries only ONE categorical outcome
    // (status). There is no second categorical reference rating on Trial
    // (referenceValue is numeric with no reference category), so Cohen's
    // kappa is inapplicable here — the mix below is computed purely from
    // the loaded trials via summarizeTrialStatuses.
    final mix = summarizeTrialStatuses(trials);
    String rateStr(double? r) =>
        r == null ? '—' : '${(r * 100).toStringAsFixed(1)}%';
    final pairs = [
      for (final t in trials)
        if (t.value != null && t.referenceValue != null)
          (t.value!, t.referenceValue!)
    ];
    final agr = agreement(pairs);
    final unit = trials.isNotEmpty ? trials.first.unit : '';

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (info.experimental)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF9A6B00)),
              borderRadius: BorderRadius.circular(10)),
          child: Text('⚠ ${s.experimentalBadge}: ${info.title} ${info.version}',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${info.title} ${info.version}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(e.description.isEmpty ? '—' : e.description),
            const SizedBox(height: 8),
            Text(s.deviceLine(e.deviceLabel, e.camera,
                e.targetDistanceCm?.toStringAsFixed(0) ?? '—') +
                (e.distanceNote == null || e.distanceNote!.isEmpty ? '' : ' (${e.distanceNote})')),
            Text(s.lightingLine(s.lightingLabel(e.lightingLevel),
                    e.lux == null ? '' : ' • ${e.lux} lx',
                    e.headAngleDeg?.toStringAsFixed(0) ?? '—', e.subjectId)),
            if (e.environmentalNotes.isNotEmpty)
              Text(s.envLine(e.environmentalNotes)),
            if (e.operatorNotes.isNotEmpty)
              Text(s.operatorLine(e.operatorNotes)),
          ]),
        ),
      ),
      const SectionTitle('Trials'),
      if (trials.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet)))
      else ...[
        TrialValueTable(
            values: [for (final t in trials) t.value], unit: unit),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Attempted ${trials.length} • Accepted ${trials.length - unable - rejected} • '
                      'Rejected $rejected • Unable $unable',
                      style:
                          Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      '${s.unableRate}: ${rate == null ? '—' : '${(rate * 100).toStringAsFixed(1)}%'} ($unable / ${trials.length})'),
                  const SizedBox(height: 8),
                  for (final t in trials)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                '${t.timestamp.toLocal().toString().substring(5, 19)} • '
                                '${s.statusLabel(t.status.code)} • ${t.inputQuality}'
                                '${t.failureReason == null ? '' : ' • ${t.failureReason}'}'
                                '${t.hasCapture ? ' • 📷' : ''}')),
                        if (t.id != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20),
                            tooltip: 'Delete trial',
                            onPressed: () async {
                              await context
                                  .read<ValidationRepository>()
                                  .deleteTrial(t.id!);
                              setState(() => loading = true);
                              _load();
                            },
                          ),
                      ]),
                    ),
                ]),
          ),
        ),
      ],
      const SectionTitle('Repeatability'),
      if (stats == null)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.noDataYet)))
      else
        StatsCard(stats: stats, unit: unit, s: s),
      const SectionTitle('Distribution'),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: HistogramBars(values: values))),
      if (trials.isNotEmpty) ...[
        SectionTitle(s.outcomeMixTitle),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.outcomeMixLine(
                    mix.accepted, mix.rejected, mix.unable, mix.total)),
                const SizedBox(height: 8),
                StatRow(s.statusLabel('accepted'),
                    '${mix.accepted} • ${rateStr(mix.acceptedRate)}'),
                StatRow(s.statusLabel('rejected'),
                    '${mix.rejected} • ${rateStr(mix.rejectedRate)}'),
                StatRow(s.statusLabel('unable'),
                    '${mix.unable} • ${rateStr(mix.unableRateValue)}'),
              ],
            ),
          ),
        ),
        SectionTitle(s.categoricalAgreementTitle),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(s.kappaLabel, '—'),
                StatRow(s.kappaBandTitle,
                    s.kappaBandLabel('insufficient-data')),
                const SizedBox(height: 4),
                Text(s.kappaNeedsPairedNote,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
      if (agr != null) ...[
        const SectionTitle('Reference agreement (paired)'),
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
                  const SizedBox(height: 4),
                  Text(
                      'Plain differences only — not diagnostic accuracy.',
                      style:
                          Theme.of(context).textTheme.bodySmall),
                ]),
          ),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ReportScreen(experiment: e))),
        icon: const Icon(Icons.summarize_outlined),
        label: Text(s.experimentReport),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                    title: Text(s.deleteExperiment),
                    content: Text(s.deleteExperimentBody),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: Text(s.cancel)),
                      FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: Text(s.delete)),
                    ],
                  ));
          if (ok != true) return;
          if (!mounted) return;
          await context
              .read<ValidationRepository>()
              .deleteExperiment(e.id!);
          // Local research captures die with the experiment.
          try {
            final base = await researchBaseDir();
            await ResearchCaptureStore(base)
                .deleteForExperiment(e.id!);
          } catch (_) {}
          if (!mounted) return;
          Navigator.pop(context, true);
        },
        icon: const Icon(Icons.delete_outline),
        label: Text(s.deleteExperiment),
      ),
      const SizedBox(height: 80),
    ]);
  }
}
