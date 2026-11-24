// Descriptive statistics for validation trials (pure Dart, no camera).
//
// Statistical safety rules (see VALIDATION.md):
//  - Every reported statistic shows n.
//  - n < minNForInterpretation (3) → "Insufficient data for reliable
//    statistical interpretation." Raw values are still shown.
//  - SD/CV require n >= 2 (sample SD, n-1 denominator); they are null below.
//  - Sensitivity/specificity are NEVER computed here: there are no labelled
//    reference outcomes in this system. Agreement against a manually entered
//    reference is reported as plain differences only.

import 'dart:math' as math;

/// Minimum sample size for interpreting (not just listing) statistics.
const int minNForInterpretation = 3;

const String insufficientDataMessage =
    'Insufficient data for reliable statistical interpretation.';

bool hasEnoughData(int n) => n >= minNForInterpretation;

class DescriptiveStats {
  final int n;
  final double mean;
  final double median;
  final double? sd; // sample SD; null when n < 2
  final double min;
  final double max;
  final double? cv; // SD/mean; null when n < 2 or mean == 0

  const DescriptiveStats({
    required this.n,
    required this.mean,
    required this.median,
    required this.sd,
    required this.min,
    required this.max,
    required this.cv,
  });

  double get range => max - min;
}

/// Returns null for an empty sample. Never invents values.
DescriptiveStats? describe(List<double> values) {
  final xs = values.where((v) => !v.isNaN).toList();
  if (xs.isEmpty) return null;
  xs.sort();
  final n = xs.length;
  final mean = xs.reduce((a, b) => a + b) / n;
  final median = n.isOdd
      ? xs[n ~/ 2]
      : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2.0;
  double? sd;
  if (n >= 2) {
    double ss = 0;
    for (final v in xs) {
      ss += (v - mean) * (v - mean);
    }
    sd = math.sqrt(ss / (n - 1));
  }
  final cv = (sd != null && mean != 0) ? sd / mean.abs() : null;
  return DescriptiveStats(
    n: n,
    mean: mean,
    median: median,
    sd: sd,
    min: xs.first,
    max: xs.last,
    cv: cv,
  );
}

/// Agreement between paired OcuScan and reference values.
/// Plain differences only — not diagnostic accuracy.
class AgreementStats {
  final int n;
  final double meanAbsDiff;
  final double meanDiff; // signed bias (ocuscan - reference)
  final double? sdDiff;
  final double? meanRelDiff; // |a-b| / mean(|a|,|b|), averaged

  const AgreementStats({
    required this.n,
    required this.meanAbsDiff,
    required this.meanDiff,
    required this.sdDiff,
    required this.meanRelDiff,
  });
}

/// Returns null when there are no complete pairs.
AgreementStats? agreement(List<(double, double)> pairs) {
  if (pairs.isEmpty) return null;
  double absSum = 0, diffSum = 0, relSum = 0;
  int relN = 0;
  final diffs = <double>[];
  for (final p in pairs) {
    final d = p.$1 - p.$2;
    diffs.add(d);
    absSum += d.abs();
    diffSum += d;
    final denom = (p.$1.abs() + p.$2.abs()) / 2.0;
    if (denom > 1e-12) {
      relSum += d.abs() / denom;
      relN++;
    }
  }
  double? sdDiff;
  if (diffs.length >= 2) {
    final m = diffSum / diffs.length;
    double ss = 0;
    for (final d in diffs) {
      ss += (d - m) * (d - m);
    }
    sdDiff = math.sqrt(ss / (diffs.length - 1));
  }
  return AgreementStats(
    n: pairs.length,
    meanAbsDiff: absSum / pairs.length,
    meanDiff: diffSum / pairs.length,
    sdDiff: sdDiff,
    meanRelDiff: relN == 0 ? null : relSum / relN,
  );
}

/// Fixed-bin histogram counts over [min, max]. Empty input → zero counts
/// with the requested bin count (bins are still shown, honestly empty).
List<int> histogram(List<double> values, {int bins = 8}) {
  assert(bins > 0);
  if (values.isEmpty) return List<int>.filled(bins, 0);
  final lo = values.reduce(math.min);
  final hi = values.reduce(math.max);
  final counts = List<int>.filled(bins, 0);
  if ((hi - lo).abs() < 1e-12) {
    counts[bins ~/ 2] += values.length;
    return counts;
  }
  for (final v in values) {
    var b = ((v - lo) / (hi - lo) * bins).floor();
    if (b < 0) b = 0;
    if (b >= bins) b = bins - 1;
    counts[b]++;
  }
  return counts;
}

/// Unable-to-assess rate. Null when there are no trials at all.
double? unableRate(int unableCount, int total) {
  if (total <= 0) return null;
  return unableCount / total;
}
