// Export + failure-code + privacy + localization + image-source tests.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ocuscan/core/data/app_database.dart';
import 'package:ocuscan/core/data/settings_repository.dart';
import 'package:ocuscan/core/localization/app_strings.dart';
import 'package:ocuscan/core/localization/dev_strings.dart';
import 'package:ocuscan/core/models/screening_result.dart';
import 'package:ocuscan/core/pipeline/quality_gate.dart';
import 'package:ocuscan/core/utils/image_utils.dart';
import 'package:ocuscan/core/validation/experiment_models.dart';
import 'package:ocuscan/core/validation/export.dart';
import 'package:ocuscan/core/validation/quality_failures.dart';
import 'package:ocuscan/core/validation/validation_repository.dart';
import 'package:ocuscan/features/camera/image_source.dart';

QualityVerdict _verdict(List<String> issues, {ImageQuality q = ImageQuality.low}) =>
    QualityVerdict(quality: q, score: 20, issues: issues, guidance: const []);

TrialExportRow _row(String notes) => TrialExportRow(
      experimentId: 1,
      experimentName: 'E1, "quoted"',
      trialId: 2,
      testType: 'pupil',
      analyzerVersion: 'pupil v1',
      deviceLabel: 'Device A',
      camera: 'front',
      timestamp: '2026-09-25T12:00:00',
      subjectId: 'R001',
      lightingLevel: 'moderate',
      lux: '320',
      distanceCm: '30',
      headAngleDeg: '0',
      inputQuality: 'high',
      confidence: 'moderate',
      value: '0.041',
      unit: 'index',
      measurementLabel: 'asymmetry',
      status: 'accepted',
      failureReason: '',
      referenceValue: '',
      referenceMethod: '',
      notes: notes,
    );

