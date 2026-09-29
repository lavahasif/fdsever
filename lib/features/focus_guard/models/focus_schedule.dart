import 'package:flutter/material.dart';

/// Represents an automated time-window schedule for Focus Guard
/// (e.g. Work Hours: 09:00 - 17:00 Mon-Fri, Bedtime Detox: 22:30 - 07:00 Daily).
class FocusSchedule {
  final String id;
  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<int> daysOfWeek; // 1 = Monday ... 7 = Sunday
  final bool isEnabled;
  final bool strictLock; // true = 0 tolerance, false = 5m budget

  const FocusSchedule({
    required this.id,
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.daysOfWeek,
    this.isEnabled = true,
    this.strictLock = true,
  });

  TimeOfDay get startTime => TimeOfDay(hour: startHour, minute: startMinute);
  TimeOfDay get endTime => TimeOfDay(hour: endHour, minute: endMinute);

  String get timeRangeString {
    final startPeriod = startHour >= 12 ? 'PM' : 'AM';
    final sHour = startHour % 12 == 0 ? 12 : startHour % 12;
    final sMin = startMinute.toString().padLeft(2, '0');

    final endPeriod = endHour >= 12 ? 'PM' : 'AM';
    final eHour = endHour % 12 == 0 ? 12 : endHour % 12;
    final eMin = endMinute.toString().padLeft(2, '0');

    return '$sHour:$sMin $startPeriod – $eHour:$eMin $endPeriod';
  }

  String get daysSummary {
    if (daysOfWeek.length == 7) return 'Every Day';
    if (daysOfWeek.length == 5 &&
        daysOfWeek.contains(1) &&
        daysOfWeek.contains(2) &&
        daysOfWeek.contains(3) &&
        daysOfWeek.contains(4) &&
        daysOfWeek.contains(5)) {
      return 'Mon – Fri (Weekdays)';
    }
    if (daysOfWeek.length == 2 && daysOfWeek.contains(6) && daysOfWeek.contains(7)) {
      return 'Sat – Sun (Weekends)';
    }
    const dayNames = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];
    return daysOfWeek.map((d) => dayNames[d - 1]).join(', ');
  }

  /// Checks if the schedule is actively running at [now]
  bool isCurrentlyActive([DateTime? now]) {
    if (!isEnabled) return false;
    final time = now ?? DateTime.now();

    // Check weekday
    if (!daysOfWeek.contains(time.weekday)) {
      // Also check overnight schedules from previous day
      final prevWeekday = time.weekday == 1 ? 7 : time.weekday - 1;
      final isOvernight = (startHour > endHour) || (startHour == endHour && startMinute > endMinute);
      if (!(isOvernight && daysOfWeek.contains(prevWeekday))) {
        return false;
      }
    }

    final currentMinutes = time.hour * 60 + time.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    if (startMinutes <= endMinutes) {
      // Same-day schedule (e.g. 09:00 - 17:00)
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Overnight schedule (e.g. 22:30 - 07:00)
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  FocusSchedule copyWith({
    String? id,
    String? name,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<int>? daysOfWeek,
    bool? isEnabled,
    bool? strictLock,
  }) {
    return FocusSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isEnabled: isEnabled ?? this.isEnabled,
      strictLock: strictLock ?? this.strictLock,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'daysOfWeek': daysOfWeek,
        'isEnabled': isEnabled,
        'strictLock': strictLock,
      };

  factory FocusSchedule.fromJson(Map<String, dynamic> json) => FocusSchedule(
        id: json['id'] as String,
        name: json['name'] as String,
        startHour: json['startHour'] as int,
        startMinute: json['startMinute'] as int,
        endHour: json['endHour'] as int,
        endMinute: json['endMinute'] as int,
        daysOfWeek: (json['daysOfWeek'] as List).map((e) => e as int).toList(),
        isEnabled: json['isEnabled'] as bool? ?? true,
        strictLock: json['strictLock'] as bool? ?? true,
      );

  static List<FocusSchedule> defaultSchedules = [
    const FocusSchedule(
      id: 'work_mode',
      name: 'Deep Work Hours',
      startHour: 9,
      startMinute: 0,
      endHour: 17,
      endMinute: 0,
      daysOfWeek: [1, 2, 3, 4, 5],
      isEnabled: true,
      strictLock: true,
    ),
    const FocusSchedule(
      id: 'night_detox',
      name: 'Bedtime Sleep Shield',
      startHour: 22,
      startMinute: 30,
      endHour: 7,
      endMinute: 0,
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      isEnabled: true,
      strictLock: true,
    ),
  ];
}
