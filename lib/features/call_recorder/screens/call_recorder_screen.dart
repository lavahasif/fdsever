import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/call_recording_item.dart';
import '../providers/call_recorder_provider.dart';
import '../services/call_recorder_share_service.dart';

class CallRecorderScreen extends StatefulWidget {
  const CallRecorderScreen({super.key});

  @override
  State<CallRecorderScreen> createState() => _CallRecorderScreenState();
}

class _CallRecorderScreenState extends State<CallRecorderScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};

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
    _searchCtrl.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPaths.clear();
    });
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Runtime Permissions Warning Banner ────────────────────────────
            _buildPermissionBanner(context, provider),

            // ── Accessibility Service Banner (Prevents in-call audio silencing) ──
            _buildAccessibilityBanner(context, provider),

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
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isSelectionMode ? LucideIcons.checkSquare : LucideIcons.listFilter,
                        size: 18,
                        color: _isSelectionMode ? const Color(0xFF10B981) : Colors.white60,
                      ),
                      tooltip: _isSelectionMode ? 'Exit Selection Mode' : 'Multi-Select',
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = !_isSelectionMode;
                          if (!_isSelectionMode) _selectedPaths.clear();
                        });
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${provider.filteredRecordings.length}/${provider.recordings.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Search & Filter Direction Controls ─────────────────────────────
            _buildSearchAndFilters(context, provider),
            const SizedBox(height: 12),

            // ── Bulk Actions Bar (when selection mode active) ───────────────────
            if (_isSelectionMode) _buildBulkActionBar(context, provider),

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

  Widget _buildAccessibilityBanner(BuildContext context, CallRecorderProvider provider) {
    if (provider.accessibilityEnabled) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.shieldAlert, color: Color(0xFF818CF8), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Accessibility Service Recommended',
                  style: TextStyle(
                    color: Color(0xFFC7D2FE),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'On Android 10 to 15, the system automatically mutes third-party microphone access during cellular phone calls. '
            'Enabling the FDServer Accessibility Service prevents this system mute, allowing clear in-call sound recording.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await provider.openAccessibilitySettings();
              },
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: const Text('Enable in Accessibility Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
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
          const Divider(color: Color(0xFF27272A), height: 24),

          // Option 1: Speech Formant EQ & Volume Escalation (Non-Speaker Mode)
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
                          'Option 1: C++ Speech EQ & Vol Boost',
                          style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EARPIECE MODE',
                            style: TextStyle(fontSize: 9, color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Extracts telephone voice formants (1.8 kHz) + auto-sets in-call volume to 90% for clear earpiece chassis conduction without speakerphone.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Switch(
                value: provider.speechEqEnabled,
                onChanged: (val) {
                  provider.setSpeechEqEnabled(val);
                  provider.setVolumeEscalationEnabled(val);
                },
                activeThumbColor: const Color(0xFF3B82F6),
              ),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 24),

          // Option 2: Accessibility Service Recording Hook
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
                          'Option 2: Accessibility Priority Hook',
                          style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ANDROID 10-15',
                            style: TextStyle(fontSize: 9, color: Color(0xFFA78BFA), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Elevates recording thread privileges via Focus Guard Accessibility Service to prevent AudioPolicy mute during active calls.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Switch(
                value: provider.accessibilityHookEnabled,
                onChanged: (val) => provider.setAccessibilityHookEnabled(val),
                activeThumbColor: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search & Filter Direction Controls ─────────────────────────────
  Widget _buildSearchAndFilters(BuildContext context, CallRecorderProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (val) => provider.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Search by contact, phone number, note...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              prefixIcon: const Icon(LucideIcons.search, size: 16, color: Colors.white54),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 14, color: Colors.white54),
                      onPressed: () {
                        _searchCtrl.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Filter direction chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', 'all', provider),
              const SizedBox(width: 6),
              _buildFilterChip('Incoming', 'incoming', provider, icon: LucideIcons.phoneIncoming),
              const SizedBox(width: 6),
              _buildFilterChip('Outgoing', 'outgoing', provider, icon: LucideIcons.phoneOutgoing),
              const SizedBox(width: 6),
              _buildFilterChip('VoIP', 'voip', provider, icon: LucideIcons.globe),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String directionKey, CallRecorderProvider provider, {IconData? icon}) {
    final isSelected = provider.filterDirection == directionKey;
    return GestureDetector(
      onTap: () => provider.setFilterDirection(directionKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF27272A),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? const Color(0xFF10B981) : Colors.white60),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF10B981) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shadcn Styled Bulk Action Bar ──────────────────────────────────
  Widget _buildBulkActionBar(BuildContext context, CallRecorderProvider provider) {
    final filtered = provider.filteredRecordings;
    final allSelected = filtered.isNotEmpty && _selectedPaths.length == filtered.length;
    final count = _selectedPaths.length;
    final selectedItems = filtered.where((r) => _selectedPaths.contains(r.path)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (allSelected) {
                  _selectedPaths.clear();
                } else {
                  _selectedPaths.addAll(filtered.map((r) => r.path));
                }
              });
            },
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: allSelected ? const Color(0xFF10B981) : const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: allSelected ? const Color(0xFF10B981) : const Color(0xFF3F3F46),
                    ),
                  ),
                  child: allSelected
                      ? const Icon(LucideIcons.check, size: 15, color: Colors.black)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  allSelected ? 'All' : 'Select All',
                  style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Share Selected ($count)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.share2, color: Color(0xFF38BDF8), size: 18),
            onPressed: count == 0 ? null : () => CallRecorderShareService.shareBulk(selectedItems),
          ),
          IconButton(
            tooltip: 'WhatsApp Selected ($count)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.messageCircle, color: Color(0xFF22C55E), size: 19),
            onPressed: count == 0 ? null : () => CallRecorderShareService.shareBulkToWhatsApp(selectedItems),
          ),
          IconButton(
            tooltip: 'Delete Selected ($count)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 18),
            onPressed: count == 0 ? null : () => _showBulkDeleteConfirmation(context, provider, count),
          ),
          IconButton(
            tooltip: 'Exit Selection',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.x, color: Color(0xFFA1A1AA), size: 18),
            onPressed: _exitSelectionMode,
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteConfirmation(BuildContext context, CallRecorderProvider provider, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text('Delete Selected Call Recordings?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to permanently delete $count selected recording(s) and their audio files?',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.bulkDeleteRecordings(_selectedPaths.toList());
              _exitSelectionMode();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList(BuildContext context, CallRecorderProvider provider) {
    final items = provider.filteredRecordings;

    if (items.isEmpty) {
      final isFiltered = provider.searchQuery.isNotEmpty || provider.filterDirection != 'all';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          children: [
            Icon(isFiltered ? LucideIcons.searchX : LucideIcons.fileAudio, size: 36, color: Colors.white30),
            const SizedBox(height: 12),
            Text(
              isFiltered ? 'No matching recordings found' : 'No call recordings yet',
              style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered ? 'Try adjusting your search query or direction filter' : 'Recordings will appear here in WAV format',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981), width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(LucideIcons.rotateCcw, size: 14),
                label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  _searchCtrl.clear();
                  provider.clearFilters();
                },
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildRecordingItem(context, provider, item);
      },
    );
  }

  Widget _buildRecordingItem(BuildContext context, CallRecorderProvider provider, CallRecordingItem item) {
    final isTrackActive = provider.isTrackSelected(item.path);
    final isPlaying = provider.isTrackPlaying(item.path);
    final isChecked = _selectedPaths.contains(item.path);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedPaths.add(item.path);
        });
      },
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (_selectedPaths.contains(item.path)) {
                  _selectedPaths.remove(item.path);
                  if (_selectedPaths.isEmpty) _isSelectionMode = false;
                } else {
                  _selectedPaths.add(item.path);
                }
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isChecked
              ? const Color(0xFF10B981).withValues(alpha: 0.1)
              : (isTrackActive ? const Color(0xFF1F1F23) : const Color(0xFF18181B)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChecked
                ? const Color(0xFF10B981)
                : (isTrackActive
                    ? (isPlaying ? const Color(0xFF10B981) : const Color(0xFF3F3F46))
                    : const Color(0xFF27272A)),
            width: (isChecked || isTrackActive) ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Multi-select Checkbox
                if (_isSelectionMode) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedPaths.contains(item.path)) {
                          _selectedPaths.remove(item.path);
                          if (_selectedPaths.isEmpty) _isSelectionMode = false;
                        } else {
                          _selectedPaths.add(item.path);
                        }
                      });
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isChecked ? const Color(0xFF10B981) : const Color(0xFF09090B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isChecked ? const Color(0xFF10B981) : const Color(0xFF3F3F46),
                        ),
                      ),
                      child: isChecked ? const Icon(LucideIcons.check, size: 15, color: Colors.black) : null,
                    ),
                  ),
                ],

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
                          if (item.directionLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: item.isIncoming
                                    ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                                    : item.isOutgoing
                                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.isIncoming
                                        ? LucideIcons.phoneIncoming
                                        : item.isOutgoing
                                            ? LucideIcons.phoneOutgoing
                                            : LucideIcons.globe,
                                    size: 10,
                                    color: item.isIncoming
                                        ? const Color(0xFF06B6D4)
                                        : item.isOutgoing
                                            ? const Color(0xFF8B5CF6)
                                            : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.directionLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.isIncoming
                                          ? const Color(0xFF06B6D4)
                                          : item.isOutgoing
                                              ? const Color(0xFF8B5CF6)
                                              : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

                // Share Button (System Share Sheet)
                IconButton(
                  icon: const Icon(LucideIcons.share2, size: 16, color: Color(0xFF38BDF8)),
                  tooltip: 'Share',
                  onPressed: () => CallRecorderShareService.shareSingle(item),
                ),

                // WhatsApp Direct Share Button
                IconButton(
                  icon: const Icon(LucideIcons.messageCircle, size: 16, color: Color(0xFF22C55E)),
                  tooltip: 'Share to WhatsApp',
                  onPressed: () => CallRecorderShareService.shareSingleToWhatsApp(item),
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
            if (isTrackActive) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF121214),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // Play / Pause / Seek / Stop controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(LucideIcons.rotateCcw, size: 16, color: Colors.white70),
                          tooltip: 'Rewind 10s',
                          onPressed: provider.playbackDurationMs > 0
                              ? () => provider.seekAudio(max(0, provider.playbackPositionMs - 10000))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPlaying ? const Color(0xFF047857) : const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(
                            isPlaying ? LucideIcons.pause : LucideIcons.play,
                            size: 15,
                          ),
                          label: Text(
                            isPlaying ? 'Pause' : 'Play',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => provider.togglePlay(item.path),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(LucideIcons.rotateCw, size: 16, color: Colors.white70),
                          tooltip: 'Forward 10s',
                          onPressed: provider.playbackDurationMs > 0
                              ? () => provider.seekAudio(min(provider.playbackDurationMs, provider.playbackPositionMs + 10000))
                              : null,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(LucideIcons.square, size: 15, color: Color(0xFFEF4444)),
                          tooltip: 'Stop',
                          onPressed: () => provider.stopAudio(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

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
