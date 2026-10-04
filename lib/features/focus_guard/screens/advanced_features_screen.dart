import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/advanced_feature.dart';
import '../providers/focus_guard_provider.dart';
import '../services/native_monitor_bridge.dart';

/// Hidden advanced features settings screen.
/// Provides runtime toggles for all 60 features organized by category,
/// with battery impact indicators and real-time native engine stats.
class AdvancedFeaturesScreen extends StatefulWidget {
  const AdvancedFeaturesScreen({super.key});

  @override
  State<AdvancedFeaturesScreen> createState() => _AdvancedFeaturesScreenState();
}

class _AdvancedFeaturesScreenState extends State<AdvancedFeaturesScreen> {
  Map<String, dynamic> _nativeStats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await NativeMonitorBridge.getStats();
    if (mounted) {
      setState(() {
        _nativeStats = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusGuardProvider>();
    final featuresByCategory = getFeaturesByCategory();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        title: const Text(
          '⚙️ Advanced Features',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF71717A)),
            onPressed: _loadStats,
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── NDK Engine Status Card ──────────────────────────────────
          _buildEngineStatusCard(),
          const SizedBox(height: 20),

          // ─── Feature Categories ──────────────────────────────────────
          ...featuresByCategory.entries.map((entry) =>
            _buildCategorySection(
              category: entry.key,
              features: entry.value,
              provider: provider,
            ),
          ),

          const SizedBox(height: 40),
          // ─── Danger Zone ─────────────────────────────────────────────
          _buildDangerZone(provider),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildEngineStatusCard() {
    final isRunning = _nativeStats['running'] == true;
    final totalPolls = _nativeStats['totalPolls'] ?? 0;
    final totalBlocks = _nativeStats['totalBlocks'] ?? 0;
    final momentum = _nativeStats['momentumScore'] ?? 100;
    final actualPoll = _nativeStats['actualPollMs'] ?? 0;
    final screenOn = _nativeStats['screenOn'] == true;
    final battery = _nativeStats['batteryLevel'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRunning
              ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
              : [const Color(0xFF7F1D1D), const Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  boxShadow: [
                    BoxShadow(
                      color: (isRunning ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                          .withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'NDK Engine ${isRunning ? "ACTIVE" : "INACTIVE"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'C++ Thread',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (isRunning) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _statChip('Polls', '$totalPolls', const Color(0xFF3B82F6)),
                _statChip('Blocks', '$totalBlocks', const Color(0xFFEF4444)),
                _statChip('Momentum', '$momentum%', _momentumColor(momentum)),
                _statChip('Poll', '${actualPoll}ms', const Color(0xFF8B5CF6)),
                _statChip('Screen', screenOn ? 'ON' : 'OFF', const Color(0xFFF59E0B)),
                _statChip('Battery', '$battery%', const Color(0xFF10B981)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _momentumColor(dynamic score) {
    final s = (score is int) ? score : 50;
    if (s >= 80) return const Color(0xFF10B981);
    if (s >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required String category,
    required List<AdvancedFeature> features,
    required FocusGuardProvider provider,
  }) {
    final icon = categoryIcons[category] ?? '⚙️';
    final desc = categoryDescriptions[category] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        if (desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2, bottom: 8),
            child: Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ),
        ...features.map((f) => _buildFeatureToggle(f, provider)),
      ],
    );
  }

  Widget _buildFeatureToggle(AdvancedFeature feature, FocusGuardProvider provider) {
    final isEnabled = provider.isFeatureEnabled(feature.key);
    final batteryDot = _batteryImpactDot(feature.batteryImpact);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF27272A)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isEnabled
                ? const Color(0xFF4F46E5).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            feature.isNative ? Icons.memory : Icons.settings,
            size: 14,
            color: isEnabled
                ? const Color(0xFF818CF8)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                feature.name,
                style: TextStyle(
                  color: isEnabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            batteryDot,
            if (feature.isNative)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NDK',
                  style: TextStyle(
                    color: Color(0xFFA78BFA),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          feature.description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (val) {
            provider.setFeatureEnabled(feature.key, val);
            // Sync native flags for NDK-level features
            if (feature.isNative) {
              NativeMonitorBridge.setFeatureFlag(feature.key, val);
            }
          },
          activeThumbColor: const Color(0xFF818CF8),
          activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
          inactiveThumbColor: const Color(0xFF52525B),
          inactiveTrackColor: const Color(0xFF27272A),
        ),
      ),
    );
  }

  Widget _batteryImpactDot(int impact) {
    final color = switch (impact) {
      0 => const Color(0xFF10B981),
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFFEF4444),
      _ => const Color(0xFFEF4444),
    };
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
      ),
    );
  }

  Widget _buildDangerZone(FocusGuardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF450A0A).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ Danger Zone',
            style: TextStyle(
              color: Color(0xFFFCA5A5),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reset all feature flags to defaults. This cannot be undone.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                provider.resetAllFeatureFlags();
                _loadStats();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All features reset to defaults'),
                    backgroundColor: Color(0xFF18181B),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Reset All Features',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
