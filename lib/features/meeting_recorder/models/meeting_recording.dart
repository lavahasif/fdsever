import 'dart:io';

class MeetingRecording {
  final int id;
  final String filePath;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMs;
  final int sizeBytes;
  final String triggerType; // 'power_button', 'notification_tap', 'manual'
  final String tags;
  final String notes;

  const MeetingRecording({
    required this.id,
    required this.filePath,
    required this.title,
    required this.startedAt,
    this.endedAt,
    this.durationMs = 0,
    this.sizeBytes = 0,
    this.triggerType = 'manual',
    this.tags = '',
    this.notes = '',
  });

  factory MeetingRecording.fromMap(Map<dynamic, dynamic> map) {
    return MeetingRecording(
      id: (map['id'] as num?)?.toInt() ?? 0,
      filePath: map['filePath']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Meeting Recording',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['startedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      endedAt: map['endedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['endedAt'] as num).toInt())
          : null,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      triggerType: map['triggerType']?.toString() ?? 'manual',
      tags: map['tags']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
    );
  }

  MeetingRecording copyWith({
    int? id,
    String? filePath,
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationMs,
    int? sizeBytes,
    String? triggerType,
    String? tags,
    String? notes,
  }) {
    return MeetingRecording(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      triggerType: triggerType ?? this.triggerType,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }

  bool get fileExists => filePath.isNotEmpty && File(filePath).existsSync();

  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    final y = startedAt.year;
    final m = startedAt.month.toString().padLeft(2, '0');
    final d = startedAt.day.toString().padLeft(2, '0');
    final h = startedAt.hour.toString().padLeft(2, '0');
    final min = startedAt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get triggerLabel {
    switch (triggerType) {
      case 'power_button':
        return 'Power ×3';
      case 'notification_tap':
        return 'Notification';
      case 'manual':
      default:
        return 'App';
    }
  }
}
