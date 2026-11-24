import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/safety/safety_language.dart';
import 'package:ocuscan/features/vision_lab/vision_logic.dart';

void main() {
  test('no banned diagnostic/regulatory phrases in evidence DB', () {
    final f = File('assets/medical_evidence.json');
    expect(f.existsSync(), true, reason: 'evidence DB must exist');
    final text = f.readAsStringSync();
    for (final banned in SafetyLanguage.bannedPhrases) {
      expect(text.toLowerCase().contains(banned), false,
          reason: 'Banned phrase in evidence DB: "$banned"');
    }
    final decoded = json.decode(text) as Map<String, dynamic>;
    for (final e in (decoded['entries'] as List).cast<Map<String, dynamic>>()) {
      for (final key in ['description', 'action']) {
        expect(SafetyLanguage.containsBannedPhrase((e[key] ?? '') as String), false,
            reason: 'Banned phrase in entry ${e['finding']}.$key');
      }
    }
  });

  test('no banned phrases in curated UI-safe strings', () {
    expect(SafetyLanguage.containsBannedPhrase(SafetyLanguage.screeningDisclaimer), false);
    expect(SafetyLanguage.containsBannedPhrase(SafetyLanguage.researchPrototypeLabel), false);
    for (final label in SafetyLanguage.categoryLabels.values) {
      expect(SafetyLanguage.containsBannedPhrase(label), false);
    }
  });

  test('safety guard detects violations', () {
    expect(SafetyLanguage.containsBannedPhrase('You have glaucoma.'), true);
    expect(SafetyLanguage.containsBannedPhrase('Possible finding detected'), false);
    expect(SafetyLanguage.containsBannedPhrase('FDA approved device'), true);
  });

  group('VisionLab logic', () {
    test('optotypes randomized structure', () {
      final opts = VisionLogic.randomizedOptotypes(5);
      expect(opts.length, 5);
      for (final o in opts) {
        expect(o.symbol.isNotEmpty, true);
        expect([0, 90, 180, 270].contains(o.rotationDeg), true);
      }
    });
    test('level pass rule 3/5', () {
      expect(VisionLogic.levelPassed(3, 5), true);
      expect(VisionLogic.levelPassed(2, 5), false);
    });
    test('color plates deterministic across axes', () {
      final axes = <String>{};
      for (int i = 0; i < 12; i++) {
        axes.add(VisionLogic.colorPlate(i)['axis'] as String);
      }
      expect(axes.length, greaterThanOrEqualTo(3));
    });
    test('refractive flag never prescribes', () {
      final msg = VisionLogic.refractiveFlag(0.5, 0.1);
      expect(msg.toLowerCase(), isNot(contains('prescription is')));
      expect(msg.toLowerCase(), contains('possible'));
    });
    test('acuity ladder ordered', () {
      for (int i = 1; i < acuityLevels.length; i++) {
        expect(acuityLevels[i].logMAR < acuityLevels[i - 1].logMAR, true);
      }
    });
  });
}
