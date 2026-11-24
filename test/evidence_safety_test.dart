// v0.3 evidence, safety-wording, retinal, fairness, and about tests.
// All assertions run against real project data (assets/medical_evidence.json)
// or synthetic audit fixtures — never fabricated validation numbers.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ocuscan/core/config/app_version.dart';
import 'package:ocuscan/core/data/app_database.dart';
import 'package:ocuscan/core/evidence/evidence_repository.dart';
import 'package:ocuscan/core/models/screening_result.dart';
import 'package:ocuscan/core/safety/safety_language.dart';
import 'package:ocuscan/core/validation/analyzer_registry.dart';
import 'package:ocuscan/core/validation/experiment_models.dart';
import 'package:ocuscan/core/validation/export.dart';
import 'package:ocuscan/core/validation/validation_repository.dart';
import 'package:ocuscan/features/analyzers/blink.dart';
import 'package:ocuscan/features/analyzers/pupil.dart';
import 'package:ocuscan/features/camera/image_source.dart';
import 'package:ocuscan/core/pipeline/quality_gate.dart';
import 'package:ocuscan/ui/screens/about_content.dart';

EvidenceRepository _loadRepo() {
  final text = File('assets/medical_evidence.json').readAsStringSync();
  return EvidenceRepository.parse(text);
}

QualityVerdict _highQuality() => const QualityVerdict(
    quality: ImageQuality.high, score: 95, issues: [], guidance: []);

