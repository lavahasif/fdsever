import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Represents a single APK install job in the queue
class ApkInstallJob {
  final String id;
  final String name;
  final List<int> bytes;
  ApkInstallStatus status;
  String? errorMessage;
  DateTime enqueuedAt;

  ApkInstallJob({
    required this.id,
    required this.name,
    required this.bytes,
    this.status = ApkInstallStatus.pending,
    this.errorMessage,
    DateTime? enqueuedAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();
}

enum ApkInstallStatus { pending, installing, success, failed }

/// Event emitted by ApkInstallService for real-time UI updates
class ApkInstallEvent {
  final String jobId;
  final String apkName;
  final ApkInstallStatus status;
  final String? message;
  final DateTime timestamp;

  ApkInstallEvent({
    required this.jobId,
    required this.apkName,
    required this.status,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Service that receives APK bytes, saves them to cache, and triggers
/// Android PackageInstaller via a Kotlin platform channel.
class ApkInstallService {
  static const _channel = MethodChannel('fdserver/apk_install');

  final _eventController = StreamController<ApkInstallEvent>.broadcast();
  final List<ApkInstallEvent> _recentEvents = [];
  final Queue<ApkInstallJob> _queue = Queue();
  bool _isProcessing = false;

  Stream<ApkInstallEvent> get events => _eventController.stream;
  List<ApkInstallEvent> get recentEvents => List.unmodifiable(_recentEvents);
  bool get isProcessing => _isProcessing;
  int get queueLength => _queue.length;

  /// Enqueue an APK for installation.
  /// [apkName] - filename (e.g. "myapp.apk")
  /// [bytes] - raw APK bytes received from HTTP or WebSocket
  Future<void> enqueue(String apkName, List<int> bytes) async {
    final job = ApkInstallJob(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      name: apkName,
      bytes: bytes,
    );
    _queue.add(job);
    _emit(job, ApkInstallStatus.pending, 'Queued (${bytes.length ~/ 1024} KB)');

    if (!_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    _isProcessing = true;
    while (_queue.isNotEmpty) {
      final job = _queue.removeFirst();
      await _installJob(job);
    }
    _isProcessing = false;
  }

  Future<void> _installJob(ApkInstallJob job) async {
    try {
      _emit(job, ApkInstallStatus.installing, 'Saving APK to cache...');

      // Save bytes to app cache directory
      final cacheDir = await getTemporaryDirectory();
      final apkCacheDir = Directory('${cacheDir.path}/apk_cache');
      if (!apkCacheDir.existsSync()) apkCacheDir.createSync(recursive: true);

      // Clean up old APKs in cache (keep last 5)
      final existing = apkCacheDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.apk'))
          .toList()
        ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      if (existing.length >= 5) {
        existing.take(existing.length - 4).forEach((f) => f.deleteSync());
      }

      final apkFile = File('${apkCacheDir.path}/${job.name}');
      await apkFile.writeAsBytes(job.bytes, flush: true);

      _emit(job, ApkInstallStatus.installing, 'Triggering PackageInstaller...');

      // Check permission first
      final canInstall = await _channel.invokeMethod<bool>('canInstallApks') ?? false;
      if (!canInstall) {
        // Will open Settings — user needs to grant permission
        await _channel.invokeMethod('installApk', {'path': apkFile.path});
        _emit(job, ApkInstallStatus.failed,
            'Grant "Install Unknown Apps" permission to FDServer in Settings, then retry.');
        return;
      }

      // Launch install intent
      final result = await _channel.invokeMethod<String>('installApk', {
        'path': apkFile.path,
      });

      _emit(job, ApkInstallStatus.success,
          result == 'launched' ? 'PackageInstaller opened ✓' : result ?? 'Done');
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_REQUIRED') {
        _emit(job, ApkInstallStatus.failed,
            'Enable "Install Unknown Apps" in Settings for FDServer, then retry.');
      } else {
        _emit(job, ApkInstallStatus.failed, 'Error: ${e.message}');
      }
    } catch (e) {
      _emit(job, ApkInstallStatus.failed, 'Unexpected error: $e');
    }
  }

  void _emit(ApkInstallJob job, ApkInstallStatus status, String message) {
    final event = ApkInstallEvent(
      jobId: job.id,
      apkName: job.name,
      status: status,
      message: message,
    );
    _recentEvents.insert(0, event);
    if (_recentEvents.length > 50) _recentEvents.removeLast();
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
  }
}
