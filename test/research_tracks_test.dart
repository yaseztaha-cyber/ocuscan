// v0.4 research-tracks catalog tests: the capability catalog stays
// separate from the validated registry, every track is honestly labeled
// (EXPERIMENTAL/FUTURE, Tier C default), and nothing here is measured.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/validation/analyzer_registry.dart';

void main() {
  group('researchTracks catalog', () {
    test('non-empty and separate from AnalyzerRegistry.all', () {
      expect(researchTracks.isNotEmpty, true);
      final regKeys = AnalyzerRegistry.all.map((a) => a.key).toSet();
      for (final t in researchTracks) {
        expect(regKeys.contains(t.key), false,
            reason: '${t.key} must not pollute the validated registry');
      }
    });

    test('every track honestly labeled', () {
      for (final t in researchTracks) {
        expect(['EXPERIMENTAL', 'FUTURE'], contains(t.status),
            reason: t.key);
        expect(t.tier, 'C', reason: t.key);
        expect(t.titleEn.isNotEmpty && t.titleAr.isNotEmpty, true,
            reason: t.key);
        expect(t.titleEn == t.titleAr, false, reason: t.key);
        expect(t.summaryEn.isNotEmpty && t.summaryAr.isNotEmpty, true,
            reason: t.key);
        expect(t.hardwareEn.isNotEmpty && t.protocolEn.isNotEmpty, true,
            reason: t.key);
      }
    });

    test('retinal tracks require future hardware', () {
      final retinal =
          researchTracks.where((t) => t.key.startsWith('retinal_'));
      expect(retinal.length, 3);
      for (final t in retinal) {
        expect(t.status, 'FUTURE');
        expect(
            t.hardwareEn.contains('absent') ||
                t.hardwareEn.contains('attachment'),
            true,
            reason: t.key);
      }
    });

    test('validated registry still pinned at 19', () {
      expect(AnalyzerRegistry.all.length, 19);
    });
  });
}