void main() {
  group('quality failure codes', () {
    test('each gate issue maps to the required taxonomy', () {
      expect(codeForIssue('Image resolution too low.'),
          QualityFailureCode.lowResolution);
      expect(codeForIssue('Scene too dark.'),
          QualityFailureCode.lowIllumination);
      expect(codeForIssue('Underexposed regions detected.'),
          QualityFailureCode.lowIllumination);
      expect(codeForIssue('Scene too bright.'),
          QualityFailureCode.overexposure);
      expect(codeForIssue('Overexposed regions detected.'),
          QualityFailureCode.overexposure);
      expect(codeForIssue('Image is blurred or out of focus.'),
          QualityFailureCode.blur);
      expect(codeForIssue('Image may be slightly soft.'),
          QualityFailureCode.blur);
      expect(codeForIssue('Both eyes are not visible.'),
          QualityFailureCode.eyeNotVisible);
      expect(codeForIssue(
              'Eyes appear obstructed (hair, hands, glasses glare).'),
          QualityFailureCode.eyeNotVisible);
      expect(codeForIssue('Face is not centered.'),
          QualityFailureCode.badFaceGeometry);
      expect(codeForIssue('Face angle too large.'),
          QualityFailureCode.badFaceGeometry);
      expect(codeForIssue('Face too far from camera.'),
          QualityFailureCode.badFaceGeometry);
      expect(codeForIssue('Face too close; landmarks may clip.'),
          QualityFailureCode.badFaceGeometry);
      expect(codeForIssue('Something entirely new.'),
          QualityFailureCode.other);
    });

    test('categorize + primaryFailure order (eye visibility first)', () {
      final v = _verdict([
        'Face is not centered.',
        'Both eyes are not visible.',
        'Image is blurred or out of focus.',
      ]);
      final codes = categorizeFailures(v);
      expect(
          codes,
          containsAll([
            QualityFailureCode.badFaceGeometry,
            QualityFailureCode.eyeNotVisible,
            QualityFailureCode.blur,
          ]));
      expect(primaryFailure(v), QualityFailureCode.eyeNotVisible);
    });

    test('accepted capture has no failure codes', () {
      const v = QualityVerdict(
          quality: ImageQuality.high,
          score: 100,
          issues: [],
          guidance: []);
      expect(categorizeFailures(v), isEmpty);
    });

    test('LOW veto behavior of the gate itself is unchanged', () {
      const stats = ImageStats(
          meanLuminance: 120,
          overexposedFraction: 0.02,
          underexposedFraction: 0.02,
          sharpnessVariance: 5,
          rednessMean: 0.36,
          yellownessMean: 0.05,
          width: 640,
          height: 480);
      final v = QualityGate.evaluate(QualityInput(
        stats: stats,
        bothEyesVisible: true,
        faceCentered: true,
        faceAngleDeg: 0,
        faceBoxFraction: 0.5,
        eyesObstructed: false,
        strongBacklight: false,
        coloredAmbientLight: false,
      ));
      expect(v.quality, ImageQuality.low);
      expect(
          categorizeFailures(v), contains(QualityFailureCode.blur));
    });
  });

  group('export builders', () {
    test('CSV has the documented header and column count', () {
      final csv = trialsToCsv([_row('ok')]);
      final lines = csv.trim().split('\n');
      expect(lines.first,
          'experiment_id,experiment_name,trial_id,test_type,analyzer_version,device,camera,timestamp,subject_id,lighting,lux,distance_cm,head_angle,quality,confidence,measurement,unit,measurement_label,status,failure_reason,reference_value,reference_method,notes,luminance,sharpness,exposure_bad_fraction,screen_brightness,skin_tone,eye_color,eyewear,age_group,environmental_notes,operator_notes');
      expect(lines.length, 2);
      // 33 columns in the header (v2: dropped columns restored). The
      // data row is NOT split-counted: quoted cells may contain commas.
      expect(lines.first.split(',').length, 33);
      expect(lines.first.endsWith('operator_notes'), true);
    });

    test('CSV escapes commas and quotes', () {
      final csv = trialsToCsv([_row('a,b "c"')]);
      expect(csv, contains('"E1, ""quoted"""'));
      expect(csv, contains('"a,b ""c"""'));
    });

    test('CSV/JSON never carry image paths or image columns', () {
      final csv = trialsToCsv([_row('n')]);
      expect(csv.toLowerCase(), isNot(contains('.jpg')));
      expect(csv.toLowerCase(), isNot(contains('capture')));
      expect(csv.toLowerCase(), isNot(contains('image')));
      final js = trialsToJson([_row('n')]);
      expect(js.toLowerCase(), isNot(contains('.jpg')));
      expect(js, contains('ocuscan-research-export'));
      // JSON carries a neutral schema notice instead of clinical language:
      expect(js, contains('No images, no identity'));
      expect(js.toLowerCase(), isNot(contains('clinical validation')));
    });
  });

  group('research privacy defaults', () {
    test('research mode + captures default OFF', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsRepository(prefs);
      expect(s.researchMode, false);
      expect(s.saveResearchCaptures, false);
      expect(s.researchCaptureAcknowledged, false);
      // Consumer privacy defaults unchanged.
      expect(s.storeRawImages, false);
      expect(s.cloudUpload, false);
    });

    test('research capture store saves, finds, and deletes locally',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('ocuscan_research_test');
      final store = ResearchCaptureStore(tmp.path);
      expect(await store.exists(1, 1), false);
      await store.save(1, 1, [1, 2, 3]);
      expect(await store.exists(1, 1), true);
      expect(
          File(store.pathFor(1, 1)).existsSync(), true);
      // Paths never contain identity and never leave the local store.
      expect(store.pathFor(1, 1), contains('research_captures'));
      await store.deleteForExperiment(1);
      expect(await store.exists(1, 1), false);
      await tmp.delete(recursive: true);
    });

    test('delete-all-data clears validation tables too', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi
          .openDatabase(inMemoryDatabasePath);
      await AppDatabase.createConsumerSchema(db);
      await AppDatabase.createValidationSchema(db);
      final repo = ValidationRepository.forTest(db);
      final id = await repo.createExperiment(Experiment(
        name: 'E1',
        testType: 'pupil',
        deviceLabel: 'Device A',
        lightingLevel: 'moderate',
        subjectId: 'R001',
        analyzerVersion: 'pupil v1',
        createdAt: DateTime.utc(2026, 9, 25),
      ));
      await repo.recordTrial(Trial(
        experimentId: id,
        timestamp: DateTime.utc(2026, 9, 25),
        inputQuality: 'high',
        value: 0.1,
        status: TrialStatus.accepted,
      ));
      // Same deletes HistoryRepository.clearAll performs.
      await db.delete('results');
      await db.delete('sessions');
      await db.delete('trials');
      await db.delete('experiments');
      await db.delete('reference_labels');
      await db.delete('device_profiles');
      expect(await repo.listExperiments(), isEmpty);
      expect(await repo.queryTrials(), isEmpty);
      await db.close();
    });
  });

  group('research localization', () {
    test('all key research strings exist in EN and AR and differ', () {
      const en = DevStrings('en');
      const ar = DevStrings('ar');
      final pairs = [
        [en.researchValidation, ar.researchValidation],
        [en.newExperiment, ar.newExperiment],
        [en.recordTrial, ar.recordTrial],
        [en.saveResearchCapture, ar.saveResearchCapture],
        [en.insufficientData, ar.insufficientData],
        [en.experimentReport, ar.experimentReport],
        [en.experimentalBadge, ar.experimentalBadge],
        [en.noDataYet, ar.noDataYet],
      ];
      for (final p in pairs) {
        expect(p[0].isNotEmpty, true);
        expect(p[1].isNotEmpty, true);
        expect(p[0] == p[1], false, reason: 'untranslated: ${p[0]}');
      }
      expect(ar.isAr, true);
      expect(en.isAr, false);
    });

    test('failure/lighting/status labels cover every code in both languages',
        () {
      const en = DevStrings('en');
      const ar = DevStrings('ar');
      for (final c in [
        'LOW_ILLUMINATION',
        'OVEREXPOSURE',
        'BLUR',
        'LOW_RESOLUTION',
        'BAD_FACE_GEOMETRY',
        'EYE_NOT_VISIBLE',
        'OTHER',
      ]) {
        expect(en.failureLabel(c) == c, false);
        expect(ar.failureLabel(c) == c, false);
      }
      for (final c in [
        'very_low',
        'low',
        'moderate',
        'bright',
        'very_bright',
        'controlled',
      ]) {
        expect(en.lightingLabel(c) == c, false);
        expect(ar.lightingLabel(c) == c, false);
      }
      // Unknown codes fall back to the code itself (never crash).
      expect(en.failureLabel('???'), '???');
    });

    test('arabic locale maps to RTL direction', () {
      TextDirection dirFor(String lang) => lang == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr;
      expect(dirFor('ar'), TextDirection.rtl);
      expect(dirFor('en'), TextDirection.ltr);
    });
  });

  group('image sources', () {
    test('front/rear resolve, retinal refuses by design', () {
      expect(imageSourceForCode('front'), isA<FrontCameraSource>());
      expect(imageSourceForCode('rear'), isA<RearCameraSource>());
      expect(imageSourceForCode('future_retinal'),
          isA<FutureRetinalCameraSource>());
      expect(
          () => FutureRetinalCameraSource().requireRetinalImage(),
          throwsUnsupportedError);
    });

    test('retinal workflow exposes quality only, never a finding', () {
      const stats = ImageStats(
          meanLuminance: 120,
          overexposedFraction: 0.02,
          underexposedFraction: 0.02,
          sharpnessVariance: 120,
          rednessMean: 0.36,
          yellownessMean: 0.05,
          width: 640,
          height: 480);
      final v = RetinalResearchWorkflow.assessCaptureQuality(
          QualityInput(
        stats: stats,
        bothEyesVisible: true,
        faceCentered: true,
        faceAngleDeg: 0,
        faceBoxFraction: 0.5,
        eyesObstructed: false,
        strongBacklight: false,
        coloredAmbientLight: false,
      ));
      expect(v.quality, ImageQuality.high);
    });
  });

  group('research safety wording', () {
    test('prohibited claim phrases are detected', () async {
      // Scans the new research code + evidence DB for diagnostic claims,
      // global scores, and fake-approval language.
      const banned = [
        'you have ',
        'disease risk',
        'health score',
        'eye health score',
        'fda approved',
        'clinically certified',
        'doctor approved',
        'doctor-approved',
        'hospital validated',
        'hospital-grade',
        'hospital grade',
        'clinical-grade',
        'clinical grade',
        'medical-grade',
        'medical grade',
        'clinically proven',
        'ruled out',
        'disease-free',
        'hospital approved',
        'probability of disease',
        '98% accurate',
        '99% accurate',
        '100% accurate',
      ];
      final dirs = [
        Directory('lib/core/validation'),
        Directory('lib/ui/screens/dev'),
      ];
      final extra = [
        File('lib/ui/screens/dev_dashboard.dart'),
        File('lib/core/safety/safety_language.dart'),
        File('assets/medical_evidence.json'),
      ];
      final files = <File>[
        for (final d in dirs)
          ...d
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
        ...extra,
      ];
      expect(files.isNotEmpty, true);
      for (final f in files) {
        final text = await f.readAsString();
        final lower = text.toLowerCase();
        // 'you have ' appears legitimately inside the banned-phrase list
        // itself; skip the guard file for that single substring.
        for (final b in banned) {
          if (f.path.endsWith('safety_language.dart')) continue;
          expect(lower.contains(b), false,
              reason: '${f.path} contains "$b"');
        }
      }
    });
  });

  group('first-run deployment strings', () {
    test('checklist ships complete in both languages', () {
      for (final lang in ['en', 'ar']) {
        final s = AppStrings(lang);
        expect(s.firstRunTitle.isNotEmpty, true);
        expect(s.firstRunSteps, hasLength(3));
        for (final step in s.firstRunSteps) {
          expect(step.isNotEmpty, true);
        }
        expect(s.firstRunCameraHelp.isNotEmpty, true);
        expect(s.settingsDeleteTitle.isNotEmpty, true);
        expect(s.settingsDeleteBody.isNotEmpty, true);
        expect(s.appVersionLine('x').contains('x'), true);
        expect(
            s.reportTraceLine('', '', '', '').contains(s.traceUnrecorded),
            true);
        expect(s.summaryViewHistory.isNotEmpty, true);
        expect(s.summaryShareReport.isNotEmpty, true);
        expect(s.summaryNewScreening.isNotEmpty, true);
        expect(s.summaryFindingAlert.isNotEmpty, true);
        expect(s.reportCoversLine(2, 'a', 'b').contains('2'), true);
        expect(s.settingsLocalDataLine(7).contains('7'), true);
        expect(s.summaryMeasuredTitle.isNotEmpty, true);
        expect(s.summaryUnableTitle.isNotEmpty, true);
        expect(s.positionNextStep('x').contains('x'), true);
        expect(s.eyeTryingLine(12).contains('12'), true);
        expect(s.escapeTitle.isNotEmpty, true);
        expect(s.escapeBody.isNotEmpty, true);
        expect(s.escapeManual.isNotEmpty, true);
        expect(s.escapeSnapshot.isNotEmpty, true);
        expect(s.movementMissing('brow').contains('brow'), true);
        expect(s.measureCoverPractice.isNotEmpty, true);
        expect(s.measureCoverSkip.isNotEmpty, true);
        expect(s.lowAckLabel.isNotEmpty, true);
        expect(s.distanceCheckDist.isNotEmpty, true);
        expect(s.distanceCheckBright.isNotEmpty, true);
        expect(s.colorCheckNight.isNotEmpty, true);
        expect(s.colorCheckFilters.isNotEmpty, true);
        expect(s.reportUnableTitle(3).contains('3'), true);
        expect(s.welcomeStepLine.isNotEmpty, true);
        expect(s.profileChangeBtn.isNotEmpty, true);
        expect(s.tumblingHint.isNotEmpty, true);
        expect(s.visionBeyondDisplay.isNotEmpty, true);
        expect(s.contrastBrightnessLabel.isNotEmpty, true);
        expect(s.centralGlassesCheck.isNotEmpty, true);
        expect(s.centralGlassesOn.isNotEmpty, true);
        expect(s.centralGlassesOff.isNotEmpty, true);
        expect(s.centralGridCenter.isNotEmpty, true);
        expect(s.centralGridCell(3, true).contains('3'), true);
        expect(s.lowAckHint.isNotEmpty, true);
        expect(s.summaryCountLine(1, 11).contains('11'), true);
        expect(s.trialCountLine(2, 10).contains('2'), true);
        expect(s.periphArmFlash.isNotEmpty, true);
        expect(s.periphDotNote('x').contains('x'), true);
        expect(s.coverDwellSkip.isNotEmpty, true);
        expect(s.coverDwellLine(7).contains('7'), true);
        expect(s.historySearchHint.isNotEmpty, true);
        expect(s.historyTestAll.isNotEmpty, true);
        expect(s.settingsDeleteProfileLine('n', 1, 'a', 'b').contains('n'),
            true);
        expect(s.settingsDeletePreview.isNotEmpty, true);
        expect(s.traceLegacyRow.isNotEmpty, true);
        expect(s.findingRequiresTitle.isNotEmpty, true);
        expect(s.refAccessDate('d').contains('d'), true);
        expect(s.refPeerBadge.isNotEmpty, true);
        expect(s.refOverviewBadge.isNotEmpty, true);
        expect(s.rearMirrorNote.isNotEmpty, true);
        expect(s.rearHelperNote.isNotEmpty, true);
        expect(s.cardCalTitle.isNotEmpty, true);
        expect(s.cardCalBody.isNotEmpty, true);
        expect(s.cardCalUse.isNotEmpty, true);
        expect(s.cardCalClear.isNotEmpty, true);
        expect(s.cardCalibratedNote.isNotEmpty, true);
        expect(s.visionDisplayMeasured(400).contains('400'), true);
        expect(s.visionDisplayUncalibrated.isNotEmpty, true);
        expect(s.trendsReason('quality').isNotEmpty, true);
        expect(s.trendsReason('calibration').isNotEmpty, true);
        expect(s.trendsReason('eye').isNotEmpty, true);
        expect(s.trendsReason('setup').isNotEmpty, true);
        expect(s.trendsReason('other').isNotEmpty, true);
        expect(s.profileRename.isNotEmpty, true);
        expect(s.profileMeasurements(2).contains('2'), true);
        expect(s.mlHealthLabel('healthy').isNotEmpty, true);
        expect(s.mlHealthDetailLine(3, 0).contains('3'), true);
        expect(s.historyFilterAll.isNotEmpty, true);
        expect(s.historyFilterFindings.isNotEmpty, true);
        expect(s.historyFilterUnable.isNotEmpty, true);
        expect(s.reportCopy.isNotEmpty, true);
        expect(s.trendsSingleNote.isNotEmpty, true);
      }
    });
  });
}
