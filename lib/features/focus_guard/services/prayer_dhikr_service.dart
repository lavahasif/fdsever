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

  // ─── AI Bulk JSON Import Engine ──────────────────────────────────────────

  static const String aiJsonPromptTemplate = '''
Generate a JSON array of Islamic Dhikr remembrances using this schema:
[
  {
    "arabic": "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
    "transliteration": "SubhanAllahi wa bihamdihi",
    "translation": "Glory be to Allah and His praise",
    "virtue": "100 times daily forgives sins even if like the foam of the sea",
    "targetCount": 100
  },
  {
    "arabic": "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ",
    "transliteration": "Allahumma Anta Rabbi la ilaha illa Anta",
    "translation": "O Allah, You are my Lord, there is no deity worthy of worship except You",
    "virtue": "Sayyid al-Istighfar (Chief of repentance)",
    "targetCount": 1
  }
]
Output ONLY valid JSON.
''';

  static const String sampleDhikrJson = '''[
  {
    "arabic": "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
    "transliteration": "SubhanAllahi wa bihamdihi",
    "translation": "Glory be to Allah and His praise",
    "virtue": "Recited 100 times daily forgives sins even if like the foam of the sea",
    "targetCount": 100
  },
  {
    "arabic": "اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ",
    "transliteration": "Allahumma salli 'ala sayyidina Muhammad",
    "translation": "O Allah, send blessings upon our Master Muhammad",
    "virtue": "Whoever sends blessings once, Allah sends blessings tenfold",
    "targetCount": 100
  },
  {
    "arabic": "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ",
    "transliteration": "La hawla wa la quwwata illa billahil-'Aliyyil-'Azeem",
    "translation": "There is no power nor strength except with Allah, the Most High, the Most Great",
    "virtue": "A treasure from beneath the Throne of Allah",
    "targetCount": 33
  }
]''';

  List<DhikrItem> parseDhikrsFromJsonString(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return [];

    // Strip markdown code blocks if AI output was wrapped in ```json ... ```
    if (cleaned.startsWith('```')) {
      final firstLineEnd = cleaned.indexOf('\n');
      if (firstLineEnd != -1) {
        cleaned = cleaned.substring(firstLineEnd + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      return [];
    }

    List<dynamic> list = [];
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      if (decoded['dhikr'] is List) {
        list = decoded['dhikr'] as List;
      } else if (decoded['items'] is List) {
        list = decoded['items'] as List;
      } else if (decoded['data'] is List) {
        list = decoded['data'] as List;
      } else {
        list = [decoded];
      }
    }

    final result = <DhikrItem>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < list.length; i++) {
      final rawItem = list[i];
      if (rawItem is! Map) continue;
      final map = Map<String, dynamic>.from(rawItem);

      final arabic = (map['arabic'] ?? map['ar'] ?? map['arabicText'] ?? map['text'] ?? '').toString().trim();
      final transliteration = (map['transliteration'] ?? map['trans'] ?? map['title'] ?? map['name'] ?? map['latin'] ?? '').toString().trim();
      final translation = (map['translation'] ?? map['meaning'] ?? map['english'] ?? map['en'] ?? '').toString().trim();
      final virtue = (map['virtue'] ?? map['benefit'] ?? map['reward'] ?? map['note'] ?? map['description'] ?? '').toString().trim();
      final targetStr = map['targetCount'] ?? map['target'] ?? map['count'] ?? map['repeat'] ?? '33';
      final targetCount = int.tryParse(targetStr.toString()) ?? 33;

      if (arabic.isEmpty && transliteration.isEmpty && translation.isEmpty) {
        continue;
      }

      result.add(
        DhikrItem(
          id: 'dhikr_imported_${timestamp}_$i',
          arabic: arabic.isNotEmpty ? arabic : transliteration,
          transliteration: transliteration.isNotEmpty ? transliteration : arabic,
          translation: translation,
          virtue: virtue,
          targetCount: targetCount > 0 ? targetCount : 33,
          currentCount: 0,
          completedCycles: 0,
          isCustom: true,
          createdAt: DateTime.now(),
        ),
      );
    }

    return result;
  }

  Future<int> importDhikrFromJson(String rawJson) async {
    final parsed = parseDhikrsFromJsonString(rawJson);
    if (parsed.isEmpty) return 0;

    _dhikrItems.insertAll(0, parsed);
    await _saveDhikrItems();
    notifyListeners();
    return parsed.length;
  }
}
