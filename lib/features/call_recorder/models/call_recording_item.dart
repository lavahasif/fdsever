import 'dart:io';

class CallRecordingItem {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime lastModified;

  CallRecordingItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
  });

  factory CallRecordingItem.fromMap(Map<dynamic, dynamic> map) {
    return CallRecordingItem(
      path: map['path']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Recording.wav',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        (map['lastModified'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
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
