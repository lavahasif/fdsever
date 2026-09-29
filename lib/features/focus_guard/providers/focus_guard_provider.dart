import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_config_model.dart';
import '../services/focus_guard_bridge.dart';

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

  bool _isLockActive = false;
  bool _blockShortsAndReels = true;
  String _targetGoal = 'Build great software & achieve financial freedom';
  int _sessionDurationMinutes = 25;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  bool _isAccessibilityGranted = false;
  bool _hasUsageStats = false;
  bool _hasOverlay = false;

  int _temptationsResisted = 0;
  int _minutesSaved = 0;

  List<BlockedAppInfo> _blockedApps = [
    const BlockedAppInfo(packageName: 'com.google.android.youtube', appName: 'YouTube (Shorts Shield)', isBlocked: false, isShortsOnly: true),
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

  // Anti-Bypass Math & Oath State
  int _mathA = 0;
  int _mathB = 0;
  int _mathC = 0;
  int _expectedMathResult = 0;
  static const String hardcoreOath = "I am choosing short-term dopamine over my future and I accept the cost.";

  // Getters
  bool get isLockActive => _isLockActive;
  bool get blockShortsAndReels => _blockShortsAndReels;
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

  FocusGuardProvider() {
    _generateMathChallenge();
    _init();
  }

  Future<void> syncConfigToNative() async {
    final activePkgs = _blockedApps.where((a) => a.isBlocked).map((a) => a.packageName).toList();
    await FocusGuardBridge.syncConfig(
      blockedPackages: activePkgs,
      blockShorts: _blockShortsAndReels,
      isStrict: _isLockActive,
    );
  }

  Future<void> _init() async {
    FocusGuardBridge.init();
    FocusGuardBridge.addInterventionListener(_handleIntervention);

    await _loadPreferences();
    await checkPermissions();
    await syncConfigToNative();
    _checkActiveSession();

    final pending = await FocusGuardBridge.checkPendingIntervention();
    if (pending != null) {
      _handleIntervention(pending['package'] ?? 'unknown', pending['reason'] ?? 'unknown');
    }
  }

  void _handleIntervention(String packageName, String reason) {
    _temptationsResisted++;
    _minutesSaved += 5; // Each blocked dopamine spiral saves an estimated 5-15 mins
    _pendingIntervention = InterventionAlert(
      packageName: packageName,
      reason: reason,
      timestamp: DateTime.now(),
    );
    _saveStats();
    notifyListeners();
  }

  void clearPendingIntervention() {
    _pendingIntervention = null;
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

  Future<bool> startFocusLock() async {
    await checkPermissions();
    if (!_isAccessibilityGranted) {
      await FocusGuardBridge.openAccessibilitySettings();
      return false;
    }

    final activePkgs = _blockedApps.where((a) => a.isBlocked).map((a) => a.packageName).toList();
    final success = await FocusGuardBridge.startFocusLock(
      blockedPackages: activePkgs,
      blockShorts: _blockShortsAndReels,
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
        stopFocusLockImmediate();
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
      stopFocusLockImmediate();
      return true;
    }
    _generateMathChallenge();
    notifyListeners();
    return false;
  }

  // Hardcore Emergency Unlock validation: requires typing the exact accountability oath
  bool verifyAndEmergencyUnlockWithOath(String typedOath) {
    if (typedOath.trim() == hardcoreOath.trim()) {
      stopFocusLockImmediate();
      return true;
    }
    return false;
  }

  Future<void> stopFocusLockImmediate() async {
    _isLockActive = false;
    _remainingSeconds = 0;
    _countdownTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEndTime);

    await FocusGuardBridge.stopFocusLock();
    _generateMathChallenge();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    FocusGuardBridge.removeInterventionListener(_handleIntervention);
    super.dispose();
  }
}
