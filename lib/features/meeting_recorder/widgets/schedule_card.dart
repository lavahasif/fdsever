import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/meeting_schedule.dart';

class ScheduleCard extends StatelessWidget {
  final MeetingSchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTestAlarm;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onTestAlarm,
  });

  @override
  Widget build(BuildContext context) {
    final nudges = schedule.computedNudgeTimes;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: schedule.isEnabled ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFF27272A),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: schedule.isEnabled
                        ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                        : const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.bellRing,
                    color: schedule.isEnabled ? const Color(0xFF60A5FA) : const Color(0xFF64748B),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.title,
                        style: TextStyle(
                          color: schedule.isEnabled ? Colors.white : const Color(0xFF94A3B8),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule.repeatSummary,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: schedule.isEnabled,
                  activeThumbColor: const Color(0xFF2563EB),
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Time banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 14, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Text(
                    '${schedule.startTimeFormatted}  ➔  ${schedule.endTimeFormatted}',
                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${schedule.totalDurationMinutes} min',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Nudges distribution
            if (nudges.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(LucideIcons.sparkles, size: 12, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    '${schedule.alarmCount} Refocus Nudges:',
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: nudges.map((time) {
                  final period = time.hour >= 12 ? 'PM' : 'AM';
                  final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
                  final m = time.minute.toString().padLeft(2, '0');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      '$h:$m $period',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Modes & Song Row
            Row(
              children: [
                _buildModeBadge('Start: ${schedule.startAlarmMode.toUpperCase()}'),
                const SizedBox(width: 6),
                _buildModeBadge('Nudge: ${schedule.nudgeAlarmMode.toUpperCase()}'),
                const Spacer(),
                IconButton(
                  tooltip: 'Test Alarm Sound',
                  icon: const Icon(LucideIcons.volume2, size: 18, color: Color(0xFF38BDF8)),
                  onPressed: onTestAlarm,
                ),
                IconButton(
                  tooltip: 'Edit Schedule',
                  icon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Delete Schedule',
                  icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFEF4444)),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
