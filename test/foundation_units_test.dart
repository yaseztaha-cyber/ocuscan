// Foundation unit tests (no device): settings persistence round-trips,
// AppState notifications, and the native engine client's offline
// behavior (MissingPlugin degrades to unavailable, never throws
// except start, which surfaces the platform error honestly).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ocuscan/main.dart';
import 'package:ocuscan/core/data/settings_repository.dart';
import 'package:ocuscan/features/vision/face_detection_engine.dart';
import 'package:ocuscan/features/vision/native_face_engine.dart';

Future<SettingsRepository> _repo() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsRepository(await SharedPreferences.getInstance());
}

void main() {
  group('SettingsRepository', () {
    test('privacy-preserving defaults', () async {
      final s = await _repo();
      expect(s.consentGiven, false);
      expect(s.storeRawImages, false);
      expect(s.cloudUpload, false);
      expect(s.historyEnabled, true);
      expect(s.language, 'en');
      expect(s.hasLanguagePreference, false);
      expect(s.activeProfileId, 'self');
      expect(s.textScale, 1.0);
      expect(s.highContrast, false);
      expect(s.testDistanceCm, 300.0);
      expect(s.researchMode, false);
      expect(s.saveResearchCaptures, false);
      expect(s.researchCaptureAcknowledged, false);
    });
    test('legacy sub-1.0 text scale migrates up on read', () async {
      final s = await _repo();
      await s.setTextScale(0.9);
      expect(s.textScale, 1.0);
    });
    test('every setter round-trips', () async {
      final s = await _repo();
      await s.setConsent(true);
      await s.setStoreRawImages(true);
      await s.setCloudUpload(true);
      await s.setHistory(false);
      await s.setLanguage('ar');
      await s.setActiveProfileId('kid1');
      await s.setTextScale(1.3);
      await s.setHighContrast(true);
      await s.setTestDistance(200);
      await s.setResearchMode(true);
      await s.setSaveResearchCaptures(true);
      await s.setResearchCaptureAcknowledged(true);
      expect(s.consentGiven, true);
      expect(s.storeRawImages, true);
      expect(s.cloudUpload, true);
      expect(s.historyEnabled, false);
      expect(s.language, 'ar');
      expect(s.hasLanguagePreference, true);
      expect(s.activeProfileId, 'kid1');
      expect(s.textScale, 1.3);
      expect(s.highContrast, true);
      expect(s.testDistanceCm, 200);
      expect(s.researchMode, true);
      expect(s.saveResearchCaptures, true);
      expect(s.researchCaptureAcknowledged, true);
    });
  });

  group('AppState', () {
    test('defaults and notifications', () {
      final app = AppState('en');
      expect(app.lang, 'en');
      expect(app.tab, 0);
      expect(app.profileId, 'self');
      var notes = 0;
      app.addListener(() => notes++);
      app.setLang('ar');
      app.setTab(2);
      app.setProfile('kid1');
      expect(app.lang, 'ar');
      expect(app.tab, 2);
      expect(app.profileId, 'kid1');
      expect(notes, 3);
    });
  });

  group('native engine client without plugin', () {
    test('capabilities and health degrade to unavailable', () async {
      final e = NativeFaceEngine();
      expect(e.engineId, 'native-mlkit');
      expect(e.running, false);
      expect(e.generation, 0);
      expect(await e.capabilities(), {'available': false});
      expect(await e.health(),
          {'running': false, 'error': 'unavailable'});
    });
    test('start surfaces the missing plugin instead of hanging',
        () async {
      await expectLater(
          NativeFaceEngine().startWithResult(front: true),
          throwsA(anything));
    });
    test('error classes map, unknowns become processing errors', () {
      expect(nativeErrorClassOf('INVALID_FRAME'),
          MlErrorClass.invalidFrame);
      expect(nativeErrorClassOf('ENGINE_UNAVAILABLE'),
          MlErrorClass.engineUnavailable);
      expect(nativeErrorClassOf('CAMERA_ERROR'), MlErrorClass.cameraError);
      expect(nativeErrorClassOf('MODEL_UNAVAILABLE'),
          MlErrorClass.modelUnavailable);
      expect(nativeErrorClassOf('PERMISSION_DENIED'),
          MlErrorClass.permissionDenied);
      expect(nativeErrorClassOf('NO_FACE'), MlErrorClass.noFace);
      expect(nativeErrorClassOf('SOMETHING_NEW'),
          MlErrorClass.processingError);
      expect(nativeErrorClassOf(null), MlErrorClass.processingError);
    });
  });
}
