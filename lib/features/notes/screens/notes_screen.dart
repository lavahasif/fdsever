import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/note_item.dart';
import '../providers/notes_provider.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNoteDialog(BuildContext context, {NoteItem? editNote}) {
    final titleController = TextEditingController(text: editNote?.title ?? '');
    final noteController = TextEditingController(text: editNote?.note ?? '');
    final linkController = TextEditingController(text: editNote?.link ?? '');

    showShadDialog(
      context: context,
      builder: (ctx) {
        return ShadDialog(
          title: Text(editNote == null ? 'Register New Note' : 'Edit Note'),
          description: const Text(
            'Saved notes are stored locally and served at /notes via the web server.',
          ),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                final provider = context.read<NotesProvider>();
                if (editNote == null) {
                  provider.addNote(
                    title: titleController.text.trim(),
                    note: noteController.text.trim(),
                    link: linkController.text.trim(),
                  );
                } else {
                  provider.updateNote(
                    id: editNote.id,
                    title: titleController.text.trim(),
                    note: noteController.text.trim(),
                    link: linkController.text.trim(),
                  );
                }
                Navigator.of(ctx).pop();
                ShadToaster.of(context).show(
                  ShadToast(
                    title: Text(editNote == null ? 'Note Created' : 'Note Updated'),
                    description: Text('"${titleController.text.trim()}" saved successfully'),
                  ),
                );
              },
              child: Text(editNote == null ? 'Save Note' : 'Update Note'),
            ),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogLabel('Title *'),
                  ShadInput(
                    controller: titleController,
                    placeholder: const Text('e.g. WiFi credentials, API endpoints...'),
                  ),
                  const SizedBox(height: 12),
                  _dialogLabel('Content / Notes'),
                  ShadInput(
                    controller: noteController,
                    placeholder: const Text('Enter note details, snippets, or instructions...'),
                    maxLines: 5,
                    minLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _dialogLabel('Associated Link / URL (optional)'),
                  ShadInput(
                    controller: linkController,
                    placeholder: const Text('https://192.168.1.1 or https://github.com/...'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, NoteItem note) {
    showShadDialog(
      context: context,
      builder: (ctx) {
        return ShadDialog.alert(
          title: const Text('Delete Note?'),
          description: Text('Are you sure you want to delete "${note.title}"? This cannot be undone.'),
          actions: [
            ShadButton.outline(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ShadButton.destructive(
              child: const Text('Delete'),
              onPressed: () {
                context.read<NotesProvider>().deleteNote(note.id);
                Navigator.of(ctx).pop();
                ShadToaster.of(context).show(
                  ShadToast.destructive(
                    title: const Text('Note Deleted'),
                    description: Text('"${note.title}" was removed'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _dialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('MMM d, y • h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.notebookPen, color: Color(0xFF8B5CF6), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Notes & Knowledge Base',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${notesProvider.notes.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Store notes, links, and code snippets locally. Automatically served via REST API at /notes.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ShadButton(
                size: ShadButtonSize.sm,
                onPressed: () => _showNoteDialog(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 15),
                    SizedBox(width: 6),
                    Text('Add Note'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Search & Filter Bar
          ShadInput(
            controller: _searchController,
            placeholder: const Text('Search notes by title, content, or link...'),
            leading: const Padding(
              padding: EdgeInsets.only(left: 8, right: 4),
              child: Icon(LucideIcons.search, size: 15, color: Colors.grey),
            ),
            trailing: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 14),
                    onPressed: () {
                      _searchController.clear();
                      notesProvider.setSearchQuery('');
                      setState(() {});
                    },
                  )
                : null,
            onChanged: (v) {
              notesProvider.setSearchQuery(v);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // Notes List / Empty State
          if (notesProvider.notes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.notebookPen, size: 36, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      notesProvider.searchQuery.isNotEmpty
                          ? 'No notes match "${notesProvider.searchQuery}"'
                          : 'Your Knowledge Base is empty',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notesProvider.searchQuery.isNotEmpty
                          ? 'Try searching with different keywords.'
                          : 'Add your first note to store credentials, endpoints, or documentation.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ShadButton.outline(
                      onPressed: () => _showNoteDialog(context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plus, size: 14),
                          SizedBox(width: 6),
                          Text('Create First Note'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 2 : 1,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 185,
                  ),
                  itemCount: notesProvider.notes.length,
                  itemBuilder: (context, index) {
                    final note = notesProvider.notes[index];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header: Title + Options
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(note.createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.copy, size: 15),
                                    tooltip: 'Copy Note',
                                    splashRadius: 16,
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                        text: '${note.title}\n${note.note}${note.link.isNotEmpty ? '\n${note.link}' : ''}',
                                      ));
                                      ShadToaster.of(context).show(
                                        const ShadToast(
                                          title: Text('Copied'),
                                          description: Text('Note copied to clipboard'),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.pencil, size: 15),
                                    tooltip: 'Edit',
                                    splashRadius: 16,
                                    onPressed: () => _showNoteDialog(context, editNote: note),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 15, color: Color(0xFFEF4444)),
                                    tooltip: 'Delete',
                                    splashRadius: 16,
                                    onPressed: () => _showDeleteConfirm(context, note),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Note Body
                          Expanded(
                            child: Text(
                              note.note,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B),
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Link Chip if available
                          if (note.link.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final uri = Uri.tryParse(note.link);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.externalLink, size: 12, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        note.link,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF3B82F6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
