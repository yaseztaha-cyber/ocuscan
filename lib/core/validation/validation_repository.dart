// Validation repository: CRUD + aggregation for research experiments.
//
// Same shared database file as consumer history (AppDatabase), separate
// tables. The database handle is injectable so tests can use an in-memory
// database without touching the real file.

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../data/app_database.dart';
import 'experiment_models.dart';

/// One joined row for export and cross-experiment analysis.
class TrialExportRow {
  final int experimentId;
  final String experimentName;
  final int trialId;
  final String testType;
  final String analyzerVersion;
  final String deviceLabel;
  final String camera;
  final String timestamp;
  final String subjectId;
  final String lightingLevel;
  final String lux;
  final String distanceCm;
  final String headAngleDeg;
  final String inputQuality;
  final String confidence;
  final String value;
  final String unit;
  final String measurementLabel;
  final String status;
  final String failureReason;
  final String referenceValue;
  final String referenceMethod;
  final String notes;
  // R1: previously dropped columns — trial quality snapshot,
  // experiment screen brightness, fairness labels, and free-text
  // conditions. Optional with empty defaults so old constructions
  // keep compiling; empty means "not recorded", never backfilled.
  final String luminance;
  final String sharpness;
  final String exposureBadFraction;
  final String screenBrightness;
  final String skinTone;
  final String eyeColor;
  final String eyewear;
  final String ageGroup;
  final String environmentalNotes;
  final String operatorNotes;

  const TrialExportRow({
    required this.experimentId,
    required this.experimentName,
    required this.trialId,
    required this.testType,
    required this.analyzerVersion,
    required this.deviceLabel,
    required this.camera,
    required this.timestamp,
    required this.subjectId,
    required this.lightingLevel,
    required this.lux,
    required this.distanceCm,
    required this.headAngleDeg,
    required this.inputQuality,
    required this.confidence,
    required this.value,
    required this.unit,
    required this.measurementLabel,
    required this.status,
    required this.failureReason,
    required this.referenceValue,
    required this.referenceMethod,
    required this.notes,
    this.luminance = '',
    this.sharpness = '',
    this.exposureBadFraction = '',
    this.screenBrightness = '',
    this.skinTone = '',
    this.eyeColor = '',
    this.eyewear = '',
    this.ageGroup = '',
    this.environmentalNotes = '',
    this.operatorNotes = '',
  });
}

class ValidationRepository {
  final Future<Database> Function() _opener;
  ValidationRepository({Future<Database> Function()? opener})
      : _opener = opener ?? AppDatabase.open;

  /// Test constructor with an already-open database (e.g. in-memory FFI).
  ValidationRepository.forTest(Database db) : _opener = (() async => db);

  Future<Database> get _db async => _opener();

  // ---- Experiments ----

  Future<int> createExperiment(Experiment e) async {
    final d = await _db;
    return d.insert('experiments', e.toMap());
  }

  Future<List<Experiment>> listExperiments() async {
    final d = await _db;
    final rows =
        await d.query('experiments', orderBy: 'createdAt DESC');
    return rows.map(Experiment.fromMap).toList();
  }

