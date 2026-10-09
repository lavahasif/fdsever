import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fdserver/core/models/note_item.dart';
import 'package:fdserver/core/models/socket_message.dart';
import 'package:fdserver/core/models/tutorial_item.dart';
import 'package:fdserver/core/services/storage_service.dart';
import 'package:fdserver/core/services/whatsapp_service.dart';
import 'package:fdserver/features/meeting_recorder/models/meeting_recording.dart';
import 'package:fdserver/features/meeting_recorder/models/meeting_schedule.dart';
import 'package:fdserver/features/meeting_recorder/services/gemini_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsAppService Unit Tests', () {
    final service = WhatsAppService();

    test('cleanNumber strips spaces, plus signs, and leading zeroes', () {
      expect(service.cleanNumber('+91 98765 43210'), '919876543210');
      expect(service.cleanNumber('09876543210', defaultPrefix: '91'), '919876543210');
      expect(service.cleanNumber('9876543210', defaultPrefix: '91'), '919876543210');
    });

    test('buildWebUrl formats wa.me URL correctly', () {
      final url = service.buildWebUrl('919876543210', 'Hello World!');
      expect(url, 'https://wa.me/919876543210?text=Hello%20World!');
    });
  });

  group('SocketMessage Unit Tests', () {
    test('extracts multiple URLs accurately from message payload', () {
      const text = 'Check out https://flutter.dev and http://192.168.1.1:8081 for updates.';
      final msg = SocketMessage(
        id: '1',
        text: text,
        source: MessageSource.server,
      );

      expect(msg.extractedUrls.length, 2);
      expect(msg.extractedUrls[0], 'https://flutter.dev');
      expect(msg.extractedUrls[1], 'http://192.168.1.1:8081');
    });
  });

  group('Models Serialization Unit Tests', () {
    test('NoteItem serialization round-trip', () {
      final note = NoteItem(
        id: '100',
        title: 'Shelf Server Setup',
        note: 'Listening on port 8081',
        link: 'https://pub.dev/packages/shelf',
        createdAt: DateTime(2026, 1, 1),
      );

      final jsonStr = note.toJson();
      final restored = NoteItem.fromJson(jsonStr);

      expect(restored.id, note.id);
      expect(restored.title, note.title);
      expect(restored.note, note.note);
      expect(restored.link, note.link);
    });

    test('TutorialItem serialization round-trip', () {
      final tut = TutorialItem(
        id: '200',
        title: 'Port Scanning in Dart',
        category: 'Network',
        description: 'Socket.connect timeout handling',
        link: 'https://dart.dev',
        createdAt: DateTime(2026, 2, 1),
      );

      final jsonStr = tut.toJson();
      final restored = TutorialItem.fromJson(jsonStr);

      expect(restored.id, tut.id);
      expect(restored.title, tut.title);
      expect(restored.category, tut.category);
    });
  });

  group('StorageService Unit Tests', () {
    test('saves and loads notes and preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      expect(storage.getFavPort(), '8069');
      await storage.setFavPort('9000');
      expect(storage.getFavPort(), '9000');

      final notes = [
        NoteItem(
          id: '1',
          title: 'Test Note',
          note: 'Sample Body',
          link: '',
          createdAt: DateTime.now(),
        )
      ];
      await storage.saveNotes(notes);
      final loaded = storage.getNotes();
      expect(loaded.length, 1);
      expect(loaded.first.title, 'Test Note');
    });
  });

  group('Meeting & Refocus Unit Tests', () {
    test('computedNudgeTimes calculates evenly spaced interval times', () {
      // 10:00 to 11:00 with 3 nudges -> 10:15, 10:30, 10:45
      final schedule = MeetingSchedule(
        id: 1,
        title: 'Weekly Standup',
        startHour: 10,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
        alarmCount: 3,
      );

      expect(schedule.totalDurationMinutes, 60);
      final nudges = schedule.computedNudgeTimes;
      expect(nudges.length, 3);
      expect(nudges[0].hour, 10);
      expect(nudges[0].minute, 15);
      expect(nudges[1].hour, 10);
      expect(nudges[1].minute, 30);
      expect(nudges[2].hour, 10);
      expect(nudges[2].minute, 45);
    });

    test('MeetingRecording formatted strings and copyWith', () {
      final rec = MeetingRecording(
        id: 1,
        filePath: '/tmp/meeting_20261008_100000.m4a',
        title: 'Strategy Review',
        startedAt: DateTime(2026, 10, 8, 10, 0),
        durationMs: 3665000, // 1 hr 1 min 5 sec
        sizeBytes: 30000000,
        triggerType: 'power_button',
      );

      expect(rec.formattedDuration, '01:01:05');
      expect(rec.formattedSize, '28.61 MB');
      expect(rec.triggerLabel, 'Power ×3');

      final renamed = rec.copyWith(title: 'Q4 Budget Alignment');
      expect(renamed.title, 'Q4 Budget Alignment');
      expect(renamed.filePath, rec.filePath);
    });

    test('GeminiVoiceResult formattedTags and formattedNotes formatting', () {
      const result = GeminiVoiceResult(
        tags: ['Roadmap', '#Budget', 'Design'],
        keyPoints: ['Finalized Q4 goals', 'Approved UX overhaul'],
        summary: 'Discussion on product roadmap and budget alignment.',
      );

      expect(result.formattedTags, '#Roadmap, #Budget, #Design');
      expect(result.formattedNotes, contains('Discussion on product roadmap and budget alignment.'));
      expect(result.formattedNotes, contains('• Finalized Q4 goals'));
      expect(result.formattedNotes, contains('• Approved UX overhaul'));
    });
  });
}
