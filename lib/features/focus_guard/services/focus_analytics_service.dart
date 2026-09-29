import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Analytics and gamification engine for Focus Guard — all local SharedPreferences, zero network.
class FocusAnalyticsService {
  static const String _keyDailyScores = 'focus_analytics_daily_scores';
  static const String _keyFocusStreak = 'focus_analytics_streak';
  static const String _keyLastStreakDate = 'focus_analytics_last_streak_date';
  static const String _keyTemptationLog = 'focus_analytics_temptation_log';
  static const String _keyAppUsageStats = 'focus_analytics_app_usage';
  static const String _keyLongestSession = 'focus_analytics_longest_session';
  static const String _keyLongestSessionDate = 'focus_analytics_longest_session_date';
  static const String _keyWhitelistSchedules = 'focus_analytics_whitelist_schedules';
  static const String _keyUnlockCooldownEnd = 'focus_analytics_unlock_cooldown_end';
  static const String _keyTotalSessionsCompleted = 'focus_analytics_sessions_completed';

  // ─── Feature 11: Daily Focus Score ────────────────────────────────────
  /// Score 0-100 based on: temptations resisted (40%), block time (30%), sessions completed (30%)
  static Future<int> calculateDailyScore() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();

    final temptations = _getTodayTemptationCount(prefs);
    final sessionsCompleted = prefs.getInt('${_keyTotalSessionsCompleted}_$today') ?? 0;
    final totalBlockMinutes = prefs.getInt('focus_guard_minutes_saved') ?? 0;

    // Temptation score: each resist = 8 points, max 40
    final temptationScore = (temptations * 8).clamp(0, 40);
    // Session score: each completed session = 15 points, max 30
    final sessionScore = (sessionsCompleted * 15).clamp(0, 30);
    // Block time score: each 10 minutes saved = 5 points, max 30
    final blockScore = ((totalBlockMinutes ~/ 10) * 5).clamp(0, 30);

    final totalScore = (temptationScore + sessionScore + blockScore).clamp(0, 100);

