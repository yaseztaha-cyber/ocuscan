// Shared research-workspace widgets. Every visualization answers a research
// question and renders ONLY actually collected data — empty states say so.

import 'package:flutter/material.dart';
import '../../../core/localization/dev_strings.dart';
import '../../../core/validation/statistics.dart';

String fmt(double v, {int frac = 3}) => v.toStringAsFixed(frac);

class InsufficientBanner extends StatelessWidget {
  final int n;
  final DevStrings s;
  const InsufficientBanner({super.key, required this.n, required this.s});

  @override
  Widget build(BuildContext context) {
    if (hasEnoughData(n)) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3E3),
        border: Border.all(color: const Color(0xFF9A6B00)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('n = $n. ${s.insufficientData}',
          style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class StatRow extends StatelessWidget {
  final String label;
  final String value;
  const StatRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text(value,
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class StatsCard extends StatelessWidget {
  final DescriptiveStats stats;
  final String unit;
  final DevStrings s;
  const StatsCard(
      {super.key, required this.stats, this.unit = '', required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsufficientBanner(n: stats.n, s: s),
              const SizedBox(height: 6),
              StatRow('n', '${stats.n}'),
              StatRow('mean', '${fmt(stats.mean)} $unit'),
              StatRow('median', '${fmt(stats.median)} $unit'),
              StatRow('SD (sample)',
                  stats.sd == null ? '— (n < 2)' : '${fmt(stats.sd!)} $unit'),
              StatRow('min', '${fmt(stats.min)} $unit'),
              StatRow('max', '${fmt(stats.max)} $unit'),
              StatRow('range', '${fmt(stats.range)} $unit'),
              StatRow(
                  'CV',
                  stats.cv == null
                      ? '—'
                      : '${(stats.cv! * 100).toStringAsFixed(1)}%'),
            ]),
      ),
    );
  }
}

/// Honest bar histogram from real counts. Equal-width bins over [min, max].
class HistogramBars extends StatelessWidget {
  final List<double> values;
  final int bins;
  const HistogramBars({super.key, required this.values, this.bins = 8});

  @override
  Widget build(BuildContext context) {
    final counts = histogram(values, bins: bins);
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final t = Theme.of(context).textTheme;
    if (values.isEmpty) {
      final s = DevStrings.of(context);
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(s.noValuesYet,
            style: t.bodySmall),
      );
    }
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < counts.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${counts[i]}', style: t.bodySmall),
                        const SizedBox(height: 2),
                        Container(
                          height: maxCount == 0
                              ? 4
                              : 4 + 88 * counts[i] / maxCount,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E7C7B),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('range ${fmt(lo)} … ${fmt(hi)} • $bins equal-width bins',
            style: t.bodySmall),
      ],
    );
  }
}

class TrialValueTable extends StatelessWidget {
  final List<double?> values;
  final String unit;
  const TrialValueTable({super.key, required this.values, this.unit = ''});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < values.length; i++)
              _row(context, textTheme, i, values[i]),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, TextTheme textTheme, int index, double? value) {
    final s = DevStrings.of(context);
    final label = value == null
        ? s.noTrialValue
        : '${fmt(value)} $unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
            width: 72,
            child: Text(s.trialTitle(index + 1),
                style: textTheme.bodyMedium)),
        Expanded(
          child: Text(label,
              style: textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
