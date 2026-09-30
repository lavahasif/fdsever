import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/call_recording_item.dart';

class CallRecorderBridge {
  static const MethodChannel _channel = MethodChannel('fdserver/call_recorder');

  static Function(String state, String number)? onCallStateChanged;
  static Function(String status)? onRecorderStatus;

  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onCallStateChanged':
            final args = call.arguments as Map?;
            final state = args?['state'] as String? ?? 'IDLE';
            final number = args?['number'] as String? ?? '';
            onCallStateChanged?.call(state, number);
            break;
          case 'onRecorderStatus':
            final status = call.arguments as String? ?? '';
            onRecorderStatus?.call(status);
            break;
        }
      });
    }
  }

  static Future<bool> startRecording({String? path, double gain = 1.8}) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final args = <String, dynamic>{'gain': gain};
      if (path != null) args['path'] = path;
      final res = await _channel.invokeMethod<bool>('startRecording', args);
      return res ?? false;
    } catch (e) {
      debugPrint('Error starting call recording: $e');
      return false;
    }
  }

  static Future<bool> stopRecording() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('stopRecording');
      return res ?? false;
    } catch (e) {
      debugPrint('Error stopping call recording: $e');
      return false;
    }
  }

  static Future<bool> isRecording() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('isRecording');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getRecordingStats() async {
    if (kIsWeb || !Platform.isAndroid) return {};
    init();
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getRecordingStats');
      return res ?? {};
    } catch (e) {
      return {};
    }
  }

  static Future<String> getCallState() async {
    if (kIsWeb || !Platform.isAndroid) return 'IDLE';
    init();
    try {
      final res = await _channel.invokeMethod<String>('getCallState');
      return res ?? 'IDLE';
    } catch (e) {
      return 'IDLE';
    }
  }

  static Future<bool> setAutoRecord(bool enabled, {double gain = 1.8}) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('setAutoRecord', {
        'enabled': enabled,
        'gain': gain,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<CallRecordingItem>> listRecordings() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    init();
    try {
      final list = await _channel.invokeListMethod<dynamic>('listRecordings');
      if (list == null) return [];
      return list.map((item) => CallRecordingItem.fromMap(Map<dynamic, dynamic>.from(item as Map))).toList();
    } catch (e) {
      debugPrint('Error listing recordings: $e');
      return [];
    }
  }

  static Future<bool> deleteRecording(String path) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('deleteRecording', {'path': path});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }
}
