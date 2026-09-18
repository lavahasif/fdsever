import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  String _favPort = AppConstants.defaultFavPort;
  String _favIp = AppConstants.defaultFavIp;
  int _timeoutMs = int.parse(AppConstants.defaultTimeoutMs);
  int _timeout2Ms = int.parse(AppConstants.defaultTimeout2Ms);
  ThemeMode _themeMode = ThemeMode.system;

  SettingsProvider(this._storageService) {
    _loadSettings();
  }

  void _loadSettings() {
    _favPort = _storageService.getFavPort();
    _favIp = _storageService.getFavIp();
    _timeoutMs = _storageService.getTimeout();
    _timeout2Ms = _storageService.getTimeout2();

    final themeStr = _storageService.getThemeMode();
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  String get favPort => _favPort;
  String get favIp => _favIp;
  int get timeoutMs => _timeoutMs;
  int get timeout2Ms => _timeout2Ms;
  ThemeMode get themeMode => _themeMode;

  Future<void> saveSettings({
    required String favPort,
    required String favIp,
    required String timeoutMs,
    required String timeout2Ms,
  }) async {
    _favPort = favPort.trim().isEmpty ? AppConstants.defaultFavPort : favPort.trim();
    _favIp = favIp.trim().isEmpty ? AppConstants.defaultFavIp : favIp.trim();
    _timeoutMs = int.tryParse(timeoutMs) ?? int.parse(AppConstants.defaultTimeoutMs);
    _timeout2Ms = int.tryParse(timeout2Ms) ?? int.parse(AppConstants.defaultTimeout2Ms);

    await _storageService.setFavPort(_favPort);
    await _storageService.setFavIp(_favIp);
    await _storageService.setTimeout(_timeoutMs.toString());
    await _storageService.setTimeout2(_timeout2Ms.toString());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _storageService.setThemeMode(modeStr);
    notifyListeners();
  }
}
