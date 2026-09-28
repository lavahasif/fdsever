import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import '../database/trail_database.dart';
import '../models/trail_point.dart';

/// Core passive background location service for Auto Trail.
/// Designed for minimal battery consumption using activity recognition gating,
/// medium accuracy, 100m distance filtering, and batch SQLite writes.
class AutoTrailService {
  static final AutoTrailService instance = AutoTrailService._init();
  final FlutterBackgroundService _service = FlutterBackgroundService();

  AutoTrailService._init();

  /// Configures and registers the background service.
  Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStartBackgroundService,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'auto_trail_service',
        initialNotificationTitle: 'Auto Trail running',
        initialNotificationContent: 'Passive location memory active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStartBackgroundService,
        autoStart: false,
      ),
    );
  }

  /// Checks if background service is currently active.
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  /// Starts background passive tracking.
  Future<bool> startService() async {
    return await _service.startService();
  }

  /// Stops background tracking.
  void stopService() {
    _service.invoke('stopService');
  }

  /// Manually triggers a single location capture and logs it.
  Future<TrailPoint?> recordCurrentLocationNow({String? customActivity}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final address = await reverseGeocode(position.latitude, position.longitude);
      final point = TrailPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accuracy: position.accuracy,
        activity: customActivity ?? 'manual',
      );

      await TrailDatabase.instance.insertPoint(point);
      return point;
    } catch (_) {
      return null;
    }
  }

  /// Listens to real-time updates broadcast from background service isolate.
  Stream<Map<String, dynamic>?> onServiceUpdate() {
    return _service.on('update');
  }

  /// Reverse geocodes coordinates to human readable address with offline fallback.
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
        if (p.subLocality != null &&
            p.subLocality!.isNotEmpty &&
            !parts.contains(p.subLocality!)) {
          parts.add(p.subLocality!);
        }
        if (p.locality != null &&
            p.locality!.isNotEmpty &&
            !parts.contains(p.locality!)) {
          parts.add(p.locality!);
        }
        if (p.administrativeArea != null &&
            p.administrativeArea!.isNotEmpty &&
            !parts.contains(p.administrativeArea!)) {
          parts.add(p.administrativeArea!);
        }

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Offline fallback: geocoding failed or device has no network
    }
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}

/// Top-level background isolate entry point for FlutterBackgroundService.
@pragma('vm:entry-point')
Future<void> onStartBackgroundService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  StreamSubscription<Position>? positionSubscription;
  StreamSubscription<Activity>? activitySubscription;
  Timer? batchFlushTimer;

  final List<TrailPoint> batchBuffer = [];
  TrailPoint? lastRecordedPoint;
  String currentActivity = 'unknown';
  bool isStationary = false;

  // Retrieve last logged point from SQLite to maintain distance threshold across restarts
  try {
    lastRecordedPoint = await TrailDatabase.instance.getLastPoint();
  } catch (_) {}

  // Flush buffer to SQLite
  Future<void> flushBatchBuffer() async {
    if (batchBuffer.isEmpty) return;
    final toWrite = List<TrailPoint>.from(batchBuffer);
    batchBuffer.clear();
    try {
      await TrailDatabase.instance.insertBatch(toWrite);
    } catch (_) {}
  }

  void scheduleBatchFlush() {
    batchFlushTimer?.cancel();
    batchFlushTimer = Timer(const Duration(seconds: 30), () async {
      await flushBatchBuffer();
    });
  }

  // Update notification info on Android
  void updateNotification(String statusText) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Auto Trail running',
        content: statusText,
      );
    }
  }

  // Handle position event from Geolocator
  Future<void> handlePosition(Position position) async {
    // Check stationary threshold against last recorded point (minimum 50 meters)
    if (lastRecordedPoint != null) {
      final distance = Geolocator.distanceBetween(
        lastRecordedPoint!.latitude,
        lastRecordedPoint!.longitude,
        position.latitude,
        position.longitude,
      );

      // If under 50m, treat as stationary and skip saving to conserve battery and avoid noise
      if (distance < 50.0) {
        return;
      }
    }

    final address = await AutoTrailService.reverseGeocode(
      position.latitude,
      position.longitude,
    );

    final newPoint = TrailPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      accuracy: position.accuracy,
      activity: currentActivity,
    );

    lastRecordedPoint = newPoint;
    batchBuffer.add(newPoint);

    // Update foreground notification
    updateNotification('Logged: $address');

    // Notify UI in real time
    service.invoke('update', {
      'event': 'new_point',
      'point': newPoint.toMap(),
      'activity': currentActivity,
    });

    // Batch write: if 3 or more points collected, flush immediately, otherwise debounce 30s
    if (batchBuffer.length >= 3) {
      await flushBatchBuffer();
    } else {
      scheduleBatchFlush();
    }
  }

  // Start polling GPS with medium accuracy & 100m distance filter
  void startPositionListening() {
    if (positionSubscription != null) return;

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.medium, // Battery-conscious: medium accuracy
      distanceFilter: 100, // Only fire after 100m movement
    );

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        handlePosition(position);
      },
      onError: (_) {
        // Handle stream errors silently
      },
    );

    updateNotification('Passive tracking active');
  }

  // Stop polling GPS when still
  void stopPositionListening() {
    positionSubscription?.cancel();
    positionSubscription = null;
    updateNotification('Idle (movement paused)');
  }

  // Initialize activity recognition to gate tracking
  try {
    final activityRec = FlutterActivityRecognition.instance;
    activitySubscription = activityRec.activityStream.listen((activity) {
      currentActivity = activity.type.name.toLowerCase();

      if (activity.type == ActivityType.STILL) {
        isStationary = true;
        // User is still -> stop polling GPS completely to save battery
        stopPositionListening();
      } else {
        isStationary = false;
        // User is moving -> start listening to movement stream
        startPositionListening();
      }

      service.invoke('update', {
        'event': 'activity_change',
        'activity': currentActivity,
        'confidence': activity.confidence.name,
      });
    }, onError: (_) {
      // If activity recognition fails or isn't available, keep standard distance-filtered tracking
      startPositionListening();
    });
  } catch (_) {
    startPositionListening();
  }

  // By default start distance-filtered listening until activity stream reports still
  if (!isStationary) {
    startPositionListening();
  }

  // Listen to commands from main app
  service.on('stopService').listen((event) async {
    await flushBatchBuffer();
    batchFlushTimer?.cancel();
    await positionSubscription?.cancel();
    await activitySubscription?.cancel();
    await service.stopSelf();
  });

  service.on('flush').listen((event) async {
    await flushBatchBuffer();
  });
}
