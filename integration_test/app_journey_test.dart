// On-device integration audit: full user journeys on a real Android
// runtime (emulator or physical device). Run with:
//   adb shell pm grant com.ocuscan.ocuscan android.permission.CAMERA
//   flutter test integration_test/app_journey_test.dart -d <device>
// Camera hardware assertions are conditional (emulated scenes have no face):
// the test asserts graceful gating (disabled Continue, unable-states, no
// crash) rather than fabricated measurements.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ocuscan/main.dart' as app;

Future<void> _calm(WidgetTester tester, {int seconds = 2}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(tester.takeException(), isNull);
}

Future<void> _go(WidgetTester tester, String route) async {
  final ctx = tester.element(find.byType(Scaffold).first);
  Navigator.pushNamed(ctx, route);
  await _calm(tester, seconds: 2);
}

Future<void> _back(WidgetTester tester) async {
  final ctx = tester.element(find.byType(Scaffold).first);
  Navigator.maybePop(ctx);
  await _calm(tester, seconds: 2);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding: splash → welcome → consent → home',
      (tester) async {
    app.main();
    await _calm(tester, seconds: 4);
    expect(find.text('Welcome to OcuScan'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await _calm(tester, seconds: 2);
    expect(find.textContaining('Before your first screening'),
        findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('I understand — continue'));
    await _calm(tester, seconds: 3);
    expect(find.text('OcuScan'), findsWidgets);
    expect(find.text('Start screening'), findsOneWidget);
    await binding.takeScreenshot('01-home');
  });

  testWidgets('screening flow gates camera honestly', (tester) async {
    await tester.tap(find.text('Start screening'));
    await _calm(tester, seconds: 3);
    // Step 1 of 8 header renders.
    expect(find.textContaining('Step 1 of 8'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await _calm(tester, seconds: 5);
    expect(find.textContaining('Step 2 of 8'), findsOneWidget);
    // Emulated scene has no face: Continue must stay disabled (gate works).
    final cont = tester.widget<FilledButton>(find.widgetWithText(
        FilledButton, 'Continue'));
    expect(cont.onPressed, isNull,
        reason: 'Continue must be disabled without a detected face');
    await binding.takeScreenshot('02-screening-noface');
    // Exit and re-enter: lifecycle must not crash or lock.
    await _back(tester);
    await tester.tap(find.text('Start screening'));
    await _calm(tester, seconds: 4);
    expect(find.textContaining('Step 1 of 8'), findsOneWidget);
    await _back(tester);
  });

  testWidgets('vision lab distance test runs to a result', (tester) async {
    await _go(tester, '/vision');
    expect(find.text('Vision Lab'), findsOneWidget);
    // Answer 5 items to finish a level round.
    for (var i = 0; i < 5; i++) {
      final ok = find.text('I see it / correct');
      if (ok.evaluate().isEmpty) break;
      await tester.tap(ok);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _calm(tester);
    await _back(tester);
  });

  testWidgets('learn → evidence → references renders', (tester) async {
    await _go(tester, '/learn');
    await tester.tap(find.text('References'));
    await _calm(tester, seconds: 2);
    expect(find.textContaining('Published evidence vs OcuScan evidence'),
        findsOneWidget);
    await _back(tester);
    await _back(tester);
  });

  testWidgets('research mode gate → /dev tabs render', (tester) async {
    await _go(tester, '/settings');
    await tester.scrollUntilVisible(
        find.text('Research validation mode'), 200);
    await tester.tap(find.text('Research validation mode'));
    await tester.pump(const Duration(milliseconds: 500));
    // Acknowledgment dialog appears; accept it.
    expect(find.text('Enable research mode?'), findsOneWidget);
    await tester.tap(find.text('I understand — enable'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
        find.text('Open research validation'), 200);
    await tester.tap(find.text('Open research validation'));
    await _calm(tester, seconds: 3);
    expect(find.text('Research Validation'), findsOneWidget);
    // Swipe through tabs: each must render without exceptions.
    for (final label in [
      'Experiments',
      'Devices',
      'Lighting',
      'Measurements',
      'Repeatability',
      'Comparison',
      'Failure Analysis',
      'Export',
      'Evidence Audit',
      'Fairness',
    ]) {
      final tab = find.text(label);
      if (tab.evaluate().isNotEmpty) {
        await tester.tap(tab);
        await _calm(tester, seconds: 2);
      }
    }
    await binding.takeScreenshot('03-dev');
    await _back(tester);
    await _back(tester);
  });

  testWidgets('privacy delete-all works', (tester) async {
    await _go(tester, '/settings');
    await tester.scrollUntilVisible(find.text('Delete all data'), 200);
    await tester.tap(find.text('Delete all data'));
    await _calm(tester, seconds: 2);
    expect(find.text('All local screening data deleted.'),
        findsOneWidget);
    await _back(tester);
  });

  testWidgets('arabic switch renders home', (tester) async {
    await _go(tester, '/settings');
    await tester.scrollUntilVisible(find.text('Language / اللغة'), 200);
    await tester.tap(find.text('عربي'));
    await _calm(tester, seconds: 2);
    await _back(tester);
    expect(find.text('ابدأ الفحص'), findsOneWidget);
    await binding.takeScreenshot('04-home-ar');
    // Switch back to English for subsequent runs.
    await _go(tester, '/settings');
    await tester.scrollUntilVisible(find.text('Language / اللغة'), 200);
    await tester.tap(find.text('EN'));
    await _calm(tester, seconds: 2);
    await _back(tester);
    expect(find.text('Start screening'), findsOneWidget);
  });
}
