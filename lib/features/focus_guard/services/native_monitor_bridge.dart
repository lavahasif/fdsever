import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter MethodChannel bridge to the NDK native monitor engine.
///
/// Provides a Dart API for controlling the C++ monitoring thread,
/// reading stats/telemetry, managing feature flags, and controlling
/// advanced features like Zen Mode, Night Owl, and Reward Unlock.
class NativeMonitorBridge {
  static const MethodChannel _channel = MethodChannel('fdserver/native_monitor');

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  /// Start the native NDK monitor foreground service.
  /// This works WITHOUT accessibility service — uses UsageStatsManager.
  static Future<bool> startMonitor() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startNativeMonitor');
      return res ?? false;
    } catch (e) {
      debugPrint('NativeMonitor start error: $e');
      return false;
    }
  }

  /// Stop the native monitor foreground service.
  static Future<bool> stopMonitor() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('stopNativeMonitor');
      return res ?? false;
    } catch (e) {
      debugPrint('NativeMonitor stop error: $e');
      return false;
    }
  }

  /// Check if native monitor service is currently running.
  static Future<bool> isRunning() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isNativeMonitorRunning');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if the NDK library was successfully loaded.
  static Future<bool> isLibraryLoaded() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isNativeLibraryLoaded');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  // ─── Stats & Telemetry ──────────────────────────────────────────────────

  /// Get real-time stats from the native C++ engine.
  /// Returns a Map with: running, screenOn, pollIntervalMs, actualPollMs,
  /// batteryLevel, totalPolls, totalBlocks, momentumScore, etc.
  static Future<Map<String, dynamic>> getStats() async {
    if (kIsWeb || !Platform.isAndroid) return {};
    try {
      final jsonStr = await _channel.invokeMethod<String>('getNativeStats');
      if (jsonStr == null || jsonStr.isEmpty) return {};
      return Map<String, dynamic>.from(json.decode(jsonStr));
    } catch (e) {
      debugPrint('NativeMonitor getStats error: $e');
      return {};
    }
  }

  /// Get the temptation pattern log from native engine.
  /// Returns a list of {pkg, ts, hour, day} entries.
  static Future<List<Map<String, dynamic>>> getTemptationLog() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final jsonStr = await _channel.invokeMethod<String>('getNativeTemptationLog');
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = json.decode(jsonStr) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('NativeMonitor getTemptationLog error: $e');
      return [];
    }
  }

  /// Get current focus momentum score (0-100).
  static Future<int> getMomentumScore() async {
    if (kIsWeb || !Platform.isAndroid) return 100;
    try {
      final res = await _channel.invokeMethod<int>('getMomentumScore');
      return res ?? 100;
    } catch (e) {
      return 100;
    }
  }

  // ─── Config Sync ────────────────────────────────────────────────────────

  /// Sync blocked packages and strict mode from SharedPreferences into native engine.
  static Future<bool> syncConfig() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('syncNativeConfig');
      return res ?? false;
    } catch (e) {
      debugPrint('NativeMonitor syncConfig error: $e');
      return false;
    }
  }

  // ─── Feature Flags (Feature #50) ────────────────────────────────────────

  /// Set a runtime feature flag on the native engine.
  /// Valid flag names: native_monitor, screen_aware, battery_adaptive,
  /// smart_debounce, temptation_pattern, momentum_score, chain_breaker,
  /// zen_mode, reward_unlock, micro_break, night_owl, cpu_self_monitor,
  /// thermal_throttle, memory_monitor
  static Future<bool> setFeatureFlag(String name, bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setFeatureFlag', {
        'name': name,
        'enabled': enabled,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('NativeMonitor setFeatureFlag error: $e');
      return false;
    }
  }

  // ─── Advanced Features ──────────────────────────────────────────────────

  /// Feature #15: Zen Mode — complete lockdown with no override.
  static Future<bool> setZenMode(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setZenMode', {'enabled': enabled});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Feature #20: Night Owl Protector — auto strict mode at night.
  static Future<bool> setNightOwl(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setNightOwl', {'enabled': enabled});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Feature #17: Reward Unlock — temporarily unlock specific apps.
  static Future<bool> setRewardUnlock({
    required bool enabled,
    int seconds = 300,
    List<String> packages = const [],
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setRewardUnlock', {
        'enabled': enabled,
        'seconds': seconds,
        'packages': packages,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Feature #19: Focus Zone Geofencing — auto strict at certain locations.
  static Future<bool> setGeofenceStrict(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setGeofenceStrict', {'enabled': enabled});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Feature #18: Acknowledge micro-break — resets the 25-minute timer.
  static Future<bool> acknowledgeBreak() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('acknowledgeBreak');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }
}
