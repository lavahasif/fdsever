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
              'Saved notes are stored locally and served at /notes via the web server.'),
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
                    title: titleController.text,
                    note: noteController.text,
                    link: linkController.text,
                  );
                } else {
                  provider.updateNote(
                    id: editNote.id,
                    title: titleController.text,
                    note: noteController.text,
                    link: linkController.text,
                  );
                }
                Navigator.of(ctx).pop();
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
                  _dialogLabel('Title'),
                  ShadInput(
                      controller: titleController,
                      placeholder: const Text('Note title...')),
                  const SizedBox(height: 12),
                  _dialogLabel('Content'),
                  ShadInput(
                    controller: noteController,
                    placeholder: const Text('Note details or snippet...'),
                    maxLines: 4,
                    minLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _dialogLabel('Link / URL (optional)'),
                  ShadInput(
                      controller: linkController,
                      placeholder: const Text('https://example.com')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notes & Knowledge Base',
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'Create and manage notes. Served at /notes via the web server.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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

          const SizedBox(height: 16),

          // Search Bar
          ShadInput(
            controller: _searchController,
            placeholder: const Text('Search notes...'),
            leading: const Padding(
              padding: EdgeInsets.only(left: 8, right: 4),
              child: Icon(LucideIcons.search, size: 15, color: Colors.grey),
            ),
            onChanged: (v) => notesProvider.setSearchQuery(v),
          ),

          const SizedBox(height: 18),

          // Notes Grid / Empty State
          if (notesProvider.notes.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.notebook,
                        size: 36, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    const Text('No notes found',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      notesProvider.searchQuery.isNotEmpty
                          ? 'Try a different search term.'
                          : 'Click "Add Note" to get started.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    if (notesProvider.searchQuery.isEmpty) ...[
                      const SizedBox(height: 16),
                      ShadButton.outline(
                        onPressed: () => _showNoteDialog(context),
                        child: const Text('Create Note'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 800
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  // Let the item determine its own height
                  childAspectRatio: cols == 2 ? 2.4 : 3.0,
                ),
                itemCount: notesProvider.notes.length,
                itemBuilder: (context, index) {
                  final note = notesProvider.notes[index];
                  return ShadCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Date row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                note.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}-${note.createdAt.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            note.note,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade400),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Bottom bar
                        Row(
                          children: [
                            if (note.link.isNotEmpty)
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => launchUrl(Uri.parse(note.link),
                                      mode: LaunchMode.externalApplication),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.link,
                                          size: 12,
                                          color: Colors.blue.shade400),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          note.link,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade400),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            // Action icons
                            ShadButton.ghost(
                              size: ShadButtonSize.sm,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text:
                                        '${note.title}\n${note.note}\n${note.link}'));
                                ShadToaster.of(context).show(
                                  const ShadToast(
                                    title: Text('Copied'),
                                    description: Text('Note content copied'),
                                  ),
                                );
                              },
                              child: const Icon(LucideIcons.copy, size: 13),
                            ),
                            ShadButton.ghost(
                              size: ShadButtonSize.sm,
                              onPressed: () =>
                                  _showNoteDialog(context, editNote: note),
                              child: const Icon(LucideIcons.pencil, size: 13),
                            ),
                            ShadButton.ghost(
                              size: ShadButtonSize.sm,
                              onPressed: () =>
                                  notesProvider.deleteNote(note.id),
                              child: Icon(LucideIcons.trash2,
                                  size: 13, color: Colors.red.shade400),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }
}
