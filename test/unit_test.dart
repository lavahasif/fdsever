import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fdserver/core/models/note_item.dart';
import 'package:fdserver/core/models/socket_message.dart';
import 'package:fdserver/core/models/tutorial_item.dart';
import 'package:fdserver/core/services/storage_service.dart';
import 'package:fdserver/core/services/whatsapp_service.dart';

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
}
