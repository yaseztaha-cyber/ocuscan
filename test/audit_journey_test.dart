// Widget-level journey audit: real routes, real providers, desktop FFI
// database — no mocks for repositories. Verifies onboarding, screening
// gating, vision persistence, learn/evidence, research gate + /dev tabs,
// experiment creation, delete-all, and Arabic rendering.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ocuscan/app.dart';
import 'package:ocuscan/main.dart';
import 'package:ocuscan/core/data/app_database.dart';
import 'package:ocuscan/core/data/history_repository.dart';
import 'package:ocuscan/core/data/settings_repository.dart';
import 'package:ocuscan/core/evidence/evidence_repository.dart';
import 'package:ocuscan/core/validation/validation_repository.dart';
import 'package:ocuscan/features/camera/camera_service.dart';
import 'package:ocuscan/features/catalog/detection_catalog.dart';

Future<void> _calm(WidgetTester tester, {int ms = 800}) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

/// Scroll until visible, then tap the ON-SCREEN match (not blindly the
/// first: duplicate texts across tabs/dialogs/off-screen list items
/// otherwise send taps to hidden widgets). Lazy lists only build
/// on-screen items, so this polls: nudge scrollables until the finder
/// matches on-screen, then tap. Never assumes uniqueness.
/// NOTE: tester.ensureVisible is deliberately avoided — awaiting its scroll
/// animation can deadlock the fake-async test clock.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  final matches = finder.evaluate();
  expect(matches.isNotEmpty, true, reason: 'never visible: $finder');
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  Element target = matches.first;
  for (final e in matches) {
    try {
      final o = e.renderObject;
      if (o is RenderBox && o.attached && o.hasSize) {
        final c = o.localToGlobal(o.size.center(Offset.zero));
        if (c.dx >= 0 &&
            c.dy >= 0 &&
            c.dx <= size.width &&
            c.dy <= size.height) {
          target = e;
          break;
        }
      }
    } catch (_) {}
  }
  await tester.tap(find.byWidget(target.widget));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scroll scrollables until [finder] matches an on-screen widget (up to
/// ~30 nudges). Uses viewport hit-coordinates instead of ensureVisible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  bool onScreen(Element e) {
    final o = e.renderObject;
    if (o is! RenderBox || !o.attached || !o.hasSize) return false;
    final c = o.localToGlobal(o.size.center(Offset.zero));
    return c.dx >= 0 &&
        c.dy >= 0 &&
        c.dx <= size.width &&
        c.dy <= size.height;
  }

  for (var i = 0; i < 30; i++) {
    var hit = false;
    for (final e in finder.evaluate()) {
      try {
        if (onScreen(e)) {
          hit = true;
          break;
        }
      } catch (_) {}
    }
    if (hit) return;
    var dragged = false;
    for (final s in find.byType(Scrollable).evaluate()) {
      await tester.drag(find.byWidget(s.widget), const Offset(0, -250),
          warnIfMissed: false);
      dragged = true;
    }
    await tester.pump(const Duration(milliseconds: 200));
    if (!dragged) return;
  }
}

/// Pump until [finder] matches or [tries] expire. Robust under load and
/// for async asset/DB loads. Returns true when found.
Future<bool> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int tries = 20,
}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return finder.evaluate().isNotEmpty;
}

