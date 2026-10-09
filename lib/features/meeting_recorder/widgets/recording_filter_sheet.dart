import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/recording_filter.dart';

class RecordingFilterSheet extends StatefulWidget {
  final RecordingFilter currentFilter;
  final ValueChanged<RecordingFilter> onApply;

  const RecordingFilterSheet({
    super.key,
    required this.currentFilter,
    required this.onApply,
  });

  @override
  State<RecordingFilterSheet> createState() => _RecordingFilterSheetState();
}

class _RecordingFilterSheetState extends State<RecordingFilterSheet> {
  late DateTime? _fromDate;
  late DateTime? _toDate;
  late MeetingTimeOfDay _timeOfDay;
  late MeetingSortBy _sortBy;
  late String _triggerFilter;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.currentFilter.fromDate;
    _toDate = widget.currentFilter.toDate;
    _timeOfDay = widget.currentFilter.timeOfDay;
    _sortBy = widget.currentFilter.sortBy;
    _triggerFilter = widget.currentFilter.triggerFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.slidersHorizontal, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Filter & Sort Recordings',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _fromDate = null;
                      _toDate = null;
                      _timeOfDay = MeetingTimeOfDay.all;
                      _sortBy = MeetingSortBy.dateDesc;
                      _triggerFilter = 'all';
                    });
                  },
                  child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444))),
                ),
              ],
            ),
            const Divider(color: Color(0xFF27272A), height: 24),

            // 1. Sort By
            const Text(
              'SORT BY',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSortChip('Newest First', MeetingSortBy.dateDesc),
                _buildSortChip('Oldest First', MeetingSortBy.dateAsc),
                _buildSortChip('Title (A-Z)', MeetingSortBy.nameAsc),
                _buildSortChip('Title (Z-A)', MeetingSortBy.nameDesc),
                _buildSortChip('Longest Duration', MeetingSortBy.durationDesc),
                _buildSortChip('Shortest Duration', MeetingSortBy.durationAsc),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Date Range
            const Text(
              'DATE RANGE',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF38BDF8)),
                    label: Text(
                      _fromDate == null
                          ? 'From Date'
                          : '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fromDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _fromDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF38BDF8)),
                    label: Text(
                      _toDate == null
                          ? 'To Date'
                          : '${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _toDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _toDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Time of Day
            const Text(
              'TIME OF DAY',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeOfDayChip('Any Time', MeetingTimeOfDay.all),
                _buildTimeOfDayChip('Morning (5am - 12pm)', MeetingTimeOfDay.morning),
                _buildTimeOfDayChip('Afternoon (12pm - 5pm)', MeetingTimeOfDay.afternoon),
                _buildTimeOfDayChip('Evening (5pm - 9pm)', MeetingTimeOfDay.evening),
                _buildTimeOfDayChip('Night (9pm - 5am)', MeetingTimeOfDay.night),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Trigger Source
            const Text(
              'TRIGGER SOURCE',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildTriggerChip('All Triggers', 'all'),
                _buildTriggerChip('Power ×3', 'power_button'),
                _buildTriggerChip('Notification', 'notification_tap'),
                _buildTriggerChip('App Manual', 'manual'),
              ],
            ),
            const SizedBox(height: 28),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final newFilter = widget.currentFilter.copyWith(
                    fromDate: _fromDate,
                    toDate: _toDate,
                    timeOfDay: _timeOfDay,
                    sortBy: _sortBy,
                    triggerFilter: _triggerFilter,
                  );
                  widget.onApply(newFilter);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, MeetingSortBy value) {
    final selected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
      ),
      onSelected: (_) => setState(() => _sortBy = value),
    );
  }

  Widget _buildTimeOfDayChip(String label, MeetingTimeOfDay value) {
    final selected = _timeOfDay == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
      ),
      onSelected: (_) => setState(() => _timeOfDay = value),
    );
  }

  Widget _buildTriggerChip(String label, String value) {
    final selected = _triggerFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
      ),
      onSelected: (_) => setState(() => _triggerFilter = value),
    );
  }
}
