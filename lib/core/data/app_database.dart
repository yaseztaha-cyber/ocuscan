// Shared local database (v0.5).
//
// One SQLite file (ocuscan.db), version 6. v1 held the consumer tables
// (results, sessions). v2 adds the research tables (experiments, trials,
// reference_labels, device_profiles) via onUpgrade. v3 adds optional
// fairness dimensions to experiments — existing user data is preserved.
// v4 adds result provenance columns (uncertainty, hardware, device,
// algorithm/evidence versions) — existing rows read back with empty
// provenance ("not recorded by that build"), never invented.
// v5 adds local person profiles: results.profileId (default 'self',
// backfilled for old rows) + profiles table. Profiles are on-device
// labels only — never identities, never uploaded.
// v6 adds explicit eye token + conditions-verified flag on results so
// trends stop regex-parsing wording. Old rows read back as unspecified
// (eye '') and unverified (0) — never backfilled, comparisons against
// them stay fail-closed to Caution.
// v7 adds measurement-trace columns (model/engine/protocol versions).
// Old rows read back empty ("not recorded by that build").
// Raw images are NEVER stored in this database.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static const String fileName = 'ocuscan.db';
  static const int version = 7;

  static Database? _db;

  static Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, fileName),
      version: version,
      onCreate: (d, v) async {
        await createConsumerSchema(d);
        await createValidationSchema(d);
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) {
          await createValidationSchema(d);
        }
        if (oldV < 3) {
          await addFairnessColumns(d);
        }
        if (oldV < 4) {
          await addResultProvenanceColumns(d);
        }
        if (oldV < 5) {
          await addProfileColumns(d);
        }
        if (oldV < 6) {
          await addEyeColumns(d);
        }
        if (oldV < 7) {
          await addTraceColumns(d);
        }
      },
    );
    return _db!;
  }

  /// Consumer tables (v1 schema + v4 provenance + v5 profile columns on
  /// fresh installs).
  static Future<void> createConsumerSchema(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS results(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        testName TEXT, measurement TEXT, measurementUnit TEXT,
        imageQuality TEXT, confidence TEXT, finding TEXT,
        findingLabel TEXT, possibleAssociations TEXT, limitations TEXT,
        recommendedAction TEXT, whyFlagged TEXT, timestamp TEXT,
        uncertainty TEXT, hardware TEXT, deviceLabel TEXT,
        algorithmVersion TEXT, evidenceVersion TEXT,
        profileId TEXT DEFAULT 'self',
        eye TEXT DEFAULT '', conditionsVerified INTEGER DEFAULT 0,
        modelVersion TEXT DEFAULT '', modelHash TEXT DEFAULT '',
        protocolVersion TEXT DEFAULT '', engine TEXT DEFAULT ''
      )''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS profiles(
        id TEXT PRIMARY KEY, name TEXT, createdAt TEXT
      )''');
    await d.execute(
        'INSERT OR IGNORE INTO profiles(id, name, createdAt) VALUES (\'self\', \'Self\', \'\')');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startedAt TEXT, finishedAt TEXT, note TEXT
      )''');
  }

  /// Research tables (v2 + v3 fairness columns). Measurements and conditions
  /// only — no images, no names, no identity. Fairness dimensions are
  /// optional researcher-entered labels, local-only.
  static Future<void> createValidationSchema(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS experiments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, description TEXT, testType TEXT,
        deviceLabel TEXT, camera TEXT,
        targetDistanceCm REAL, distanceNote TEXT,
        lightingLevel TEXT, lux REAL, screenBrightness REAL, headAngleDeg REAL,
        subjectId TEXT, environmentalNotes TEXT, operatorNotes TEXT,
        analyzerVersion TEXT, createdAt TEXT,
        skinTone TEXT, eyeColor TEXT, eyewear TEXT, ageGroup TEXT
      )''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS trials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        experimentId INTEGER, timestamp TEXT,
        inputQuality TEXT, value REAL, unit TEXT, measurementLabel TEXT,
        confidence TEXT, status TEXT, failureReason TEXT,
        referenceValue REAL, referenceMethod TEXT,
        lightingLevel TEXT, lux REAL, distanceCm REAL, headAngleDeg REAL,
        deviceLabel TEXT, subjectId TEXT, testType TEXT,
        notes TEXT, hasCapture INTEGER,
        luminance REAL, sharpness REAL, exposureBadFraction REAL
      )''');
    await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_trials_experiment ON trials(experimentId)');
    await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_trials_testtype ON trials(testType)');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS reference_labels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datasetId TEXT, sampleId TEXT, testType TEXT,
        referenceFinding TEXT, referenceMethod TEXT, source TEXT
      )''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS device_profiles(
        deviceLabel TEXT PRIMARY KEY,
        manufacturer TEXT, model TEXT, osVersion TEXT, runtimeVersion TEXT,
        camera TEXT, resolution TEXT, orientation TEXT,
        screenWidthPx INTEGER, screenHeightPx INTEGER
      )''');
  }

  /// v3 upgrade: optional fairness-dimension columns on experiments.
  static Future<void> addFairnessColumns(Database d) async {
    for (final col in ['skinTone', 'eyeColor', 'eyewear', 'ageGroup']) {
      try {
        await d.execute('ALTER TABLE experiments ADD COLUMN $col TEXT');
      } catch (_) {
        // Column already exists (fresh v3 installs) — nothing to do.
      }
    }
  }

  /// v4 upgrade: result provenance columns on results. Old rows keep
  /// working — reads fall back to empty provenance.
  static Future<void> addResultProvenanceColumns(Database d) async {
    for (final col in [
      'uncertainty',
      'hardware',
      'deviceLabel',
      'algorithmVersion',
      'evidenceVersion'
    ]) {
      try {
        await d.execute('ALTER TABLE results ADD COLUMN $col TEXT');
      } catch (_) {
        // Column already exists (fresh v4 installs) — nothing to do.
      }
    }
  }

  /// v5 upgrade: profile column (backfilled to 'self') + profiles table.
  /// Old rows belong to the default profile; nothing is lost or moved.
  static Future<void> addProfileColumns(Database d) async {
    try {
      await d.execute(
          'ALTER TABLE results ADD COLUMN profileId TEXT DEFAULT \'self\'');
    } catch (_) {
      // Column already exists (fresh v5 installs) — nothing to do.
    }
    await d.execute('''
      CREATE TABLE IF NOT EXISTS profiles(
        id TEXT PRIMARY KEY, name TEXT, createdAt TEXT
      )''');
    await d.execute(
        'INSERT OR IGNORE INTO profiles(id, name, createdAt) VALUES (\'self\', \'Self\', \'\')');
  }

  /// v6 upgrade: explicit eye token + conditions-verified flag. Old rows
  /// keep working — reads fall back to unspecified/unverified and trend
  /// comparisons against them stay fail-closed. Never backfilled.
  static Future<void> addEyeColumns(Database d) async {
    try {
      await d.execute(
          'ALTER TABLE results ADD COLUMN eye TEXT DEFAULT \'\'');
    } catch (_) {
      // Column already exists (fresh v6 installs) — nothing to do.
    }
    try {
      await d.execute(
          'ALTER TABLE results ADD COLUMN conditionsVerified INTEGER DEFAULT 0');
    } catch (_) {
      // Column already exists (fresh v6 installs) — nothing to do.
    }
  }

  /// v7 upgrade: measurement-trace columns. Old rows keep working —
  /// reads fall back to empty trace ("not recorded by that build").
  static Future<void> addTraceColumns(Database d) async {
    for (final col in [
      'modelVersion TEXT DEFAULT \'\'',
      'modelHash TEXT DEFAULT \'\'',
      'protocolVersion TEXT DEFAULT \'\'',
      'engine TEXT DEFAULT \'\'',
    ]) {
      try {
        final name = col.split(' ').first;
        await d.execute('ALTER TABLE results ADD COLUMN $col');
        // Touch the default explicitly so pre-existing rows read back
        // empty rather than NULL on engines that allow it.
        await d.execute(
            'UPDATE results SET $name = \'\' WHERE $name IS NULL');
      } catch (_) {
        // Column already exists (fresh v7 installs) — nothing to do.
      }
    }
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