  Future<Experiment?> getExperiment(int id) async {
    final d = await _db;
    final rows =
        await d.query('experiments', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Experiment.fromMap(rows.first);
  }

  Future<int> updateExperiment(Experiment e) async {
    final d = await _db;
    final m = e.toMap()..remove('id');
    return d.update('experiments', m, where: 'id = ?', whereArgs: [e.id]);
  }

  Future<int> deleteExperiment(int id) async {
    final d = await _db;
    await d.delete('trials', where: 'experimentId = ?', whereArgs: [id]);
    await d.delete('experiments', where: 'id = ?', whereArgs: [id]);
    return 1;
  }

  // ---- Trials ----

  Future<int> recordTrial(Trial t) async {
    final d = await _db;
    return d.insert('trials', t.toMap());
  }

  Future<int> updateTrial(Trial t) async {
    final d = await _db;
    final m = t.toMap()..remove('id');
    return d.update('trials', m, where: 'id = ?', whereArgs: [t.id]);
  }

  Future<List<Trial>> trialsForExperiment(int experimentId) async {
    final d = await _db;
    final rows = await d.query('trials',
        where: 'experimentId = ?',
        whereArgs: [experimentId],
        orderBy: 'timestamp ASC');
    return rows.map(Trial.fromMap).toList();
  }

  Future<int> deleteTrial(int id) async {
    final d = await _db;
    return d.delete('trials', where: 'id = ?', whereArgs: [id]);
  }

  /// All trials matching optional grouping filters (null = no filter).
  Future<List<Trial>> queryTrials({
    String? testType,
    String? deviceLabel,
    String? lightingLevel,
    double? distanceCm,
    double? headAngleDeg,
    String? subjectId,
  }) async {
    final d = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    void add(String clause, Object? arg) {
      clauses.add(clause);
      args.add(arg);
    }

    if (testType != null) add('testType = ?', testType);
    if (deviceLabel != null) add('deviceLabel = ?', deviceLabel);
    if (lightingLevel != null) add('lightingLevel = ?', lightingLevel);
    if (distanceCm != null) add('distanceCm = ?', distanceCm);
    if (headAngleDeg != null) add('headAngleDeg = ?', headAngleDeg);
    if (subjectId != null) add('subjectId = ?', subjectId);
    final rows = await d.query('trials',
        where: clauses.isEmpty ? null : clauses.join(' AND '),
        whereArgs: clauses.isEmpty ? null : args,
        orderBy: 'timestamp ASC');
    return rows.map(Trial.fromMap).toList();
  }

  /// Unable-to-assess counts grouped by an arbitrary trial column.
  /// [column] must be one of the whitelisted grouping columns.
  Future<Map<String, ({int unable, int total})>> unableBy(
      String column) async {
    const allowed = {
      'testType',
      'deviceLabel',
      'lightingLevel',
      'distanceCm',
      'headAngleDeg',
      'subjectId',
      'inputQuality',
    };
    if (!allowed.contains(column)) {
      throw ArgumentError('Invalid grouping column: $column');
    }
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT COALESCE(CAST($column AS TEXT), 'unspecified') AS grp,
             SUM(CASE WHEN status = 'unable' THEN 1 ELSE 0 END) AS unable,
             COUNT(*) AS total
      FROM trials GROUP BY grp ORDER BY grp
    ''');
    final out = <String, ({int unable, int total})>{};
    for (final r in rows) {
      out[(r['grp'] ?? 'unspecified').toString()] = (
        unable: (r['unable'] as num? ?? 0).toInt(),
        total: (r['total'] as num? ?? 0).toInt(),
      );
    }
    return out;
  }

  /// Failure-reason counts (rejected + unable trials with a recorded reason).
  Future<Map<String, int>> failureCounts() async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT COALESCE(failureReason, 'UNSPECIFIED') AS reason, COUNT(*) AS n
      FROM trials WHERE status != 'accepted'
      GROUP BY reason ORDER BY n DESC
    ''');
    return {
      for (final r in rows)
        (r['reason'] ?? 'UNSPECIFIED').toString():
            (r['n'] as num? ?? 0).toInt()
    };
  }

  // ---- Reference labels (future-ready, researcher-documented only) ----

  Future<int> addReferenceLabel(ReferenceLabel l) async {
    final d = await _db;
    return d.insert('reference_labels', l.toMap());
  }

  Future<List<ReferenceLabel>> listReferenceLabels() async {
    final d = await _db;
    final rows = await d.query('reference_labels');
    return rows.map(ReferenceLabel.fromMap).toList();
  }

  // ---- Device profiles ----

