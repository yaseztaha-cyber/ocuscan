// Person-profile storage tests: scoping, CRUD, backfill behavior.
// In-memory FFI, no widgets.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ocuscan/core/data/app_database.dart';
import 'package:ocuscan/core/data/history_repository.dart';
import 'package:ocuscan/core/models/screening_result.dart';

ScreeningResult _row(String test, String profile) => ScreeningResult(
      testName: test,
      measurement: 'm',
      measurementUnit: '',
      imageQuality: ImageQuality.high,
      confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'x',
      possibleAssociations: const [],
      limitations: const [],
      recommendedAction: 'x',
      whyFlagged: 'x',
      timestamp: DateTime.utc(2026, 1, 1),
      profileId: profile,
    );

void main() {
  late HistoryRepository history;
  setUpAll(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createConsumerSchema(db);
    await AppDatabase.createValidationSchema(db);
    history = HistoryRepository.forTest(db);
  });

  test('default profile seeded', () async {
    final profs = await history.profiles();
    expect(profs.any((p) => p['id'] == 'self'), true);
  });

  test('rows are scoped per profile', () async {
    await history.insert(_row('T1', 'self'));
    await history.insert(_row('T1', 'pKid'));
    final selfRows = await history.all(profileId: 'self');
    final kidRows = await history.all(profileId: 'pKid');
    expect(selfRows.every((r) => r.profileId == 'self'), true);
    expect(kidRows.every((r) => r.profileId == 'pKid'), true);
    expect(kidRows.length, 1);
  });

  test('testNames scoped per profile', () async {
    final names = await history.testNames(profileId: 'pKid');
    expect(names, ['T1']);
  });

  test('add + delete profile with data', () async {
    await history.addProfile('pTmp', 'Tmp');
    var profs = await history.profiles();
    expect(profs.any((p) => p['id'] == 'pTmp'), true);
    await history.insert(_row('T9', 'pTmp'));
    await history.deleteProfile('pTmp');
    profs = await history.profiles();
    expect(profs.any((p) => p['id'] == 'pTmp'), false);
    final rows = await history.all(profileId: 'pTmp');
    expect(rows, isEmpty);
  });

  test('summary counts full history per profile', () async {
    ScreeningResult row(String test, ResultCategory f, DateTime t) =>
        ScreeningResult(
          testName: test,
          measurement: 'm',
          measurementUnit: '',
          imageQuality: ImageQuality.high,
          confidence: Confidence.low,
          finding: f,
          findingLabel: 'x',
          possibleAssociations: const [],
          limitations: const [],
          recommendedAction: 'x',
          whyFlagged: 'x',
          timestamp: t,
          profileId: 'pSum',
        );
    await history.insert(
        row('T1', ResultCategory.possibleFinding, DateTime.utc(2026, 2, 1)));
    await history.insert(row(
        'T2', ResultCategory.unableToAssess, DateTime.utc(2026, 2, 2)));
    await history.insert(row('T3', ResultCategory.noObviousAbnormality,
        DateTime.utc(2026, 2, 3)));
    final s = await history.summary(profileId: 'pSum');
    expect(s.total, 3);
    expect(s.possibleFindings, 1);
    expect(s.unableToAssess, 1);
    expect(s.latest, DateTime.utc(2026, 2, 3));
    expect(s.isEmpty, false);
    final empty = await history.summary(profileId: 'pNobody');
    expect(empty.isEmpty, true);
    expect(empty.latest, isNull);
  });

  test('eye + verified columns round-trip; old maps default safely', () async {
    final r = ScreeningResult(
      testName: 'T-eye',
      measurement: '6/12 (right eye)',
      measurementUnit: '',
      imageQuality: ImageQuality.high,
      confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'x',
      possibleAssociations: const [],
      limitations: const [],
      recommendedAction: 'x',
      whyFlagged: 'x',
      timestamp: DateTime.utc(2026, 3, 1),
      profileId: 'pEye',
      eye: 'right',
      conditionsVerified: true,
    );
    await history.insert(r);
    final rows = await history.all(profileId: 'pEye');
    expect(rows.length, 1);
    expect(rows.first.eye, 'right');
    expect(rows.first.conditionsVerified, true);
    // Pre-v6 map without the keys: unspecified + unverified, never invented.
    final legacy = ScreeningResult.fromMap(
        Map<String, dynamic>.of(r.toMap())
          ..remove('eye')
          ..remove('conditionsVerified'));
    expect(legacy.eye, '');
    expect(legacy.conditionsVerified, false);
  });

  test('profileStats reports counts and spans; rename works', () async {
    await history.addProfile('pFam', 'Fam');
    await history.insert(_row('T1', 'pFam'));
    var stats = await history.summary(profileId: 'pFam');
    expect(stats.total, greaterThanOrEqualTo(1));
    final all = await history.profileStats();
    final fam = all.firstWhere((s) => s.id == 'pFam');
    expect(fam.total, greaterThanOrEqualTo(1));
    expect(fam.name, 'Fam');
    await history.renameProfile('pFam', 'Family');
    final renamed = await history.profiles();
    expect(
        renamed.firstWhere((p) => p['id'] == 'pFam')['name'], 'Family');
    await history.renameProfile('pFam', '   ');
    final kept = await history.profiles();
    expect(
        kept.firstWhere((p) => p['id'] == 'pFam')['name'], 'Family');
  });

  test('v7 trace columns round-trip; legacy maps default empty', () async {
    ScreeningResult row() => ScreeningResult(
          testName: 'T-trace',
          measurement: 'm',
          measurementUnit: '',
          imageQuality: ImageQuality.high,
          confidence: Confidence.low,
          finding: ResultCategory.noObviousAbnormality,
          findingLabel: 'x',
          possibleAssociations: const [],
          limitations: const [],
          recommendedAction: 'x',
          whyFlagged: 'x',
          timestamp: DateTime.utc(2026, 4, 1),
          profileId: 'pTrace',
          modelVersion: 'face-detection:16.1.7 (bundled)',
          protocolVersion: 'quality-gate-v1',
          engine: 'dart-mlkit',
        );
    await history.insert(row());
    final rows = await history.all(profileId: 'pTrace');
    expect(rows.length, 1);
    expect(rows.first.modelVersion, contains('16.1.7'));
    expect(rows.first.modelHash, '');
    expect(rows.first.protocolVersion, 'quality-gate-v1');
    expect(rows.first.engine, 'dart-mlkit');
    // Pre-v7 map without trace keys: empty, never invented.
    final legacy = ScreeningResult.fromMap(
        Map<String, dynamic>.of(row().toMap())
          ..remove('modelVersion')
          ..remove('modelHash')
          ..remove('protocolVersion')
          ..remove('engine'));
    expect(legacy.modelVersion, '');
    expect(legacy.engine, '');
  });

  test('self profile cannot be deleted', () async {
    await history.deleteProfile('self');
    final profs = await history.profiles();
    expect(profs.any((p) => p['id'] == 'self'), true);
  });

  test('rows default to self profile', () async {
    final r = ScreeningResult(
      testName: 'T',
      measurement: 'm',
      measurementUnit: '',
      imageQuality: ImageQuality.high,
      confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'x',
      possibleAssociations: const [],
      limitations: const [],
      recommendedAction: 'x',
      whyFlagged: 'x',
      timestamp: DateTime.utc(2026, 1, 1),
    );
    expect(r.profileId, 'self');
    expect(r.copyWith(profileId: 'pKid').profileId, 'pKid');
  });
}
