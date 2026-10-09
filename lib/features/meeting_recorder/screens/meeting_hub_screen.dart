import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/meeting_recording.dart';
import '../providers/meeting_recorder_provider.dart';
import '../providers/meeting_schedule_provider.dart';
import '../services/gemini_voice_service.dart';
import '../services/meeting_share_service.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/recording_filter_sheet.dart';
import '../widgets/recording_list_tile.dart';
import '../widgets/schedule_card.dart';
import 'schedule_editor_screen.dart';

class MeetingHubScreen extends StatefulWidget {
  const MeetingHubScreen({super.key});

  @override
  State<MeetingHubScreen> createState() => _MeetingHubScreenState();
}

class _MeetingHubScreenState extends State<MeetingHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<MeetingRecorderProvider>();
    final scheduler = context.watch<MeetingScheduleProvider>();
    final currentPlayingRec = recorder.recordings
        .where((r) => r.filePath == recorder.currentlyPlayingPath)
        .firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Shadcn deep background
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B), // Shadcn surface
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: const Icon(LucideIcons.mic, color: Color(0xFF38BDF8), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Meeting & Refocus Hub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gemini AI Voice Settings',
            icon: const Icon(LucideIcons.sparkles, size: 18, color: Color(0xFFA855F7)),
            onPressed: () => _showGeminiApiKeyDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF71717A),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.mic, size: 16),
                  const SizedBox(width: 8),
                  const Text('Recorder & Library'),
                  if (recorder.isRecording) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.bellRing, size: 16),
                  const SizedBox(width: 8),
                  Text('Focus Alarms (${scheduler.schedules.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildRecorderTab(context, recorder),
              _buildSchedulesTab(context, scheduler),
            ],
          ),

          // Mini Player floating at bottom when playing audio
          if (recorder.currentlyPlayingPath.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: MiniPlayerBar(
                title: currentPlayingRec?.title ?? 'Meeting Audio',
                isPlaying: recorder.isPlaying,
                currentPositionMs: recorder.playerCurrentMs,
                durationMs: recorder.playerDurationMs,
                onPlayPause: () {
                  if (recorder.isPlaying) {
                    recorder.pausePlayer();
                  } else {
                    recorder.playAudio(recorder.currentlyPlayingPath);
                  }
                },
                onStop: () => recorder.stopPlayer(),
                onSeek: (pos) => recorder.seekPlayer(pos),
                onShare: currentPlayingRec != null
                    ? () => MeetingShareService.shareSingle(currentPlayingRec)
                    : null,
                onWhatsAppShare: currentPlayingRec != null
                    ? () => MeetingShareService.shareSingleToWhatsApp(currentPlayingRec)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  // --- Tab 1: Recorder & Library ---
  Widget _buildRecorderTab(BuildContext context, MeetingRecorderProvider recorder) {
    final recordings = recorder.recordings;

    return RefreshIndicator(
      onRefresh: () => recorder.loadRecordings(),
      color: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF18181B),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          (recorder.currentlyPlayingPath.isNotEmpty ? 130 : 24) + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // 1. Instant Trigger Ready Card
          _buildTriggerStatusCard(recorder),
          const SizedBox(height: 16),

          // 2. Active Recording Banner or Start Button
          if (recorder.isRecording)
            _buildActiveRecordingBanner(recorder)
          else
            _buildManualRecordButton(recorder),

          const SizedBox(height: 20),

          // 3. Search Bar, Filter and Select Mode Toolbar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (val) {
                    recorder.setFilter(recorder.filter.copyWith(searchQuery: val));
                  },
                  decoration: InputDecoration(
                    hintText: 'Search title, notes, #tags...',
                    hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                    prefixIcon: const Icon(LucideIcons.search, color: Color(0xFF71717A), size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFFA1A1AA)),
                            onPressed: () {
                              _searchCtrl.clear();
                              recorder.setFilter(recorder.filter.copyWith(searchQuery: ''));
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF18181B),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter Sheet Button
              Stack(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF27272A)),
                      ),
                    ),
                    icon: const Icon(LucideIcons.slidersHorizontal, color: Color(0xFF38BDF8), size: 19),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => RecordingFilterSheet(
                          currentFilter: recorder.filter,
                          onApply: (f) => recorder.setFilter(f),
                        ),
                      );
                    },
                  ),
                  if (recorder.filter.isFilteringActive)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),

              // Multi-select toggle button
              IconButton(
                tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Multiple',
                style: IconButton.styleFrom(
                  backgroundColor: _isSelectionMode
                      ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                      : const Color(0xFF18181B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _isSelectionMode ? const Color(0xFF38BDF8) : const Color(0xFF27272A),
                    ),
                  ),
                ),
                icon: Icon(
                  _isSelectionMode ? LucideIcons.checkCheck : LucideIcons.listChecks,
                  color: _isSelectionMode ? const Color(0xFF38BDF8) : const Color(0xFFA1A1AA),
                  size: 19,
                ),
                onPressed: () {
                  if (_isSelectionMode) {
                    _exitSelectionMode();
                  } else {
                    setState(() => _isSelectionMode = true);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Bulk Action Bar (when in Multi-Select Mode)
          if (_isSelectionMode) ...[
            _buildBulkActionBar(recordings, recorder),
            const SizedBox(height: 14),
          ] else ...[
            // Header with count & sort info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECORDINGS (${recordings.length})',
                  style: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (recorder.filter.isFilteringActive)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      recorder.resetFilter();
                    },
                    child: const Text(
                      'Clear filters',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 5. Recordings list
          if (recordings.isEmpty)
            _buildEmptyState()
          else
            ...recordings.map((rec) {
              final isPlayingThis = recorder.currentlyPlayingPath == rec.filePath && recorder.isPlaying;
              final isTrackActiveThis = recorder.currentlyPlayingPath == rec.filePath;
              final isSelectedThis = _selectedIds.contains(rec.id);

              return RecordingListTile(
                recording: rec,
                isPlaying: isPlayingThis,
                isTrackActive: isTrackActiveThis,
                playbackPositionMs: isTrackActiveThis ? recorder.playerCurrentMs : 0,
                playbackDurationMs: isTrackActiveThis && recorder.playerDurationMs > 0
                    ? recorder.playerDurationMs
                    : rec.durationMs,
                onSeek: (ms) => recorder.seekPlayer(ms),
                onStop: () => recorder.stopPlayer(),
                isSelectionMode: _isSelectionMode,
                isSelected: isSelectedThis,
                onPlayToggle: () => recorder.togglePlayAudio(rec.filePath),
                onToggleSelect: () {
                  setState(() {
                    if (_selectedIds.contains(rec.id)) {
                      _selectedIds.remove(rec.id);
                      if (_selectedIds.isEmpty) _isSelectionMode = false;
                    } else {
                      _selectedIds.add(rec.id);
                    }
                  });
                },
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIds.add(rec.id);
                  });
                },
                onRename: (newTitle) => recorder.renameRecording(rec.id, newTitle),
                onNotesSaved: (notes, tags) => recorder.updateNotesAndTags(rec.id, notes, tags),
                onDelete: () => recorder.deleteRecording(rec.id),
                onShare: () => MeetingShareService.shareSingle(rec),
                onWhatsAppShare: () => MeetingShareService.shareSingleToWhatsApp(rec),
                onGeminiExtract: () => _handleGeminiExtract(context, rec, recorder),
                onGeminiChatShare: () => GeminiVoiceService.shareToGeminiChat(rec),
                onConfigureGeminiKey: () => _showGeminiApiKeyDialog(context),
              );
            }),
        ],
      ),
    );
  }

  // --- Shadcn Styled Bulk Action Bar ---
  Widget _buildBulkActionBar(List<MeetingRecording> recordings, MeetingRecorderProvider recorder) {
    final allSelected = recordings.isNotEmpty && _selectedIds.length == recordings.length;
    final count = _selectedIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Shadcn Card surface
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Select All Checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                if (allSelected) {
                  _selectedIds.clear();
                } else {
                  _selectedIds.addAll(recordings.map((r) => r.id));
                }
              });
            },
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: allSelected ? const Color(0xFF2563EB) : const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: allSelected ? const Color(0xFF38BDF8) : const Color(0xFF3F3F46),
                    ),
                  ),
                  child: allSelected
                      ? const Icon(LucideIcons.check, size: 15, color: Colors.white)
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

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
            ),
            child: Text(
              '$count selected',
              style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),

          const Spacer(),

          // Bulk Share Button
          IconButton(
            tooltip: 'Share Selected ($count)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.share2, color: Color(0xFF38BDF8), size: 18),
            onPressed: count == 0
                ? null
                : () {
                    final selected = recordings.where((r) => _selectedIds.contains(r.id)).toList();
                    MeetingShareService.shareBulk(selected);
                  },
          ),

          // Bulk WhatsApp Button
          IconButton(
            tooltip: 'WhatsApp Selected ($count)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.messageCircle, color: Color(0xFF22C55E), size: 19),
            onPressed: count == 0
                ? null
                : () {
                    final selected = recordings.where((r) => _selectedIds.contains(r.id)).toList();
                    MeetingShareService.shareBulkToWhatsApp(selected);
                  },
          ),

          // Bulk Gemini Chat Share Button
          IconButton(
            tooltip: 'Share to Gemini Chat',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.sparkles, color: Color(0xFFA855F7), size: 18),
            onPressed: count == 0
                ? null
                : () {
                    final selected = recordings.where((r) => _selectedIds.contains(r.id)).toList();
                    if (selected.isNotEmpty) {
                      GeminiVoiceService.shareToGeminiChat(selected.first);
                    }
                  },
          ),

          // Bulk Delete Button
          IconButton(
            tooltip: 'Delete Selected ($count)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 18),
            onPressed: count == 0
                ? null
                : () => _showBulkDeleteConfirmation(context, recorder, count),
          ),

          // Close Selection Mode
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

  void _showBulkDeleteConfirmation(BuildContext context, MeetingRecorderProvider recorder, int count) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text('Delete Selected Recordings?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to permanently delete $count selected recording(s) and their audio files?',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final idsToDelete = List<int>.from(_selectedIds);
              for (final id in idsToDelete) {
                await recorder.deleteRecording(id);
              }
              _exitSelectionMode();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGeminiExtract(
    BuildContext context,
    MeetingRecording rec,
    MeetingRecorderProvider recorder,
  ) async {
    final hasKey = await GeminiVoiceService.hasApiKey();
    if (!hasKey) {
      if (!context.mounted) return;
      _showGeminiApiKeyDialog(
        context,
        onSaved: () => _handleGeminiExtract(context, rec, recorder),
      );
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gemini AI Analyzing Voice...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Extracting topic tags & key takeaways',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await GeminiVoiceService.extractVoiceInfo(filePath: rec.filePath);
      final newTags = result.formattedTags;
      final newNotes = result.formattedNotes;

      await recorder.updateNotesAndTags(rec.id, newNotes, newTags);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF18181B),
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: Color(0xFF22C55E), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Extracted ${result.tags.length} topic tags with Gemini!',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF450A0A),
            content: Text(
              'Gemini error: ${e.toString().replaceAll("Exception: ", "")}',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
            ),
            action: SnackBarAction(
              label: 'API Key',
              textColor: const Color(0xFF38BDF8),
              onPressed: () => _showGeminiApiKeyDialog(context),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _showGeminiApiKeyDialog(BuildContext context, {VoidCallback? onSaved}) async {
    final currentKey = await GeminiVoiceService.getApiKey() ?? '';
    final ctrl = TextEditingController(text: currentKey);
    bool obscure = true;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.sparkles, size: 18, color: Color(0xFFA855F7)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Gemini AI Voice Settings',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connect Google Gemini directly to extract topic tags, decisions, and action items from meeting voice audio.',
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  const Text('Google Gemini API Key:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'AIzaSy...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF09090B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF27272A)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                          size: 16,
                          color: Colors.white60,
                        ),
                        onPressed: () => setModalState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => GeminiVoiceService.openApiKeyPortal(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.externalLink, size: 14, color: Color(0xFF38BDF8)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Get free Gemini API Key at Google AI Studio',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final key = ctrl.text.trim();
                  await GeminiVoiceService.saveApiKey(key);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (key.isNotEmpty) {
                    onSaved?.call();
                  }
                },
                child: const Text('Save Key', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTriggerStatusCard(MeetingRecorderProvider recorder) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recorder.isStandby ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF27272A),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: recorder.isStandby
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF27272A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.power,
                  color: recorder.isStandby ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instant Capture Standby',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      recorder.isStandby
                          ? 'Active: Press Power ×3 or tap notification'
                          : 'Turn on to arm Power ×3 and notification tap',
                      style: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: recorder.isStandby,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) => recorder.toggleStandby(val),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: Color(0xFF38BDF8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Power ×3 works even when phone is locked. Stop button is strictly on the notification.',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRecordingBanner(MeetingRecorderProvider recorder) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF450A0A), // Red 950
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'LIVE RECORDING',
                style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                recorder.formattedElapsed,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Amplitude waveform indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(14, (index) {
              final normAmp = (recorder.latestAmplitude / 2500).clamp(0.1, 1.0);
              final barHeight = 8.0 + (sin(index * 0.7) * 6.0 + 8.0) * normAmp;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 4,
                height: barHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(LucideIcons.square, size: 16, color: Colors.white),
              label: const Text(
                'Stop Recording',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () => recorder.stopRecordingManual(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualRecordButton(MeetingRecorderProvider recorder) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(LucideIcons.disc, color: Colors.white, size: 18),
        label: const Text(
          'Start Meeting Recording',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onPressed: () => recorder.startRecordingManual(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF18181B),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.micOff, size: 36, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          const Text(
            'No meeting recordings found',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start an instant recording or press the power button 3 times.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --- Tab 2: Focus Alarms ---
  Widget _buildSchedulesTab(BuildContext context, MeetingScheduleProvider scheduler) {
    final schedules = scheduler.schedules;

    return RefreshIndicator(
      onRefresh: () => scheduler.loadSchedules(),
      color: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF18181B),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF09090B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.sparkles, color: Color(0xFFF59E0B), size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Decoupled Focus Schedules',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rings at start, then triggers N in-between nudges evenly across the meeting window.',
                        style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Add Schedule Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Add Focus Schedule',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScheduleEditorScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Schedules List
          if (schedules.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(LucideIcons.bellOff, size: 36, color: Color(0xFF64748B)),
                  SizedBox(height: 12),
                  Text(
                    'No focus schedules configured',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create one to stay attentive during long discussions.',
                    style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...schedules.map(
              (s) => ScheduleCard(
                schedule: s,
                onToggle: (val) => scheduler.toggleSchedule(s.id, val),
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ScheduleEditorScreen(existingSchedule: s)),
                  );
                },
                onDelete: () => scheduler.deleteSchedule(s.id),
                onTestAlarm: () {
                  scheduler.previewAlarm(
                    soundMode: s.startAlarmMode,
                    ringtoneUri: s.ringtoneUri,
                    volume: s.volume,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
