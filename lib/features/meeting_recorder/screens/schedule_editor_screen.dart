import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/meeting_schedule.dart';
import '../providers/meeting_schedule_provider.dart';

class ScheduleEditorScreen extends StatefulWidget {
  final MeetingSchedule? existingSchedule;

  const ScheduleEditorScreen({super.key, this.existingSchedule});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  late TextEditingController _titleCtrl;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _alarmCount;
  late int _repeatDays;
  late String _startAlarmMode;
  late String _nudgeAlarmMode;
  String? _ringtoneUri;
  String _ringtoneName = 'Default Alarm';
  double _volume = 0.8;

  @override
  void initState() {
    super.initState();
    final s = widget.existingSchedule;
    _titleCtrl = TextEditingController(text: s?.title ?? 'Meeting Focus');
    _startTime = s != null ? TimeOfDay(hour: s.startHour, minute: s.startMinute) : const TimeOfDay(hour: 9, minute: 0);
    _endTime = s != null ? TimeOfDay(hour: s.endHour, minute: s.endMinute) : const TimeOfDay(hour: 10, minute: 0);
    _alarmCount = s?.alarmCount ?? 3;
    _repeatDays = s?.repeatDays ?? 0;
    _startAlarmMode = s?.startAlarmMode ?? 'ring';
    _nudgeAlarmMode = s?.nudgeAlarmMode ?? 'vibrate';
    _ringtoneUri = s?.ringtoneUri;
    _ringtoneName = s?.ringtoneName ?? 'Default Alarm';
    _volume = s?.volume ?? 0.8;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  List<TimeOfDay> get _computedNudges {
    if (_alarmCount <= 0) return [];
    final startTotal = _startTime.hour * 60 + _startTime.minute;
    var endTotal = _endTime.hour * 60 + _endTime.minute;
    if (endTotal <= startTotal) endTotal += 24 * 60;
    final totalDuration = endTotal - startTotal;

    final results = <TimeOfDay>[];
    for (int k = 1; k <= _alarmCount; k++) {
      final nudgeTotal = startTotal + (k * totalDuration) ~/ (_alarmCount + 1);
      final normalized = nudgeTotal % (24 * 60);
      results.add(TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<MeetingScheduleProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: Text(
          widget.existingSchedule != null ? 'Edit Focus Schedule' : 'New Focus Schedule',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => _saveSchedule(scheduleProvider),
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 32 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'MEETING TITLE',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Design Review & Standup',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF18181B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF27272A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Start & End Time
            const Text(
              'MEETING WINDOW (START & END)',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerTile('Start Time', _startTime, (picked) {
                    setState(() => _startTime = picked);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePickerTile('End Time', _endTime, (picked) {
                    setState(() => _endTime = picked);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // In-between Nudge Count N
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'IN-BETWEEN REFOCUS NUDGES (N)',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_alarmCount nudges',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _alarmCount.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              activeColor: const Color(0xFF2563EB),
              inactiveColor: const Color(0xFF27272A),
              onChanged: (val) => setState(() => _alarmCount = val.toInt()),
            ),
            const SizedBox(height: 10),

            // Live Computed Nudges Timeline Preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.gitCommitVertical, color: Color(0xFFF59E0B), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Computed Evenly-Spaced Intervals',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTimelineChip('Start: ${_formatTime(_startTime)}', const Color(0xFF2563EB)),
                      ..._computedNudges.map(
                        (n) => _buildTimelineChip('Nudge: ${_formatTime(n)}', const Color(0xFFD97706)),
                      ),
                      _buildTimelineChip('End: ${_formatTime(_endTime)}', const Color(0xFF475569)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Repeat Days
            const Text(
              'REPEAT SCHEDULE',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRepeatPresetChip('One-time', 0),
                _buildRepeatPresetChip('Every day', 127),
                _buildRepeatPresetChip('Weekdays (Mon–Fri)', 31),
                _buildRepeatPresetChip('Weekends (Sat–Sun)', 96),
              ],
            ),
            const SizedBox(height: 20),

            // Alarm Sound Modes
            const Text(
              'ALARM MODES',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _buildModeSelector(
                    title: 'Start Alarm Mode (Default: Ring)',
                    current: _startAlarmMode,
                    onSelected: (m) => setState(() => _startAlarmMode = m),
                  ),
                  const Divider(color: Color(0xFF27272A), height: 20),
                  _buildModeSelector(
                    title: 'In-Between Nudges (Default: Vibrate)',
                    current: _nudgeAlarmMode,
                    onSelected: (m) => setState(() => _nudgeAlarmMode = m),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Ringtone / Song Picker
            const Text(
              'RINGTONE / CUSTOM SONG',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.music, color: Color(0xFF38BDF8), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ringtoneName,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Plays up to 10 seconds max',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27272A),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(LucideIcons.folderOpen, size: 14, color: Colors.white),
                        label: const Text('Pick Song', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: _pickSongFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Volume & Test Audio
                  Row(
                    children: [
                      const Icon(LucideIcons.volume2, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          min: 0.1,
                          max: 1.0,
                          activeColor: const Color(0xFF38BDF8),
                          inactiveColor: const Color(0xFF334155),
                          onChanged: (v) => setState(() => _volume = v),
                        ),
                      ),
                      IconButton(
                        tooltip: scheduleProvider.isPreviewingAlarm ? 'Stop Preview' : 'Test Sound',
                        icon: Icon(
                          scheduleProvider.isPreviewingAlarm ? LucideIcons.square : LucideIcons.play,
                          color: scheduleProvider.isPreviewingAlarm ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          size: 18,
                        ),
                        onPressed: () {
                          if (scheduleProvider.isPreviewingAlarm) {
                            scheduleProvider.stopAlarmPreview();
                          } else {
                            scheduleProvider.previewAlarm(
                              soundMode: _startAlarmMode,
                              ringtoneUri: _ringtoneUri,
                              volume: _volume,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          border: const Border(top: BorderSide(color: Color(0xFF27272A))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          10,
          18,
          12 + MediaQuery.paddingOf(context).bottom, // ALWAYS clears notch and gesture navigation bar
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(LucideIcons.save, size: 18, color: Colors.white),
            onPressed: () => _saveSchedule(scheduleProvider),
            label: const Text(
              'Save Focus Schedule',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerTile(String label, TimeOfDay time, ValueChanged<TimeOfDay> onSelected) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.clock, size: 16, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Text(
                  _formatTime(time),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRepeatPresetChip(String label, int bitmask) {
    final selected = _repeatDays == bitmask;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFF18181B),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF38BDF8) : const Color(0xFF27272A),
      ),
      onSelected: (_) => setState(() => _repeatDays = bitmask),
    );
  }

  Widget _buildModeSelector({
    required String title,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildModeChip('Ring', 'ring', current, onSelected),
            const SizedBox(width: 8),
            _buildModeChip('Vibrate', 'vibrate', current, onSelected),
            const SizedBox(width: 8),
            _buildModeChip('Both', 'both', current, onSelected),
          ],
        ),
      ],
    );
  }

  Widget _buildModeChip(String label, String value, String current, ValueChanged<String> onSelected) {
    final selected = current == value;
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
      onSelected: (_) => onSelected(value),
    );
  }

  Future<void> _pickSongFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (files.isNotEmpty && files.first.path != null) {
        setState(() {
          _ringtoneUri = files.first.path;
          _ringtoneName = files.first.name;
        });
      }
    } catch (_) {}
  }

  String _formatTime(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Future<void> _saveSchedule(MeetingScheduleProvider provider) async {
    final title = _titleCtrl.text.trim().isEmpty ? 'Meeting Focus' : _titleCtrl.text.trim();
    final schedule = MeetingSchedule(
      id: widget.existingSchedule?.id ?? 0,
      title: title,
      startHour: _startTime.hour,
      startMinute: _startTime.minute,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
      alarmCount: _alarmCount,
      repeatDays: _repeatDays,
      startAlarmMode: _startAlarmMode,
      nudgeAlarmMode: _nudgeAlarmMode,
      ringtoneUri: _ringtoneUri,
      ringtoneName: _ringtoneName,
      volume: _volume,
      isEnabled: widget.existingSchedule?.isEnabled ?? true,
    );

    final ok = await provider.saveSchedule(schedule);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save schedule')),
        );
      }
    }
  }
}
