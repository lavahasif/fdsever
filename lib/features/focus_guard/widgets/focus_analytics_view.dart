import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/focus_guard_provider.dart';

/// Comprehensive Analytics & Insights View covering Focus Guard Features 11-20
class FocusAnalyticsView extends StatelessWidget {
  final FocusGuardProvider provider;
  final bool isDark;

  const FocusAnalyticsView({
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
          // ─── Feature 20: Emergency Unlock Cooldown Warning ─────────────
          if (provider.isInCooldown) ...[
            _buildCooldownWarning(),
            const SizedBox(height: 16),
          ],

          // ─── Feature 11: Hero Daily Focus Score ────────────────────────
          _buildDailyScoreHero(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 12: Focus Streak Counter ──────────────────────────
          _buildStreakCard(isDark),
          const SizedBox(height: 16),

          // ─── Feature 16: Quick Block Presets ───────────────────────────
          _buildQuickPresetsCard(context, bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 15: Longest Focus Session Record ──────────────────
          _buildPersonalBestCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 13: Temptation Heatmap (By Hour) ──────────────────
          _buildHeatmapCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 14: App-Specific Usage Stats ──────────────────────
          _buildAppUsageStatsCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 18: Weekly Summary Report ─────────────────────────
          _buildWeeklyReportCard(context, bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 19: Whitelist Schedule ────────────────────────────
          _buildWhitelistScheduleCard(context, bgCard, borderColor, textMuted),
          const SizedBox(height: 16),

          // ─── Feature 17: Intervention History Log ──────────────────────
          _buildInterventionLogCard(bgCard, borderColor, textMuted),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Feature 20: Cooldown Penalty ──────────────────────────────────────
  Widget _buildCooldownWarning() {
    final mins = provider.cooldownRemainingSeconds ~/ 60;
    final secs = provider.cooldownRemainingSeconds % 60;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldAlert, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Unlock Cooldown Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFCA5A5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Penalty lock: ${mins}m ${secs}s remaining before you can start a new session.',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 11: Daily Focus Score Hero ────────────────────────────────
  Widget _buildDailyScoreHero(Color bgCard, Color borderColor, Color textMuted) {
    final score = provider.dailyFocusScore;
    String status = 'Novice';
    Color scoreColor = const Color(0xFFEF4444);

    if (score >= 80) {
      status = 'Zen Master 🧘';
      scoreColor = const Color(0xFF10B981);
    } else if (score >= 50) {
      status = 'Focused Defender 🛡️';
      scoreColor = const Color(0xFF3B82F6);
    } else if (score >= 20) {
      status = 'Building Momentum ⚡';
      scoreColor = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Score Ring / Badge
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scoreColor, width: 4),
              color: scoreColor.withOpacity(0.1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(fontSize: 10, color: textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Focus Score',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Calculated from temptations resisted, focus sessions completed & screen minutes saved today.',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 12: Focus Streak Counter ──────────────────────────────────
  Widget _buildStreakCard(bool isDark) {
    final streak = provider.focusStreak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
                  streak > 0 ? '$streak-Day Focus Streak!' : 'Start Your Focus Streak!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak > 0
                      ? 'You have completed full focus sessions $streak days in a row.'
                      : 'Complete a full focus session today without early unlock to begin.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 16: Quick Block Presets ───────────────────────────────────
  Widget _buildQuickPresetsCard(
    BuildContext context,
    Color bgCard,
    Color borderColor,
    Color textMuted,
  ) {
    final isLocked = provider.isLockActive;

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
              Icon(LucideIcons.zap, size: 18, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text(
                'Quick Lock Presets',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPresetButton(
                context,
                title: '30m Sprint',
                mins: 30,
                color: const Color(0xFF10B981),
                isLocked: isLocked,
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                context,
                title: '2h Deep Work',
                mins: 120,
                color: const Color(0xFF3B82F6),
                isLocked: isLocked,
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                context,
                title: '8h Lockdown',
                mins: 480,
                color: const Color(0xFFEF4444),
                isLocked: isLocked,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(
    BuildContext context, {
    required String title,
    required int mins,
    required Color color,
    required bool isLocked,
  }) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLocked ? Colors.grey.withOpacity(0.2) : color.withOpacity(0.15),
          foregroundColor: isLocked ? Colors.grey : color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isLocked ? Colors.transparent : color.withOpacity(0.4)),
          ),
        ),
        onPressed: isLocked
            ? null
            : () async {
                final ok = await provider.startPresetSession(mins);
                if (context.mounted && !ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.isInCooldown
                            ? 'Cooldown penalty active. Please wait.'
                            : 'Could not start lock. Enable accessibility service.',
                      ),
                    ),
                  );
                }
              },
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ─── Feature 15: Longest Focus Session Record ──────────────────────────
  Widget _buildPersonalBestCard(Color bgCard, Color borderColor, Color textMuted) {
    final record = provider.longestSession;
    final mins = (record['minutes'] as num?)?.toInt() ?? 0;
    final date = record['date'] as String? ?? 'Never';

    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    final displayTime = hours > 0 ? '${hours}h ${remainingMins}m' : '${mins}m';

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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.trophy, color: Color(0xFFF59E0B), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Best Focus Lock',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  mins > 0 ? '$displayTime without breaking lock' : 'No completed lock sessions yet',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  mins > 0 ? 'Achieved on: $date' : 'Complete a focus session to set your first record',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 13: Temptation Heatmap ────────────────────────────────────
  Widget _buildHeatmapCard(Color bgCard, Color borderColor, Color textMuted) {
    final heatmap = provider.temptationHeatmap;
    int maxAttempts = 1;
    for (final v in heatmap.values) {
      if (v > maxAttempts) maxAttempts = v;
    }

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
              Icon(LucideIcons.clock, size: 18, color: Color(0xFFEC4899)),
              SizedBox(width: 8),
              Text(
                'Temptation Heatmap by Hour',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Displays peak times of the day when blocked apps were attempted.',
            style: TextStyle(fontSize: 11, color: textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (hour) {
                final attempts = heatmap[hour] ?? 0;
                final heightPct = attempts / maxAttempts;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (attempts > 0)
                          Text(
                            '$attempts',
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        Container(
                          height: (heightPct * 50).clamp(4.0, 50.0),
                          decoration: BoxDecoration(
                            color: attempts > 0 ? const Color(0xFFEC4899) : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hour % 6 == 0)
                          Text(
                            '$hour',
                            style: TextStyle(fontSize: 9, color: textMuted),
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature 14: App-Specific Usage Stats ──────────────────────────────
  Widget _buildAppUsageStatsCard(Color bgCard, Color borderColor, Color textMuted) {
    final stats = provider.appUsageStats;

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
              Icon(LucideIcons.barChart2, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text(
                'Top Blocked Apps Today',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.isEmpty) ...[
            Text('No app blocks recorded today yet.', style: TextStyle(fontSize: 12, color: textMuted)),
          ] else ...[
            ...stats.take(5).map((app) {
              final name = app['appName'] as String? ?? 'App';
              final blocks = app['blocksToday'] as int? ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$blocks block(s)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                      ),
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

  // ─── Feature 18: Weekly Summary Report ─────────────────────────────────
  Widget _buildWeeklyReportCard(
    BuildContext context,
    Color bgCard,
    Color borderColor,
    Color textMuted,
  ) {
    final report = provider.weeklyReport;
    final totalTemptations = report['totalTemptations'] ?? 0;
    final hoursSaved = report['estimatedHoursSaved'] ?? '0.0';
    final topApp = report['mostBlockedApp'] ?? 'None';

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
              const Icon(LucideIcons.calendarCheck, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Text(
                'Weekly Summary Report',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text('Last 7 Days', style: TextStyle(fontSize: 11, color: textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildReportMetric('Temptations', '$totalTemptations', textMuted),
              const SizedBox(width: 8),
              _buildReportMetric('Hours Saved', '$hoursSaved hrs', textMuted),
              const SizedBox(width: 8),
              _buildReportMetric('Top App', '$topApp', textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportMetric(String label, String value, Color textMuted) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: textMuted)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Feature 19: Whitelist Schedule ────────────────────────────────────
  Widget _buildWhitelistScheduleCard(
    BuildContext context,
    Color bgCard,
    Color borderColor,
    Color textMuted,
  ) {
    final schedules = provider.whitelistSchedules;

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
              const Icon(LucideIcons.unlock, size: 18, color: Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              const Text(
                'App Whitelist Windows',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.plus, size: 18),
                onPressed: () => _showAddWhitelistDialog(context),
              ),
            ],
          ),
          Text(
            'Allow selected blocked apps during specific permitted hours (e.g. Instagram 18:00 - 19:00).',
            style: TextStyle(fontSize: 11, color: textMuted),
          ),
          const SizedBox(height: 10),
          if (schedules.isEmpty) ...[
            Text('No whitelist windows configured.', style: TextStyle(fontSize: 12, color: textMuted)),
          ] else ...[
            ...schedules.map((s) {
              final pkg = s['package'] as String;
              final startH = s['startHour'] as int;
              final startM = s['startMinute'] as int;
              final endH = s['endHour'] as int;
              final endM = s['endMinute'] as int;

              final timeStr =
                  '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')} - '
                  '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(pkg.split('.').last, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const Spacer(),
                    Text(timeStr, style: const TextStyle(fontSize: 12)),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.red),
                      onPressed: () => provider.deleteWhitelistSchedule(pkg),
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

  void _showAddWhitelistDialog(BuildContext context) {
    String selectedPkg = 'com.instagram.android';
    int startHour = 18;
    int endHour = 19;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Whitelist Window', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select App to Permit:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: selectedPkg,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'com.instagram.android', child: Text('Instagram')),
                  DropdownMenuItem(value: 'com.google.android.youtube', child: Text('YouTube')),
                  DropdownMenuItem(value: 'com.twitter.android', child: Text('X / Twitter')),
                  DropdownMenuItem(value: 'com.zhiliaoapp.musically', child: Text('TikTok')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => selectedPkg = val);
                },
              ),
              const SizedBox(height: 12),
              Text('Allowed Hours: $startHour:00 to $endHour:00', style: const TextStyle(fontSize: 12)),
              Slider(
                value: startHour.toDouble(),
                min: 0,
                max: 23,
                divisions: 23,
                label: '$startHour:00',
                onChanged: (v) {
                  setState(() {
                    startHour = v.toInt();
                    if (endHour <= startHour) endHour = (startHour + 1).clamp(0, 24);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
              onPressed: () {
                Navigator.pop(ctx);
                provider.addOrUpdateWhitelistSchedule({
                  'package': selectedPkg,
                  'startHour': startHour,
                  'startMinute': 0,
                  'endHour': endHour,
                  'endMinute': 0,
                  'enabled': true,
                });
              },
              child: const Text('Save Window', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Feature 17: Intervention History Log ──────────────────────────────
  Widget _buildInterventionLogCard(Color bgCard, Color borderColor, Color textMuted) {
    final log = provider.interventionLog;

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
              const Icon(LucideIcons.history, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Text(
                'Recent Intervention History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text('${log.length} events', style: TextStyle(fontSize: 11, color: textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          if (log.isEmpty) ...[
            Text('No app interventions recorded yet.', style: TextStyle(fontSize: 12, color: textMuted)),
          ] else ...[
            ...log.take(8).map((item) {
              final pkg = item['package'] as String? ?? 'unknown';
              final reason = item['reason'] as String? ?? 'App Blocked';
              final ts = item['timestamp'] as int? ?? 0;
              final dt = DateTime.fromMillisecondsSinceEpoch(ts);
              final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.shieldOff, color: Color(0xFFEF4444), size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pkg.split('.').last, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(reason, style: TextStyle(fontSize: 10, color: textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Text(timeStr, style: TextStyle(fontSize: 11, color: textMuted)),
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
