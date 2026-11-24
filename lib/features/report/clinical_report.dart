// Human-readable screening summary for sharing with a professional
// (v0.6). Pure builder: latest row per test, full limitations and
// actions included, explicit non-diagnosis framing. Never scores,
// never probabilities, never diagnoses. Tested for banned language.
import '../../core/localization/app_strings.dart';
import '../../core/models/screening_result.dart';

String findingWords(AppStrings s, ResultCategory f) {
  switch (f) {
    case ResultCategory.possibleFinding:
      return s.badgePossibleFinding;
    case ResultCategory.unableToAssess:
      return s.badgeUnable;
    default:
      return s.badgeNoFinding;
  }
}

/// Coverage of a latest-per-test set: how many tests, oldest and newest
/// row timestamps (nulls when empty). Pure helper for the report header.
({int count, DateTime? from, DateTime? to}) reportCoverage(
    List<ScreeningResult> latestRows) {
  if (latestRows.isEmpty) return (count: 0, from: null, to: null);
  final sorted = List<ScreeningResult>.of(latestRows)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return (
    count: sorted.length,
    from: sorted.first.timestamp,
    to: sorted.last.timestamp
  );
}

/// Latest row per testName, newest first by test.
List<ScreeningResult> latestPerTest(List<ScreeningResult> rows) {
  final seen = <String>{};
  final out = <ScreeningResult>[];
  final sorted = List<ScreeningResult>.of(rows)
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  for (final r in sorted) {
    if (seen.add(r.testName)) out.add(r);
  }
  out.sort((a, b) => a.testName.compareTo(b.testName));
  return out;
}

String buildClinicalReport({
  required AppStrings s,
  required String profileName,
  required String generatedAt,
  required String appVersion,
  required String evidenceVersion,
  required List<ScreeningResult> latestRows,
}) {
  final b = StringBuffer();
  b.writeln(s.reportTitle);
  b.writeln(s.reportProfile(profileName));
  b.writeln(s.reportGenerated(generatedAt));
  b.writeln(s.reportVersions(appVersion, evidenceVersion));
  b.writeln(s.disclaimer);
  b.writeln();
  b.writeln(s.reportLatestTitle);
  b.writeln();
  // Quality-weighted view (D8): unable rows are grouped in their own
  // section so a reader discounts them at a glance. Nothing is dropped;
  // limitations and actions print verbatim in both sections.
  final measured = latestRows
      .where((r) => r.finding != ResultCategory.unableToAssess)
      .toList();
  final unable = latestRows
      .where((r) => r.finding == ResultCategory.unableToAssess)
      .toList();
  void writeRow(ScreeningResult r) {
    b.writeln('## ${r.testName}');
    b.writeln(s.reportRowDate(
        r.timestamp.toLocal().toString().substring(0, 16)));
    b.writeln(findingWords(s, r.finding));
    b.writeln(r.measurement);
    b.writeln(s.detailQualityLine(
        r.imageQuality.name, r.confidence.name));
    b.writeln(s.reportTraceLine(r.hardware, r.deviceLabel,
        r.algorithmVersion, r.evidenceVersion,
        model: r.modelVersion, engine: r.engine));
    if (r.limitations.isNotEmpty) {
      b.writeln('${s.detailCannotTell}:');
      for (final l in r.limitations) {
        b.writeln('- $l');
      }
    }
    if (r.recommendedAction.isNotEmpty) {
      b.writeln('${s.detailWhenPro}: ${r.recommendedAction}');
    }
    b.writeln();
  }

  for (final r in measured) {
    writeRow(r);
  }
  if (unable.isNotEmpty) {
    b.writeln('## ${s.reportUnableTitle(unable.length)}');
    b.writeln();
    for (final r in unable) {
      writeRow(r);
    }
  }
  b.writeln(s.reportFooterNote);
  return b.toString();
}
