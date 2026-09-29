import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_navigator.dart';
import '../models/focus_config_model.dart';
import '../models/focus_schedule.dart';
import '../screens/mindful_friction_screen.dart';
import '../screens/motivation_reader_screen.dart';
import '../screens/prayer_intervention_screen.dart';
import '../screens/reality_check_screen.dart';
import '../services/focus_analytics_service.dart';
import '../services/focus_guard_bridge.dart';
import '../services/prayer_dhikr_service.dart';

class InterventionAlert {
  final String packageName;
  final String reason;
  final DateTime timestamp;

  InterventionAlert({
    required this.packageName,
    required this.reason,
    required this.timestamp,
  });
}

class FocusGuardProvider extends ChangeNotifier {
  static const String _keyGoal = 'focus_guard_goal';
  static const String _keyBlockedApps = 'focus_guard_apps';
  static const String _keyBlockShorts = 'focus_guard_block_shorts';
  static const String _keyEndTime = 'focus_guard_end_time';
  static const String _keyTemptations = 'focus_guard_temptations';
  static const String _keyMinutesSaved = 'focus_guard_minutes_saved';
  static const String _keyHourlyBudget = 'focus_guard_hourly_budget';
  static const String _keyDiversionType = 'focus_guard_diversion_type';
  static const String _keyAutoDivert = 'focus_guard_auto_divert';
  static const String _keySchedules = 'focus_guard_schedules';

  bool _isLockActive = false;
  bool _blockShortsAndReels = true;
  int _hourlyBudgetMinutes = 5; // 0 (strict), 5m, 10m allowed per hour
  String _diversionType = 'mindful_friction'; // 'mindful_friction' | 'prayer' | 'pdf' | 'video' | 'reality_screen'
  bool _autoDivertEnabled = true;
  final PrayerDhikrService _prayerDhikrService = PrayerDhikrService();
  String _targetGoal = 'Build great software & achieve financial freedom';
  int _sessionDurationMinutes = 25;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _scheduleWatcherTimer;

  List<FocusSchedule> _schedules = List.from(FocusSchedule.defaultSchedules);

  bool _isAccessibilityGranted = false;
  bool _hasUsageStats = false;
  bool _hasOverlay = false;

  int _temptationsResisted = 0;
  int _minutesSaved = 0;

  // ─── Focus Guard Analytics (Features 11-20) ───────────────────────────
  int _dailyFocusScore = 0;
  int _focusStreak = 0;
  Map<int, int> _temptationHeatmap = {};
  List<Map<String, dynamic>> _appUsageStats = [];
  Map<String, dynamic> _longestSession = {};
  List<Map<String, dynamic>> _interventionLog = [];
  Map<String, dynamic> _weeklyReport = {};
  List<Map<String, dynamic>> _whitelistSchedules = [];
  int _cooldownRemainingSeconds = 0;

  int get dailyFocusScore => _dailyFocusScore;
  int get focusStreak => _focusStreak;
  Map<int, int> get temptationHeatmap => _temptationHeatmap;
  List<Map<String, dynamic>> get appUsageStats => _appUsageStats;
  Map<String, dynamic> get longestSession => _longestSession;
  List<Map<String, dynamic>> get interventionLog => _interventionLog;
  Map<String, dynamic> get weeklyReport => _weeklyReport;
  List<Map<String, dynamic>> get whitelistSchedules => _whitelistSchedules;
  int get cooldownRemainingSeconds => _cooldownRemainingSeconds;
  bool get isInCooldown => _cooldownRemainingSeconds > 0;

  List<BlockedAppInfo> _blockedApps = [
    const BlockedAppInfo(packageName: 'com.google.android.youtube', appName: 'YouTube', isBlocked: true),
    const BlockedAppInfo(packageName: 'com.instagram.android', appName: 'Instagram', isBlocked: true),
    const BlockedAppInfo(packageName: 'com.zhiliaoapp.musically', appName: 'TikTok', isBlocked: true),
    const BlockedAppInfo(packageName: 'com.ss.android.ugc.trill', appName: 'TikTok (Asia)', isBlocked: true),
    const BlockedAppInfo(packageName: 'com.facebook.katana', appName: 'Facebook', isBlocked: true),
    const BlockedAppInfo(packageName: 'com.twitter.android', appName: 'X / Twitter', isBlocked: true),
    const BlockedAppInfo(packageName: 'com.snapchat.android', appName: 'Snapchat', isBlocked: true),
    const BlockedAppInfo(packageName: 'com.reddit.frontpage', appName: 'Reddit', isBlocked: false),
  ];

