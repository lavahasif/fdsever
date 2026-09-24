import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/power_service.dart';
import '../../../core/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final PowerService? _powerService;

  String _favPort = AppConstants.defaultFavPort;
  String _favIp = AppConstants.defaultFavIp;
  int _timeoutMs = int.parse(AppConstants.defaultTimeoutMs);
  int _timeout2Ms = int.parse(AppConstants.defaultTimeout2Ms);
  ThemeMode _themeMode = ThemeMode.system;

  bool _keepScreenOn = false;
  bool _keepCpuAwake = false;

  SettingsProvider(this._storageService, [this._powerService]) {
    _loadSettings();
    _powerService?.batteryOptimizationStream.listen((_) => notifyListeners());
    _powerService?.wakeLockStream.listen((_) => notifyListeners());
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

    _keepScreenOn = _storageService.getKeepScreenOn();
    _keepCpuAwake = _storageService.getKeepCpuAwake();

    if (_powerService != null) {
      if (_keepScreenOn) _powerService.setKeepScreenOn(true);
      if (_keepCpuAwake) _powerService.setForcedCpuAwake(true);
      _powerService.checkBatteryOptimization();
    }

    notifyListeners();
  }

  String get favPort => _favPort;
  String get favIp => _favIp;
  int get timeoutMs => _timeoutMs;
  int get timeout2Ms => _timeout2Ms;
  ThemeMode get themeMode => _themeMode;

  bool get keepScreenOn => _keepScreenOn;
  bool get keepCpuAwake => _keepCpuAwake;
  bool get isIgnoringBattery => _powerService?.isIgnoringBattery ?? true;
  bool get isWakeLockHeld => _powerService?.isWakeLockHeld ?? false;

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

  Future<void> toggleKeepScreenOn(bool enable) async {
    _keepScreenOn = enable;
    await _storageService.setKeepScreenOn(enable);
    await _powerService?.setKeepScreenOn(enable);
    notifyListeners();
  }

  Future<void> toggleKeepCpuAwake(bool enable) async {
    _keepCpuAwake = enable;
    await _storageService.setKeepCpuAwake(enable);
    await _powerService?.setForcedCpuAwake(enable);
    notifyListeners();
  }

  Future<bool> requestDisableBatteryOptimization() async {
    final res = await _powerService?.requestDisableBatteryOptimization() ?? false;
    notifyListeners();
    return res;
  }

  Future<void> openBatterySettings() async {
    await _powerService?.openBatterySettings();
  }

  Future<void> refreshBatteryStatus() async {
    await _powerService?.checkBatteryOptimization();
    notifyListeners();
  }
}
