import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/note_item.dart';
import '../models/tutorial_item.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Preferences
  String getFavPort() => _prefs.getString(AppConstants.prefFavPort) ?? AppConstants.defaultFavPort;
  Future<void> setFavPort(String port) => _prefs.setString(AppConstants.prefFavPort, port);

  String getFavIp() => _prefs.getString(AppConstants.prefFavIp) ?? AppConstants.defaultFavIp;
  Future<void> setFavIp(String ip) => _prefs.setString(AppConstants.prefFavIp, ip);

  int getTimeout() => int.tryParse(_prefs.getString(AppConstants.prefTimeout) ?? '') ?? int.parse(AppConstants.defaultTimeoutMs);
  Future<void> setTimeout(String ms) => _prefs.setString(AppConstants.prefTimeout, ms);

  int getTimeout2() => int.tryParse(_prefs.getString(AppConstants.prefTimeout2) ?? '') ?? int.parse(AppConstants.defaultTimeout2Ms);
  Future<void> setTimeout2(String ms) => _prefs.setString(AppConstants.prefTimeout2, ms);

  bool getDeleteAfterUpload() => _prefs.getBool(AppConstants.prefDeleteAfterUpload) ?? false;
  Future<void> setDeleteAfterUpload(bool value) => _prefs.setBool(AppConstants.prefDeleteAfterUpload, value);

  String getWhatsAppMessage() => _prefs.getString(AppConstants.prefWhatsAppMessage) ?? 'Hello!';
  Future<void> setWhatsAppMessage(String msg) => _prefs.setString(AppConstants.prefWhatsAppMessage, msg);

  String getThemeMode() => _prefs.getString(AppConstants.prefThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(AppConstants.prefThemeMode, mode);

  // Notes persistence
  List<NoteItem> getNotes() {
    final rawList = _prefs.getStringList(AppConstants.prefNotes) ?? [];
    return rawList.map((e) => NoteItem.fromJson(e)).toList();
  }

  Future<void> saveNotes(List<NoteItem> notes) async {
    final rawList = notes.map((e) => e.toJson()).toList();
    await _prefs.setStringList(AppConstants.prefNotes, rawList);
  }

  // Tutorials persistence
  List<TutorialItem> getTutorials() {
    final rawList = _prefs.getStringList(AppConstants.prefTutorials) ?? [];
    if (rawList.isEmpty) {
      // Return default sample tutorials
      return [
        TutorialItem(
          id: 'tut-1',
          title: 'Host Flutter Web on Mobile',
          category: 'Server',
          description: 'How to use Shelf to serve static assets and APIs on local WiFi.',
          link: 'https://flutter.dev',
          createdAt: DateTime.now(),
        ),
        TutorialItem(
          id: 'tut-2',
          title: 'TCP Port Scanning Basics',
          category: 'Network',
          description: 'Understanding socket connect timeouts and multi-device discovery.',
          link: 'https://dart.dev',
          createdAt: DateTime.now(),
        ),
      ];
    }
    return rawList.map((e) => TutorialItem.fromJson(e)).toList();
  }

  Future<void> saveTutorials(List<TutorialItem> tuts) async {
    final rawList = tuts.map((e) => e.toJson()).toList();
    await _prefs.setStringList(AppConstants.prefTutorials, rawList);
  }

  // Recent WhatsApp Numbers
  List<String> getRecentNumbers() => _prefs.getStringList(AppConstants.prefRecentNumbers) ?? [];

  Future<void> addRecentNumber(String number) async {
    final current = getRecentNumbers();
    current.remove(number);
    current.insert(0, number);
    if (current.length > 20) current.removeLast();
    await _prefs.setStringList(AppConstants.prefRecentNumbers, current);
  }

  Future<void> clearRecentNumbers() async {
    await _prefs.remove(AppConstants.prefRecentNumbers);
  }
}