  List<Map<String, String>> _installedDeviceApps = [];
  bool _isLoadingApps = false;

  InterventionAlert? _pendingIntervention;

  // Guard to prevent infinite diversion page stacking
  bool _isDiversionActive = false;
  DateTime? _lastDiversionTime;

  // Anti-Bypass Math & Oath State
  int _mathA = 0;
  int _mathB = 0;
  int _mathC = 0;
  int _expectedMathResult = 0;
  static const String hardcoreOath = "I am choosing short-term dopamine over my future and I accept the cost.";

  // Getters
  bool get isLockActive => _isLockActive;
  bool get blockShortsAndReels => _blockShortsAndReels;
  int get hourlyBudgetMinutes => _hourlyBudgetMinutes;
  String get diversionType => _diversionType;
  bool get autoDivertEnabled => _autoDivertEnabled;
  String get targetGoal => _targetGoal;
  int get remainingSeconds => _remainingSeconds;
  int get sessionDurationMinutes => _sessionDurationMinutes;
  bool get isAccessibilityGranted => _isAccessibilityGranted;
  bool get hasUsageStats => _hasUsageStats;
  bool get hasOverlay => _hasOverlay;
  int get temptationsResisted => _temptationsResisted;
  int get minutesSaved => _minutesSaved;
  List<BlockedAppInfo> get blockedApps => List.unmodifiable(_blockedApps);
  List<Map<String, String>> get installedDeviceApps => _installedDeviceApps;
  bool get isLoadingApps => _isLoadingApps;
  InterventionAlert? get pendingIntervention => _pendingIntervention;

  String get mathQuestion => '($_mathA × $_mathB) + $_mathC';
  int get expectedMathResult => _expectedMathResult;

  List<FocusSchedule> get schedules => List.unmodifiable(_schedules);

  bool get isScheduleCurrentlyActive {
    final now = DateTime.now();
    return _schedules.any((s) => s.isCurrentlyActive(now));
  }

  FocusSchedule? get activeSchedule {
    final now = DateTime.now();
    try {
      return _schedules.firstWhere((s) => s.isCurrentlyActive(now));
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleSchedule(String id) async {
    final idx = _schedules.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _schedules[idx] = _schedules[idx].copyWith(isEnabled: !_schedules[idx].isEnabled);
      await _saveSchedules();
      await syncConfigToNative();
      notifyListeners();
    }
  }

  Future<void> updateSchedule(FocusSchedule schedule) async {
    final idx = _schedules.indexWhere((s) => s.id == schedule.id);
    if (idx != -1) {
      _schedules[idx] = schedule;
    } else {
      _schedules.add(schedule);
    }
    await _saveSchedules();
    await syncConfigToNative();
    notifyListeners();
  }

  Future<void> deleteSchedule(String id) async {
    _schedules.removeWhere((s) => s.id == id);
    await _saveSchedules();
    await syncConfigToNative();
    notifyListeners();
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _schedules.map((s) => s.toJson()).toList();
    await prefs.setString(_keySchedules, jsonEncode(jsonList));
  }

  FocusGuardProvider() {
    _generateMathChallenge();
    _init();
  }

  Future<void> syncConfigToNative() async {
    // Include all blocked apps + shortsOnly apps (YouTube) when shorts blocking is enabled
    final activePkgs = _blockedApps
        .where((a) => a.isBlocked || (a.isShortsOnly && _blockShortsAndReels))
        .map((a) => a.packageName)
        .toSet()
        .toList();
    final isScheduleActive = isScheduleCurrentlyActive;
    final isStrict = _isLockActive || isScheduleActive;
    await FocusGuardBridge.syncConfig(
      blockedPackages: activePkgs,
      blockShorts: _blockShortsAndReels,
      isStrict: isStrict,
      hourlyBudgetMinutes: isScheduleActive ? 0 : _hourlyBudgetMinutes,
    );
  }

  Future<void> _init() async {
    FocusGuardBridge.init();
    FocusGuardBridge.addInterventionListener(_handleIntervention);

    await _loadPreferences();
    await _prayerDhikrService.init();
    await checkPermissions();
    await syncConfigToNative();
    _checkActiveSession();

    // Periodic watcher to dynamically engage/disengage scheduled focus windows
    _scheduleWatcherTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncConfigToNative();
    });

