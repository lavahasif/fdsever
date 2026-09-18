import 'package:flutter/foundation.dart';
import '../../../core/models/tutorial_item.dart';
import '../../../core/services/storage_service.dart';

class TutorialsProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<TutorialItem> _tutorials = [];
  String _selectedCategory = 'All';

  TutorialsProvider(this._storageService) {
    _loadTutorials();
  }

  void _loadTutorials() {
    _tutorials = _storageService.getTutorials();
    notifyListeners();
  }

  List<TutorialItem> get tutorials {
    if (_selectedCategory == 'All') return _tutorials;
    return _tutorials.where((t) => t.category == _selectedCategory).toList();
  }

  List<String> get categories {
    final set = {'All'};
    for (final t in _tutorials) {
      set.add(t.category);
    }
    return set.toList();
  }

  String get selectedCategory => _selectedCategory;

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> addTutorial({
    required String title,
    required String category,
    required String description,
    required String link,
  }) async {
    final item = TutorialItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      description: description.trim(),
      link: link.trim(),
      createdAt: DateTime.now(),
    );
    _tutorials.insert(0, item);
    await _storageService.saveTutorials(_tutorials);
    notifyListeners();
  }

  Future<void> deleteTutorial(String id) async {
    _tutorials.removeWhere((t) => t.id == id);
    await _storageService.saveTutorials(_tutorials);
    notifyListeners();
  }
}
