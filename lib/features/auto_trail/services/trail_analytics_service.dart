import 'package:geolocator/geolocator.dart';
import '../database/trail_database.dart';
import '../models/saved_place.dart';
import '../models/trail_point.dart';

/// Pure analytics computations for Auto Trail — all local, zero battery/data.
class TrailAnalyticsService {
  static final TrailDatabase _db = TrailDatabase.instance;

  // ─── Feature 1: Weekly Heatmap Calendar ───────────────────────────────
  /// Returns a map of date -> point count for the last N days (default 42 = 6 weeks)
  static Future<Map<DateTime, int>> getWeeklyHeatmapData({int days = 42}) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final result = <DateTime, int>{};

    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT (timestamp / 86400000) AS day_key, COUNT(*) AS cnt
      FROM trail_points
      WHERE timestamp >= ?
      GROUP BY day_key
      ORDER BY day_key ASC
    ''', [startDate.millisecondsSinceEpoch]);

    for (final row in rows) {
      final dayKey = (row['day_key'] as num).toInt();
      final millis = dayKey * 86400000;
      final date = DateTime.fromMillisecondsSinceEpoch(millis);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      result[normalizedDate] = (row['cnt'] as num).toInt();
    }
    return result;
  }

  // ─── Feature 2: Speed & Movement Analytics ────────────────────────────
  static Map<String, dynamic> computeSpeedAnalytics(List<TrailPoint> points) {
    if (points.length < 2) {
      return {
        'avgSpeedKmh': 0.0,
        'maxSpeedKmh': 0.0,
        'totalMovingMinutes': 0,
        'totalStationaryMinutes': 0,
      };
    }

    final sorted = List<TrailPoint>.from(points)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    double totalDistance = 0;
    double maxSpeed = 0;
    int movingMs = 0;
    int stationaryMs = 0;
    const double movingThresholdKmh = 1.5; // Below 1.5 km/h = stationary

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      final distMeters = Geolocator.distanceBetween(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      );
      final timeDiffMs = curr.timestamp - prev.timestamp;
      if (timeDiffMs <= 0 || timeDiffMs > 3600000) continue; // Skip gaps > 1hr

      final timeDiffHours = timeDiffMs / 3600000.0;
      final speedKmh = (distMeters / 1000.0) / timeDiffHours;
      totalDistance += distMeters;

      if (speedKmh > movingThresholdKmh && speedKmh < 200) {
        // Reasonable speed
        movingMs += timeDiffMs;
        if (speedKmh > maxSpeed) maxSpeed = speedKmh;
      } else {
        stationaryMs += timeDiffMs;
      }
    }

    final totalTimeHrs = movingMs / 3600000.0;
    final avgSpeed = totalTimeHrs > 0 ? (totalDistance / 1000.0) / totalTimeHrs : 0.0;

    return {
      'avgSpeedKmh': avgSpeed,
      'maxSpeedKmh': maxSpeed,
      'totalMovingMinutes': (movingMs / 60000).round(),
      'totalStationaryMinutes': (stationaryMs / 60000).round(),
      'totalDistanceKm': totalDistance / 1000.0,
    };
  }

  // ─── Feature 3: Visit Frequency Counter ───────────────────────────────
  /// Counts how many times each saved place has been visited (all-time)
  static Future<Map<String, int>> getVisitFrequency(List<SavedPlace> places) async {
    if (places.isEmpty) return {};

    final db = await _db.database;
    final allPoints = await db.query('trail_points', columns: ['latitude', 'longitude', 'timestamp']);

    // Group points by day first, then check if any point that day is inside a saved place
    final dayPlaceHits = <String, Set<int>>{}; // placeId -> set of dayKeys

    for (final row in allPoints) {
      final lat = (row['latitude'] as num).toDouble();
      final lng = (row['longitude'] as num).toDouble();
      final ts = (row['timestamp'] as num).toInt();
      final dayKey = ts ~/ 86400000;

      for (final place in places) {
        if (place.isInside(lat, lng)) {
          dayPlaceHits.putIfAbsent(place.id, () => {});
          dayPlaceHits[place.id]!.add(dayKey);
        }
      }
    }

    return dayPlaceHits.map((id, days) => MapEntry(
      places.firstWhere((p) => p.id == id).name,
      days.length,
    ));
  }

  // ─── Feature 4: Night Owl Detector ────────────────────────────────────
  static List<TrailPoint> getNightOwlPoints(List<TrailPoint> points) {
    return points.where((p) {
      final hour = p.dateTime.hour;
      return hour >= 0 && hour < 5; // 12AM - 5AM
    }).toList();
  }

  static bool hasNightActivity(List<TrailPoint> points) {
    return getNightOwlPoints(points).isNotEmpty;
  }

  // ─── Feature 5: Commute Time Estimator ────────────────────────────────
  /// Detects home<->office pattern from saved places and computes avg commute
  static Future<Map<String, dynamic>> estimateCommute(List<SavedPlace> places) async {
    // Find home and office places
    final home = places.where((p) => p.icon == 'home').toList();
    final office = places.where((p) => p.icon == 'office').toList();

    if (home.isEmpty || office.isEmpty) {
      return {'hasData': false, 'avgCommuteMinutes': 0, 'commuteCount': 0};
    }

    final homePl = home.first;
    final officePl = office.first;
    final straightDistKm = Geolocator.distanceBetween(
      homePl.latitude, homePl.longitude,
      officePl.latitude, officePl.longitude,
    ) / 1000.0;

    // Estimate commute time using average city speed (~30 km/h)
    final estimatedMinutes = (straightDistKm / 30.0 * 60.0 * 1.4).round(); // 1.4x for road factor

    return {
      'hasData': true,
      'avgCommuteMinutes': estimatedMinutes,
      'straightDistKm': straightDistKm,
      'homeName': homePl.name,
      'officeName': officePl.name,
    };
  }

  // ─── Feature 6: Location Streak Counter ───────────────────────────────
  static Future<int> getTrackingStreak() async {
    final days = await _db.getDistinctDays();
    if (days.isEmpty) return 0;

    // Days are in DESC order — find consecutive streak from today
    final today = DateTime.now();
    int streak = 0;
    for (int i = 0; i < days.length && i < 365; i++) {
      final expectedDate = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final hasData = days.any((d) =>
        d.year == expectedDate.year && d.month == expectedDate.month && d.day == expectedDate.day,
      );
      if (hasData) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ─── Feature 7: Place Dwell Leaderboard ───────────────────────────────
  /// Returns ranked places by total dwell time (all available dates)
  static Future<List<Map<String, dynamic>>> getPlaceDwellLeaderboard(List<SavedPlace> places) async {
    if (places.isEmpty) return [];

    final db = await _db.database;
    final allPoints = await db.query(
      'trail_points',
      columns: ['latitude', 'longitude', 'timestamp'],
      orderBy: 'timestamp ASC',
    );

    // Compute time near each place
    final dwellMs = <String, int>{};
    for (final place in places) {
      dwellMs[place.id] = 0;
    }

    for (int i = 1; i < allPoints.length; i++) {
      final prev = allPoints[i - 1];
      final curr = allPoints[i];
      final lat = (curr['latitude'] as num).toDouble();
      final lng = (curr['longitude'] as num).toDouble();
      final timeDiff = (curr['timestamp'] as num).toInt() - (prev['timestamp'] as num).toInt();
      if (timeDiff <= 0 || timeDiff > 3600000) continue;

      for (final place in places) {
        if (place.isInside(lat, lng)) {
          dwellMs[place.id] = (dwellMs[place.id] ?? 0) + timeDiff;
        }
      }
    }

    final results = places.map((p) => {
      'name': p.name,
      'icon': p.icon,
      'totalMinutes': ((dwellMs[p.id] ?? 0) / 60000).round(),
      'totalHours': ((dwellMs[p.id] ?? 0) / 3600000.0),
    }).toList();

    results.sort((a, b) => (b['totalMinutes'] as int).compareTo(a['totalMinutes'] as int));
    return results;
  }

  // ─── Feature 8: Activity Breakdown ────────────────────────────────────
  static Map<String, int> getActivityBreakdown(List<TrailPoint> points) {
    final counts = <String, int>{};
    for (final p in points) {
      final activity = p.activity ?? 'unknown';
      counts[activity] = (counts[activity] ?? 0) + 1;
    }
    return counts;
  }

  static Map<String, double> getActivityPercentages(List<TrailPoint> points) {
    final counts = getActivityBreakdown(points);
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return {};
    return counts.map((k, v) => MapEntry(k, (v / total * 100)));
  }

  // ─── Feature 9: Trail Distance Milestones ─────────────────────────────
  static Future<Map<String, dynamic>> getDistanceMilestones() async {
    final db = await _db.database;
    final allPoints = await db.query(
      'trail_points',
      columns: ['latitude', 'longitude', 'timestamp'],
      orderBy: 'timestamp ASC',
      limit: 50000,
    );

    double totalDistKm = 0;
    for (int i = 1; i < allPoints.length; i++) {
      final prev = allPoints[i - 1];
      final curr = allPoints[i];
      final dist = Geolocator.distanceBetween(
        (prev['latitude'] as num).toDouble(),
        (prev['longitude'] as num).toDouble(),
        (curr['latitude'] as num).toDouble(),
        (curr['longitude'] as num).toDouble(),
      );
      final timeDiff = (curr['timestamp'] as num).toInt() - (prev['timestamp'] as num).toInt();
      // Only count reasonable segments
      if (timeDiff > 0 && timeDiff < 3600000 && dist < 100000) {
        totalDistKm += dist / 1000.0;
      }
    }

    const milestones = [10, 50, 100, 250, 500, 1000, 5000];
    final achieved = milestones.where((m) => totalDistKm >= m).toList();
    final nextMilestone = milestones.firstWhere((m) => totalDistKm < m, orElse: () => 10000);
    final progressToNext = totalDistKm / nextMilestone;

    return {
      'totalDistKm': totalDistKm,
      'achievedMilestones': achieved,
      'nextMilestone': nextMilestone,
      'progressToNext': progressToNext.clamp(0.0, 1.0),
    };
  }

  // ─── Feature 10: Quick Note (DB helper) ───────────────────────────────
  // Note text is stored in the address field with a prefix "[Note: xxx] Original Address"
  static TrailPoint attachNote(TrailPoint point, String note) {
    final notePrefix = note.trim().isNotEmpty ? '[📝 $note] ' : '';
    return point.copyWith(address: '$notePrefix${point.address}');
  }

  static String? extractNote(TrailPoint point) {
    final match = RegExp(r'\[📝 (.+?)\]').firstMatch(point.address);
    return match?.group(1);
  }

  static bool hasNote(TrailPoint point) {
    return point.address.contains('[📝');
  }
}
