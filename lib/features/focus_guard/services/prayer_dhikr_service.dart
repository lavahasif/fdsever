import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_dhikr_model.dart';

class PrayerDhikrService extends ChangeNotifier {
  static final PrayerDhikrService _instance = PrayerDhikrService._internal();
  factory PrayerDhikrService() => _instance;
  PrayerDhikrService._internal();

  static const String _keyPrayerNotes = 'focus_guard_prayer_notes_v2';
  static const String _keyDhikrItems = 'focus_guard_dhikr_items_v2';
  static const String _keyRandomPrayer = 'focus_guard_prayer_random_selection';
  static const String _keyAlwaysShowDhikr = 'focus_guard_prayer_always_show_dhikr';
  static const String _keySelectedPrayerId = 'focus_guard_prayer_selected_id';

  bool _isInitialized = false;
  List<PrayerNoteItem> _prayerNotes = [];
  List<DhikrItem> _dhikrItems = [];
  bool _isRandomPrayerEnabled = true;
  bool _isAlwaysShowDhikrEnabled = false;
  String? _selectedPrayerId;

  bool get isInitialized => _isInitialized;
  List<PrayerNoteItem> get prayerNotes => List.unmodifiable(_prayerNotes);
  List<DhikrItem> get dhikrItems => List.unmodifiable(_dhikrItems);
  bool get isRandomPrayerEnabled => _isRandomPrayerEnabled;
  bool get isAlwaysShowDhikrEnabled => _isAlwaysShowDhikrEnabled;
  String? get selectedPrayerId => _selectedPrayerId;

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    _isRandomPrayerEnabled = prefs.getBool(_keyRandomPrayer) ?? true;
    _isAlwaysShowDhikrEnabled = prefs.getBool(_keyAlwaysShowDhikr) ?? false;
    _selectedPrayerId = prefs.getString(_keySelectedPrayerId);

    // Load Prayer Notes
    final savedNotesJson = prefs.getString(_keyPrayerNotes);
    if (savedNotesJson != null) {
      try {
        final decoded = jsonDecode(savedNotesJson) as List;
        _prayerNotes = decoded
            .map((e) => PrayerNoteItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error loading saved prayer notes: $e');
        _prayerNotes = List.from(PrayerNoteItem.curatedPrayers);
      }
    } else {
      _prayerNotes = List.from(PrayerNoteItem.curatedPrayers);
    }

    // Load Dhikr Items
    final savedDhikrJson = prefs.getString(_keyDhikrItems);
    if (savedDhikrJson != null) {
      try {
        final decoded = jsonDecode(savedDhikrJson) as List;
        _dhikrItems = decoded
            .map((e) => DhikrItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error loading saved dhikr items: $e');
        _dhikrItems = List.from(DhikrItem.curatedDhikr);
      }
    } else {
      _dhikrItems = List.from(DhikrItem.curatedDhikr);
    }

    _isInitialized = true;
    notifyListeners();
  }

  // ─── Prayer Settings ───────────────────────────────────────────────────────

  Future<void> setRandomPrayerEnabled(bool enabled) async {
    _isRandomPrayerEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRandomPrayer, enabled);
    notifyListeners();
  }

