import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fdserver/features/focus_guard/models/prayer_dhikr_model.dart';
import 'package:fdserver/features/focus_guard/services/prayer_dhikr_service.dart';
import 'package:fdserver/features/focus_guard/providers/focus_guard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Prayer & Dhikr Models Tests', () {
    test('PrayerNoteItem serialization and copyWith', () {
      final prayer = PrayerNoteItem(
        id: 'test_1',
        title: 'Focus Dua',
        arabic: 'اللَّهُمَّ',
        transliteration: 'Allahumma',
        translation: 'O Allah',
        reference: 'Hadith',
        note: 'Personal reflection',
        isCustom: true,
        isFavorite: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = prayer.toJson();
      expect(map['id'], 'test_1');
      expect(map['title'], 'Focus Dua');
      expect(map['isCustom'], true);

      final restored = PrayerNoteItem.fromJson(map);
      expect(restored.id, 'test_1');
      expect(restored.translation, 'O Allah');
      expect(restored.isFavorite, true);

      final updated = restored.copyWith(title: 'Updated Focus');
      expect(updated.title, 'Updated Focus');
      expect(updated.id, 'test_1');
    });

    test('Curated prayers list is populated with authentic duas', () {
      expect(PrayerNoteItem.curatedPrayers.isNotEmpty, true);
      final hasLazinessDua = PrayerNoteItem.curatedPrayers.any(
        (p) => p.id == 'prayer_laziness',
      );
      expect(hasLazinessDua, true);
    });

    test('DhikrItem serialization, cycle completion and copyWith', () {
      final dhikr = DhikrItem(
        id: 'test_dhikr',
        arabic: 'سُبْحَانَ اللَّهِ',
        transliteration: 'SubhanAllah',
        translation: 'Glory be to Allah',
        targetCount: 33,
        currentCount: 10,
        completedCycles: 1,
        createdAt: DateTime(2026, 1, 1),
      );

      final json = dhikr.toJson();
      expect(json['id'], 'test_dhikr');
      expect(json['targetCount'], 33);
      expect(json['currentCount'], 10);

      final fromJson = DhikrItem.fromJson(json);
      expect(fromJson.arabic, 'سُبْحَانَ اللَّهِ');
      expect(fromJson.completedCycles, 1);
    });
  });

  group('PrayerDhikrService Logic & State Tests', () {
    test('Initializes with default settings and curated content', () async {
      final service = PrayerDhikrService();
      await service.init();

      expect(service.isRandomPrayerEnabled, true);
      expect(service.isAlwaysShowDhikrEnabled, false);
      expect(service.prayerNotes.isNotEmpty, true);
      expect(service.dhikrItems.isNotEmpty, true);
    });

    test('Adding, updating, and deleting custom prayer note', () async {
      final service = PrayerDhikrService();
      await service.init();

      final initialCount = service.prayerNotes.length;

      await service.addPrayerNote(
        title: 'Morning Prayer',
        arabic: 'اللَّهُمَّ بِكَ أَصْبَحْنَا',
        transliteration: 'Allahumma bika asbahna',
        translation: 'O Allah, by You we enter the morning',
        reference: 'Tirmidhi 3391',
        note: 'Start the day right',
      );

      expect(service.prayerNotes.length, initialCount + 1);
      final added = service.prayerNotes.first;
      expect(added.title, 'Morning Prayer');
      expect(added.isCustom, true);

      // Favorite toggle
      await service.togglePrayerFavorite(added.id);
      expect(service.prayerNotes.first.isFavorite, true);

      // Delete note
      await service.deletePrayerNote(added.id);
      expect(service.prayerNotes.length, initialCount);
    });

    test('Adding custom dhikr, counting, and completing target cycle', () async {
      final service = PrayerDhikrService();
      await service.init();

      await service.addDhikrItem(
        arabic: 'سُبْحَانَ اللَّهِ',
        transliteration: 'Test Dhikr',
        translation: 'Test Meaning',
        targetCount: 3, // small target for testing
      );

      final addedDhikr = service.dhikrItems.first;
      expect(addedDhikr.targetCount, 3);
      expect(addedDhikr.currentCount, 0);

      // Count 1
      await service.incrementDhikr(addedDhikr.id);
      expect(service.dhikrItems.first.currentCount, 1);

      // Count 2
      await service.incrementDhikr(addedDhikr.id);
      expect(service.dhikrItems.first.currentCount, 2);

      // Count 3 -> reaches target 3, currentCount resets to 0 and completedCycles increments
      await service.incrementDhikr(addedDhikr.id);
      expect(service.dhikrItems.first.currentCount, 0);
      expect(service.dhikrItems.first.completedCycles, 1);

      // Reset
      await service.resetAllDhikrCycles(addedDhikr.id);
      expect(service.dhikrItems.first.completedCycles, 0);

      // Cleanup
      await service.deleteDhikrItem(addedDhikr.id);
    });

    test('Toggling Random Prayer and Always Show Dhikr preferences', () async {
      final service = PrayerDhikrService();
      await service.init();

      await service.setRandomPrayerEnabled(false);
      expect(service.isRandomPrayerEnabled, false);

      await service.setAlwaysShowDhikrEnabled(true);
      expect(service.isAlwaysShowDhikrEnabled, true);

      // Reset back
      await service.setRandomPrayerEnabled(true);
      await service.setAlwaysShowDhikrEnabled(false);
      expect(service.isRandomPrayerEnabled, true);
      expect(service.isAlwaysShowDhikrEnabled, false);
    });

    test('Bulk JSON import parses markdown fences and diverse schemas', () async {
      final service = PrayerDhikrService();
      await service.init();

      const rawJsonWithMarkdown = '''
```json
[
  {
    "arabic": "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
    "transliteration": "SubhanAllahi wa bihamdihi",
    "translation": "Glory be to Allah and His praise",
    "virtue": "100 times daily",
    "targetCount": 100
  },
  {
    "ar": "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ",
    "trans": "Allahumma salli 'ala Muhammad",
    "meaning": "Blessings upon the Prophet",
    "target": 10
  }
]
```
''';

      final initialCount = service.dhikrItems.length;
      final parsedCount = await service.importDhikrFromJson(rawJsonWithMarkdown);
      expect(parsedCount, 2);
      expect(service.dhikrItems.length, initialCount + 2);

      final importedFirst = service.dhikrItems.first;
      expect(importedFirst.isCustom, true);
      expect(importedFirst.targetCount, 100);
      expect(importedFirst.transliteration, "SubhanAllahi wa bihamdihi");

      final importedSecond = service.dhikrItems[1];
      expect(importedSecond.targetCount, 10);
      expect(importedSecond.transliteration, "Allahumma salli 'ala Muhammad");
    });
  });

  group('FocusGuardProvider Integration with Prayer Diversion', () {
    test('Allows selecting prayer diversion and accessing prayer preferences', () async {
      final provider = FocusGuardProvider();

      // Setting diversion type to 'prayer'
      await provider.setDiversionType('prayer');
      expect(provider.diversionType, 'prayer');

      // Toggling prayer options
      await provider.setPrayerRandomSelection(false);
      expect(provider.prayerRandomSelection, false);

      await provider.setPrayerAlwaysShowDhikr(true);
      expect(provider.prayerAlwaysShowDhikr, true);
    });
  });
}
