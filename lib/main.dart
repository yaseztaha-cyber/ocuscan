import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/data/history_repository.dart';
import 'core/data/settings_repository.dart';
import 'core/validation/validation_repository.dart';
import 'features/camera/camera_service.dart';

/// Re-exported for existing importers: the canonical version lives in
/// core/config/app_version.dart (single source of truth).
export 'core/config/app_version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs);
  runApp(
    MultiProvider(
      providers: [
        Provider<SettingsRepository>.value(value: settings),
        Provider<HistoryRepository>(create: (_) => HistoryRepository()),
        Provider<ValidationRepository>(
            create: (_) => ValidationRepository()),
        ChangeNotifierProvider<CameraService>(create: (_) => CameraService()),
        ChangeNotifierProvider<AppState>(
            create: (_) =>
                AppState(settings.language, settings.activeProfileId)),
      ],
      child: const OcuScanApp(),
    ),
  );
}

class AppState extends ChangeNotifier {
  String lang;
  int tab = 0;
  String profileId;
  AppState(this.lang, [this.profileId = 'self']);
  void setLang(String v) { lang = v; notifyListeners(); }
  void setTab(int v) { tab = v; notifyListeners(); }
  void setProfile(String v) { profileId = v; notifyListeners(); }
}
