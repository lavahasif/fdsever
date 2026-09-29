import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef InterventionCallback = void Function(String packageName, String reason);

class FocusGuardBridge {
  static const MethodChannel _channel = MethodChannel('fdserver/focus_guard');

  static final List<InterventionCallback> _interventionListeners = [];

  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onInterventionTriggered') {
          final args = call.arguments as Map?;
          final pkg = args?['package'] as String? ?? 'unknown';
          final reason = args?['reason'] as String? ?? 'general';
          for (final listener in _interventionListeners) {
            listener(pkg, reason);
          }
        }
      });
    }
  }

  static void addInterventionListener(InterventionCallback callback) {
    init();
    if (!_interventionListeners.contains(callback)) {
      _interventionListeners.add(callback);
    }
  }

  static void removeInterventionListener(InterventionCallback callback) {
    _interventionListeners.remove(callback);
  }

  static Future<bool> isAccessibilityEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking accessibility: $e');
      return false;
    }
  }

  static Future<bool> openAccessibilitySettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return res ?? false;
    } catch (e) {
      debugPrint('Error opening accessibility settings: $e');
      return false;
    }
  }

  static Future<bool> hasUsageStatsPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking usage stats permission: $e');
      return false;
    }
  }

  static Future<bool> openUsageStatsSettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openUsageStatsSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('Error opening usage stats settings: $e');
      return false;
    }
  }

  static Future<bool> hasOverlayPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  static Future<bool> openOverlaySettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openOverlaySettings');
      return res ?? false;
    } catch (e) {
      debugPrint('Error opening overlay settings: $e');
      return false;
    }
  }

  static Future<bool> syncConfig({
    required List<String> blockedPackages,
    required bool blockShorts,
    bool? isStrict,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('syncConfig', {
        'blockedPackages': blockedPackages,
        'blockShorts': blockShorts,
        if (isStrict != null) 'isStrict': isStrict,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error syncing FocusGuard config: $e');
      return false;
    }
  }

  static Future<Map<String, String>?> checkPendingIntervention() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMapMethod<String, String>('checkPendingIntervention');
      return res;
    } catch (e) {
      debugPrint('Error checking pending intervention: $e');
      return null;
    }
  }

  static Future<bool> startFocusLock({
    required List<String> blockedPackages,
    bool blockShorts = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('startFocusLock', {
        'blockedPackages': blockedPackages,
        'blockShorts': blockShorts,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error starting focus lock: $e');
      return false;
    }
  }

  static Future<bool> stopFocusLock() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('stopFocusLock');
      return res ?? false;
    } catch (e) {
      debugPrint('Error stopping focus lock: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getStatus() async {
    if (kIsWeb || !Platform.isAndroid) {
      return {
        'isServiceRunning': false,
        'isStrictActive': false,
        'blockShorts': true,
        'blockedPackages': <String>[],
        'temptationsCount': 0,
      };
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      return res ?? {};
    } catch (e) {
      debugPrint('Error getting focus guard status: $e');
      return {};
    }
  }

  static Future<List<Map<String, String>>> getInstalledApps() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeListMethod<dynamic>('getInstalledApps');
      if (res == null) return [];
      return res.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return {
          'packageName': map['packageName']?.toString() ?? '',
          'appName': map['appName']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching installed apps: $e');
      return [];
    }
  }
}
