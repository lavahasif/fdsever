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
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.volume2, size: 16, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📢 Tip for Clear Two-Way Audio',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
                SizedBox(height: 4),
                Text(
                  'Android blocks third-party apps from recording internal carrier lines. '
                  'For loud and clear recordings of both parties, tap Speakerphone on your call screen. '
                  'Our high-gain native acoustic booster captures the caller voice through the mic.',
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Background Auto-Record',
                          style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EVEN WHEN CLOSED',
                            style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'BroadcastReceiver automatically starts recording in background on phone calls',
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

          // VoIP auto-record switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'VoIP Call Recording',
                          style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        if (provider.voipCallActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CALL LIVE',
                              style: TextStyle(fontSize: 9, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Auto-records WhatsApp, IMO, Botim, Meet & other VoIP calls. Use speakerphone for the caller\'s voice.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Switch(
                value: provider.voipRecordEnabled,
                onChanged: (val) => provider.setVoipRecordEnabled(val),
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
            value: provider.gainMultiplier.clamp(1.0, 10.0),
            min: 1.0,
            max: 10.0,
            divisions: 90,
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
    final isSelected = provider.isTrackSelected(item.path);
    final isPlaying = provider.isTrackPlaying(item.path);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1F1F23) : const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isPlaying ? const Color(0xFF10B981) : const Color(0xFF3F3F46))
              : const Color(0xFF27272A),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play / Pause Circle Button
              GestureDetector(
                onTap: () => provider.togglePlay(item.path),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? const Color(0xFF10B981)
                        : const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: isPlaying ? Colors.black : const Color(0xFF10B981),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Mobile Number, Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.phoneNumber.isNotEmpty && item.phoneNumber != 'Unknown')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.phone, size: 10, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  item.phoneNumber,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(item.formattedDate, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        Text('•', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
                        Text(item.formattedSize, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📝 ${item.notes}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),

              // Open with External Media Player (VLC / System Music / Chooser)
              IconButton(
                icon: const Icon(LucideIcons.externalLink, size: 16, color: Color(0xFF10B981)),
                tooltip: 'Open with Player',
                onPressed: () async {
                  await provider.openWithExternalPlayer(item.path);
                },
              ),

              // Edit Metadata Action
              IconButton(
                icon: const Icon(LucideIcons.penLine, size: 16, color: Colors.white60),
                tooltip: 'Edit Mobile No / Notes',
                onPressed: () => _showEditMetadataDialog(context, provider, item),
              ),

              // Delete Action
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.white38),
                tooltip: 'Delete',
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

          // Audio Player progress scrubber bar when selected
          if (isSelected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF121214),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveTrackColor: const Color(0xFF27272A),
                      thumbColor: const Color(0xFF10B981),
                    ),
                    child: Slider(
                      value: provider.playbackDurationMs > 0
                          ? (provider.playbackPositionMs / provider.playbackDurationMs).clamp(0.0, 1.0)
                          : 0.0,
                      onChanged: (val) {
                        final targetMs = (val * provider.playbackDurationMs).toInt();
                        provider.seekAudio(targetMs);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CallRecorderProvider.formatMs(provider.playbackPositionMs),
                          style: const TextStyle(fontSize: 11, color: Colors.white60, fontFamily: 'monospace'),
                        ),
                        Text(
                          CallRecorderProvider.formatMs(provider.playbackDurationMs),
                          style: const TextStyle(fontSize: 11, color: Colors.white38, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditMetadataDialog(BuildContext context, CallRecorderProvider provider, CallRecordingItem item) {
    final phoneCtrl = TextEditingController(text: item.phoneNumber);
    final nameCtrl = TextEditingController(text: item.contactName);
    final notesCtrl = TextEditingController(text: item.notes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.penLine, size: 16, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            const Text(
              'Edit Call Metadata',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Caller / Receiver Mobile No:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '+1 234 567 8900',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(LucideIcons.phone, size: 16, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: const Color(0xFF27272A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Contact / Person Name:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. John Doe, Support, Client',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(LucideIcons.user, size: 16, color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF27272A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Notes / Description:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Discussed project delivery deadline',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF27272A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(LucideIcons.externalLink, size: 14, color: Color(0xFF10B981)),
            label: const Text('Open Player', style: TextStyle(color: Color(0xFF10B981), fontSize: 13)),
            onPressed: () => provider.openWithExternalPlayer(item.path),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.updateRecordingMetadata(
                path: item.path,
                phoneNumber: phoneCtrl.text.trim(),
                contactName: nameCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
              );
            },
            child: const Text('Save Metadata', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