  Future<void> setAlwaysShowDhikrEnabled(bool enabled) async {
    _isAlwaysShowDhikrEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAlwaysShowDhikr, enabled);
    notifyListeners();
  }

  Future<void> setSelectedPrayerId(String? id) async {
    _selectedPrayerId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_keySelectedPrayerId);
    } else {
      await prefs.setString(_keySelectedPrayerId, id);
    }
    notifyListeners();
  }

  // ─── Prayer Notes Retrieval & Mutations ────────────────────────────────────

  PrayerNoteItem getPrayerForIntervention({bool forceRandom = false}) {
    if (_prayerNotes.isEmpty) {
      _prayerNotes = List.from(PrayerNoteItem.curatedPrayers);
    }

    if (forceRandom || _isRandomPrayerEnabled || _selectedPrayerId == null) {
      final rand = Random();
      return _prayerNotes[rand.nextInt(_prayerNotes.length)];
    }

    try {
      return _prayerNotes.firstWhere(
        (p) => p.id == _selectedPrayerId,
        orElse: () => _prayerNotes.first,
      );
    } catch (_) {
      return _prayerNotes.first;
    }
  }

  Future<void> addPrayerNote({
    required String title,
    required String arabic,
    required String transliteration,
    required String translation,
    required String reference,
    String note = '',
  }) async {
    final newNote = PrayerNoteItem(
      id: 'prayer_custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      arabic: arabic.trim(),
      transliteration: transliteration.trim(),
      translation: translation.trim(),
      reference: reference.trim(),
      note: note.trim(),
      isCustom: true,
      createdAt: DateTime.now(),
    );

    _prayerNotes.insert(0, newNote);
    await _savePrayerNotes();
    notifyListeners();
  }

  Future<void> updatePrayerNote(PrayerNoteItem updatedNote) async {
    final idx = _prayerNotes.indexWhere((p) => p.id == updatedNote.id);
    if (idx != -1) {
      _prayerNotes[idx] = updatedNote;
      await _savePrayerNotes();
      notifyListeners();
    }
  }

  Future<void> togglePrayerFavorite(String id) async {
    final idx = _prayerNotes.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _prayerNotes[idx] = _prayerNotes[idx].copyWith(
        isFavorite: !_prayerNotes[idx].isFavorite,
      );
      await _savePrayerNotes();
      notifyListeners();
    }
  }

  Future<void> deletePrayerNote(String id) async {
    _prayerNotes.removeWhere((p) => p.id == id);
    if (_selectedPrayerId == id) {
      _selectedPrayerId = null;
    }
    await _savePrayerNotes();
    notifyListeners();
  }

  Future<void> _savePrayerNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _prayerNotes.map((e) => e.toJson()).toList();
    await prefs.setString(_keyPrayerNotes, jsonEncode(jsonList));
  }

  // ─── Dhikr Retrieval & Mutations ───────────────────────────────────────────

  Future<void> addDhikrItem({
    required String arabic,
    required String transliteration,
    required String translation,
    String virtue = '',
    int targetCount = 33,
  }) async {
    final newDhikr = DhikrItem(
      id: 'dhikr_custom_${DateTime.now().millisecondsSinceEpoch}',
      arabic: arabic.trim(),
      transliteration: transliteration.trim(),
      translation: translation.trim(),
      virtue: virtue.trim(),
      targetCount: targetCount > 0 ? targetCount : 33,
      currentCount: 0,
      completedCycles: 0,
      isCustom: true,
      createdAt: DateTime.now(),
    );

    _dhikrItems.insert(0, newDhikr);
    await _saveDhikrItems();
    notifyListeners();
  }

  Future<void> deleteDhikrItem(String id) async {
    _dhikrItems.removeWhere((d) => d.id == id);
    await _saveDhikrItems();
    notifyListeners();
  }

  Future<void> incrementDhikr(String id) async {
    final idx = _dhikrItems.indexWhere((d) => d.id == id);
    if (idx == -1) return;

    final item = _dhikrItems[idx];
    final nextCount = item.currentCount + 1;

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    if (nextCount >= item.targetCount) {
      // Completed cycle!
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      _dhikrItems[idx] = item.copyWith(
        currentCount: 0,
        completedCycles: item.completedCycles + 1,
      );
    } else {
      _dhikrItems[idx] = item.copyWith(currentCount: nextCount);
    }

    await _saveDhikrItems();
    notifyListeners();
  }

  Future<void> resetDhikr(String id) async {
    final idx = _dhikrItems.indexWhere((d) => d.id == id);
    if (idx == -1) return;

    _dhikrItems[idx] = _dhikrItems[idx].copyWith(
      currentCount: 0,
    );
    await _saveDhikrItems();
    notifyListeners();
  }

  Future<void> resetAllDhikrCycles(String id) async {
    final idx = _dhikrItems.indexWhere((d) => d.id == id);
    if (idx == -1) return;

    _dhikrItems[idx] = _dhikrItems[idx].copyWith(
      currentCount: 0,
      completedCycles: 0,
    );
    await _saveDhikrItems();
    notifyListeners();
  }

  Future<void> _saveDhikrItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _dhikrItems.map((e) => e.toJson()).toList();
    await prefs.setString(_keyDhikrItems, jsonEncode(jsonList));
  }
}
