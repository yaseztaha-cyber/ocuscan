// v0.5 risk-register tests: schema completeness for every entry.
// Research documentation layer — validates structure, not certification.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('risk_management.json', () {
    late Map<String, dynamic> doc;
    setUpAll(() {
      doc = json.decode(
          File('assets/risk_management.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('disclaims certification', () {
      expect((doc['_note'] as String).contains('NOT'), true);
    });

    test('every entry has the full ISO-14971-style record', () {
      const required = [
        'feature',
        'hazard',
        'cause',
        'possible_harm',
        'severity',
        'probability',
        'risk_level',
        'mitigation',
        'residual_risk',
        'verification',
        'safety_relevance',
      ];
      final risks = (doc['risks'] as List).cast<Map<String, dynamic>>();
      expect(risks.length, greaterThanOrEqualTo(10));
      const severities = {'negligible', 'minor', 'serious', 'critical'};
      const probs = {'rare', 'occasional', 'frequent'};
      for (final r in risks) {
        for (final k in required) {
          expect((r[k] as String?)?.isNotEmpty, true,
              reason: '$k missing in ${r['feature']}');
        }
        expect(severities.contains(r['severity']), true,
            reason: '${r['feature']} severity');
        expect(probs.contains(r['probability']), true,
            reason: '${r['feature']} probability');
      }
    });

    test('critical hazards have high safety relevance', () {
      final risks = (doc['risks'] as List).cast<Map<String, dynamic>>();
      for (final r in risks) {
        if (r['severity'] == 'critical') {
          expect(r['safety_relevance'], 'high',
              reason: '${r['feature']}');
        }
      }
    });

    test('no certification language inside mitigations', () {
      final text = File('assets/risk_management.json').readAsStringSync().toLowerCase();
      for (final banned in [
        'iso 14971 certified',
        'iec 62304 compliant',
        'fda approved',
        'clinically proven',
      ]) {
        expect(text.contains(banned), false, reason: banned);
      }
    });
  });
}
