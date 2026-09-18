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
      builder: (context) {
        return ShadDialog(
          title: Text(editNote == null ? 'Register New Note' : 'Edit Note'),
          description: const Text('Saved notes are stored locally and accessible via the local web server at /notes.'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(),
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
                Navigator.of(context).pop();
              },
              child: Text(editNote == null ? 'Save Note' : 'Update Note'),
            ),
          ],
          child: Container(
            width: 450,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                ShadInput(controller: titleController, placeholder: const Text('Note title...')),
                const SizedBox(height: 12),
                const Text('Content', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                ShadInput(
                  controller: noteController,
                  placeholder: const Text('Note details or code snippet...'),
                  maxLines: 4,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                const Text('Link / URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                ShadInput(controller: linkController, placeholder: const Text('https://example.com')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notes & Knowledge Base', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                      'Create, manage, and query notes. Notes are automatically served on your web server /notes.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ShadButton(
                onPressed: () => _showNoteDialog(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 16),
                    SizedBox(width: 8),
                    Text('Add Note'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Search Bar
          ShadInput(
            controller: _searchController,
            placeholder: const Text('Search notes by title, keyword, or link...'),
            leading: const Padding(
              padding: EdgeInsets.only(left: 8, right: 8),
              child: Icon(LucideIcons.search, size: 16, color: Colors.grey),
            ),
            onChanged: (val) => notesProvider.setSearchQuery(val),
          ),

          const SizedBox(height: 20),

          // Notes List
          if (notesProvider.notes.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.notebook, size: 36, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No notes found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Click "Add Note" to create your first registered note.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    ShadButton.outline(
                      onPressed: () => _showNoteDialog(context),
                      child: const Text('Create Note'),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: notesProvider.notes.length,
                  itemBuilder: (context, index) {
                    final note = notesProvider.notes[index];
                    return ShadCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  note.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}-${note.createdAt.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          Text(
                            note.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (note.link.isNotEmpty)
                                ShadButton.ghost(
                                  size: ShadButtonSize.sm,
                                  onPressed: () => launchUrl(Uri.parse(note.link), mode: LaunchMode.externalApplication),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.link, size: 12),
                                      const SizedBox(width: 4),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 150),
                                        child: Text(
                                          note.link,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShadButton.ghost(
                                    size: ShadButtonSize.sm,
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: '${note.title}\n${note.note}\n${note.link}'));
                                      ShadToaster.of(context).show(
                                        const ShadToast(
                                          title: Text('Copied to Clipboard'),
                                          description: Text('Note content copied'),
                                        ),
                                      );
                                    },
                                    child: const Icon(LucideIcons.copy, size: 14),
                                  ),
                                  ShadButton.ghost(
                                    size: ShadButtonSize.sm,
                                    onPressed: () => _showNoteDialog(context, editNote: note),
                                    child: const Icon(LucideIcons.pencil, size: 14),
                                  ),
                                  ShadButton.ghost(
                                    size: ShadButtonSize.sm,
                                    onPressed: () => notesProvider.deleteNote(note.id),
                                    child: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
