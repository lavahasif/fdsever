import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/trail_point.dart';

/// SQLite local database for storing passive location trail points.
class TrailDatabase {
  static final TrailDatabase instance = TrailDatabase._init();
  static Database? _database;

  TrailDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('auto_trail.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trail_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        timestamp INTEGER NOT NULL,
        accuracy REAL,
        activity TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_trail_points_timestamp ON trail_points (timestamp)
    ''');
  }

  /// Inserts a single trail point.
  Future<int> insertPoint(TrailPoint point) async {
    final db = await database;
    return await db.insert(
      'trail_points',
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts a batch of points inside a single transaction for efficiency.
  Future<void> insertBatch(List<TrailPoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final pt in points) {
        batch.insert(
          'trail_points',
          pt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Retrieves the most recently logged point.
  Future<TrailPoint?> getLastPoint() async {
    final db = await database;
    final maps = await db.query(
      'trail_points',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return TrailPoint.fromMap(maps.first);
    }
    return null;
  }

  /// Retrieves points for a specific 24-hour day.
  Future<List<TrailPoint>> getPointsByDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    return getPointsBetween(startOfDay, endOfDay);
  }

  /// Retrieves points between epoch millis range.
  Future<List<TrailPoint>> getPointsBetween(int startMillis, int endMillis) async {
    final db = await database;
    final maps = await db.query(
      'trail_points',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startMillis, endMillis],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => TrailPoint.fromMap(m)).toList();
  }

  /// Retrieves all points with pagination support.
  Future<List<TrailPoint>> getAllPoints({int limit = 500, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'trail_points',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => TrailPoint.fromMap(m)).toList();
  }

  /// Text and keyword search on address, activity, or date strings.
  Future<List<TrailPoint>> searchPoints(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return getAllPoints(limit: 100);

    final db = await database;
    final maps = await db.query(
      'trail_points',
      where: 'address LIKE ? OR activity LIKE ?',
      whereArgs: ['%$clean%', '%$clean%'],
      orderBy: 'timestamp DESC',
      limit: 200,
    );
    return maps.map((m) => TrailPoint.fromMap(m)).toList();
  }

  /// Returns list of distinct days that have at least one trail point recorded.
  Future<List<DateTime>> getDistinctDays() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT (timestamp / 86400000) * 86400000 AS day_millis
      FROM trail_points
      ORDER BY day_millis DESC
    ''');

    return result.map((r) {
      final millis = (r['day_millis'] as num).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: false);
    }).toList();
  }

  /// Deletes a single point by ID.
  Future<int> deletePoint(int id) async {
    final db = await database;
    return await db.delete(
      'trail_points',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clears all recorded trail points.
  Future<int> clearAllPoints() async {
    final db = await database;
    return await db.delete('trail_points');
  }

  /// Returns aggregate stats: total points, total days tracked, earliest and latest timestamps.
  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM trail_points');
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count == 0) {
      return {
        'totalPoints': 0,
        'earliest': null,
        'latest': null,
      };
    }

    final minMaxResult = await db.rawQuery(
      'SELECT MIN(timestamp) as min_ts, MAX(timestamp) as max_ts FROM trail_points',
    );
    final minTs = minMaxResult.first['min_ts'] as int?;
    final maxTs = minMaxResult.first['max_ts'] as int?;

    return {
      'totalPoints': count,
      'earliest': minTs != null ? DateTime.fromMillisecondsSinceEpoch(minTs) : null,
      'latest': maxTs != null ? DateTime.fromMillisecondsSinceEpoch(maxTs) : null,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