  Future<void> upsertDeviceProfile(DeviceProfile p) async {
    final d = await _db;
    await d.insert('device_profiles', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DeviceProfile>> listDeviceProfiles() async {
    final d = await _db;
    final rows = await d.query('device_profiles');
    return rows.map(DeviceProfile.fromMap).toList();
  }

  // ---- Export ----

  Future<List<TrialExportRow>> exportRows({int? experimentId}) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT t.id AS trialId, t.experimentId AS experimentId,
             e.name AS experimentName,
             COALESCE(t.testType, e.testType) AS testType,
             e.analyzerVersion AS analyzerVersion,
             COALESCE(t.deviceLabel, e.deviceLabel) AS deviceLabel,
             e.camera AS camera, t.timestamp AS timestamp,
             COALESCE(t.subjectId, e.subjectId) AS subjectId,
             COALESCE(t.lightingLevel, e.lightingLevel) AS lightingLevel,
             COALESCE(t.lux, e.lux) AS lux,
             COALESCE(t.distanceCm, e.targetDistanceCm) AS distanceCm,
             COALESCE(t.headAngleDeg, e.headAngleDeg) AS headAngleDeg,
             t.inputQuality AS inputQuality, t.confidence AS confidence,
             t.value AS value, t.unit AS unit,
             t.measurementLabel AS measurementLabel,
             t.status AS status, t.failureReason AS failureReason,
             t.referenceValue AS referenceValue,
             t.referenceMethod AS referenceMethod, t.notes AS notes,
             t.luminance AS luminance, t.sharpness AS sharpness,
             t.exposureBadFraction AS exposureBadFraction,
             e.screenBrightness AS screenBrightness,
             e.skinTone AS skinTone, e.eyeColor AS eyeColor,
             e.eyewear AS eyewear, e.ageGroup AS ageGroup,
             e.environmentalNotes AS environmentalNotes,
             e.operatorNotes AS operatorNotes
      FROM trials t JOIN experiments e ON e.id = t.experimentId
      ${experimentId == null ? '' : 'WHERE t.experimentId = ?'}
      ORDER BY t.timestamp ASC
    ''', experimentId == null ? null : [experimentId]);
    String cell(Object? v) => v == null ? '' : v.toString();
    return [
      for (final r in rows)
        TrialExportRow(
          experimentId: (r['experimentId'] as num? ?? 0).toInt(),
          experimentName: cell(r['experimentName']),
          trialId: (r['trialId'] as num? ?? 0).toInt(),
          testType: cell(r['testType']),
          analyzerVersion: cell(r['analyzerVersion']),
          deviceLabel: cell(r['deviceLabel']),
          camera: cell(r['camera']),
          timestamp: cell(r['timestamp']),
          subjectId: cell(r['subjectId']),
          lightingLevel: cell(r['lightingLevel']),
          lux: cell(r['lux']),
          distanceCm: cell(r['distanceCm']),
          headAngleDeg: cell(r['headAngleDeg']),
          inputQuality: cell(r['inputQuality']),
          confidence: cell(r['confidence']),
          value: cell(r['value']),
          unit: cell(r['unit']),
          measurementLabel: cell(r['measurementLabel']),
          status: cell(r['status']),
          failureReason: cell(r['failureReason']),
          referenceValue: cell(r['referenceValue']),
          referenceMethod: cell(r['referenceMethod']),
          notes: cell(r['notes']),
          luminance: cell(r['luminance']),
          sharpness: cell(r['sharpness']),
          exposureBadFraction: cell(r['exposureBadFraction']),
          screenBrightness: cell(r['screenBrightness']),
          skinTone: cell(r['skinTone']),
          eyeColor: cell(r['eyeColor']),
          eyewear: cell(r['eyewear']),
          ageGroup: cell(r['ageGroup']),
          environmentalNotes: cell(r['environmentalNotes']),
          operatorNotes: cell(r['operatorNotes']),
        )
    ];
  }
}

/// Local research-capture file storage. Images are stored ONLY when the
/// researcher explicitly enables "Save research capture" (OFF by default,
/// acknowledged, local-only, deletable). Capture files are never included
/// in CSV/JSON exports — exports carry measurement rows only.
class ResearchCaptureStore {
  final String baseDir;

  ResearchCaptureStore(this.baseDir);

  String pathFor(int experimentId, int trialId) =>
      '$baseDir/research_captures/exp_$experimentId/trial_$trialId.jpg';

  String dirForExperiment(int experimentId) =>
      '$baseDir/research_captures/exp_$experimentId';

  Future<bool> exists(int experimentId, int trialId) =>
      _file(pathFor(experimentId, trialId)).exists();

  /// Save raw JPEG bytes for a trial. Callers must verify the research
  /// capture switch + acknowledgment BEFORE calling.
  Future<void> save(
      int experimentId, int trialId, List<int> bytes) async {
    final f = _file(pathFor(experimentId, trialId));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  Future<void> deleteTrial(int experimentId, int trialId) async {
    try {
      final f = _file(pathFor(experimentId, trialId));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Delete all captures of an experiment (also called on experiment
  /// deletion and on delete-all-data).
  Future<void> deleteForExperiment(int experimentId) async {
    try {
      final dir = _dir(dirForExperiment(experimentId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  // Separated for unit tests (dart:io works in flutter test on desktop).
  File _file(String path) => File(path);
  Directory _dir(String path) => Directory(path);
}