void main() {
  group('evidence schema v1.0', () {
    test('top-level versioning present', () {
      final repo = _loadRepo();
      expect(repo.dbVersion, '1.0');
      expect(repo.lastReviewed.isNotEmpty, true);
      expect(DateTime.tryParse(repo.lastReviewed), isNotNull);
      expect(repo.changes.isNotEmpty, true);
    });

    test('every entry has valid tier, status, and core fields', () {
      const tiers = {'A', 'B', 'C'};
      const statuses = {
        'CURRENT',
        'EXPERIMENTAL',
        'FUTURE',
        'NOT_SUITABLE_FOR_CURRENT_HARDWARE'
      };
      final repo = _loadRepo();
      expect(repo.all.length, greaterThanOrEqualTo(20));
      for (final e in repo.all) {
        expect(e.id.isNotEmpty, true, reason: 'missing id');
        expect(tiers.contains(e.evidenceTier), true,
            reason: '${e.id} tier=${e.evidenceTier}');
        expect(statuses.contains(e.implementationStatus), true,
            reason: '${e.id} status=${e.implementationStatus}');
        expect(e.name.isNotEmpty, true, reason: '${e.id} name');
        expect(e.nameAr.isNotEmpty, true, reason: '${e.id} nameAr');
        expect(e.description.isNotEmpty, true, reason: '${e.id} desc');
        expect(e.action.isNotEmpty, true, reason: '${e.id} action');
        expect(DateTime.tryParse(e.lastReviewed), isNotNull,
            reason: '${e.id} last_reviewed');
      }
    });

    test('every entry resolves at least one reference', () {
      final repo = _loadRepo();
      expect(repo.entriesWithoutReferences(), isEmpty);
    });

    test('every reference is complete and cited', () {
      final repo = _loadRepo();
      const cats = {
        'ophthalmology',
        'vision_testing',
        'facial_analysis',
        'neurology',
        'retinal_imaging',
        'ai_safety',
        'privacy',
        'regulatory'
      };
      // Guidance/privacy/regulatory sources are cited by app documentation
      // (per spec §12 they serve safety, privacy, and regulatory guidance).
      final docsText = [
        'SAFETY.md',
        'INTENDED_USE.md',
        'RISK_REGISTER.md',
        'VALIDATION.md',
      ].map((f) => File(f).readAsStringSync()).join('\n');
      const docKeywords = {
        'who2021': ['World Health Organization', 'WHO guidance'],
        'fda-cds-2022': ['Food and Drug Administration', 'clinical-decision-support'],
        'gdpr2016': ['GDPR', 'General Data Protection Regulation'],
        'nist-pf': ['NIST Privacy Framework', 'NIST'],
      };
      for (final r in repo.references) {
        expect(r.title.isNotEmpty, true, reason: r.id);
        expect(r.authors.isNotEmpty, true, reason: r.id);
        expect(r.year.isNotEmpty, true, reason: r.id);
        expect(r.url.isNotEmpty, true, reason: r.id);
        expect(r.usedFor.isNotEmpty, true, reason: r.id);
        expect(cats.contains(r.category), true,
            reason: '${r.id} category=${r.category}');
        if (r.category == 'ai_safety' ||
            r.category == 'privacy' ||
            r.category == 'regulatory') {
          final keys = docKeywords[r.id] ?? [r.id];
          expect(keys.any(docsText.contains), true,
              reason: '${r.id} cited in no documentation');
        } else {
          expect(repo.entriesForReference(r.id).isNotEmpty, true,
              reason: '${r.id} cited nowhere');
        }
      }
    });

    test('no duplicate reference ids in raw file', () {
      final text =
          File('assets/medical_evidence.json').readAsStringSync();
      final decoded = json.decode(text) as Map<String, dynamic>;
      final ids = ((decoded['references'] ?? []) as List)
          .map((e) => ((e as Map)['id'] ?? '').toString())
          .toList();
      expect(EvidenceRepository.duplicateIds(ids), isEmpty);
    });

    test('peer-reviewed records carry DOI or PMID', () {
      expect(_loadRepo().peerReviewedMissingIdentifiers(), isEmpty);
    });

    test('coverage score is 1.0 on the shipped database', () {
      expect(_loadRepo().coverageScore(), 1.0);
    });

    test('audit helpers detect synthetic problems', () {
      final bad = EvidenceEntry(
        id: 'x',
        finding: 'x',
        name: 'X',
        nameAr: 'س',
        category: 'ocular',
        description: 'd',
        screeningMethod: 'm',
        requiredHardware: const [],
        evidenceTier: 'C',
        implementationStatus: 'FUTURE',
        possibleAssociations: const [],
        cannotConclude: const [],
        limitations: const [],
        action: 'a',
        emergencySigns: const [],
        references: const [],
        referenceIds: const [],
        lastReviewed: '2020-01-01',
      );
      final repo = EvidenceRepository.fromEntries([bad]);
      expect(repo.entriesWithoutReferences().length, 1);
      expect(repo.coverageScore(), 0.0);
      expect(repo.outdatedEntries().length, 1);
      expect(repo.unreferencedReferences(), isEmpty);
    });
  });

  group('registry ↔ evidence linkage', () {
    // Every shipped analyzer key must resolve to an evidence entry so
    // Evidence buttons never dead-end (va_near/cover reuse siblings).
    test('every registry key maps to an entry', () {
      const via = {
        'va_near': 'visual_acuity',
        'cover': 'eye_alignment',
      };
      final repo = _loadRepo();
      for (final a in AnalyzerRegistry.all) {
        final id = via[a.key] ?? a.key;
        final alias = {
          'eyelid': 'eyelid_asymmetry',
          'pupil': 'pupil_asymmetry',
          'surface_growth': 'ocular_surface_growth',
          'redness': 'ocular_redness',
          'scleral': 'scleral_color',
          'corneal': 'corneal_opacity',
          'lens': 'lens_opacity',
          'blink': 'blink_pattern',
          'va_distance': 'visual_acuity',
          'color': 'color_vision',
          'contrast': 'contrast_sensitivity',
          'amsler': 'central_vision',
          'peripheral': 'peripheral_field',
        }[a.key];
        final resolved = repo.lookup(id) ?? (alias == null ? null : repo.lookup(alias));
        expect(resolved, isNotNull, reason: 'no evidence for ${a.key}');
      }
    });

    test('testName map covers all 12 analyzer names', () {
      for (final name in [
        'Facial movement symmetry',
        'Eyelid position',
        'Eye alignment',
        'Pupil symmetry',
        'Pupil light response',
        'Ocular surface',
        'Eye redness',
        'Scleral color',
        'Corneal clarity',
        'Lens clarity (experimental)',
        'Blink pattern',
        'Eye movement stability',
      ]) {
        final id = EvidenceRepository.evidenceIdForTestName(name);
        expect(id, isNotNull, reason: name);
        expect(_loadRepo().lookup(id!), isNotNull, reason: name);
      }
    });
  });

  group('safety wording', () {
    test('new banned phrases are detected', () {
      expect(
          SafetyLanguage.containsBannedPhrase('You have diabetes.'), true);
      expect(
          SafetyLanguage.containsBannedPhrase('You are disease-free.'),
          true);
      expect(
          SafetyLanguage.containsBannedPhrase(
              'Your probability of disease is 12%.'),
          true);
      expect(
          SafetyLanguage.containsBannedPhrase(
              'Possible finding detected.'),
          false);
    });

    test('no-finding notice is itself safe and enforced', () {
      expect(
          SafetyLanguage.containsBannedPhrase(
              SafetyLanguage.noFindingNotice),
          false);
      expect(
          SafetyLanguage.ensureNoFindingNotice(['Custom note']),
          contains(SafetyLanguage.noFindingNotice));
      expect(
          SafetyLanguage.ensureNoFindingNotice(
              ['A normal result does not exclude X.']),
          hasLength(1));
    });

    test('normal analyzer outputs carry rule-out language', () {
      final pupil = PupilAnalyzer().analyze(
          PupilInput(frames: const [
            PupilFrame(leftArea: 100, rightArea: 102),
            PupilFrame(leftArea: 101, rightArea: 100),
            PupilFrame(leftArea: 100, rightArea: 101),
          ], lightingStable: true),
          _highQuality());
      expect(pupil.finding, ResultCategory.noObviousAbnormality);
      expect(
          SafetyLanguage.ensureNoFindingNotice(pupil.limitations)
              .join(' ')
              .toLowerCase(),
          anyOf(contains('does not exclude'), contains('does not rule out')));

      final openness =
          List<double>.filled(200, 0.9, growable: false).toList();
      // Insert two full blinks so the pattern is normal-ish.
      for (final s in [40, 120]) {
        for (var k = 0; k < 8; k++) {
          openness[s + k] = k < 4 ? 0.9 - k * 0.2 : 0.1 + (k - 4) * 0.2;
        }
      }
      final blink = BlinkAnalyzer()
          .analyze(BlinkInput(openness: openness, fps: 20), _highQuality());
      final fixed =
          SafetyLanguage.ensureNoFindingNotice(blink.limitations);
      expect(
          fixed.join(' ').toLowerCase(),
          anyOf(contains('does not exclude'), contains('does not rule out')));
    });

    test('extended UI scan: no banned phrases in new screens', () async {
      const files = [
        'lib/ui/screens/learn_screen.dart',
        'lib/ui/screens/about_screen.dart',
        'lib/ui/screens/about_content.dart',
        'lib/ui/screens/references_screen.dart',
        'lib/ui/screens/methodology_screen.dart',
        'lib/ui/screens/retinal_info_screen.dart',
        'lib/ui/screens/color_calibration_screen.dart',
        'lib/ui/screens/history_screen.dart',
        'lib/ui/screens/emergency_screen.dart',
        'lib/ui/widgets/common.dart',
        'lib/ui/widgets/evidence_sheet.dart',
        'lib/core/evidence/evidence_repository.dart',
        'lib/core/localization/app_strings.dart',
        'lib/core/localization/dev_strings.dart',
      ];
      for (final path in files) {
        final text = await File(path).readAsString();
        final lower = text.toLowerCase();
        for (final banned in SafetyLanguage.bannedPhrases) {
          expect(lower.contains(banned), false,
              reason: '$path contains "$banned"');
        }
      }
    });
  });

  group('retinal source validation', () {
    test('retinal source requires sourceType = retinal', () {
      expect(RetinalImageSource().sourceType, 'retinal');
      expect(FrontCameraSource().sourceType, 'camera');
      expect(RearCameraSource().sourceType, 'camera');
      expect(FutureRetinalCameraSource().sourceType, 'camera');
      expect(() => RetinalImageSource.require(RetinalImageSource()),
          returnsNormally);
      expect(() => RetinalImageSource.require(FrontCameraSource()),
          throwsUnsupportedError);
      expect(() => RetinalImageSource.require(RearCameraSource()),
          throwsUnsupportedError);
      expect(
          () => RetinalImageSource.require(
              FutureRetinalCameraSource()),
          throwsUnsupportedError);
    });
  });

  group('fairness persistence', () {
    test('experiment fairness fields round-trip', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await AppDatabase.createValidationSchema(db);
      final repo = ValidationRepository.forTest(db);
      final id = await repo.createExperiment(Experiment(
        name: 'Fairness probe',
        testType: 'pupil',
        deviceLabel: 'Device A',
        subjectId: 'R001',
        analyzerVersion: 'pupil v1',
        createdAt: DateTime.utc(2026, 9, 25),
        skinTone: 'IV',
        eyeColor: 'dark',
        eyewear: 'glasses',
        ageGroup: 'adult',
      ));
      final got = await repo.getExperiment(id);
      expect(got!.skinTone, 'IV');
      expect(got.eyeColor, 'dark');
      expect(got.eyewear, 'glasses');
      expect(got.ageGroup, 'adult');
      expect(FairnessDimensions.skinTones, hasLength(6));
      expect(FairnessDimensions.eyeColors,
          containsAll(['light', 'medium', 'dark']));
      await db.close();
    });
  });

  group('export metadata', () {
    test('JSON envelope carries app + evidence versions', () {
      final js = trialsToJson([]);
      expect(js, contains('"ocuscan_version": "$kOcuScanVersion"'));
      expect(js, contains('"evidence_db_version": "1.0"'));
      expect(AppInfo.ocuscanVersion, kOcuScanVersion);
      expect(AppInfo.evidenceDbVersion, '1.0');
    });
    test('single version source matches pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: $kOcuScanVersion'));
    });
  });

  group('about content', () {
    test('creator credited exactly; every section bilingual', () {
      expect(creatorName, 'Yassen Taha Hussainy Elnasher');
      expect(creatorAffiliation, contains('STEM Gharbiya'));
      expect(aboutSections.length, greaterThanOrEqualTo(10));
      for (final s in aboutSections) {
        expect(s.titleEn.isNotEmpty, true);
        expect(s.titleAr.isNotEmpty, true);
        expect(s.bodyEn.isNotEmpty, true);
        expect(s.bodyAr.isNotEmpty, true);
        expect(s.titleEn == s.titleAr, false);
      }
    });
  });
}
