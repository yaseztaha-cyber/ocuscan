// Detection-catalog tests (§77): schema, separated statuses, hardware
// requirements, evidence linkage against real IDs, risk mapping.
// Reads the files directly (no asset bundle needed).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/catalog/detection_catalog.dart';

void main() {
  late DetectionCatalog catalog;
  late Set<String> evidenceRefIds;
  setUpAll(() {
    catalog = DetectionCatalog.parse(File('assets/detection_catalog.json')
        .readAsStringSync());
    final ev = json.decode(File('assets/medical_evidence.json')
        .readAsStringSync()) as Map<String, dynamic>;
    evidenceRefIds = {
      for (final r in (ev['references'] as List))
        (r as Map)['id'].toString()
    };
  });

  group('catalog schema', () {
    test('non-empty with unique ids', () {
      expect(catalog.all.length, greaterThanOrEqualTo(60));
      final ids = catalog.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final c in catalog.all) {
        expect(c.name.isNotEmpty && c.nameAr.isNotEmpty, true,
            reason: c.id);
        expect(c.name == c.nameAr, false, reason: c.id);
        expect(c.observableFinding.isNotEmpty, true, reason: c.id);
        expect(c.hardwareRequired.isNotEmpty, true, reason: c.id);
        expect(c.limitations.isNotEmpty, true, reason: c.id);
        expect(c.failureConditions.isNotEmpty, true, reason: c.id);
      }
    });

    test('status vocabularies are separated, never merged', () {
      const impl = {
        'CURRENT',
        'RESEARCH-SUPPORTED',
        'EXPERIMENTAL',
        'FUTURE',
        'HARDWARE-REQUIRED',
        'UNSUPPORTED'
      };
      const valid = {
        'IMPLEMENTED',
        'NOT IMPLEMENTED',
        'VALIDATION PENDING',
        'CLINICAL VALIDATION PENDING'
      };
      const risks = {'low', 'medium', 'high'};
      for (final c in catalog.all) {
        expect(impl.contains(c.implementationStatus), true,
            reason: '${c.id}: ${c.implementationStatus}');
        expect(valid.contains(c.validationStatus), true,
            reason: '${c.id}: ${c.validationStatus}');
        expect(risks.contains(c.riskLevel), true, reason: c.id);
        expect(['A', 'B', 'C'].contains(c.evidenceStatus), true,
            reason: c.id);
      }
    });

    test('CURRENT capabilities all carry references', () {
      for (final c in catalog.byStatus('CURRENT')) {
        expect(c.references.isNotEmpty, true, reason: c.id);
      }
    });

    test('clinical status never claims more than research', () {
      for (final c in catalog.all) {
        expect(c.clinicalStatus, 'research-only', reason: c.id);
      }
    });

    test('no diagnosis language in catalog text', () {
      final text = File('assets/detection_catalog.json')
          .readAsStringSync()
          .toLowerCase();
      for (final banned in [
        ' diagnosed',
        'diagnosis:',
        'you have ',
        'disease risk',
        'health score',
        'hospital-grade',
        'clinically proven',
      ]) {
        expect(text.contains(banned), false, reason: banned);
      }
    });
  });

  group('evidence linkage', () {
    test('capability references are real evidence IDs', () {
      for (final c in catalog.all) {
        for (final r in c.references) {
          expect(evidenceRefIds.contains(r), true,
              reason: '${c.id} -> $r');
        }
      }
    });

    test('category coverage across the platform', () {
      for (final cat in ['face', 'eye', 'vision', 'retina']) {
        expect(catalog.byCategory(cat).isNotEmpty, true,
            reason: cat);
      }
      expect(catalog.byStatus('FUTURE').isNotEmpty, true);
      expect(catalog.byStatus('EXPERIMENTAL').isNotEmpty, true);
    });
  });
}