    // Save daily score
    await _saveDailyScore(prefs, today, totalScore);
    return totalScore;
  }

  static Future<void> _saveDailyScore(SharedPreferences prefs, String day, int score) async {
    final scoresJson = prefs.getString(_keyDailyScores) ?? '{}';
    final scores = Map<String, dynamic>.from(jsonDecode(scoresJson) as Map);
    scores[day] = score;
    // Keep last 30 days only
    if (scores.length > 30) {
      final sortedKeys = scores.keys.toList()..sort();
      for (int i = 0; i < scores.length - 30; i++) {
        scores.remove(sortedKeys[i]);
      }
    }
    await prefs.setString(_keyDailyScores, jsonEncode(scores));
  }

  static Future<Map<String, int>> getDailyScoreHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final scoresJson = prefs.getString(_keyDailyScores) ?? '{}';
    final scores = Map<String, dynamic>.from(jsonDecode(scoresJson) as Map);
    return scores.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  // ─── Feature 12: Focus Streak Counter ─────────────────────────────────
  static Future<int> getFocusStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFocusStreak) ?? 0;
  }

  static Future<int> updateFocusStreak({required bool sessionCompleted}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDate = prefs.getString(_keyLastStreakDate) ?? '';
    final currentStreak = prefs.getInt(_keyFocusStreak) ?? 0;

    if (sessionCompleted) {
      if (lastDate == today) return currentStreak; // Already counted today
      final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
      final newStreak = (lastDate == yesterday) ? currentStreak + 1 : 1;
      await prefs.setInt(_keyFocusStreak, newStreak);
      await prefs.setString(_keyLastStreakDate, today);
      return newStreak;
    }
    return currentStreak;
  }

  // ─── Feature 13: Temptation Heatmap (by hour) ─────────────────────────
  static Future<void> logTemptation(String packageName, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final logJson = prefs.getString(_keyTemptationLog) ?? '[]';
    final log = List<Map<String, dynamic>>.from(
      (jsonDecode(logJson) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    log.add({
      'package': packageName,
      'reason': reason,
      'timestamp': now.millisecondsSinceEpoch,
      'hour': now.hour,
      'day': _todayKey(),
    });

    // Keep last 500 entries
    if (log.length > 500) {
      log.removeRange(0, log.length - 500);
    }

    await prefs.setString(_keyTemptationLog, jsonEncode(log));

    // Update app-specific stats (Feature 14)
    await _updateAppUsageStats(prefs, packageName);
  }

  static Future<Map<int, int>> getTemptationHeatmap() async {
    final prefs = await SharedPreferences.getInstance();
    final logJson = prefs.getString(_keyTemptationLog) ?? '[]';
    final log = List<Map<String, dynamic>>.from(
      (jsonDecode(logJson) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final heatmap = <int, int>{};
    for (int h = 0; h < 24; h++) {
      heatmap[h] = 0;
    }
    for (final entry in log) {
      final hour = entry['hour'] as int;
      heatmap[hour] = (heatmap[hour] ?? 0) + 1;
    }
    return heatmap;
  }

  // ─── Feature 14: App-Specific Usage Stats ─────────────────────────────
  static Future<void> _updateAppUsageStats(SharedPreferences prefs, String packageName) async {
    final statsJson = prefs.getString(_keyAppUsageStats) ?? '{}';
    final stats = Map<String, dynamic>.from(jsonDecode(statsJson) as Map);
    final today = _todayKey();

    final key = '${packageName}_$today';
    stats[key] = ((stats[key] as num?)?.toInt() ?? 0) + 1;

    // Prune old stats (> 7 days)
    final cutoff = _dateKey(DateTime.now().subtract(const Duration(days: 7)));
    stats.removeWhere((k, _) {
      final parts = k.split('_');
      if (parts.length >= 2) {
        final dateStr = parts.last;
        return dateStr.compareTo(cutoff) < 0;
      }
      return false;
    });

    await prefs.setString(_keyAppUsageStats, jsonEncode(stats));
  }

  static Future<List<Map<String, dynamic>>> getAppUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_keyAppUsageStats) ?? '{}';
    final stats = Map<String, dynamic>.from(jsonDecode(statsJson) as Map);
    final today = _todayKey();

    // Aggregate by app for today
    final appCounts = <String, int>{};
    for (final entry in stats.entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2 && entry.key.endsWith(today)) {
        final pkg = parts.sublist(0, parts.length - 1).join('_');
        appCounts[pkg] = (entry.value as num).toInt();
      }
    }

    final result = appCounts.entries.map((e) => {
      'package': e.key,
      'appName': _friendlyAppName(e.key),
      'blocksToday': e.value,
    }).toList();

    result.sort((a, b) => (b['blocksToday'] as int).compareTo(a['blocksToday'] as int));
    return result;
  }

  // ─── Feature 15: Longest Focus Session Record ─────────────────────────
  static Future<Map<String, dynamic>> getLongestSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'minutes': prefs.getInt(_keyLongestSession) ?? 0,
      'date': prefs.getString(_keyLongestSessionDate) ?? 'Never',
    };
  }

  static Future<bool> recordSessionCompletion(int durationMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyLongestSession) ?? 0;
    final today = _todayKey();

    // Increment sessions completed for daily score
    final sessionsKey = '${_keyTotalSessionsCompleted}_$today';
    final sessions = (prefs.getInt(sessionsKey) ?? 0) + 1;
    await prefs.setInt(sessionsKey, sessions);

    // Update streak
    await updateFocusStreak(sessionCompleted: true);

    if (durationMinutes > current) {
      await prefs.setInt(_keyLongestSession, durationMinutes);
      await prefs.setString(_keyLongestSessionDate, today);
      return true; // New record!
    }
    return false;
  }

  // ─── Feature 17: Blocked App Notification Log ─────────────────────────
  static Future<List<Map<String, dynamic>>> getInterventionLog({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final logJson = prefs.getString(_keyTemptationLog) ?? '[]';
    final log = List<Map<String, dynamic>>.from(
      (jsonDecode(logJson) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    // Return most recent first
    return log.reversed.take(limit).toList();
  }

  // ─── Feature 18: Weekly Summary Report ────────────────────────────────
  static Future<Map<String, dynamic>> generateWeeklyReport() async {
    final prefs = await SharedPreferences.getInstance();
    final logJson = prefs.getString(_keyTemptationLog) ?? '[]';
    final log = List<Map<String, dynamic>>.from(
      (jsonDecode(logJson) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekAgoMs = weekAgo.millisecondsSinceEpoch;

    final weekEntries = log.where((e) => (e['timestamp'] as num).toInt() > weekAgoMs).toList();

    // Total temptations this week
    final totalTemptations = weekEntries.length;

    // Most blocked app
    final appCounts = <String, int>{};
    for (final e in weekEntries) {
      final pkg = e['package'] as String? ?? 'unknown';
      appCounts[pkg] = (appCounts[pkg] ?? 0) + 1;
    }
    String mostBlockedApp = 'None';
    int mostBlockedCount = 0;
    for (final entry in appCounts.entries) {
      if (entry.value > mostBlockedCount) {
        mostBlockedCount = entry.value;
        mostBlockedApp = _friendlyAppName(entry.key);
      }
    }

    // Daily score trend
    final scores = await getDailyScoreHistory();
    final weekScores = <int>[];
    for (int i = 0; i < 7; i++) {
      final day = _dateKey(now.subtract(Duration(days: i)));
      weekScores.add(scores[day] ?? 0);
    }
    final avgScore = weekScores.isEmpty ? 0 : weekScores.reduce((a, b) => a + b) ~/ weekScores.length;

    // Hours saved estimate
    final hoursSaved = (totalTemptations * 5 / 60).toStringAsFixed(1);

    return {
      'totalTemptations': totalTemptations,
      'mostBlockedApp': mostBlockedApp,
      'mostBlockedCount': mostBlockedCount,
      'avgDailyScore': avgScore,
      'scoreTrend': weekScores.reversed.toList(), // oldest first
      'estimatedHoursSaved': hoursSaved,
      'streak': await getFocusStreak(),
    };
  }

  // ─── Feature 19: Whitelist Schedule ───────────────────────────────────
  static Future<List<Map<String, dynamic>>> getWhitelistSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyWhitelistSchedules) ?? '[]';
    return List<Map<String, dynamic>>.from(
      (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  static Future<void> saveWhitelistSchedule(Map<String, dynamic> schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getWhitelistSchedules();
    // Update if exists, add if new
    final idx = list.indexWhere((s) => s['package'] == schedule['package']);
    if (idx >= 0) {
      list[idx] = schedule;
    } else {
      list.add(schedule);
    }
    await prefs.setString(_keyWhitelistSchedules, jsonEncode(list));
  }

  static Future<void> removeWhitelistSchedule(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getWhitelistSchedules();
    list.removeWhere((s) => s['package'] == packageName);
    await prefs.setString(_keyWhitelistSchedules, jsonEncode(list));
  }

  /// Checks if a package is currently in its whitelist window
  static Future<bool> isInWhitelistWindow(String packageName) async {
    final schedules = await getWhitelistSchedules();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (final s in schedules) {
      if (s['package'] == packageName && s['enabled'] == true) {
        final startMin = (s['startHour'] as int) * 60 + (s['startMinute'] as int);
        final endMin = (s['endHour'] as int) * 60 + (s['endMinute'] as int);
        if (currentMinutes >= startMin && currentMinutes <= endMin) {
          return true;
        }
      }
    }
    return false;
  }

  // ─── Feature 20: Emergency Unlock Cooldown ────────────────────────────
  static Future<void> startUnlockCooldown({int minutes = 15}) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownEnd = DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;
    await prefs.setInt(_keyUnlockCooldownEnd, cooldownEnd);
  }

  static Future<int> getRemainingCooldownSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownEnd = prefs.getInt(_keyUnlockCooldownEnd) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = cooldownEnd - now;
    return remaining > 0 ? (remaining / 1000).round() : 0;
  }

  static Future<bool> isInCooldown() async {
    return (await getRemainingCooldownSeconds()) > 0;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────
  static String _todayKey() => _dateKey(DateTime.now());

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _getTodayTemptationCount(SharedPreferences prefs) {
    final logJson = prefs.getString(_keyTemptationLog) ?? '[]';
    final log = List<Map<String, dynamic>>.from(
      (jsonDecode(logJson) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final today = _todayKey();
    return log.where((e) => e['day'] == today).length;
  }

  static String _friendlyAppName(String pkg) {
    const names = {
      'com.google.android.youtube': 'YouTube',
      'com.instagram.android': 'Instagram',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.ss.android.ugc.trill': 'TikTok',
      'com.facebook.katana': 'Facebook',
      'com.twitter.android': 'X / Twitter',
      'com.snapchat.android': 'Snapchat',
      'com.reddit.frontpage': 'Reddit',
    };
    return names[pkg] ?? pkg.split('.').last;
  }
}