    final pending = await FocusGuardBridge.checkPendingIntervention();
    if (pending != null) {
      _handleIntervention(pending['package'] ?? 'unknown', pending['reason'] ?? 'unknown');
    }
    await loadAnalytics();
  }

  Future<void> _handleIntervention(String packageName, String reason) async {
    // Feature 19: Check whitelist window
    if (await FocusAnalyticsService.isInWhitelistWindow(packageName)) {
      return;
    }

    _temptationsResisted++;
    _minutesSaved += 5; // Each blocked dopamine spiral saves an estimated 5-15 mins
    _pendingIntervention = InterventionAlert(
      packageName: packageName,
      reason: reason,
      timestamp: DateTime.now(),
    );
    _saveStats();
    await FocusAnalyticsService.logTemptation(packageName, reason);
    _dailyFocusScore = await FocusAnalyticsService.calculateDailyScore();
    notifyListeners();

    if (_autoDivertEnabled && !_isDiversionActive) {
      // Debounce: don't push another screen if one was pushed within last 3s
      final now = DateTime.now();
      if (_lastDiversionTime != null &&
          now.difference(_lastDiversionTime!).inSeconds < 3) {
        return;
      }
      _lastDiversionTime = now;
      _executeDiversion(packageName, reason);
    }
  }

  Future<void> _executeDiversion(String packageName, String reason) async {
    if (_isDiversionActive) return; // Prevent stacking
    _isDiversionActive = true;

    try {
      if (_diversionType == 'prayer') {
        final nav = appNavigatorKey.currentState;
        if (nav != null) {
          await nav.push(
            smoothTransitionRoute(
              PrayerInterventionScreen(
                blockedPackage: packageName,
                blockReason: reason,
              ),
            ),
          );
        }
      } else if (_diversionType == 'mindful_friction') {
        final nav = appNavigatorKey.currentState;
        if (nav != null) {
          await nav.push(
            smoothTransitionRoute(
              MindfulFrictionScreen(
                blockedPackage: packageName,
                blockReason: reason,
              ),
            ),
          );
        }
      } else if (_diversionType == 'video') {
        const videoUrl = 'https://www.youtube.com/watch?v=kYfNvmF0Bqw';
        final uri = Uri.parse(videoUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (_diversionType == 'reality_screen') {
        final nav = appNavigatorKey.currentState;
        if (nav != null) {
          await nav.push(
            smoothTransitionRoute(
              RealityCheckScreen(
                blockedPackage: packageName,
                blockReason: reason,
              ),
            ),
          );
        }
      } else {
        // Default 'pdf' / Motivation Guide
        final nav = appNavigatorKey.currentState;
        if (nav != null) {
          await nav.push(
            smoothTransitionRoute(
              MotivationReaderScreen(
                reason: reason,
                blockedPackage: packageName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error triggering auto-diversion: $e');
    } finally {
      _isDiversionActive = false;
    }
  }

  void clearPendingIntervention() {
    _pendingIntervention = null;
    _isDiversionActive = false; // Reset guard when user clears intervention
    notifyListeners();
  }

  Future<void> checkPermissions() async {
    _isAccessibilityGranted = await FocusGuardBridge.isAccessibilityEnabled();
    _hasUsageStats = await FocusGuardBridge.hasUsageStatsPermission();
    _hasOverlay = await FocusGuardBridge.hasOverlayPermission();
    notifyListeners();
  }

  void _generateMathChallenge() {
    final rand = Random();
    _mathA = 12 + rand.nextInt(38); // 12..49
    _mathB = 14 + rand.nextInt(26); // 14..39
    _mathC = 20 + rand.nextInt(80); // 20..99
    _expectedMathResult = (_mathA * _mathB) + _mathC;
  }

  void regenerateChallenge() {
    _generateMathChallenge();
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _targetGoal = prefs.getString(_keyGoal) ?? _targetGoal;
    _blockShortsAndReels = prefs.getBool(_keyBlockShorts) ?? true;
    _temptationsResisted = prefs.getInt(_keyTemptations) ?? 0;
    _minutesSaved = prefs.getInt(_keyMinutesSaved) ?? 0;
    _hourlyBudgetMinutes = prefs.getInt(_keyHourlyBudget) ?? 5;
    _diversionType = prefs.getString(_keyDiversionType) ?? 'mindful_friction';
    _autoDivertEnabled = prefs.getBool(_keyAutoDivert) ?? true;

    final schedulesJson = prefs.getString(_keySchedules);
    if (schedulesJson != null) {
      try {
        final decoded = jsonDecode(schedulesJson) as List;
        _schedules = decoded.map((e) => FocusSchedule.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {}
    }

    final appsJson = prefs.getString(_keyBlockedApps);
    if (appsJson != null) {
      try {
        final decoded = jsonDecode(appsJson) as List;
        _blockedApps = decoded.map((e) => BlockedAppInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveApps() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_blockedApps.map((e) => e.toJson()).toList());
    await prefs.setString(_keyBlockedApps, jsonStr);
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTemptations, _temptationsResisted);
    await prefs.setInt(_keyMinutesSaved, _minutesSaved);
  }

  Future<void> setHourlyBudgetMinutes(int minutes) async {
    _hourlyBudgetMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHourlyBudget, minutes);
    await syncConfigToNative();
    notifyListeners();
  }

  Future<void> setDiversionType(String type) async {
    _diversionType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDiversionType, type);
    notifyListeners();
  }

  PrayerDhikrService get prayerDhikrService => _prayerDhikrService;
  bool get prayerRandomSelection => _prayerDhikrService.isRandomPrayerEnabled;
  bool get prayerAlwaysShowDhikr => _prayerDhikrService.isAlwaysShowDhikrEnabled;

  Future<void> setPrayerRandomSelection(bool enabled) async {
    await _prayerDhikrService.setRandomPrayerEnabled(enabled);
    notifyListeners();
  }

  Future<void> setPrayerAlwaysShowDhikr(bool enabled) async {
    await _prayerDhikrService.setAlwaysShowDhikrEnabled(enabled);
    notifyListeners();
  }

  Future<void> setAutoDivertEnabled(bool enabled) async {
    _autoDivertEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoDivert, enabled);
    notifyListeners();
  }

  Future<void> setGoal(String newGoal) async {
    if (newGoal.trim().isEmpty) return;
    _targetGoal = newGoal.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoal, _targetGoal);
    notifyListeners();
  }

  void setSessionDuration(int minutes) {
    _sessionDurationMinutes = minutes;
    notifyListeners();
  }

  void toggleShortsBlocking(bool enabled) async {
    _blockShortsAndReels = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBlockShorts, enabled);
    await syncConfigToNative();
    notifyListeners();
  }

  void toggleAppBlocked(String packageName) async {
    final index = _blockedApps.indexWhere((a) => a.packageName == packageName);
    if (index >= 0) {
      _blockedApps[index] = _blockedApps[index].copyWith(isBlocked: !_blockedApps[index].isBlocked);
    } else {
      _blockedApps.add(BlockedAppInfo(packageName: packageName, appName: packageName, isBlocked: true));
    }
    await _saveApps();
    await syncConfigToNative();
    notifyListeners();
  }

  void addCustomApp(String packageName, String appName) async {
    final exists = _blockedApps.any((a) => a.packageName == packageName);
    if (!exists) {
      _blockedApps.add(BlockedAppInfo(packageName: packageName, appName: appName, isBlocked: true));
      await _saveApps();
      await syncConfigToNative();
      notifyListeners();
    }
  }

  Future<void> fetchInstalledApps() async {
    _isLoadingApps = true;
    notifyListeners();

    try {
      final apps = await FocusGuardBridge.getInstalledApps();
      _installedDeviceApps = apps;
    } catch (e) {
      debugPrint('Error fetching apps: $e');
    } finally {
      _isLoadingApps = false;
      notifyListeners();
    }
  }

  Future<void> loadAnalytics() async {
    try {
      _dailyFocusScore = await FocusAnalyticsService.calculateDailyScore();
      _focusStreak = await FocusAnalyticsService.getFocusStreak();
      _temptationHeatmap = await FocusAnalyticsService.getTemptationHeatmap();
      _appUsageStats = await FocusAnalyticsService.getAppUsageStats();
      _longestSession = await FocusAnalyticsService.getLongestSession();
      _interventionLog = await FocusAnalyticsService.getInterventionLog();
      _weeklyReport = await FocusAnalyticsService.generateWeeklyReport();
      _whitelistSchedules = await FocusAnalyticsService.getWhitelistSchedules();
      _cooldownRemainingSeconds = await FocusAnalyticsService.getRemainingCooldownSeconds();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading focus analytics: $e');
    }
  }

  // Feature 16: Quick Block Presets
  Future<bool> startPresetSession(int minutes) async {
    setSessionDuration(minutes);
    return await startFocusLock();
  }

  // Feature 19: Whitelist Schedule operations
  Future<void> addOrUpdateWhitelistSchedule(Map<String, dynamic> schedule) async {
    await FocusAnalyticsService.saveWhitelistSchedule(schedule);
    _whitelistSchedules = await FocusAnalyticsService.getWhitelistSchedules();
    notifyListeners();
  }

  Future<void> deleteWhitelistSchedule(String packageName) async {
    await FocusAnalyticsService.removeWhitelistSchedule(packageName);
    _whitelistSchedules = await FocusAnalyticsService.getWhitelistSchedules();
    notifyListeners();
  }

  Future<bool> startFocusLock() async {
    // Feature 20: Emergency Unlock Cooldown check
    final remainingCooldown = await FocusAnalyticsService.getRemainingCooldownSeconds();
    if (remainingCooldown > 0) {
      _cooldownRemainingSeconds = remainingCooldown;
      notifyListeners();
      return false; // In cooldown penalty!
    }

    await checkPermissions();
    if (!_isAccessibilityGranted) {
      await FocusGuardBridge.openAccessibilitySettings();
      return false;
    }

    final activePkgs = _blockedApps.where((a) => a.isBlocked).map((a) => a.packageName).toList();
    final success = await FocusGuardBridge.startFocusLock(
      blockedPackages: activePkgs,
      blockShorts: _blockShortsAndReels,
      hourlyBudgetMinutes: _hourlyBudgetMinutes,
    );

    if (success) {
      _isLockActive = true;
      _remainingSeconds = _sessionDurationMinutes * 60;
      final endTime = DateTime.now().add(Duration(minutes: _sessionDurationMinutes)).millisecondsSinceEpoch;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyEndTime, endTime);

      _startTimer();
      _generateMathChallenge();
      notifyListeners();
      return true;
    }
    return false;
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
        // Session successfully completed!
        FocusAnalyticsService.recordSessionCompletion(_sessionDurationMinutes);
        stopFocusLockImmediate(isEmergency: false);
      }
    });
  }

  Future<void> _checkActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt(_keyEndTime);
    if (endTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (endTime > now) {
        _remainingSeconds = ((endTime - now) / 1000).round();
        _isLockActive = true;
        _startTimer();
        notifyListeners();
      } else {
        await prefs.remove(_keyEndTime);
      }
    }
  }

  // Hardcore Emergency Unlock validation: requires solving the exact math problem
  bool verifyAndEmergencyUnlockWithMath(int enteredResult) {
    if (enteredResult == _expectedMathResult) {
      stopFocusLockImmediate(isEmergency: true);
      return true;
    }
    _generateMathChallenge();
    notifyListeners();
    return false;
  }

  // Hardcore Emergency Unlock validation: requires typing the exact accountability oath
  bool verifyAndEmergencyUnlockWithOath(String typedOath) {
    if (typedOath.trim() == hardcoreOath.trim()) {
      stopFocusLockImmediate(isEmergency: true);
      return true;
    }
    return false;
  }

  Future<void> stopFocusLockImmediate({bool isEmergency = false}) async {
    _isLockActive = false;
    _remainingSeconds = 0;
    _countdownTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEndTime);

    await FocusGuardBridge.stopFocusLock();
    _generateMathChallenge();

    if (isEmergency) {
      // Feature 20: 15-minute emergency unlock penalty cooldown
      await FocusAnalyticsService.startUnlockCooldown(minutes: 15);
      _cooldownRemainingSeconds = 15 * 60;
    }

    await loadAnalytics();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scheduleWatcherTimer?.cancel();
    FocusGuardBridge.removeInterventionListener(_handleIntervention);
    super.dispose();
  }
}
