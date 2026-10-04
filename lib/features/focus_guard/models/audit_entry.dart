import 'package:flutter/material.dart';

/// Cryptographically chained Audit Trail entry model.
class AuditEntry {
  final int id;
  final int timestamp;
  final String eventType;
  final String packageName;
  final String category;
  final String payload;
  final String prevHash;
  final String currentHash;
  final double latitude;
  final double longitude;

  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.packageName,
    required this.category,
    required this.payload,
    required this.prevHash,
    required this.currentHash,
    required this.latitude,
    required this.longitude,
  });

  factory AuditEntry.fromMap(Map<dynamic, dynamic> map) {
    return AuditEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      eventType: map['eventType'] as String? ?? 'UNKNOWN',
      packageName: map['packageName'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      payload: map['payload'] as String? ?? '',
      prevHash: map['prevHash'] as String? ?? '',
      currentHash: map['currentHash'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  String get shortHash =>
      currentHash.length >= 12 ? currentHash.substring(0, 12) : currentHash;

  bool get hasLocation => latitude != 0.0 || longitude != 0.0;

  IconData get icon {
    switch (eventType) {
      case 'TEMPTATION_BLOCKED':
      case 'OVERLAY_ENFORCED':
        return Icons.shield_rounded;
      case 'EMERGENCY_BYPASS_ACTIVATED':
        return Icons.emergency_rounded;
      case 'GEOFENCE_ENTER':
        return Icons.location_on_rounded;
      case 'GEOFENCE_EXIT':
        return Icons.location_off_rounded;
      case 'WIFI_SHIELD_MATCH':
        return Icons.wifi_protected_setup_rounded;
      case 'ATTENTION_FRAGMENTATION':
        return Icons.psychology_alt_rounded;
      case 'DRIVING_SHIELD_TRIGGERED':
        return Icons.directions_car_rounded;
      case 'KINETIC_QUOTA_CONSUMED':
        return Icons.directions_walk_rounded;
      case 'STRICT_LOCK_ENGAGED':
        return Icons.lock_clock_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color get accentColor {
    switch (eventType) {
      case 'TEMPTATION_BLOCKED':
      case 'OVERLAY_ENFORCED':
        return const Color(0xFFEF4444); // Red
      case 'EMERGENCY_BYPASS_ACTIVATED':
        return const Color(0xFFF97316); // Orange
      case 'GEOFENCE_ENTER':
      case 'WIFI_SHIELD_MATCH':
        return const Color(0xFF10B981); // Emerald
      case 'GEOFENCE_EXIT':
        return const Color(0xFF64748B); // Slate
      case 'ATTENTION_FRAGMENTATION':
        return const Color(0xFFA855F7); // Purple
      case 'DRIVING_SHIELD_TRIGGERED':
        return const Color(0xFF06B6D4); // Cyan
      case 'KINETIC_QUOTA_CONSUMED':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

/// Geofence Focus Zone definition
class GeofenceZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool strictMode;

  const GeofenceZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.strictMode = true,
  });

  factory GeofenceZone.fromMap(Map<String, dynamic> map) {
    return GeofenceZone(
      id: map['id'] as String? ?? UniqueKey().toString(),
      name: map['name'] as String? ?? 'Focus Zone',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 100.0,
      strictMode: map['strictMode'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'strictMode': strictMode,
      };
}

/// Kinetic step-banking status
class KineticStepStatus {
  final int bankedSteps;
  final int earnedMinutes;
  final int usedMinutes;
  final int remainingMinutes;

  const KineticStepStatus({
    required this.bankedSteps,
    required this.earnedMinutes,
    required this.usedMinutes,
    required this.remainingMinutes,
  });

  factory KineticStepStatus.fromMap(Map<dynamic, dynamic> map) {
    return KineticStepStatus(
      bankedSteps: (map['bankedSteps'] as num?)?.toInt() ?? 0,
      earnedMinutes: (map['earnedMinutes'] as num?)?.toInt() ?? 0,
      usedMinutes: (map['usedMinutes'] as num?)?.toInt() ?? 0,
      remainingMinutes: (map['remainingMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  double get progressRatio =>
      earnedMinutes > 0 ? (usedMinutes / earnedMinutes).clamp(0.0, 1.0) : 0.0;
}

/// Verification result for SHA-256 blockchain-style integrity
class IntegrityVerificationResult {
  final bool isValid;
  final int brokenAtId;

  const IntegrityVerificationResult({
    required this.isValid,
    required this.brokenAtId,
  });

  factory IntegrityVerificationResult.fromMap(Map<dynamic, dynamic> map) {
    return IntegrityVerificationResult(
      isValid: map['isValid'] as bool? ?? false,
      brokenAtId: (map['brokenAtId'] as num?)?.toInt() ?? -1,
    );
  }
}
