import 'package:sqflite/sqflite.dart';
import '../../core/models/screening_result.dart';
import 'app_database.dart';

/// Local-only storage of measurements (never raw face images by default).
class HistoryRepository {
  Database? _db;

  HistoryRepository();

  /// Test/seeding constructor with an already-open database (e.g. desktop
  /// FFI database in widget tests). Production uses [AppDatabase.open].
  HistoryRepository.forTest(Database db) : _db = db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    // Single shared database file (v2 also holds research tables).
    _db = await AppDatabase.open();
    return _db!;
  }

  Future<void> insert(ScreeningResult r) async {
    final d = await db;
    await d.insert('results', r.toMap());
  }

  Future<List<ScreeningResult>> all(
      {int limit = 200, String profileId = 'self'}) async {
    final d = await db;
    final rows = await d.query('results',
        where: 'profileId = ?',
        whereArgs: [profileId],
        orderBy: 'timestamp DESC',
        limit: limit);
    return rows.map(ScreeningResult.fromMap).toList();
  }

  /// Profile-wide summary for the Home dashboard: full-history counts plus
  /// the newest row timestamp. Home previously counted only the last 6
  /// rows, understating longer histories. A single conditional-aggregation
  /// query keeps this to one transaction (concurrent multi-query loads
  /// contend on the database lock).
  Future<HistorySummary> summary({String profileId = 'self'}) async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT COUNT(*) AS c, MAX(timestamp) AS latest, '
        "SUM(CASE WHEN finding = 'possible_finding' THEN 1 ELSE 0 END) AS p, "
        "SUM(CASE WHEN finding = 'unable_to_assess' THEN 1 ELSE 0 END) AS u "
        'FROM results WHERE profileId = ?',
        [profileId]);
    final r = rows.first;
    final latestRaw = r['latest'] as String?;
    return HistorySummary(
      total: (r['c'] as int?) ?? 0,
      possibleFindings: (r['p'] as int?) ?? 0,
      unableToAssess: (r['u'] as int?) ?? 0,
      latest: latestRaw == null ? null : DateTime.tryParse(latestRaw),
    );
  }

  Future<List<ScreeningResult>> since(DateTime t,
      {String profileId = 'self'}) async {
    final d = await db;
    final rows = await d.query('results',
        where: 'timestamp >= ? AND profileId = ?',
        whereArgs: [t.toIso8601String(), profileId],
        orderBy: 'timestamp DESC');
    return rows.map(ScreeningResult.fromMap).toList();
  }

  /// Distinct test names with rows for a profile (drives trends + report).
  Future<List<String>> testNames({String profileId = 'self'}) async {
    final d = await db;
    final rows = await d.query('results',
        columns: ['testName'],
        where: 'profileId = ?',
        whereArgs: [profileId],
        orderBy: 'timestamp DESC');
    final seen = <String>[];
    for (final r in rows) {
      final n = (r['testName'] ?? '') as String;
      if (n.isNotEmpty && !seen.contains(n)) seen.add(n);
    }
    return seen;
  }

  // ---------- Local person profiles (on-device labels only) ----------

  Future<List<Map<String, String>>> profiles() async {
    final d = await db;
    try {
      final rows = await d.query('profiles', orderBy: 'createdAt ASC');
      return [
        for (final r in rows)
          {
            'id': (r['id'] ?? 'self').toString(),
            'name': (r['name'] ?? 'Self').toString(),
          }
      ];
    } catch (_) {
      return [
        {'id': 'self', 'name': 'Self'}
      ];
    }
  }

  /// Per-profile deletion preflight (D9): row counts + date spans so a
  /// delete-all confirmation shows exactly what will be destroyed.
  Future<List<ProfileStats>> profileStats() async {
    final d = await db;
    final profs = await profiles();
    final out = <ProfileStats>[];
    for (final p in profs) {
      final id = p['id'] ?? 'self';
      final rows = await d.rawQuery(
          'SELECT COUNT(*) AS c, MIN(timestamp) AS first, '
          'MAX(timestamp) AS latest FROM results WHERE profileId = ?',
          [id]);
      final r = rows.first;
      out.add(ProfileStats(
        id: id,
        name: p['name'] ?? id,
        total: (r['c'] as int?) ?? 0,
        first: r['first'] as String?,
        latest: r['latest'] as String?,
      ));
    }
    return out;
  }

  Future<void> addProfile(String id, String name) async {
    final d = await db;
    await d.insert('profiles', {
      'id': id,
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Rename a profile label (D6). Labels only — never identities.
  Future<void> renameProfile(String id, String name) async {
    if (name.trim().isEmpty) return;
    final d = await db;
    await d.update('profiles', {'name': name.trim()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProfile(String id) async {
    if (id == 'self') return;
    final d = await db;
    await d.delete('results', where: 'profileId = ?', whereArgs: [id]);
    await d.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final d = await db;
    await d.delete('results');
    await d.delete('sessions');
    // Privacy: delete-all also removes research measurements.
    await d.delete('trials');
    await d.delete('experiments');
    await d.delete('reference_labels');
    await d.delete('device_profiles');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/// One profile's deletion-preflight numbers.
class ProfileStats {
  final String id;
  final String name;
  final int total;
  final String? first;
  final String? latest;

  const ProfileStats({
    required this.id,
    required this.name,
    required this.total,
    required this.first,
    required this.latest,
  });
}

/// Profile-wide dashboard summary (full history, not a recent slice).
class HistorySummary {
  final int total;
  final int possibleFindings;
  final int unableToAssess;
  final DateTime? latest;

  const HistorySummary({
    required this.total,
    required this.possibleFindings,
    required this.unableToAssess,
    required this.latest,
  });

  bool get isEmpty => total == 0;
}
