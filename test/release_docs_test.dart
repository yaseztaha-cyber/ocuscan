// v0.7 doc guards: required documentation exists, disclaims
// certification, and carries no banned clinical claims (quoted
// prohibitions like "never X" are allowed; claims are not).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _docs = [
  'SYSTEM_ARCHITECTURE.md',
  'RISK_MANAGEMENT.md',
  'USABILITY_ENGINEERING.md',
  'INTENDED_USE.md',
  'VALIDATION_PLAN.md',
  'MODEL_CARDS.md',
  'ALGORITHM_CARDS.md',
  'DATASET_CARDS.md',
  'REPRODUCIBILITY.md',
  'DEVICE_COMPATIBILITY.md',
  'MEDICAL_LIMITATIONS.md',
  'RELEASE_CHECKLIST.md',
  'V0_7_FINAL_PRODUCT_AUDIT.md',
];

void main() {
  group('release documentation', () {
    test('all required docs exist and are non-trivial', () {
      for (final d in _docs) {
        final f = File(d);
        expect(f.existsSync(), true, reason: d);
        expect(f.readAsStringSync().length, greaterThan(500),
            reason: d);
      }
    });

    test('no certification or approval claims in docs', () {
      for (final d in _docs) {
        final text =
            File(d).readAsStringSync().toLowerCase();
        for (final banned in [
          'iso 14971 certified',
          'iec 62304 compliant',
          'iec 62366 certified',
          'fda approved',
          'ce certified',
          'clinically proven',
          'hospital-grade',
          'doctor approved',
        ]) {
          expect(text.contains(banned), false,
              reason: '$d contains "$banned"');
        }
      }
    });

    test('standards references carry no-compliance disclaimers', () {
      for (final d in [
        'RISK_MANAGEMENT.md',
        'USABILITY_ENGINEERING.md',
        'V0_7_FINAL_PRODUCT_AUDIT.md'
      ]) {
        final text = File(d).readAsStringSync().toLowerCase();
        expect(
            text.contains('not') &&
                (text.contains('certification') ||
                    text.contains('certified') ||
                    text.contains('compliance')),
            true,
            reason: d);
      }
    });
  });
}
