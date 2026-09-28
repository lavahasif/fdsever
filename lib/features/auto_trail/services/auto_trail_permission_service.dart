import 'dart:io';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:geolocator/geolocator.dart';

enum AutoTrailPermissionStatus {
  allGranted,
  foregroundOnly,
  denied,
  permanentlyDenied,
}

class AutoTrailPermissionService {
  /// Checks current permission state for both location and activity recognition.
  static Future<AutoTrailPermissionStatus> checkStatus() async {
    final locationStatus = await Geolocator.checkPermission();

    if (locationStatus == LocationPermission.deniedForever) {
      return AutoTrailPermissionStatus.permanentlyDenied;
    }

    if (locationStatus == LocationPermission.denied) {
      return AutoTrailPermissionStatus.denied;
    }

    if (locationStatus == LocationPermission.whileInUse) {
      // In Android, background location needs LocationPermission.always
      if (Platform.isAndroid || Platform.isIOS) {
        return AutoTrailPermissionStatus.foregroundOnly;
      }
      return AutoTrailPermissionStatus.allGranted;
    }

    if (locationStatus == LocationPermission.always) {
      return AutoTrailPermissionStatus.allGranted;
    }

    return AutoTrailPermissionStatus.denied;
  }

  /// Step 1: Request foreground fine location
  static Future<LocationPermission> requestForegroundLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Step 2: Request background location (Android 10+ requires separate prompt)
  static Future<LocationPermission> requestBackgroundLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse) {
      // Prompt second time for "Allow all the time"
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Request Activity Recognition permission for motion gating
  static Future<bool> requestActivityRecognition() async {
    try {
      final activityRec = FlutterActivityRecognition.instance;
      final check = await activityRec.checkPermission();
      if (check == ActivityPermission.GRANTED) {
        return true;
      }
      final req = await activityRec.requestPermission();
      return req == ActivityPermission.GRANTED;
    } catch (_) {
      return true; // Ignore if activity recognition is unsupported on platform
    }
  }

  /// Complete 2-step permission sequence
  static Future<AutoTrailPermissionStatus> requestAllPermissions() async {
    // 1. Foreground location
    var loc = await requestForegroundLocation();
    if (loc == LocationPermission.denied || loc == LocationPermission.deniedForever) {
      return loc == LocationPermission.deniedForever
          ? AutoTrailPermissionStatus.permanentlyDenied
          : AutoTrailPermissionStatus.denied;
    }

    // 2. Activity recognition
    await requestActivityRecognition();

    // 3. Background location (Android 10+)
    if (Platform.isAndroid || Platform.isIOS) {
      loc = await requestBackgroundLocation();
      if (loc != LocationPermission.always) {
        return AutoTrailPermissionStatus.foregroundOnly;
      }
    }

    return AutoTrailPermissionStatus.allGranted;
  }

  /// Open device app settings
  static Future<bool> openSettings() async {
    return await Geolocator.openAppSettings();
  }
}
