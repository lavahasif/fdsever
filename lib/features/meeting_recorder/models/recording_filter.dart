enum MeetingSortBy {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc,
  durationDesc,
  durationAsc,
}

enum MeetingTimeOfDay {
  all,
  morning,   // 05:00 - 11:59
  afternoon, // 12:00 - 16:59
  evening,   // 17:00 - 20:59
  night,     // 21:00 - 04:59
}

class RecordingFilter {
  final String searchQuery;
  final DateTime? fromDate;
  final DateTime? toDate;
  final MeetingTimeOfDay timeOfDay;
  final MeetingSortBy sortBy;
  final String triggerFilter; // 'all', 'power_button', 'notification_tap', 'manual'

  const RecordingFilter({
    this.searchQuery = '',
    this.fromDate,
    this.toDate,
    this.timeOfDay = MeetingTimeOfDay.all,
    this.sortBy = MeetingSortBy.dateDesc,
    this.triggerFilter = 'all',
  });

  RecordingFilter copyWith({
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
    MeetingTimeOfDay? timeOfDay,
    MeetingSortBy? sortBy,
    String? triggerFilter,
    bool clearDates = false,
  }) {
    return RecordingFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
      timeOfDay: timeOfDay ?? this.timeOfDay,
      sortBy: sortBy ?? this.sortBy,
      triggerFilter: triggerFilter ?? this.triggerFilter,
    );
  }

  bool get isFilteringActive =>
      searchQuery.trim().isNotEmpty ||
      fromDate != null ||
      toDate != null ||
      timeOfDay != MeetingTimeOfDay.all ||
      triggerFilter != 'all';
}
