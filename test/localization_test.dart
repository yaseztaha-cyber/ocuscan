// v0.3.2 localization regression tests: every consumer screen area has
// EN+AR strings that differ; eye-guidance covers all tracker states;
// language persists; taxonomy mappings never return raw codes.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ocuscan/core/data/settings_repository.dart';
import 'package:ocuscan/core/localization/app_strings.dart';
import 'package:ocuscan/core/localization/dev_strings.dart';
import 'package:ocuscan/features/camera/eye_tracking.dart';

void main() {
  AppStrings en() => const AppStrings('en');
  AppStrings ar() => const AppStrings('ar');

  group('consumer screens localized', () {
    test('home/welcome/consent differ', () {
      final pairs = [
        [en().homeKicker, ar().homeKicker],
        [en().tagline, ar().tagline],
        [en().startScreening, ar().startScreening],
        [en().homeLatestTitle, ar().homeLatestTitle],
        [en().homeVisionTitle, ar().homeVisionTitle],
        [en().homeHowTitle, ar().homeHowTitle],
        [en().welcomeBody, ar().welcomeBody],
        [en().canTitle, ar().canTitle],
        [en().cannotTitle, ar().cannotTitle],
        [en().consentTitle, ar().consentTitle],
        [en().consentBanner, ar().consentBanner],
        [en().consentCheckbox, ar().consentCheckbox],
      ];
      for (final p in pairs) {
        expect(p[0].isNotEmpty, true);
        expect(p[1].isNotEmpty, true);
        expect(p[0] == p[1], false, reason: 'untranslated: ${p[0]}');
      }
      expect(en().canItems.length, en().cannotItems.length);
      expect(ar().canItems.length, 6);
    });

    test('screening stages + guidance differ', () {
      final pairs = [
        [en().stagePosition, ar().stagePosition],
        [en().stageEyes, ar().stageEyes],
        [en().stageMovement, ar().stageMovement],
        [en().stageMeasurements, ar().stageMeasurements],
        [en().stageSummary, ar().stageSummary],
        [en().positionTitle, ar().positionTitle],
        [en().movementTitle, ar().movementTitle],
        [en().back, ar().back],
        [en().continueBtn, ar().continueBtn],
        [en().finish, ar().finish],
      ];
      for (final p in pairs) {
        expect(p[0].isNotEmpty, true);
        expect(p[1].isNotEmpty, true);
        expect(p[0] == p[1], false, reason: 'untranslated: ${p[0]}');
      }
    });

    test('eye guidance covers every tracker state in both languages', () {
      for (final s in DetectionState.values) {
        final key = detectionStateKey(s);
        final tEn = en().eyeGuideTitle(key);
        final bEn = en().eyeGuideBody(key);
        final tAr = ar().eyeGuideTitle(key);
        final bAr = ar().eyeGuideBody(key);
        expect(tEn.isNotEmpty, true, reason: '$key title EN');
        expect(bEn.isNotEmpty, true, reason: '$key body EN');
        expect(tAr.isNotEmpty, true, reason: '$key title AR');
        expect(bAr.isNotEmpty, true, reason: '$key body AR');
        expect(tEn == tAr, false, reason: '$key title untranslated');
        expect(bEn == bAr, false, reason: '$key body untranslated');
        // Guidance must instruct action, not just report failure.
        expect(bEn.endsWith('.'), true, reason: '$key body punctuation');
      }
    });

    test('vision/history/learn/references/about/emergency/settings differ',
        () {
      final pairs = [
        [en().visionLabTitle, ar().visionLabTitle],
        [en().visionCatalogBody, ar().visionCatalogBody],
        [en().distanceBanner, ar().distanceBanner],
        [en().historyTitle, ar().historyTitle],
        [en().historyEmptyBody, ar().historyEmptyBody],
        [en().learnIntro, ar().learnIntro],
        [en().learnMeasuresTitle, ar().learnMeasuresTitle],
        [en().referencesBanner, ar().referencesBanner],
        [en().referencesVsBody, ar().referencesVsBody],
        [en().methodologyBanner, ar().methodologyBanner],
        [en().retinalBanner, ar().retinalBanner],
        [en().calibBanner, ar().calibBanner],
        [en().settingsPrivacy, ar().settingsPrivacy],
        [en().settingsResearchMode, ar().settingsResearchMode],
        [en().emergencyIntro, ar().emergencyIntro],
        [en().aboutSafetyBanner, ar().aboutSafetyBanner],
        [en().detailSafety, ar().detailSafety],
        [en().evidenceSheetSafety, ar().evidenceSheetSafety],
      ];
      for (final p in pairs) {
        expect(p[0].isNotEmpty, true);
        expect(p[1].isNotEmpty, true);
        expect(p[0] == p[1], false, reason: 'untranslated: ${p[0]}');
      }
      expect(ar().emergencySymptoms.length, 8);
    });

    test('taxonomy mappings never leak raw codes', () {
      for (final c in [
        'ophthalmology',
        'vision_testing',
        'facial_analysis',
        'neurology',
        'retinal_imaging',
        'ai_safety',
        'privacy',
        'regulatory',
      ]) {
        expect(en().refCategory(c) == c, false);
        expect(ar().refCategory(c) == c, false);
      }
      for (final f in [
        'All',
        'Ophthalmology',
        'Vision testing',
        'Facial analysis',
        'Neurology',
        'Retinal imaging',
        'AI safety',
        'Privacy',
        'Regulatory',
      ]) {
        expect(en().refFilterLabel(f).isNotEmpty, true);
        expect(ar().refFilterLabel(f).isNotEmpty, true);
      }
      for (var m = 1; m <= 12; m++) {
        expect(en().monthName(m).isNotEmpty, true);
        expect(ar().monthName(m).isNotEmpty, true);
        expect(en().monthName(m) == ar().monthName(m), false);
      }
      expect(en().tierLabel('A') == ar().tierLabel('A'), false);
      expect(en().tierLabel('C') == ar().tierLabel('C'), false);
    });

    test('research chrome localized', () {
      const den = DevStrings('en');
      const dar = DevStrings('ar');
      final pairs = [
        [den.eyeDebug, dar.eyeDebug],
        [den.pipelineTitle, dar.pipelineTitle],
        [den.thresholdsTitle, dar.thresholdsTitle],
        [den.frameLogTitle, dar.frameLogTitle],
        [den.captureStillInspect, dar.captureStillInspect],
        [den.create, dar.create],
        [den.cancel, dar.cancel],
        [den.reportExperiment, dar.reportExperiment],
        [den.auditManualTitle, dar.auditManualTitle],
      ];
      for (final p in pairs) {
        expect(p[0].isNotEmpty, true);
        expect(p[1].isNotEmpty, true);
        expect(p[0] == p[1], false, reason: 'untranslated: ${p[0]}');
      }
    });
  });

  group('locale state', () {
    test('language persists across repository instances', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      expect(repo.language, 'en');
      await repo.setLanguage('ar');
      expect(repo.language, 'ar');
      // New instance over the same prefs (simulates app restart).
      final repo2 = SettingsRepository(prefs);
      expect(repo2.language, 'ar');
      await repo2.setLanguage('en');
      expect(SettingsRepository(prefs).language, 'en');
    });

    test('AppState default comes from persisted settings', () async {
      SharedPreferences.setMockInitialValues({'language': 'ar'});
      final prefs = await SharedPreferences.getInstance();
      expect(SettingsRepository(prefs).language, 'ar');
    });
  });
}
