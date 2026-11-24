import 'package:shared_preferences/shared_preferences.dart';

/// App settings + privacy switches. Defaults are privacy-preserving:
/// raw images OFF, cloud upload OFF, history ON (local only).
class SettingsRepository {
  static const _consent = 'consent_v1';
  static const _storeImages = 'store_raw_images';
  static const _cloud = 'cloud_upload';
  static const _history = 'history_enabled';
  static const _lang = 'language';
  static const _textScale = 'text_scale';
  static const _contrast = 'high_contrast';
  static const _distanceCm = 'test_distance_cm';
  static const _researchMode = 'research_mode_enabled';
  static const _researchCaptures = 'save_research_captures';
  static const _researchAck = 'research_capture_acknowledged';
  static const _profile = 'active_profile_id';

  final SharedPreferences prefs;
  SettingsRepository(this.prefs);

  bool get consentGiven => prefs.getBool(_consent) ?? false;
  bool get storeRawImages => prefs.getBool(_storeImages) ?? false;
  bool get cloudUpload => prefs.getBool(_cloud) ?? false;
  bool get historyEnabled => prefs.getBool(_history) ?? true;
  String get language => prefs.getString(_lang) ?? 'en';

  /// True once the user explicitly chose a language (O1: splash may
  /// otherwise default to the system locale on first launch).
  bool get hasLanguagePreference => prefs.containsKey(_lang);
  String get activeProfileId => prefs.getString(_profile) ?? 'self';
  // O5: the 0.9 shrink option is gone (it fought system accessibility
  // scaling). Old installs stored at 0.9 migrate up to 1.0 on read.
  double get textScale {
    final v = prefs.getDouble(_textScale) ?? 1.0;
    return v < 1.0 ? 1.0 : v;
  }
  bool get highContrast => prefs.getBool(_contrast) ?? false;
  double get testDistanceCm => prefs.getDouble(_distanceCm) ?? 300.0;

  /// Research validation mode (gates /dev tools). OFF by default.
  bool get researchMode => prefs.getBool(_researchMode) ?? false;

  /// Research-only local capture storage. OFF by default and requires
  /// explicit acknowledgment before it can be enabled.
  bool get saveResearchCaptures => prefs.getBool(_researchCaptures) ?? false;
  bool get researchCaptureAcknowledged =>
      prefs.getBool(_researchAck) ?? false;

  Future<void> setConsent(bool v) => prefs.setBool(_consent, v);
  Future<void> setStoreRawImages(bool v) => prefs.setBool(_storeImages, v);
  Future<void> setCloudUpload(bool v) => prefs.setBool(_cloud, v);
  Future<void> setHistory(bool v) => prefs.setBool(_history, v);
  Future<void> setLanguage(String v) => prefs.setString(_lang, v);
  Future<void> setActiveProfileId(String v) =>
      prefs.setString(_profile, v);
  Future<void> setTextScale(double v) => prefs.setDouble(_textScale, v);
  Future<void> setHighContrast(bool v) => prefs.setBool(_contrast, v);
  Future<void> setTestDistance(double v) => prefs.setDouble(_distanceCm, v);
  Future<void> setResearchMode(bool v) => prefs.setBool(_researchMode, v);
  Future<void> setSaveResearchCaptures(bool v) =>
      prefs.setBool(_researchCaptures, v);
  Future<void> setResearchCaptureAcknowledged(bool v) =>
      prefs.setBool(_researchAck, v);
}
