import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/audit_entry.dart';

/// Service interfacing with native Tamper-Evident Blackbox SQLite & Sensor Telemetry
class AuditService {
  static const MethodChannel _channel = MethodChannel('fdserver/audit_trail');

  /// Fetch chronologically logged events from the tamper-evident SQLite chain
  static Future<List<AuditEntry>> getAuditLogs({
    int limit = 100,
    int offset = 0,
    String? category,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getAuditLogs', {
        'limit': limit,
        'offset': offset,
        'category': category,
      });
      if (res == null) return [];
      return res.map((item) => AuditEntry.fromMap(item as Map)).toList();
    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      return [];
    }
  }

  /// Cryptographically re-computes SHA-256 signatures across all records from Genesis
  static Future<IntegrityVerificationResult> verifyAuditIntegrity() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const IntegrityVerificationResult(isValid: true, brokenAtId: -1);
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('verifyAuditIntegrity');
      if (res == null) {
        return const IntegrityVerificationResult(isValid: false, brokenAtId: -1);
      }
      return IntegrityVerificationResult.fromMap(res);
    } catch (e) {
      debugPrint('Error verifying audit integrity: $e');
      return const IntegrityVerificationResult(isValid: false, brokenAtId: -1);
    }
  }

  /// Aggregated distraction cluster coordinates for geospatial heatmap
  static Future<List<Map<String, dynamic>>> getDistractionCoordinates() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getDistractionCoordinates');
      if (res == null) return [];
      return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('Error getting distraction coordinates: $e');
      return [];
    }
  }

  /// Exports entire chain to CSV format
  static Future<String> exportAuditCsv() async {
    if (kIsWeb || !Platform.isAndroid) return '';
    try {
      final res = await _channel.invokeMethod<String>('exportAuditCsv');
      return res ?? '';
    } catch (e) {
      debugPrint('Error exporting audit CSV: $e');
      return '';
    }
  }

  /// Triggers 5-minute emergency distress unlock with GPS logging
  static Future<DateTime?> triggerEmergencyBypass({
    required String reason,
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<num>('triggerEmergencyBypass', {
        'reason': reason,
        'latitude': latitude,
        'longitude': longitude,
      });
      if (res != null) {
        return DateTime.fromMillisecondsSinceEpoch(res.toInt());
      }
      return null;
    } catch (e) {
      debugPrint('Error triggering emergency bypass: $e');
      return null;
    }
  }

  /// Checks if emergency bypass is currently active
  static Future<bool> isEmergencyBypassActive() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isEmergencyBypassActive');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Remaining seconds in active emergency bypass
  static Future<int> getEmergencyBypassRemainingSeconds() async {
    if (kIsWeb || !Platform.isAndroid) return 0;
    try {
      final res = await _channel.invokeMethod<num>('getEmergencyBypassRemainingSeconds');
      return res?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Kinetic hardware step counter telemetry & banked screen time
  static Future<KineticStepStatus> getKineticStepStatus() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const KineticStepStatus(
        bankedSteps: 0,
        earnedMinutes: 0,
        usedMinutes: 0,
        remainingMinutes: 0,
      );
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getKineticStepStatus');
      if (res == null) {
        return const KineticStepStatus(
          bankedSteps: 0,
          earnedMinutes: 0,
          usedMinutes: 0,
          remainingMinutes: 0,
        );
      }
      return KineticStepStatus.fromMap(res);
    } catch (e) {
      debugPrint('Error getting kinetic step status: $e');
      return const KineticStepStatus(
        bankedSteps: 0,
        earnedMinutes: 0,
        usedMinutes: 0,
        remainingMinutes: 0,
      );
    }
  }

  /// Consume banked kinetic screen time
  static Future<bool> consumeKineticMinutes(int minutes) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('consumeKineticMinutes', {
        'minutes': minutes,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get configured geofence focus zones
  static Future<List<GeofenceZone>> getGeofenceZones() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final jsonStr = await _channel.invokeMethod<String>('getGeofenceZones');
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]') return [];
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => GeofenceZone.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      debugPrint('Error reading geofence zones: $e');
      return [];
    }
  }

  /// Save configured geofence focus zones
  static Future<bool> saveGeofenceZones(List<GeofenceZone> zones) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final list = zones.map((z) => z.toMap()).toList();
      final jsonStr = jsonEncode(list);
      final res = await _channel.invokeMethod<bool>('setGeofenceZones', {
        'zonesJson': jsonStr,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error saving geofence zones: $e');
      return false;
    }
  }

  /// Configured Wi-Fi shield SSIDs
  static Future<List<String>> getWifiShieldSsids() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getWifiShieldSsids');
      if (res == null) return [];
      return res.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save Wi-Fi shield SSIDs
  static Future<bool> saveWifiShieldSsids(List<String> ssids) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setWifiShieldSsids', {
        'ssids': ssids,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Evaluate GPS location against geofence zones
  static Future<Map<String, dynamic>> evaluateLocation(double lat, double lng) async {
    if (kIsWeb || !Platform.isAndroid) return {'inZone': false, 'zoneName': ''};
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('evaluateLocation', {
        'latitude': lat,
        'longitude': lng,
      });
      if (res == null) return {'inZone': false, 'zoneName': ''};
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'inZone': false, 'zoneName': ''};
    }
  }

  /// Commute / Driving status
  static Future<Map<String, dynamic>> getDrivingStatus() async {
    if (kIsWeb || !Platform.isAndroid) return {'isDriving': false, 'speedKmh': 0.0};
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDrivingStatus');
      if (res == null) return {'isDriving': false, 'speedKmh': 0.0};
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'isDriving': false, 'speedKmh': 0.0};
    }
  }

  /// Sleep Sanctuary (11 PM - 6 AM)
  static Future<bool> isSleepSanctuaryActive() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSleepSanctuaryStatus');
      return res?['isSanctuaryActive'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Low battery travel throttle
  static Future<Map<String, dynamic>> getBatteryThrottleStatus({bool isAwayFromHome = false}) async {
    if (kIsWeb || !Platform.isAndroid) return {'isLowBatteryAway': false, 'batteryLevel': 100};
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBatteryThrottleStatus', {
        'isAwayFromHome': isAwayFromHome,
      });
      if (res == null) return {'isLowBatteryAway': false, 'batteryLevel': 100};
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'isLowBatteryAway': false, 'batteryLevel': 100};
    }
  }

  /// Record manual or synthetic audit event
  static Future<bool> recordAuditLog({
    required String eventType,
    String? packageName,
    String category = 'Audit & Geospatial',
    required String payload,
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('recordAuditLog', {
        'eventType': eventType,
        'packageName': packageName,
        'category': category,
        'payload': payload,
        'latitude': latitude,
        'longitude': longitude,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error recording manual audit log: $e');
      return false;
    }
  }
}
