import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/call_recording_item.dart';
import '../providers/call_recorder_provider.dart';

class CallRecorderScreen extends StatefulWidget {
  const CallRecorderScreen({super.key});

  @override
  State<CallRecorderScreen> createState() => _CallRecorderScreenState();
}

class _CallRecorderScreenState extends State<CallRecorderScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CallRecorderProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.phoneCall, color: Color(0xFF10B981), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Call Voice Recorder',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18, color: Colors.white70),
            onPressed: () => provider.refreshRecordings(),
            tooltip: 'Refresh Recordings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Runtime Permissions Warning Banner ────────────────────────────
            _buildPermissionBanner(context, provider),

            // ── Live Recorder Status Card ──────────────────────────────────────
            _buildLiveStatusCard(context, provider),
            const SizedBox(height: 16),

            // ── Speakerphone Acoustic Clarity Advisory ─────────────────────────
            _buildSpeakerphoneTipCard(),
            const SizedBox(height: 16),

            // ── Configuration & Gain Boost Controls ───────────────────────────
            _buildSettingsCard(context, provider),
            const SizedBox(height: 24),

            // ── Recordings Header ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.disc, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    const Text(
                      'Recorded Calls & Voice Memos',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${provider.recordings.length} files',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Recordings List ───────────────────────────────────────────────
            _buildRecordingsList(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context, CallRecorderProvider provider) {
    if (provider.allPermissionsGranted) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF451A03).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Microphone & Phone Permissions Required',
                  style: TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Android requires microphone access to record voice audio and phone state permission to detect cellular calls.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => provider.requestPermissions(),
              icon: const Icon(LucideIcons.shieldCheck, size: 16),
              label: const Text('Grant Permissions Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard(BuildContext context, CallRecorderProvider provider) {
    final isRec = provider.isRecording;
    final isCallActive = provider.callState == 'OFFHOOK';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRec
              ? [const Color(0xFF1E1015), const Color(0xFF18181B)]
              : [const Color(0xFF18181B), const Color(0xFF141416)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRec ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFF27272A),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cellular call state badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCallActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCallActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCallActive ? LucideIcons.phoneForwarded : LucideIcons.phone,
                      size: 13,
                      color: isCallActive ? const Color(0xFF10B981) : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCallActive ? 'CALL IN PROGRESS' : 'PHONE IDLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCallActive ? const Color(0xFF10B981) : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),

              // Recording state indicator
              if (isRec)
                FadeTransition(
                  opacity: _pulseController,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: Color(0xFFEF4444)),
                        SizedBox(width: 6),
                        Text(
                          'RECORDING LIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Duration Display
          Text(
            provider.formattedDuration,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              provider.statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: provider.statusMessage.contains('unavailable') ||
                       provider.statusMessage.contains('denied') ||
                       provider.statusMessage.contains('interrupted') ||
                       provider.statusMessage.contains('silenced')
                    ? const Color(0xFFF59E0B)
                    : (isRec ? const Color(0xFF10B981) : Colors.white60),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Audio Waveform Simulation Bar
          _buildWaveformBar(provider),
          const SizedBox(height: 24),

          // Main Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRec ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () async {
                if (isRec) {
                  await provider.stopManualRecording();
                } else {
                  await provider.startManualRecording();
                }
              },
              icon: Icon(isRec ? LucideIcons.square : LucideIcons.mic, size: 20),
              label: Text(
                isRec ? 'Stop Recording' : 'Start Recording Now',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformBar(CallRecorderProvider provider) {
    final isRec = provider.isRecording;
    final amp = provider.latestAmplitude;
    final norm = min(1.0, max(0.1, amp / 20000.0));

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(24, (i) {
          final heightFactor = isRec ? ((sin(i * 0.5 + norm * 5) + 1.0) / 2.0 * norm).clamp(0.15, 1.0) : 0.15;
          return Container(
            width: 3.5,
            height: 32 * heightFactor,
            decoration: BoxDecoration(
              color: isRec
                  ? (heightFactor > 0.6 ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                  : const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSpeakerphoneTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.volume2, size: 16, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Two-Way Clarity Advisory',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                ),
                SizedBox(height: 4),
                Text(
                  'On Android 10–16, direct telephony line taps are restricted by Google. Turning on Speakerphone or holding the phone naturally allows our high-gain acoustic engine to capture both your voice and the caller with optimal balance.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, CallRecorderProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recording Configuration',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 14),

          // Auto-record switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Record on Phone Call',
                      style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Automatically starts when call connects, stops on hangup',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Switch(
                value: provider.autoRecordEnabled,
                onChanged: (val) => provider.setAutoRecordEnabled(val),
                activeThumbColor: const Color(0xFF10B981),
              ),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 24),

          // Receiver acoustic gain boost slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Receiver Audio Gain Boost',
                style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${provider.gainMultiplier.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Amplifies faint acoustic incoming speaker sound without clipping near voice',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          Slider(
            value: provider.gainMultiplier,
            min: 1.0,
            max: 3.0,
            divisions: 20,
            label: '${provider.gainMultiplier.toStringAsFixed(1)}x',
            activeColor: const Color(0xFF10B981),
            inactiveColor: const Color(0xFF27272A),
            onChanged: (val) => provider.setGainMultiplier(val),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList(BuildContext context, CallRecorderProvider provider) {
    if (provider.recordings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: const Column(
          children: [
            Icon(LucideIcons.fileAudio, size: 36, color: Colors.white30),
            SizedBox(height: 12),
            Text(
              'No call recordings yet',
              style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'Recordings will appear here in WAV format',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.recordings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = provider.recordings[index];
        return _buildRecordingItem(context, provider, item);
      },
    );
  }

  Widget _buildRecordingItem(BuildContext context, CallRecorderProvider provider, CallRecordingItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.volume2, color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(item.formattedDate, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    const SizedBox(width: 10),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text(item.formattedSize, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.white38),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF18181B),
                  title: const Text('Delete Recording?', style: TextStyle(color: Colors.white, fontSize: 16)),
                  content: Text('Are you sure you want to delete ${item.name}?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await provider.deleteRecording(item.path);
              }
            },
          ),
        ],
      ),
    );
  }
}
