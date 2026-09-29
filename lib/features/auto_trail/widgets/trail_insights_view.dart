import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/auto_trail_provider.dart';

/// Comprehensive Insights View covering Auto Trail Features 1-10
class TrailInsightsView extends StatelessWidget {
  final AutoTrailProvider provider;
  final bool isDark;

  const TrailInsightsView({
    super.key,
    required this.provider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgCard = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return RefreshIndicator(
      onRefresh: () => provider.loadAnalytics(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Feature 6: Location Streak Counter ────────────────────────
          _buildStreakBanner(isDark),
          const SizedBox(height: 16),

          // ─── Feature 10: Quick Location Note Action ────────────────────
          _buildQuickNoteCard(context, bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 1: Weekly Heatmap Calendar ────────────────────────
          _buildHeatmapCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 4: Night Owl Detector ─────────────────────────────
          if (provider.hasNightActivity) ...[
            _buildNightOwlAlert(),
            const SizedBox(height: 16),
          ],

          // ─── Feature 2: Speed & Movement Analytics ─────────────────────
          _buildSpeedAnalyticsCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 8: Activity Breakdown ─────────────────────────────
          _buildActivityBreakdownCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 9: Trail Distance Milestones ──────────────────────
          _buildMilestonesCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 5: Commute Time Estimator ─────────────────────────
          _buildCommuteCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 3 & 7: Place Frequency & Dwell Leaderboard ────────
          _buildLeaderboardCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Feature 6: Streak Banner ──────────────────────────────────────────
  Widget _buildStreakBanner(bool isDark) {
    final streak = provider.trackingStreak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '$streak-Day Tracking Streak!' : 'Start Your Streak Today!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak > 0
                      ? 'You have recorded movement for $streak consecutive days.'
                      : 'Log at least one point today to start building your streak.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 10: Quick Location Note ───────────────────────────────────
  Widget _buildQuickNoteCard(
    BuildContext context,
    Color bgCard,
    Color borderColor,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.fileText, color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Location Note',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Pin your current GPS with a short reminder note',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('Add Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: () => _showAddNoteDialog(context),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.mapPin, color: Color(0xFF3B82F6), size: 20),
            SizedBox(width: 8),
            Text('Log Location with Note', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your current GPS location will be captured immediately and tagged with your note:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g., Met with client, delicious cafe, car parked here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () async {
              final note = controller.text.trim();
              Navigator.pop(ctx);
              final pt = await provider.recordCurrentLocation(note: note.isNotEmpty ? note : null);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(pt != null ? 'Location logged with note!' : 'Could not fetch GPS'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Save GPS & Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Feature 1: Weekly Heatmap Calendar ────────────────────────────────
  Widget _buildHeatmapCard(Color bgCard, Color borderColor, Color textMuted) {
    final heatmap = provider.heatmapData;
    final now = DateTime.now();

    // Past 14 days
    final days = List.generate(14, (i) {
      final d = now.subtract(Duration(days: 13 - i));
      return DateTime(d.year, d.month, d.day);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Text(
                '14-Day Activity Heatmap',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text('Tap day to jump', style: TextStyle(fontSize: 11, color: textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: days.map((day) {
                final count = heatmap[day] ?? 0;
                final isSelected = day.year == provider.selectedDate.year &&
                    day.month == provider.selectedDate.month &&
                    day.day == provider.selectedDate.day;

                Color cellColor;
                if (count == 0) {
                  cellColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
                } else if (count < 20) {
                  cellColor = const Color(0xFF065F46);
                } else if (count < 60) {
                  cellColor = const Color(0xFF059669);
                } else {
                  cellColor = const Color(0xFF10B981);
                }

                return GestureDetector(
                  onTap: () => provider.setSelectedDate(day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E').format(day).substring(0, 1),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: count == 0 ? textMuted : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: count == 0 ? textMuted : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 9,
                            color: count == 0 ? Colors.transparent : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 4: Night Owl Alert ────────────────────────────────────────
  Widget _buildNightOwlAlert() {
    final count = provider.nightOwlPoints.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🦉', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Night Owl Activity Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC4B5FD),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$count location point(s) recorded between 12:00 AM and 5:00 AM today.',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 2: Speed & Movement Analytics ─────────────────────────────
  Widget _buildSpeedAnalyticsCard(Color bgCard, Color borderColor, Color textMuted) {
    final stats = provider.speedAnalytics;
    final avgSpeed = (stats['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final maxSpeed = (stats['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final movingMins = (stats['movingMinutes'] as num?)?.toInt() ?? 0;
    final stationaryMins = (stats['stationaryMinutes'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.gauge, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text(
                'Speed & Movement Analytics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricTile('Avg Speed', '${avgSpeed.toStringAsFixed(1)} km/h', LucideIcons.move, textMuted),
              const SizedBox(width: 12),
              _buildMetricTile('Max Speed', '${maxSpeed.toStringAsFixed(1)} km/h', LucideIcons.zap, textMuted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricTile('Moving Time', '${movingMins}m', LucideIcons.activity, textMuted),
              const SizedBox(width: 12),
              _buildMetricTile('Stationary', '${stationaryMins}m', LucideIcons.anchor, textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color textMuted) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: textMuted),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 11, color: textMuted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // ─── Feature 8: Activity Breakdown ─────────────────────────────────────
  Widget _buildActivityBreakdownCard(Color bgCard, Color borderColor, Color textMuted) {
    final activities = provider.activityPercentages;
    final still = activities['still'] ?? 0.0;
    final walking = activities['walking'] ?? 0.0;
    final driving = activities['driving'] ?? 0.0;
    final running = activities['running'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.pieChart, size: 18, color: Color(0xFFEC4899)),
              SizedBox(width: 8),
              Text(
                'Activity Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActivityProgressBar('Still / Resting', still, const Color(0xFF6B7280)),
          const SizedBox(height: 8),
          _buildActivityProgressBar('Walking', walking, const Color(0xFF10B981)),
          const SizedBox(height: 8),
          _buildActivityProgressBar('In Vehicle', driving, const Color(0xFF3B82F6)),
          const SizedBox(height: 8),
          _buildActivityProgressBar('Running', running, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildActivityProgressBar(String title, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            Text('${(pct * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ─── Feature 9: Trail Distance Milestones ──────────────────────────────
  Widget _buildMilestonesCard(Color bgCard, Color borderColor, Color textMuted) {
    final milestones = provider.distanceMilestones;
    final totalKm = (milestones['totalDistanceKm'] as num?)?.toDouble() ?? 0.0;
    final nextMilestone = (milestones['nextMilestoneKm'] as num?)?.toDouble() ?? 50.0;
    final progress = (milestones['progressToNext'] as num?)?.toDouble() ?? 0.0;
    final unlocked = (milestones['unlockedBadges'] as List?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.award, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text(
                'Distance Milestones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text('${totalKm.toStringAsFixed(1)} km total', style: TextStyle(fontSize: 12, color: textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Progress to ${nextMilestone.toInt()} km Milestone:',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBadge('10km', '🥉', unlocked.contains('10km')),
              _buildBadge('50km', '🥈', unlocked.contains('50km')),
              _buildBadge('100km', '🥇', unlocked.contains('100km')),
              _buildBadge('500km', '💎', unlocked.contains('500km')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, String emoji, bool isUnlocked) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked
                ? const Color(0xFFF59E0B).withOpacity(0.18)
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5)),
            border: Border.all(
              color: isUnlocked ? const Color(0xFFF59E0B) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: 20, color: isUnlocked ? null : Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
            color: isUnlocked ? null : Colors.grey,
          ),
        ),
      ],
    );
  }

  // ─── Feature 5: Commute Time Estimator ─────────────────────────────────
  Widget _buildCommuteCard(Color bgCard, Color borderColor, Color textMuted) {
    final commute = provider.commuteData;
    final hasCommute = commute['hasCommute'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.navigation, size: 18, color: Color(0xFF06B6D4)),
              SizedBox(width: 8),
              Text(
                'Commute Time Estimator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasCommute) ...[
            Text(
              'Average Daily Commute: ${commute['averageMinutes']} minutes',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Detected between your saved "Home" and "Work" locations based on repeated routes.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ] else ...[
            Text(
              'Save places named "Home" and "Work" to automatically calculate your average daily commute duration.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Feature 3 & 7: Place Frequency & Dwell Leaderboard ─────────────────
  Widget _buildLeaderboardCard(Color bgCard, Color borderColor, Color textMuted) {
    final leaderboard = provider.dwellLeaderboard;
    final frequency = provider.visitFrequency;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.trophy, size: 18, color: Color(0xFFEAB308)),
              SizedBox(width: 8),
              Text(
                'Place Dwell Leaderboard & Visits',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (leaderboard.isEmpty) ...[
            Text(
              'Save places on the Visits tab to see dwell time rankings and visit frequency.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ] else ...[
            ...leaderboard.map((item) {
              final name = item['name'] as String;
              final hours = (item['hours'] as num?)?.toDouble() ?? 0.0;
              final visitCount = frequency[name] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAB308),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${leaderboard.indexOf(item) + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('$visitCount total visit(s)', style: TextStyle(fontSize: 11, color: textMuted)),
                        ],
                      ),
                    ),
                    Text(
                      '${hours.toStringAsFixed(1)} hrs',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
