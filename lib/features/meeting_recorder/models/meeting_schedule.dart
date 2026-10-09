import 'package:flutter/material.dart';

class MeetingSchedule {
  final int id;
  final String title;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int repeatDays; // bitmask: 1=Mon, 2=Tue, 4=Wed, 8=Thu, 16=Fri, 32=Sat, 64=Sun, 0=One-off
  final String? targetDate; // YYYY-MM-DD
  final int alarmCount; // N in-between nudges
  final String startAlarmMode; // 'ring', 'vibrate', 'both'
  final String nudgeAlarmMode; // 'ring', 'vibrate', 'both'
  final String? ringtoneUri;
  final String ringtoneName;
  final double volume;
  final bool isEnabled;

  const MeetingSchedule({
    required this.id,
    required this.title,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.repeatDays = 0,
    this.targetDate,
    this.alarmCount = 3,
    this.startAlarmMode = 'ring',
    this.nudgeAlarmMode = 'vibrate',
    this.ringtoneUri,
    this.ringtoneName = 'Default Alarm',
    this.volume = 0.8,
    this.isEnabled = true,
  });

  factory MeetingSchedule.fromMap(Map<dynamic, dynamic> map) {
    return MeetingSchedule(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString() ?? 'Meeting Refocus',
      startHour: (map['startHour'] as num?)?.toInt() ?? 9,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (map['endHour'] as num?)?.toInt() ?? 10,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      repeatDays: (map['repeatDays'] as num?)?.toInt() ?? 0,
      targetDate: map['targetDate']?.toString(),
      alarmCount: (map['alarmCount'] as num?)?.toInt() ?? 3,
      startAlarmMode: map['startAlarmMode']?.toString() ?? 'ring',
      nudgeAlarmMode: map['nudgeAlarmMode']?.toString() ?? 'vibrate',
      ringtoneUri: map['ringtoneUri']?.toString(),
      ringtoneName: map['ringtoneName']?.toString() ?? 'Default Alarm',
      volume: (map['volume'] as num?)?.toDouble() ?? 0.8,
      isEnabled: map['isEnabled'] == true || map['isEnabled'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'repeatDays': repeatDays,
      'targetDate': targetDate,
      'alarmCount': alarmCount,
      'startAlarmMode': startAlarmMode,
      'nudgeAlarmMode': nudgeAlarmMode,
      'ringtoneUri': ringtoneUri,
      'ringtoneName': ringtoneName,
      'volume': volume,
      'isEnabled': isEnabled,
    };
  }

  MeetingSchedule copyWith({
    int? id,
    String? title,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? repeatDays,
    String? targetDate,
    int? alarmCount,
    String? startAlarmMode,
    String? nudgeAlarmMode,
    String? ringtoneUri,
    String? ringtoneName,
    double? volume,
    bool? isEnabled,
  }) {
    return MeetingSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      repeatDays: repeatDays ?? this.repeatDays,
      targetDate: targetDate ?? this.targetDate,
      alarmCount: alarmCount ?? this.alarmCount,
      startAlarmMode: startAlarmMode ?? this.startAlarmMode,
      nudgeAlarmMode: nudgeAlarmMode ?? this.nudgeAlarmMode,
      ringtoneUri: ringtoneUri ?? this.ringtoneUri,
      ringtoneName: ringtoneName ?? this.ringtoneName,
      volume: volume ?? this.volume,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  String get startTimeFormatted => _formatTime(startHour, startMinute);
  String get endTimeFormatted => _formatTime(endHour, endMinute);

  int get totalDurationMinutes {
    final startTotal = startHour * 60 + startMinute;
    var endTotal = endHour * 60 + endMinute;
    if (endTotal <= startTotal) {
      endTotal += 24 * 60; // Crosses midnight
    }
    return endTotal - startTotal;
  }

  /// Calculates the exact TimeOfDay for each of the N in-between nudges
  List<TimeOfDay> get computedNudgeTimes {
    if (alarmCount <= 0) return const [];
    final startTotal = startHour * 60 + startMinute;
    final totalDuration = totalDurationMinutes;

    final results = <TimeOfDay>[];
    for (int k = 1; k <= alarmCount; k++) {
      final nudgeTotal = startTotal + (k * totalDuration) ~/ (alarmCount + 1);
      final normalizedMin = nudgeTotal % (24 * 60);
      results.add(TimeOfDay(hour: normalizedMin ~/ 60, minute: normalizedMin % 60));
    }
    return results;
  }

  String get repeatSummary {
    if (repeatDays == 0) return targetDate != null ? 'On $targetDate' : 'One-time';
    if (repeatDays == 127) return 'Every day';
    if (repeatDays == 31) return 'Weekdays (Mon–Fri)';
    if (repeatDays == 96) return 'Weekends (Sat–Sun)';

    final days = <String>[];
    if ((repeatDays & 1) != 0) days.add('Mon');
    if ((repeatDays & 2) != 0) days.add('Tue');
    if ((repeatDays & 4) != 0) days.add('Wed');
    if ((repeatDays & 8) != 0) days.add('Thu');
    if ((repeatDays & 16) != 0) days.add('Fri');
    if ((repeatDays & 32) != 0) days.add('Sat');
    if ((repeatDays & 64) != 0) days.add('Sun');
    return days.join(', ');
  }

  static String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }
}