/// Yield real time so real-async work (asset reads, DB I/O) can finish,
// then pump to rebuild. Fake-clock pumps alone cannot complete real I/O.
//
// FFI queries started from widget code need INTERLEAVED progress: each
// round trip alternates between the real event loop and fake-zone
// microtasks, so a single real window is not enough — ratchet both
// clocks several times instead (proven against widget-test stalls).
Future<void> _settleRealIO(WidgetTester tester,
    {int seconds = 2}) async {
  final cycles = (seconds * 3).clamp(3, 9);
  for (var i = 0; i < cycles; i++) {
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Flush sqflite's internal transaction timers: DB-backed screens fire
/// FFI queries that never complete in the fake zone, leaving the
/// driver's timeout timers pending at test end (framework failure).
/// Advancing the fake clock lets them fire and settle. Call at the end
/// of tests that visit DB-backed routes without a ratchet.
Future<void> _flushDbTimers(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Tap a TabBar label. Scrollable tab bars lay out wider than the
/// viewport, so first scroll the tab strip horizontally until the label
/// center is inside the screen, then tap and let the page animation run.
Future<void> _tapTab(WidgetTester tester, String label) async {
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final tab = find.text(label);
  for (var i = 0; i < 20; i++) {
    final e = tab.evaluate();
    if (e.isNotEmpty) {
      final o = e.first.renderObject;
      if (o is RenderBox && o.attached && o.hasSize) {
        final c = o.localToGlobal(o.size.center(Offset.zero));
        if (c.dx >= 0 &&
            c.dx <= size.width &&
            c.dy >= 0 &&
            c.dy <= size.height) {
          await tester.tap(tab);
          await tester.pump(const Duration(milliseconds: 700));
          return;
        }
        final dx = c.dx > size.width ? -240.0 : 240.0;
        await tester.drag(find.byType(TabBar).first, Offset(dx, 0),
            warnIfMissed: false);
        // Long pump lets the strip fling settle so the next measurement
        // reflects the final position (tapping mid-fling coordinates
        // misses the tab).
        await tester.pump(const Duration(milliseconds: 1000));
        continue;
      }
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('tab not reachable: $label');
}

void main() {
  late HistoryRepository history;
  late ValidationRepository validation;

  setUpAll(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createConsumerSchema(db);
    await AppDatabase.createValidationSchema(db);
    history = HistoryRepository.forTest(db);
    validation = ValidationRepository.forTest(db);
    // Same asset file, disk transport: rootBundle never resolves inside
    // the fake-async widget-test zone (proven), so read the identical
    // JSON from disk instead. Only the transport differs, not the data.
    EvidenceRepository.debugLoaderOverride = () async {
      for (final p in [
        'assets/medical_evidence.json',
        '../assets/medical_evidence.json',
        '${Directory.current.path}${Platform.pathSeparator}assets'
            '${Platform.pathSeparator}medical_evidence.json',
        'D:${Platform.pathSeparator}YASEZ_HOME${Platform.pathSeparator}projects'
            '${Platform.pathSeparator}medical eye app${Platform.pathSeparator}assets'
            '${Platform.pathSeparator}medical_evidence.json',
      ]) {
        final f = File(p);
        if (f.existsSync()) {
          return EvidenceRepository.parse(f.readAsStringSync());
        }
      }
      throw StateError('medical_evidence.json not found; cwd='
          '${Directory.current.path}');
    };
    // Same pattern for the capability catalog: the audit tab loads it,
    // and rootBundle never resolves in the test zone.
    DetectionCatalog.debugLoaderOverride = () async {
      for (final p in [
        'assets/detection_catalog.json',
        '../assets/detection_catalog.json',
        '${Directory.current.path}${Platform.pathSeparator}assets'
            '${Platform.pathSeparator}detection_catalog.json',
      ]) {
        final f = File(p);
        if (f.existsSync()) {
          return DetectionCatalog.parse(f.readAsStringSync());
        }
      }
      throw StateError('detection_catalog.json not found; cwd='
          '${Directory.current.path}');
    };
  });

  tearDownAll(() {
    EvidenceRepository.debugLoaderOverride = null;
    DetectionCatalog.debugLoaderOverride = null;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsRepository>.value(
              value: SettingsRepository(prefs)),
          Provider<HistoryRepository>.value(value: history),
          Provider<ValidationRepository>.value(value: validation),
          ChangeNotifierProvider<CameraService>(
              create: (_) => CameraService()),
          ChangeNotifierProvider<AppState>(
              create: (_) => AppState('en')),
        ],
        child: const OcuScanApp(),
      ),
    );
    await _calm(tester, ms: 1500);
  }

  testWidgets('onboarding reaches home without loops', (tester) async {
    await pumpApp(tester);
    expect(find.text('Welcome to OcuScan'), findsOneWidget);
    await _tapVisible(tester, find.text('Continue'));
    await _calm(tester);
    expect(find.textContaining('Before your first screening'),
        findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump(const Duration(milliseconds: 300));
    await _tapVisible(tester, find.text('I understand — continue'));
    await _calm(tester, ms: 1200);
    expect(find.text('Start screening'), findsOneWidget);
    await _scrollTo(tester, find.textContaining('Research mode: OFF'));
    expect(find.textContaining('Research mode: OFF'), findsOneWidget);
  });
  testWidgets('screening gates camera honestly on camerless runtime',
      (tester) async {
    await pumpApp(tester);
    // Fast-forward past onboarding.
    await _tapVisible(tester, find.text('Continue'));
    await _calm(tester);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump(const Duration(milliseconds: 300));
    await _tapVisible(tester, find.text('I understand — continue'));
    await _calm(tester, ms: 1200);

    await tester.tap(find.text('Start screening'));
    await _calm(tester, ms: 1500);
    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    await _tapVisible(
        tester, find.widgetWithText(FilledButton, 'Continue'));
    await _calm(tester, ms: 1500);
    expect(find.textContaining('Step 2 of 5'), findsOneWidget);
    // No camera on desktop: staged eye view shows guidance, Continue
    // disabled until a real eye lock (impossible without a camera).
    // The eye stage is taller than the viewport: scroll to build the bar.
    expect(find.textContaining('Camera unavailable'), findsWidgets);
    // v0.3.3 camera UI present even without hardware: source selector,
    // pipeline checklist, and camera help entry (scroll to build it).
    expect(find.text('Best for this test'), findsOneWidget);
    await _scrollTo(tester, find.text('Camera help'));
    expect(find.text('Camera help'), findsWidgets);
    await _scrollTo(
        tester, find.widgetWithText(FilledButton, 'Continue'));
    final cont = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(cont.onPressed, isNull);
    // Exit and re-enter without crash (lifecycle).
    await tester.tap(find.byIcon(Icons.close));
    await _calm(tester);
    await tester.tap(find.text('Start screening'));
    await _calm(tester, ms: 1500);
    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
  });

  testWidgets('vision distance test completes and persists', (tester) async {
    // Tall surface: the whole running branch fits without scrolling, so
    // answer taps cannot land on neighboring tiles (scroll-position
    // dependent misses made this test flaky on the default 800x600).
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    final ctx = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(ctx, '/vision');
    await _calm(tester, ms: 1200);
    expect(find.text('Vision Lab'), findsOneWidget);
    // Begin the distance test, then answer a fixed direction: the
    // forced-choice staircase descends on balance and completes with a
    // final measured result (also exercising the uncalibrated → unable
    // path, since the checklist starts unchecked).
    await _tapVisible(tester, find.text('Begin test'));
    // Fixed-direction answers: the staircase needs 24 registered answers
    // (reversals or max trials). Taps occasionally land on a neighboring
    // checkbox while the list settles, wasting an answer without effect,
    // so allow generous margin — completion, not tap count, is asserted.
    for (var i = 0; i < 60; i++) {
      if (find.textContaining('Measured visual acuity').evaluate().isNotEmpty) {
        break;
      }
      if (find.text('↑').evaluate().isEmpty) break;
      await _tapVisible(tester, find.text('↑'));
    }
    // The result screen (and its persisted row) needs extra pumps after
    // the completing tap — assert with a wait, not immediately.
    expect(
        await _pumpUntilFound(
            tester, find.textContaining('Measured visual acuity'),
            tries: 30),
        true,
        reason: 'distance staircase never produced a result');
    expect(tester.takeException(), isNull);
    // Allow the UI-triggered persist to finish real I/O, then verify.
    await _settleRealIO(tester);
    final rows =
        await tester.runAsync(() => history.all(limit: 50)) ?? [];
    expect(rows.isNotEmpty, true,
        reason: 'vision outcome must persist to history');
    final saved = rows.firstWhere(
        (r) => r.testName == 'Distance visual acuity',
        orElse: () => throw 'missing distance row');
    // Uncalibrated checklist → honest unable-to-assess record.
    expect(saved.finding.name, 'unableToAssess');
  });

  testWidgets('learn renders tiers; references page filters', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(ctx, '/learn');
    // Asset reads are real-async: yield real time before polling.
    await _settleRealIO(tester);
    expect(await _pumpUntilFound(tester, find.text('What OcuScan measures')),
        true);
    expect(find.textContaining('Tier'), findsWidgets);
    await _tapVisible(tester, find.text('References'));
    await _settleRealIO(tester);
    expect(
        await _pumpUntilFound(
            tester,
            find.textContaining(
                'Published evidence vs OcuScan evidence')),
        true);
    // Filter chip: pick one category and verify it is the active filter.
    await _tapVisible(tester, find.text('Vision testing'));
    await _calm(tester);
    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((c) => c.selected)
        .map((c) => (c.label as Text).data)
        .toList();
    expect(selected, ['Vision testing']);
    // Cards render lazily: scroll to build them before asserting.
    await _scrollTo(tester, find.textContaining('Cited by'));
    expect(find.textContaining('Cited by'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('research gate, dev tabs, experiment create, delete-all',
      (tester) async {
    await pumpApp(tester);
    var ctx = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(ctx, '/settings');
    await _calm(tester);
    await _tapVisible(tester, find.text('Research validation mode'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Enable research mode?'), findsOneWidget);
    await _tapVisible(tester, find.text('I understand — enable'));
    await _settleRealIO(tester);
    await tester.pump(const Duration(milliseconds: 500));
    // The new tile is appended below the fold (lazy list, not built yet):
    // scroll-tap directly instead of a no-scroll pre-check.
    await _tapVisible(tester, find.text('Open research validation'));
    await _settleRealIO(tester);
    expect(await _pumpUntilFound(tester, find.text('Research Validation')),
        true);
    for (final entry in [
      ('Evidence Audit', 'Evidence coverage'),
      ('Fairness & Robustness', 'Not evaluated'),
      ('Export', 'Export CSV'),
      ('Experiments', 'New experiment'),
    ]) {
      // Tab strip scrolls horizontally; only _tapTab can reach far tabs.
      await _tapTab(tester, entry.$1);
      // Tab pages load repos via FFI: ratchet both clocks, then scroll
      // the page to build lazy content before asserting.
      await _settleRealIO(tester, seconds: 2);
      await _scrollTo(tester, find.textContaining(entry.$2));
      expect(await _pumpUntilFound(tester, find.textContaining(entry.$2),
          tries: 30), true,
          reason: 'tab ${entry.$1} content missing');
    }
    // Create an experiment via the dialog (already on Experiments tab).
    await _calm(tester);
    await tester.tap(
        find.widgetWithText(FloatingActionButton, 'New experiment'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(
        find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextField))
            .first,
        'Audit probe experiment');
    await tester.tap(find.text('Create'));
    await _settleRealIO(tester);
    await _calm(tester, ms: 1200);
    await _scrollTo(tester, find.text('Audit probe experiment'));
    expect(find.text('Audit probe experiment'), findsOneWidget);
    // Back to settings: delete-all clears everything.
    ctx = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(ctx, '/settings');
    await _calm(tester);
    await _tapVisible(tester, find.text('Delete all data'));
    // The dialog opens after a real database read (per-profile stats),
    // so settle real I/O first, then poll for its title.
    await _settleRealIO(tester, seconds: 2);
    expect(
        await _pumpUntilFound(tester, find.text('Delete all data?'),
            tries: 30),
        true,
        reason: 'delete-all confirmation dialog missing');
    // Confirm the delete-all dialog (confirm button repeats the label).
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete all data')));
    await _settleRealIO(tester);
    await _calm(tester, ms: 1200);
    expect(find.text('All local screening data deleted.'),
        findsOneWidget);
    final remainingHistory =
        await tester.runAsync(() => history.all(limit: 5)) ?? [];
    expect(remainingHistory, isEmpty);
    final remainingExps =
        await tester.runAsync(() => validation.listExperiments()) ?? [];
    expect(remainingExps, isEmpty);
  });

  testWidgets('arabic renders home RTL', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(ctx, '/settings');
    await _calm(tester);
    await _scrollTo(tester, find.text('Language / اللغة'));
    await _tapVisible(tester, find.text('عربي'));
    await _calm(tester, ms: 1200);
    var backCtx = tester.element(find.byType(Scaffold).first);
    Navigator.maybePop(backCtx);
    await _calm(tester, ms: 1200);
    // Back on the welcome screen, now in Arabic with RTL direction.
    // The Continue button sits at the bottom of a lazy ListView: scroll first.
    expect(find.text('أهلاً بك في OcuScan'), findsOneWidget);
    await _scrollTo(tester, find.text('متابعة'));
    expect(find.text('متابعة'), findsOneWidget);
    expect(
        tester
            .widget<Directionality>(find.byType(Directionality).first)
            .textDirection,
        TextDirection.rtl);
  });

  testWidgets('arabic walkthrough renders all major screens', (tester) async {
    await pumpApp(tester);
    var ctx = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(ctx, '/settings');
    await _calm(tester);
    await _scrollTo(tester, find.text('Language / اللغة'));
    await _tapVisible(tester, find.text('عربي'));
    await _calm(tester, ms: 1200);
    // Walk every major consumer route in Arabic; each must build without
    // errors (catches missing localizations, RTL overflows, RTL crashes).
    // Research gate intentionally left OFF: /dev shows its Arabic gate.
    const routes = [
      '/consent',
      '/home',
      '/screening',
      '/vision',
      '/history',
      '/learn',
      '/references',
      '/about',
      '/emergency',
      '/settings',
      '/methodology',
      '/retinal-info',
      '/color-calibration',
      '/camera-help',
      '/dev',
      '/eye-debug',
      '/face-test',
      '/ml-test',
      '/face-diagnostic',
      '/compat-lab',
      '/trends',
      '/report',
      '/capabilities',
    ];
    for (final r in routes) {
      ctx = tester.element(find.byType(Scaffold).first);
      Navigator.pushReplacementNamed(ctx, r);
      if (r == '/learn' || r == '/references') {
        await _settleRealIO(tester);
      }
      await _calm(tester, ms: 1200);
      expect(tester.takeException(), isNull, reason: 'route $r');
      expect(find.byType(Scaffold).evaluate().isNotEmpty, true,
          reason: 'route $r builds a screen');
    }
    // Flush sqflite's internal timers from late DB-backed routes before
    // the framework's end-of-test pending-timer check.
    await _flushDbTimers(tester);
    // Still RTL at the end, still Arabic strings on a deep screen.
    expect(
        tester
            .widget<Directionality>(find.byType(Directionality).first)
            .textDirection,
        TextDirection.rtl);
  });
}
