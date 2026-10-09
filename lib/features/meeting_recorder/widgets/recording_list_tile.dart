import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/meeting_recording.dart';
import 'rename_dialog.dart';

class RecordingListTile extends StatelessWidget {
  final MeetingRecording recording;
  final bool isPlaying;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onPlayToggle;
  final ValueChanged<String> onRename;
  final Function(String notes, String tags) onNotesSaved;
  final VoidCallback onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onWhatsAppShare;
  final VoidCallback? onGeminiExtract;
  final VoidCallback? onGeminiChatShare;
  final VoidCallback? onConfigureGeminiKey;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const RecordingListTile({
    super.key,
    required this.recording,
    required this.isPlaying,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onPlayToggle,
    required this.onRename,
    required this.onNotesSaved,
    required this.onDelete,
    this.onShare,
    this.onWhatsAppShare,
    this.onGeminiExtract,
    this.onGeminiChatShare,
    this.onConfigureGeminiKey,
    this.onToggleSelect,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (isSelectionMode) {
          onToggleSelect?.call();
        } else {
          onPlayToggle();
        }
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E293B).withValues(alpha: 0.7)
              : const Color(0xFF18181B), // Shadcn Card/Surface
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : (isPlaying ? const Color(0xFF2563EB) : const Color(0xFF27272A)),
            width: isSelected || isPlaying ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Multi-select Checkbox (if selection mode is active)
                  if (isSelectionMode) ...[
                    GestureDetector(
                      onTap: onToggleSelect,
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF09090B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF3F3F46),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ] else ...[
                    // Play / Pause round button
                    GestureDetector(
                      onTap: onPlayToggle,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPlaying ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                          boxShadow: isPlaying
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isPlaying ? LucideIcons.pause : LucideIcons.play,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Title and metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                recording.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isSelectionMode)
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => RenameDialog(
                                      currentTitle: recording.title,
                                      onSaved: onRename,
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(LucideIcons.pencil, size: 14, color: Color(0xFF71717A)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              recording.formattedDate,
                              style: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            _buildTriggerBadge(recording.triggerLabel),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions for single mode
                  if (!isSelectionMode) ...[
                    // Gemini AI Extraction Button
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Extract Voice with Gemini AI',
                      icon: const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFFA855F7)),
                      onPressed: onGeminiExtract,
                    ),

                    // Direct Share Button
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Share Audio',
                      icon: const Icon(LucideIcons.share2, size: 16, color: Color(0xFF38BDF8)),
                      onPressed: onShare,
                    ),

                    // Direct WhatsApp Share Button
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Share to WhatsApp',
                      icon: const Icon(LucideIcons.messageCircle, size: 18, color: Color(0xFF22C55E)),
                      onPressed: onWhatsAppShare,
                    ),

                    // More Popup Menu
                    PopupMenuButton<String>(
                      icon: const Icon(LucideIcons.ellipsisVertical, color: Color(0xFF71717A), size: 16),
                      color: const Color(0xFF18181B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF27272A)),
                      ),
                      onSelected: (val) {
                        if (val == 'play') {
                          onPlayToggle();
                        } else if (val == 'gemini_extract') {
                          onGeminiExtract?.call();
                        } else if (val == 'gemini_chat') {
                          onGeminiChatShare?.call();
                        } else if (val == 'gemini_key') {
                          onConfigureGeminiKey?.call();
                        } else if (val == 'share') {
                          onShare?.call();
                        } else if (val == 'whatsapp') {
                          onWhatsAppShare?.call();
                        } else if (val == 'rename') {
                          showDialog(
                            context: context,
                            builder: (_) => RenameDialog(
                              currentTitle: recording.title,
                              onSaved: onRename,
                            ),
                          );
                        } else if (val == 'notes') {
                          _showNotesDialog(context);
                        } else if (val == 'delete') {
                          _showDeleteConfirmation(context);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'play',
                          child: Row(
                            children: [
                              Icon(
                                isPlaying ? LucideIcons.pause : LucideIcons.play,
                                size: 15,
                                color: const Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 8),
                              Text(isPlaying ? 'Pause' : 'Play Audio', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'gemini_extract',
                          child: Row(
                            children: [
                              Icon(LucideIcons.sparkles, size: 15, color: Color(0xFFA855F7)),
                              SizedBox(width: 8),
                              Text('Extract with Gemini AI', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'gemini_chat',
                          child: Row(
                            children: [
                              Icon(LucideIcons.messageSquareShare, size: 15, color: Color(0xFF38BDF8)),
                              SizedBox(width: 8),
                              Text('Share to Gemini Chat', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'gemini_key',
                          child: Row(
                            children: [
                              Icon(LucideIcons.keyRound, size: 15, color: Color(0xFFF59E0B)),
                              SizedBox(width: 8),
                              Text('Gemini API Key', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(LucideIcons.share2, size: 15, color: Color(0xFF38BDF8)),
                              SizedBox(width: 8),
                              Text('Share Audio', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'whatsapp',
                          child: Row(
                            children: [
                              Icon(LucideIcons.messageCircle, size: 15, color: Color(0xFF22C55E)),
                              SizedBox(width: 8),
                              Text('WhatsApp Share', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(LucideIcons.pencil, size: 15, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Rename Title', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'notes',
                          child: Row(
                            children: [
                              Icon(LucideIcons.fileText, size: 15, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Notes & Tags', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(LucideIcons.trash2, size: 15, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),
              // Badges row: Duration, File size, Quick Extract button
              Row(
                children: [
                  _buildInfoBadge(LucideIcons.clock, recording.formattedDuration),
                  const SizedBox(width: 6),
                  _buildInfoBadge(LucideIcons.hardDrive, recording.formattedSize),
                  if (recording.tags.isEmpty && !isSelectionMode) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onGeminiExtract,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.sparkles, size: 10, color: Color(0xFFA855F7)),
                            SizedBox(width: 3),
                            Text(
                              'Extract Tags',
                              style: TextStyle(color: Color(0xFFD8B4FE), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Compact Tag Pills directly tagged with voice
              if (recording.tags.isNotEmpty) ...[
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: recording.tags
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .map((t) => _buildTagPill(t))
                      .toList(),
                ),
              ],

              // Key discussion points & summary (pure native cards, no rich HTML)
              if (recording.notes.isNotEmpty) ...[
                const SizedBox(height: 7),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.sparkle, size: 10, color: Color(0xFFA855F7)),
                          SizedBox(width: 4),
                          Text(
                            'KEY POINTS & TAKEAWAYS',
                            style: TextStyle(
                              color: Color(0xFFA855F7),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recording.notes,
                        style: const TextStyle(
                          color: Color(0xFFD4D4D8),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriggerBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF71717A)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPill(String tag) {
    final clean = tag.startsWith('#') ? tag : '#$tag';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.tag, size: 9.5, color: Color(0xFFA855F7)),
          const SizedBox(width: 4),
          Text(
            clean,
            style: const TextStyle(
              color: Color(0xFFE9D5FF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(BuildContext context) {
    final notesCtrl = TextEditingController(text: recording.notes);
    final tagsCtrl = TextEditingController(text: recording.tags);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Notes & Tags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tagsCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tags (e.g. #strategy, #standup)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF09090B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Meeting Notes / Highlights',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF09090B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              onNotesSaved(notesCtrl.text.trim(), tagsCtrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Recording?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${recording.title}" and its audio file from device storage.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
