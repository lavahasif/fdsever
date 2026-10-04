import 'dart:io';

class CallRecordingItem {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime lastModified;
  final String phoneNumber;
  final String contactName;
  final String callDirection;
  final String notes;
  final double durationSeconds;

  CallRecordingItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    this.phoneNumber = '',
    this.contactName = '',
    this.callDirection = 'unknown',
    this.notes = '',
    this.durationSeconds = 0.0,
  });

  factory CallRecordingItem.fromMap(Map<dynamic, dynamic> map) {
    return CallRecordingItem(
      path: map['path']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Recording.wav',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        (map['lastModified'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      contactName: map['contactName']?.toString() ?? '',
      callDirection: map['callDirection']?.toString() ?? 'unknown',
      notes: map['notes']?.toString() ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0.0,
    );
  }

  CallRecordingItem copyWith({
    String? path,
    String? name,
    int? sizeBytes,
    DateTime? lastModified,
    String? phoneNumber,
    String? contactName,
    String? callDirection,
    String? notes,
    double? durationSeconds,
  }) {
    return CallRecordingItem(
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastModified: lastModified ?? this.lastModified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      callDirection: callDirection ?? this.callDirection,
      notes: notes ?? this.notes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  String get displayName {
    if (contactName.trim().isNotEmpty) {
      return contactName.trim();
    }
    if (phoneNumber.trim().isNotEmpty && phoneNumber.trim() != 'Unknown') {
      return phoneNumber.trim();
    }
    return name;
  }

  bool get isIncoming => callDirection == 'incoming';
  bool get isOutgoing => callDirection == 'outgoing';
  bool get isVoIP => callDirection == 'voip' || phoneNumber == 'VoIP';

  String get directionLabel {
    if (isIncoming) return 'Incoming';
    if (isOutgoing) return 'Outgoing';
    if (isVoIP) return 'VoIP';
    return '';
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final totalSec = durationSeconds.toInt();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${_twoDigits(mins)}:${_twoDigits(secs)}';
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    return '${lastModified.year}-${_twoDigits(lastModified.month)}-${_twoDigits(lastModified.day)} '
        '${_twoDigits(lastModified.hour)}:${_twoDigits(lastModified.minute)}';
  }

  bool get exists => File(path).existsSync();

  static String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}
