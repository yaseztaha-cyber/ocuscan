// Validation database tests: experiment/trial/reference/device CRUD,
// unable-rate aggregation, failure counts, cascade delete, export join.
// Uses an in-memory database (sqflite_common_ffi) — never the real file.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ocuscan/core/data/app_database.dart';
import 'package:ocuscan/core/validation/experiment_models.dart';
import 'package:ocuscan/core/validation/validation_repository.dart';

int _dbCounter = 0;

/// Isolated file-backed database per test (never the real app file).
Future<ValidationRepository> _repo() async {
  sqfliteFfiInit();
  final tmp = await Directory.systemTemp.createTemp('ocuscan_db_test');
  final path = '${tmp.path}/test_${_dbCounter++}.db';
  final db = await databaseFactoryFfi.openDatabase(path);
  await AppDatabase.createConsumerSchema(db);
  await AppDatabase.createValidationSchema(db);
  return ValidationRepository.forTest(db);
}

Experiment _exp(String name) => Experiment(
      name: name,
      testType: 'pupil',
      deviceLabel: 'Device A',
      lightingLevel: 'moderate',
      subjectId: 'R001',
      analyzerVersion: 'pupil v1',
      createdAt: DateTime.utc(2026, 9, 25),
    );

Trial _trial(int expId, TrialStatus status,
        {double? value, String? failure}) =>
    Trial(
      experimentId: expId,
      timestamp: DateTime.utc(2026, 9, 25, 12),
      inputQuality: 'high',
      value: value,
      unit: 'index',
      status: status,
      failureReason: failure,
      lightingLevel: 'moderate',
      deviceLabel: 'Device A',
      subjectId: 'R001',
      testType: 'pupil',
    );

void main() {
  group('experiments', () {
    test('create, read, update, delete', () async {
      final repo = await _repo();
      final id = await repo.createExperiment(_exp('E1'));
      expect(id, greaterThan(0));

      final list = await repo.listExperiments();
      expect(list.length, 1);
      expect(list.first.name, 'E1');

      final got = await repo.getExperiment(id);
      expect(got!.analyzerVersion, 'pupil v1');

      await repo.updateExperiment(got);
      final id2 = await repo.createExperiment(_exp('E2'));
      expect((await repo.listExperiments()).length, 2);

      await repo.deleteExperiment(id2);
      expect((await repo.listExperiments()).length, 1);
    });
  });

  group('trials', () {
    test('record and list in timestamp order', () async {
      final repo = await _repo();
      final id = await repo.createExperiment(_exp('E1'));
      await repo.recordTrial(_trial(id, TrialStatus.accepted, value: 0.041));
      await repo.recordTrial(_trial(id, TrialStatus.unable,
          failure: 'LOW_ILLUMINATION'));
      final trials = await repo.trialsForExperiment(id);
      expect(trials.length, 2);
      expect(trials.first.value, closeTo(0.041, 1e-12));
    });

    test('deleteExperiment cascades its trials', () async {
      final repo = await _repo();
      final id = await repo.createExperiment(_exp('E1'));
      await repo.recordTrial(_trial(id, TrialStatus.accepted, value: 0.1));
      await repo.deleteExperiment(id);
      expect(await repo.trialsForExperiment(id), isEmpty);
      expect(await repo.queryTrials(testType: 'pupil'), isEmpty);
    });

    test('queryTrials filters by grouping columns', () async {
      final repo = await _repo();
      final id = await repo.createExperiment(_exp('E1'));
      await repo.recordTrial(_trial(id, TrialStatus.accepted, value: 0.1));
      expect(
          (await repo.queryTrials(
                  testType: 'pupil', deviceLabel: 'Device A'))
              .length,
          1);
      expect(
          (await repo.queryTrials(deviceLabel: 'Device Z')).length, 0);
    });

    test('unableBy groups unable counts per test', () async {
      final repo = await _repo();
      final id = await repo.createExperiment(_exp('E1'));
      await repo.recordTrial(_trial(id, TrialStatus.accepted, value: 0.1));
      await repo.recordTrial(
          _trial(id, TrialStatus.unable, failure: 'BLUR'));
      await repo.recordTrial(
          _trial(id, TrialStatus.unable, failure: 'BLUR'));
      final m = await repo.unableBy('testType');
      expect(m['pupil']!.unable, 2);
      expect(m['pupil']!.total, 3);
    });

    test('unableBy rejects non-whitelisted columns', () async {
      final repo = await _repo();
      expect(() => repo.unableBy('value; DROP TABLE trials;--'),
          throwsArgumentError);
    });

    test('failureCounts tallies non-accepted reasons', () async {
      final repo = await _repo();
      final id = await repo.createExperiment(_exp('E1'));
      await repo.recordTrial(
          _trial(id, TrialStatus.rejected, failure: 'BLUR'));
      await repo.recordTrial(
          _trial(id, TrialStatus.unable, failure: 'BLUR'));
      await repo.recordTrial(_trial(id, TrialStatus.accepted, value: 0.2));
      final counts = await repo.failureCounts();
      expect(counts['BLUR'], 2);
      expect(counts.containsKey('OTHER'), false);
    });
  });

  group('reference labels + devices + export rows', () {
    test('reference labels persist researcher documentation', () async {
      final repo = await _repo();
      await repo.addReferenceLabel(const ReferenceLabel(
        datasetId: 'local-repeat-study',
        sampleId: 'R001-s1',
        testType: 'pupil',
        referenceFinding: 'filed in lab notebook',
        referenceMethod: 'documented procedure',
        source: 'operator',
      ));
      final labels = await repo.listReferenceLabels();
      expect(labels.length, 1);
      expect(labels.first.datasetId, 'local-repeat-study');
    });

    test('device profiles upsert by anonymous label', () async {
      final repo = await _repo();
      await repo.upsertDeviceProfile(
          const DeviceProfile(deviceLabel: 'Device A', model: 'M1'));
      await repo.upsertDeviceProfile(
          const DeviceProfile(deviceLabel: 'Device A', model: 'M2'));
      final profiles = await repo.listDeviceProfiles();
      expect(profiles.length, 1);
      expect(profiles.first.model, 'M2');
    });

    test('exportRows joins trials with experiment context', () async {
      final repo = await _repo();
      final id = await repo.createExperiment(_exp('E1'));
      await repo.recordTrial(_trial(id, TrialStatus.accepted, value: 0.041));
      final rows = await repo.exportRows(experimentId: id);
      expect(rows.length, 1);
      expect(rows.first.experimentName, 'E1');
      expect(rows.first.analyzerVersion, 'pupil v1');
      expect(rows.first.value, '0.041');
      expect(rows.first.status, 'accepted');
    });
  });
}
