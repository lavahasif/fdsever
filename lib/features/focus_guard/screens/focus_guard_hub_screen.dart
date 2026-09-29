import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../shared/widgets/resource_telemetry_modal.dart';
import '../providers/focus_guard_provider.dart';
import '../services/focus_guard_bridge.dart';
import 'app_blacklist_screen.dart';
import 'reality_check_screen.dart';

class FocusGuardHubScreen extends StatefulWidget {
  const FocusGuardHubScreen({super.key});

  @override
  State<FocusGuardHubScreen> createState() => _FocusGuardHubScreenState();
}

class _FocusGuardHubScreenState extends State<FocusGuardHubScreen> {
  final TextEditingController _goalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FocusGuardProvider>().checkPermissions();
    });
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showEditGoalDialog(BuildContext context, FocusGuardProvider provider) {
    _goalController.text = provider.targetGoal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Set Your Life Goal Anchor', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Whenever an impulse to scroll hits, this goal will be displayed to wake you up.',
              style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g., Master coding, build my startup, get physically fit...',
                hintStyle: const TextStyle(color: Color(0xFF71717A)),
                filled: true,
                fillColor: const Color(0xFF27272A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () {
              provider.setGoal(_goalController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Goal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusGuardProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Automatic push of Reality Check screen if an intervention was triggered
    if (provider.pendingIntervention != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final alert = provider.pendingIntervention;
        if (alert != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RealityCheckScreen(
                blockedPackage: alert.packageName,
                blockReason: alert.reason,
              ),
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Card (Countdown or Start Session)
            _buildHeroFocusCard(context, provider),

            const SizedBox(height: 20),

            // Goal Anchor Banner
            _buildGoalBanner(context, provider),

            const SizedBox(height: 20),

            // Distraction Shield Stats
            _buildStatsRow(provider),

            const SizedBox(height: 24),

            // Permission Verification Card
            _buildPermissionsCard(context, provider),

            const SizedBox(height: 24),

            // Quick Actions & Configuration
            _buildActionButtons(context, provider),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroFocusCard(BuildContext context, FocusGuardProvider provider) {
    if (provider.isLockActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7F1D1D),
              Color(0xFF450A0A),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.lock, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'HARDCORE LOCK ENGAGED',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${provider.blockedApps.where((a) => a.isBlocked).length} Apps Guarded',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFCA5A5)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _formatTimer(provider.remainingSeconds),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Zero distractions allowed. Your brain is in deep focus mode.',
              style: TextStyle(fontSize: 12, color: Color(0xFFFCA5A5)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RealityCheckScreen(
                        blockReason: 'Emergency Unlock Request',
                      ),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.keyRound, size: 16),
                label: const Text(
                  'Emergency Unlock Challenge',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Inactive Hero Card
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF312E81)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.shield, color: Color(0xFF818CF8), size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FocusGuard Shield',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Kill YouTube Shorts, Reels & Distractions',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Session Duration:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildDurationChip(provider, 25, '25m Sprint'),
              const SizedBox(width: 8),
              _buildDurationChip(provider, 50, '50m Flow'),
              const SizedBox(width: 8),
              _buildDurationChip(provider, 90, '90m Titan'),
              const SizedBox(width: 8),
              _buildDurationChip(provider, 180, '3h Grind'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                final started = await provider.startFocusLock();
                if (!started && !provider.isAccessibilityGranted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enable FocusGuard in Accessibility settings first!'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(LucideIcons.zap, size: 18),
              label: Text(
                'LOCK IN FOR ${provider.sessionDurationMinutes} MINUTES',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(FocusGuardProvider provider, int minutes, String label) {
    final isSelected = provider.sessionDurationMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setSessionDuration(minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalBanner(BuildContext context, FocusGuardProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.trophy, color: Color(0xFFF59E0B), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WHY ARE YOU FIGHTING DISTRACTIONS?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  provider.targetGoal,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFFA1A1AA)),
            tooltip: 'Edit Life Goal',
            onPressed: () => _showEditGoalDialog(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(FocusGuardProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            icon: LucideIcons.shieldAlert,
            title: 'Temptations Resisted',
            value: '${provider.temptationsResisted}',
            subtitle: 'Dopamine traps killed',
            accent: const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            icon: LucideIcons.clock3,
            title: 'Focus Time Saved',
            value: '${provider.minutesSaved}m',
            subtitle: 'Reclaimed for greatness',
            accent: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF71717A))),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(BuildContext context, FocusGuardProvider provider) {
    final allGranted = provider.isAccessibilityGranted && provider.hasUsageStats && provider.hasOverlay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allGranted ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allGranted ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle,
                size: 18,
                color: allGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              const Text(
                'Android OS Permissions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => provider.checkPermissions(),
                child: const Text('Refresh', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPermissionItem(
            name: 'Accessibility Service (Shorts/Reels detection)',
            isGranted: provider.isAccessibilityGranted,
            onTap: () => FocusGuardBridge.openAccessibilitySettings(),
          ),
          const Divider(color: Color(0xFF27272A), height: 16),
          _buildPermissionItem(
            name: 'Usage Access (App tracking)',
            isGranted: provider.hasUsageStats,
            onTap: () => FocusGuardBridge.openUsageStatsSettings(),
          ),
          const Divider(color: Color(0xFF27272A), height: 16),
          _buildPermissionItem(
            name: 'Draw Over Apps (Reality screen overlay)',
            isGranted: provider.hasOverlay,
            onTap: () => FocusGuardBridge.openOverlaySettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required String name,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Icon(
          isGranted ? LucideIcons.check : LucideIcons.x,
          size: 14,
          color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 12, color: Color(0xFFE4E4E7)),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(
            isGranted ? 'Enabled' : 'Enable',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, FocusGuardProvider provider) {
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          tileColor: const Color(0xFF18181B),
          leading: const Icon(LucideIcons.listFilter, color: Color(0xFF3B82F6)),
          title: const Text('Blocked Apps & Shorts Shield', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: Text('${provider.blockedApps.where((a) => a.isBlocked).length} apps blacklisted', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
          trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFF71717A)),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppBlacklistScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          tileColor: const Color(0xFF18181B),
          leading: const Icon(LucideIcons.eye, color: Color(0xFFF59E0B)),
          title: const Text('Test Reality Check Screen', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('See what will display when an impulse strikes', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
          trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFF71717A)),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RealityCheckScreen(
                  blockReason: 'Manual Test Run',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF059669)),
          ),
          tileColor: const Color(0xFF064E3B).withValues(alpha: 0.2),
          leading: const Icon(LucideIcons.gauge, color: Color(0xFF10B981)),
          title: const Text('Power & Data Diagnostics', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('Live battery (< 0.2%/24h) & zero data footprint telemetry', style: TextStyle(color: Color(0xFF34D399), fontSize: 11)),
          trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFF10B981)),
          onTap: () => ResourceTelemetryModal.show(context, feature: 'focus_guard'),
        ),
      ],
    );
  }
}
