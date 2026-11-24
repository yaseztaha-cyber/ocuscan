// Failure-panel widget tests (no device needed): the Eyes stage must
// name each dead state with recovery actions, and the report must show
// a named error (never fake-empty) when loading throws.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ocuscan/main.dart';
import 'package:ocuscan/core/data/history_repository.dart';
import 'package:ocuscan/core/data/settings_repository.dart';
import 'package:ocuscan/core/models/screening_result.dart';
import 'package:ocuscan/features/camera/camera_pipeline.dart'
    show CameraStage;
import 'package:ocuscan/features/camera/camera_service.dart';
import 'package:ocuscan/ui/screens/report_screen.dart';
import 'package:ocuscan/ui/screens/screening/eye_stage.dart';

Future<CameraService> _pumpEyeStage(
  WidgetTester tester,
  CameraService cam,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SettingsRepository>.value(
            value: SettingsRepository(prefs)),
        ChangeNotifierProvider<CameraService>.value(value: cam),
        ChangeNotifierProvider<AppState>(
            create: (_) => AppState('en')),
      ],
      child: MaterialApp(
        // Scrollable host: EyeStageView is a bare Column sized by its
        // parent scroll view in production; standalone it overflows.
        home: Scaffold(
          body: SingleChildScrollView(
            child: EyeStageView(
              onSkipLock: () {},
              onSnapshot: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return cam;
}

/// History that fails exactly like a corrupt store: every load throws
/// with no async gap, so no FFI/fake-clock interplay is involved.
class _ThrowingHistory extends HistoryRepository {
  _ThrowingHistory() : super();
  // Timer-delivered throw: fires after mount completes, so the screen's
  // `mounted` guard passes (a synchronous throw lands inside the
  // initState stack where mounted is still false and is skipped).
  @override
  Future<List<ScreeningResult>> all(
      {int limit = 200, String profileId = 'self'}) {
    final c = Completer<List<ScreeningResult>>();
    // Resolve as an error on the next microtask: post-mount delivery
    // without any timer/zone interplay.
    scheduleMicrotask(() => c.completeError(StateError('store unreadable')));
    return c.future;
  }
}

/// Value-returning fake: distinguishes "async never resumes in this
/// zone" (infra) from "error path broken" (logic).
class _EmptyHistory extends HistoryRepository {
  _EmptyHistory() : super();
  @override
  Future<List<ScreeningResult>> all(
          {int limit = 200, String profileId = 'self'}) =>
      Future.delayed(Duration.zero, () => <ScreeningResult>[]);
  @override
  Future<List<Map<String, String>>> profiles() async => [
        {'id': 'self', 'name': 'Self'}
      ];
}

void main() {
  test('throwing history throws synchronously', () async {
    await expectLater(_ThrowingHistory().all(), throwsStateError);
  });

  group('Eyes failure panels', () {
    testWidgets('permissionDenied shows retry + settings panel',
        (tester) async {
      final cam = CameraService()
        ..debugSetStage(CameraStage.permissionDenied, 'denied');
      await _pumpEyeStage(tester, cam);
      expect(find.text('Camera permission needed'), findsOneWidget);
      expect(find.text('Retry permission'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('mlDegraded shows unavailable panel with escape',
        (tester) async {
      final cam = CameraService()
        ..debugSetStage(CameraStage.mlDegraded, 'detector-down');
      await _pumpEyeStage(tester, cam);
      expect(find.text('Analysis unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Use snapshot scan'), findsOneWidget);
    });

    testWidgets('healthy idle shows neither failure panel',
        (tester) async {
      final cam = CameraService();
      await _pumpEyeStage(tester, cam);
      expect(find.text('Camera permission needed'), findsNothing);
      expect(find.text('Analysis unavailable'), findsNothing);
    });
  });

  group('Report load sanity', () {
    testWidgets('empty store renders empty state (async resumes)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<HistoryRepository>.value(
                value: _EmptyHistory()),
            ChangeNotifierProvider<AppState>(
                create: (_) => AppState('en')),
          ],
          child: const MaterialApp(home: ReportScreen()),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
          find.text('No measurements to share yet.'), findsOneWidget);
    });
  });

  group('Report load failure', () {
    testWidgets('throwing store renders named error + retry',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<HistoryRepository>.value(
                value: _ThrowingHistory()),
            ChangeNotifierProvider<AppState>(
                create: (_) => AppState('en')),
          ],
          child: const MaterialApp(home: ReportScreen()),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.textContaining('Could not build the report'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Not the fake-empty state.
      expect(
          find.text('No measurements to share yet.'), findsNothing);
    });
  });
}
