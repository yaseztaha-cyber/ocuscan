import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/app.dart';
import 'package:ocuscan/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ocuscan/core/data/settings_repository.dart';
import 'package:ocuscan/core/data/history_repository.dart';
import 'package:ocuscan/core/validation/validation_repository.dart';
import 'package:ocuscan/features/camera/camera_service.dart';

void main() {
  testWidgets('OcuScan boots to splash without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsRepository>.value(value: settings),
          Provider<HistoryRepository>(create: (_) => HistoryRepository()),
          Provider<ValidationRepository>(
              create: (_) => ValidationRepository()),
          ChangeNotifierProvider<CameraService>(create: (_) => CameraService()),
          ChangeNotifierProvider<AppState>(create: (_) => AppState('en')),
        ],
        child: const OcuScanApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('OcuScan'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    // Splash routes to Welcome (no consent yet) or Home (consent set).
    expect(find.text('Welcome to OcuScan').evaluate().isNotEmpty ||
        find.text('OcuScan').evaluate().isNotEmpty, true);
  });
}
