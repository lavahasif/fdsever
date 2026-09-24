import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Service managing Android PowerManager WakeLock, KeepScreenOn,
/// and Battery Optimization (Doze mode exemption) to prevent servers,
/// proxy tunnels, and the APK auto installer from pausing when the screen turns off.
class PowerService {
  static const MethodChannel _channel = MethodChannel('fdserver/power');

  final Set<String> _activeConsumers = <String>{};
  bool _isIgnoringBattery = false;
  bool _isScreenKeepOn = false;
  bool _isForcedCpuAwake = false;

  final StreamController<bool> _batteryOptController = StreamController<bool>.broadcast();
  final StreamController<bool> _wakeLockController = StreamController<bool>.broadcast();

  Stream<bool> get batteryOptimizationStream => _batteryOptController.stream;
  Stream<bool> get wakeLockStream => _wakeLockController.stream;

  bool get isIgnoringBattery => _isIgnoringBattery;
  bool get isWakeLockHeld => _activeConsumers.isNotEmpty || _isForcedCpuAwake;
  bool get isScreenKeepOn => _isScreenKeepOn;
  bool get isForcedCpuAwake => _isForcedCpuAwake;
  Set<String> get activeConsumers => Set.unmodifiable(_activeConsumers);

  Future<void> init({bool initialKeepScreenOn = false, bool initialKeepCpuAwake = false}) async {
    if (!Platform.isAndroid) return;

    await checkBatteryOptimization();
    if (initialKeepScreenOn) {
      await setKeepScreenOn(true);
    }
    if (initialKeepCpuAwake) {
      await setForcedCpuAwake(true);
    }
  }

  /// Checks whether Android has battery optimization disabled (unrestricted) for this app
  Future<bool> checkBatteryOptimization() async {
    if (!Platform.isAndroid) {
      _isIgnoringBattery = true;
      return true;
    }
    try {
      final isIgnoring = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      if (_isIgnoringBattery != isIgnoring) {
        _isIgnoringBattery = isIgnoring;
        _batteryOptController.add(isIgnoring);
      }
      return isIgnoring;
    } catch (_) {
      return false;
    }
  }

  /// Launches the Android system dialog requesting to remove Battery Optimization for FDServer
  Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    try {
      final success = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
      await Future.delayed(const Duration(milliseconds: 500));
      await checkBatteryOptimization();
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Android Battery Optimization Settings list as a fallback
  Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  /// Requests a Partial WakeLock for a specific subsystem or operation
  /// e.g. [consumerTag] = "apk_download", "proxy_forward", "proxy_reverse"
  Future<bool> acquireWakeLock(String consumerTag) async {
    _activeConsumers.add(consumerTag);
    _wakeLockController.add(isWakeLockHeld);

    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('acquireWakeLock', {'tag': 'fdserver:$consumerTag'}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Releases a Partial WakeLock for a specific subsystem or operation
  Future<bool> releaseWakeLock(String consumerTag) async {
    _activeConsumers.remove(consumerTag);
    _wakeLockController.add(isWakeLockHeld);

    if (!Platform.isAndroid) return true;
    if (_activeConsumers.isEmpty && !_isForcedCpuAwake) {
      try {
        return await _channel.invokeMethod<bool>('releaseWakeLock') ?? false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// User setting toggle to keep CPU awake continuously
  Future<void> setForcedCpuAwake(bool enable) async {
    _isForcedCpuAwake = enable;
    _wakeLockController.add(isWakeLockHeld);

    if (!Platform.isAndroid) return;
    try {
      if (enable) {
        await _channel.invokeMethod<bool>('acquireWakeLock', {'tag': 'fdserver:forced_user_lock'});
      } else if (_activeConsumers.isEmpty) {
        await _channel.invokeMethod<bool>('releaseWakeLock');
      }
    } catch (_) {}
  }

  /// Toggles the FLAG_KEEP_SCREEN_ON window flag so the screen doesn't turn off
  Future<bool> setKeepScreenOn(bool enable) async {
    _isScreenKeepOn = enable;

    if (!Platform.isAndroid) return true;
    try {
      final success = await _channel.invokeMethod<bool>('setKeepScreenOn', {'enable': enable}) ?? false;
      return success;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _batteryOptController.close();
    _wakeLockController.close();
  }
}
