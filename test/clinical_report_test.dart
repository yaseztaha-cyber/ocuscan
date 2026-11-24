// Clinical-report builder tests: structure, latest-per-test selection,
// and banned-language safety in both languages.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/localization/app_strings.dart';
import 'package:ocuscan/core/models/screening_result.dart';
import 'package:ocuscan/features/report/clinical_report.dart';

ScreeningResult _row(String test, String measurement, DateTime t,
        {ResultCategory f = ResultCategory.noObviousAbnormality}) =>
    ScreeningResult(
      testName: test,
      measurement: measurement,
      measurementUnit: '',
      imageQuality: ImageQuality.high,
      confidence: Confidence.low,
      finding: f,
      findingLabel: 'Measured (screening)',
      possibleAssociations: const [],
      limitations: const ['Screening only.'],
      recommendedAction: 'Repeat as needed.',
      whyFlagged: 'x',
      timestamp: t,
    );

void main() {
  group('reportCoverage', () {
    test('counts tests and spans oldest to newest', () {
      final rows = [
        _row('B', 'm2', DateTime.utc(2026, 9, 28)),
        _row('A', 'm1', DateTime.utc(2026, 9, 27)),
      ];
      final c = reportCoverage(rows);
      expect(c.count, 2);
      expect(c.from, DateTime.utc(2026, 9, 27));
      expect(c.to, DateTime.utc(2026, 9, 28));
    });
    test('empty set reports nulls', () {
      final c = reportCoverage([]);
      expect(c.count, 0);
      expect(c.from, isNull);
      expect(c.to, isNull);
    });
  });

  group('unable grouping', () {
    ScreeningResult unable(String test) => ScreeningResult(
          testName: test,
          measurement: 'not measured',
          measurementUnit: '',
          imageQuality: ImageQuality.low,
          confidence: Confidence.low,
          finding: ResultCategory.unableToAssess,
          findingLabel: 'Unable to assess reliably',
          possibleAssociations: const [],
          limitations: const ['Low quality.'],
          recommendedAction: 'Repeat.',
          whyFlagged: 'low',
          timestamp: DateTime.utc(2026, 9, 27),
        );
    test('unable rows grouped in their own section, nothing dropped', () {
      final text = buildClinicalReport(
        s: const AppStrings('en'),
        profileName: 'Self',
        generatedAt: '2026-09-27',
        appVersion: '0.5.0+6',
        evidenceVersion: '1.0',
        latestRows: [
          _row('Eye redness', 'Mean redness 0.380',
              DateTime.utc(2026, 9, 27)),
          unable('Eye alignment'),
          unable('Pupil symmetry'),
        ],
      );
      final unableIdx = text.indexOf('Unable to assess (2)');
      expect(unableIdx, greaterThanOrEqualTo(0));
      expect(text.indexOf('## Eye alignment'), greaterThan(unableIdx));
      expect(text.indexOf('## Pupil symmetry'), greaterThan(unableIdx));
      expect(text.indexOf('## Eye redness'), lessThan(unableIdx));
    });
  });

  group('trace carries model + engine only when recorded', () {
    ScreeningResult traced() => ScreeningResult(
          testName: 'Eye redness',
          measurement: 'Mean redness 0.380',
          measurementUnit: '',
          imageQuality: ImageQuality.high,
          confidence: Confidence.low,
          finding: ResultCategory.noObviousAbnormality,
          findingLabel: 'Measured (screening)',
          possibleAssociations: const [],
          limitations: const ['Screening only.'],
          recommendedAction: 'Repeat as needed.',
          whyFlagged: 'x',
          timestamp: DateTime.utc(2026, 9, 27),
          hardware: 'front',
          deviceLabel: 'CPH2121',
          algorithmVersion: 'redness v2',
          evidenceVersion: '1.0',
          modelVersion: 'face-detection:16.1.7 (bundled)',
          engine: 'dart-mlkit',
        );
    test('model/engine appended for traced rows', () {
      final text = buildClinicalReport(
        s: const AppStrings('en'),
        profileName: 'Self',
        generatedAt: '2026-09-27',
        appVersion: '0.7.12+20',
        evidenceVersion: '1.0',
        latestRows: [traced()],
      );
      expect(text.contains('16.1.7'), true);
      expect(text.contains('dart-mlkit'), true);
    });
    test('untraced rows keep the original four-field line', () {
      final text = buildClinicalReport(
        s: const AppStrings('en'),
        profileName: 'Self',
        generatedAt: '2026-09-27',
        appVersion: '0.7.12+20',
        evidenceVersion: '1.0',
        latestRows: [
          _row('Eye redness', 'Mean redness 0.380',
              DateTime.utc(2026, 9, 27)),
        ],
      );
      expect(text.contains('model'), false);
      expect(text.contains('Trace: hardware'), true);
    });
  });

  group('latestPerTest', () {
    test('keeps newest row per test', () {
      final rows = [
        _row('A', 'old', DateTime.utc(2026, 1, 1)),
        _row('B', 'mid', DateTime.utc(2026, 1, 2)),
        _row('A', 'new', DateTime.utc(2026, 1, 3)),
      ];
      final latest = latestPerTest(rows);
      expect(latest.length, 2);
      expect(
          latest
              .firstWhere((r) => r.testName == 'A')
              .measurement,
          'new');
    });
  });

  group('buildClinicalReport', () {
    test('structure in English', () {
      final text = buildClinicalReport(
        s: const AppStrings('en'),
        profileName: 'Self',
        generatedAt: '2026-09-27',
        appVersion: '0.5.0+6',
        evidenceVersion: '1.0',
        latestRows: [
          _row('Distance visual acuity', '6/12 (right eye)',
              DateTime.utc(2026, 9, 27)),
        ],
      );
      expect(text.contains('Screening summary report'), true);
      expect(text.contains('Profile: Self'), true);
      expect(text.contains('## Distance visual acuity'), true);
      expect(text.contains('6/12 (right eye)'), true);
      expect(text.contains('not a diagnosis'), true);
      expect(text.contains('Trace: hardware'), true);
      expect(text.contains('not recorded on this row'), true);
    });

    test('structure in Arabic with profile', () {
      final text = buildClinicalReport(
        s: const AppStrings('ar'),
        profileName: 'ليلى',
        generatedAt: '2026-09-27',
        appVersion: '0.5.0+6',
        evidenceVersion: '1.0',
        latestRows: [
          _row('Distance visual acuity', '6/12 (right eye)',
              DateTime.utc(2026, 9, 27)),
        ],
      );
      expect(text.contains('ليلى'), true);
      expect(text.contains('ليس تشخيصاً'), true);
    });

    test('no banned clinical language in either locale', () {
      const banned = [
        'you have glaucoma',
        'disease risk',
        'health score',
        'you are healthy',
        'disease-free',
        'diagnosis:',
        'hospital-grade',
        'clinically proven',
      ];
      final rows = [
        _row('Pupil symmetry', 'Relative asymmetry 4.2%',
            DateTime.utc(2026, 9, 27),
            f: ResultCategory.possibleFinding),
      ];
      for (final lang in ['en', 'ar']) {
        final text = buildClinicalReport(
          s: AppStrings(lang),
          profileName: 'Self',
          generatedAt: '2026-09-27',
          appVersion: '0.5.0+6',
          evidenceVersion: '1.0',
          latestRows: rows,
        ).toLowerCase();
        for (final b in banned) {
          expect(text.contains(b), false, reason: '$lang: $b');
        }
      }
    });
  });

  group('new UI strings (history filter / report copy / trends single)', () {
    test('history filter chips localized and distinct', () {
      const en = AppStrings('en');
      const ar = AppStrings('ar');
      expect(en.historyFilterAll.isNotEmpty, true);
      expect(en.historyFilterFindings.isNotEmpty, true);
      expect(en.historyFilterUnable.isNotEmpty, true);
      expect(ar.historyFilterAll.isNotEmpty, true);
      expect(ar.historyFilterFindings.isNotEmpty, true);
      expect(ar.historyFilterUnable.isNotEmpty, true);
      expect(en.historyFilterAll == ar.historyFilterAll, false);
      expect(en.historyFilterFindings == ar.historyFilterFindings, false);
      expect(en.historyFilterUnable == ar.historyFilterUnable, false);
    });

    test('report copy strings localized and distinct', () {
      const en = AppStrings('en');
      const ar = AppStrings('ar');
      expect(en.reportCopy.isNotEmpty, true);
      expect(en.reportCopied.isNotEmpty, true);
      expect(ar.reportCopy.isNotEmpty, true);
      expect(ar.reportCopied.isNotEmpty, true);
      expect(en.reportCopy == ar.reportCopy, false);
      expect(en.reportCopied == ar.reportCopied, false);
    });

    test('trends single-row note localized, screening wording only', () {
      const en = AppStrings('en');
      const ar = AppStrings('ar');
      expect(en.trendsSingleNote.isNotEmpty, true);
      expect(ar.trendsSingleNote.isNotEmpty, true);
      expect(en.trendsSingleNote == ar.trendsSingleNote, false);
      for (final text in [en.trendsSingleNote, ar.trendsSingleNote]) {
        final lower = text.toLowerCase();
        expect(lower.contains('diagnos'), false);
        expect(lower.contains('disease progression'), false);
        expect(lower.contains('glaucoma'), false);
      }
      // English note keeps trendsNoData-style compare-across-visits framing.
      expect(en.trendsSingleNote.contains('Repeat'), true);
    });
  });
}
