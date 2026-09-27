import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashBreadcrumb {
  final String timestamp;
  final String category;
  final String message;

  const CrashBreadcrumb({
    required this.timestamp,
    required this.category,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'category': category,
        'message': message,
      };

  factory CrashBreadcrumb.fromJson(Map<String, dynamic> json) => CrashBreadcrumb(
        timestamp: json['timestamp'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        message: json['message'] as String? ?? '',
      );

  @override
  String toString() => '[$timestamp] ($category) $message';
}

class CrashLogItem {
  final String id;
  final String timestamp;
  final String isoTimestamp;
  final String type;
  final String component;
  final String message;
  final String stackTrace;
  final String deviceModel;
  final String osVersion;
  final List<CrashBreadcrumb> breadcrumbs;
  final Map<String, dynamic> contextData;

  const CrashLogItem({
    required this.id,
    required this.timestamp,
    required this.isoTimestamp,
    required this.type,
    required this.component,
    required this.message,
    required this.stackTrace,
    required this.deviceModel,
    required this.osVersion,
    this.breadcrumbs = const [],
    this.contextData = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'isoTimestamp': isoTimestamp,
        'type': type,
        'component': component,
        'message': message,
        'stackTrace': stackTrace,
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'breadcrumbs': breadcrumbs.map((b) => b.toJson()).toList(),
        'contextData': contextData,
      };

  factory CrashLogItem.fromJson(Map<String, dynamic> json) {
    final rawBreadcrumbs = json['breadcrumbs'] as List<dynamic>? ?? [];
    return CrashLogItem(
      id: json['id'] as String? ?? 'crash_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] as String? ?? '',
      isoTimestamp: json['isoTimestamp'] as String? ?? '',
      type: json['type'] as String? ?? 'EXCEPTION',
      component: json['component'] as String? ?? 'App',
      message: json['message'] as String? ?? 'Unknown error',
      stackTrace: json['stackTrace'] as String? ?? '',
      deviceModel: json['deviceModel'] as String? ?? 'Unknown Device',
      osVersion: json['osVersion'] as String? ?? 'Unknown OS',
      breadcrumbs: rawBreadcrumbs
          .whereType<Map<String, dynamic>>()
          .map((b) => CrashBreadcrumb.fromJson(b))
          .toList(),
      contextData: (json['contextData'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Formats this crash into a structured Markdown prompt optimized for AI diagnosis
  String toAiPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('### 🚨 FDServer Crash & Exception Report for AI Diagnosis');
    buffer.writeln();
    buffer.writeln('Please analyze this crash report from **FDServer** (a Flutter + Android desktop/mobile server app).');
    buffer.writeln('Identify the exact root cause, explain why it occurred, and provide the exact code changes or configuration required to resolve it.');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('#### 📌 Failure Overview');
    buffer.writeln('- **Error Type**: `$type`');
    buffer.writeln('- **Component / Origin**: `$component`');
    buffer.writeln('- **Timestamp**: `$timestamp` ($isoTimestamp)');
    buffer.writeln('- **Error Message**:');
    buffer.writeln('```');
    buffer.writeln(message.trim());
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('#### 📱 Device & Environment');
    buffer.writeln('- **Device Model**: $deviceModel');
    buffer.writeln('- **OS Version**: $osVersion');
    buffer.writeln('- **Platform**: ${kIsWeb ? "Web" : Platform.operatingSystem} (${Platform.operatingSystemVersion})');
    buffer.writeln('- **Flutter Mode**: ${kReleaseMode ? "Release" : (kDebugMode ? "Debug" : "Profile")}');
    if (contextData.isNotEmpty) {
      buffer.writeln('- **Additional Context**:');
      contextData.forEach((k, v) {
        buffer.writeln('  - **$k**: $v');
      });
    }
    buffer.writeln();

    if (breadcrumbs.isNotEmpty) {
      buffer.writeln('#### 👣 Recent Activity Breadcrumbs (Actions before crash)');
      for (int i = 0; i < breadcrumbs.length; i++) {
        final b = breadcrumbs[i];
        buffer.writeln('${i + 1}. `[${b.timestamp}]` **${b.category}**: ${b.message}');
      }
      buffer.writeln();
    }

    buffer.writeln('#### 🔍 Full Stack Trace');
    buffer.writeln('```');
    if (stackTrace.trim().isNotEmpty) {
      buffer.writeln(stackTrace.trim());
    } else {
      buffer.writeln('No stack trace was captured for this event.');
    }
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('#### 🎯 Specific Instructions for AI:');
    buffer.writeln('1. **Root Cause**: Why did this exception get thrown given the environment and recent breadcrumbs?');
    buffer.writeln('2. **Android / Flutter Specifics**: Is this due to permissions, foreground service limits, missing threads, port collisions, or unhandled nulls?');
    buffer.writeln('3. **Step-by-step Solution**: Provide code edits with exact filenames to fix and prevent this permanently.');

    return buffer.toString();
  }
}

class CrashLogService extends ChangeNotifier {
  static final CrashLogService _instance = CrashLogService._internal();
  factory CrashLogService() => _instance;
  CrashLogService._internal();

  static const String _prefCrashLogsKey = 'fdserver_crash_logs_v1';
  static const MethodChannel _nativeChannel = MethodChannel('fdserver/crash_logs');

  final List<CrashLogItem> _logs = [];
  final List<CrashBreadcrumb> _breadcrumbs = [];
  static const int _maxBreadcrumbs = 30;
  static const int _maxLogs = 60;

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  List<CrashLogItem> get logs => List.unmodifiable(_logs);
  List<CrashBreadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);
  int get errorCount => _logs.length;
  bool get hasCrashes => _logs.isNotEmpty;

  /// Initialize service, load persisted logs, and sync any native crashes
  Future<void> init([SharedPreferences? prefs]) async {
    if (_isInitialized) return;
    _prefs = prefs ?? await SharedPreferences.getInstance();
    _isInitialized = true;

    // Load persisted Flutter crash logs
    final rawList = _prefs?.getStringList(_prefCrashLogsKey) ?? [];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _logs.add(CrashLogItem.fromJson(map));
      } catch (_) {}
    }

    // Record app launch breadcrumb
    addBreadcrumb('System', 'App initialized (Platform: ${Platform.operatingSystem})');

    // Fetch any JVM/Native Android crash logs stored by CrashRecorder
    await syncNativeCrashLogs();
  }

  /// Add an activity breadcrumb (e.g. user pressed a button, switched tab, started server)
  void addBreadcrumb(String category, String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    _breadcrumbs.add(CrashBreadcrumb(
      timestamp: timestamp,
      category: category,
      message: message,
    ));

    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Fetch and merge native Android crashes captured by CrashRecorder
  Future<void> syncNativeCrashLogs() async {
    if (!Platform.isAndroid) return;
    try {
      final rawJson = await _nativeChannel.invokeMethod<String>('getNativeCrashLogs');
      if (rawJson != null && rawJson.isNotEmpty && rawJson != '[]') {
        final list = jsonDecode(rawJson) as List<dynamic>;
        bool addedNew = false;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String? ?? 'native_${DateTime.now().millisecondsSinceEpoch}';
            // Avoid duplicate entries
            if (!_logs.any((l) => l.id == id)) {
              _logs.insert(
                0,
                CrashLogItem(
                  id: id,
                  timestamp: item['timestamp'] as String? ?? '',
                  isoTimestamp: item['isoTimestamp'] as String? ?? '',
                  type: item['type'] as String? ?? 'NATIVE_ANDROID_CRASH',
                  component: item['component'] as String? ?? 'AndroidNative',
                  message: item['message'] as String? ?? 'Native exception occurred',
                  stackTrace: item['stackTrace'] as String? ?? '',
                  deviceModel: item['deviceModel'] as String? ?? 'Android Device',
                  osVersion: item['androidVersion'] as String? ?? '',
                  breadcrumbs: List.from(_breadcrumbs),
                  contextData: (item['context'] as Map<String, dynamic>?) ?? {},
                ),
              );
              addedNew = true;
            }
          }
        }

        if (addedNew) {
          await _persistLogs();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[CrashLogService] Error syncing native crashes: $e');
    }
  }

  /// Record a Flutter UI framework error (from FlutterError.onError)
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    final now = DateTime.now();
    final log = CrashLogItem(
      id: 'flutter_${now.millisecondsSinceEpoch}',
      timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      isoTimestamp: now.toIso8601String(),
      type: 'FLUTTER_FRAMEWORK_ERROR',
      component: details.library ?? 'FlutterUI',
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString() ?? '',
      deviceModel: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      breadcrumbs: List.from(_breadcrumbs),
      contextData: {
        'summary': details.summary.toString(),
        'context': details.context?.toString() ?? '',
      },
    );

    await _insertLog(log);
  }

  /// Record an unhandled asynchronous Dart exception
  Future<void> recordAsyncError(Object error, StackTrace stack, {String component = 'AsyncDart'}) async {
    final now = DateTime.now();
    final log = CrashLogItem(
      id: 'async_${now.millisecondsSinceEpoch}',
      timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      isoTimestamp: now.toIso8601String(),
      type: 'ASYNC_UNHANDLED_EXCEPTION',
      component: component,
      message: error.toString(),
      stackTrace: stack.toString(),
      deviceModel: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      breadcrumbs: List.from(_breadcrumbs),
    );

    await _insertLog(log);
  }

  /// Manually record a caught feature error (e.g. from VPN, Forward Proxy, or Network failure)
  Future<void> recordManualError(
    String component,
    Object error, [
    StackTrace? stack,
    Map<String, dynamic>? extra,
  ]) async {
    final now = DateTime.now();
    final log = CrashLogItem(
      id: 'manual_${now.millisecondsSinceEpoch}',
      timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      isoTimestamp: now.toIso8601String(),
      type: 'CAUGHT_RUNTIME_ERROR',
      component: component,
      message: error.toString(),
      stackTrace: stack?.toString() ?? '',
      deviceModel: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      breadcrumbs: List.from(_breadcrumbs),
      contextData: extra ?? {},
    );

    await _insertLog(log);
  }

  Future<void> _insertLog(CrashLogItem log) async {
    _logs.insert(0, log);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    await _persistLogs();
    notifyListeners();
  }

  Future<void> _persistLogs() async {
    final rawList = _logs.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs?.setStringList(_prefCrashLogsKey, rawList);
  }

  /// Clear all crash and error logs
  Future<void> clearAllLogs() async {
    _logs.clear();
    await _prefs?.remove(_prefCrashLogsKey);
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('clearNativeCrashLogs');
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Generates a master AI diagnostic prompt combining all recent crashes
  String generateFullDiagnosticsAiPrompt() {
    if (_logs.isEmpty) {
      return '### ✅ FDServer Diagnostics: Clean State\nNo active crash or exception logs have been recorded in FDServer.';
    }

    final buffer = StringBuffer();
    buffer.writeln('### 🚨 FDServer Comprehensive Diagnostic & Crash Report for AI');
    buffer.writeln();
    buffer.writeln('**Total Recorded Events**: ${_logs.length}');
    buffer.writeln('**Report Generated**: ${DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now())}');
    buffer.writeln('**Platform**: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})');
    buffer.writeln();
    buffer.writeln('Below are the crash/exception events recorded in FDServer in chronological order (newest first).');
    buffer.writeln('Please review each issue, pinpoint root causes, and provide code fixes.');
    buffer.writeln();

    for (int i = 0; i < _logs.length; i++) {
      final log = _logs[i];
      buffer.writeln('---');
      buffer.writeln('### Event #${i + 1}: [${log.type}] ${log.component}');
      buffer.writeln('- **Timestamp**: ${log.timestamp}');
      buffer.writeln('- **Message**: `${log.message}`');
      if (log.breadcrumbs.isNotEmpty) {
        buffer.writeln('- **Preceding Breadcrumbs**:');
        for (final b in log.breadcrumbs.take(5)) {
          buffer.writeln('  - `[${b.timestamp}]` ${b.category}: ${b.message}');
        }
      }
      buffer.writeln('- **Stack Trace**:');
      buffer.writeln('```');
      buffer.writeln(log.stackTrace.trim().isNotEmpty ? log.stackTrace.trim() : 'No stack trace captured.');
      buffer.writeln('```');
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('#### 🎯 AI Response Instructions:');
    buffer.writeln('1. Focus on the most recent crashes first.');
    buffer.writeln('2. Clearly distinguish between Android foreground service/permission crashes and Flutter/Dart runtime errors.');
    buffer.writeln('3. Provide production-ready, bulletproof code corrections with filenames.');

    return buffer.toString();
  }
}
