import 'package:flutter/foundation.dart';
import '../../../core/models/note_item.dart';
import '../../../core/services/storage_service.dart';

class NotesProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<NoteItem> _notes = [];
  String _searchQuery = '';
  NoteItem? _selectedNote;

  NotesProvider(this._storageService) {
    _loadNotes();
  }

  void _loadNotes() {
    _notes = _storageService.getNotes();
    notifyListeners();
  }

  List<NoteItem> get notes {
    if (_searchQuery.isEmpty) return _notes;
    final q = _searchQuery.toLowerCase();
    return _notes.where((n) =>
      n.title.toLowerCase().contains(q) ||
      n.note.toLowerCase().contains(q) ||
      n.link.toLowerCase().contains(q)
    ).toList();
  }

  NoteItem? get selectedNote => _selectedNote;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectNote(NoteItem? note) {
    _selectedNote = note;
    notifyListeners();
  }

  Future<void> addNote({
    required String title,
    required String note,
    required String link,
  }) async {
    final newNote = NoteItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      note: note.trim(),
      link: link.trim(),
      createdAt: DateTime.now(),
    );
    _notes.insert(0, newNote);
    await _storageService.saveNotes(_notes);
    notifyListeners();
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String note,
    required String link,
  }) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        title: title.trim(),
        note: note.trim(),
        link: link.trim(),
      );
      await _storageService.saveNotes(_notes);
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    if (_selectedNote?.id == id) _selectedNote = null;
    await _storageService.saveNotes(_notes);
    notifyListeners();
  }

  Future<void> clearAllNotes() async {
    _notes.clear();
    _selectedNote = null;
    await _storageService.saveNotes(_notes);
    notifyListeners();
  }
}
