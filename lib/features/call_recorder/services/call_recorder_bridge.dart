import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/call_recording_item.dart';

class CallRecorderBridge {
  static const MethodChannel _channel = MethodChannel('fdserver/call_recorder');

  static Function(String state, String number)? onCallStateChanged;
  static Function(String status)? onRecorderStatus;
  static Function(Map<String, dynamic> status)? onAudioPlaybackStateChanged;

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
          case 'onAudioPlaybackStateChanged':
            final args = call.arguments as Map?;
            if (args != null) {
              onAudioPlaybackStateChanged?.call(Map<String, dynamic>.from(args));
            }
            break;
        }
      });
    }
  }

  static Future<bool> startRecording({String? path, double gain = 5.0, String? phoneNumber}) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final args = <String, dynamic>{'gain': gain};
      if (path != null) args['path'] = path;
      if (phoneNumber != null) args['phoneNumber'] = phoneNumber;
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
      return res != null ? Map<String, dynamic>.from(res) : {};
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

  static Future<bool> setAutoRecord(bool enabled, {double gain = 5.0}) async {
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

  static Future<bool> setVoipRecording(bool enabled, {double gain = 5.0}) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('setVoipRecording', {
        'enabled': enabled,
        'gain': gain,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error setting VoIP recording: $e');
      return false;
    }
  }

  static Future<Map<String, bool>> getVoipStatus() async {
    if (kIsWeb || !Platform.isAndroid) return {'armed': false, 'callActive': false};
    init();
    try {
      final res = await _channel.invokeMapMethod<String, bool>('getVoipStatus');
      return res != null ? Map<String, bool>.from(res) : {'armed': false, 'callActive': false};
    } catch (e) {
      return {'armed': false, 'callActive': false};
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

  static Future<bool> updateRecordingMetadata({
    required String path,
    required String phoneNumber,
    String contactName = '',
    String notes = '',
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('updateRecordingMetadata', {
        'path': path,
        'phoneNumber': phoneNumber,
        'contactName': contactName,
        'notes': notes,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error updating recording metadata: $e');
      return false;
    }
  }

  static Future<bool> playAudio(String path) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('playAudio', {'path': path});
      return res ?? false;
    } catch (e) {
      debugPrint('Error playing audio: $e');
      return false;
    }
  }

  static Future<bool> pauseAudio() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('pauseAudio');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> resumeAudio() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('resumeAudio');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopAudio() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('stopAudio');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> seekAudio(int positionMs) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('seekAudio', {'positionMs': positionMs});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> openWithExternalPlayer(String path) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('openWithExternalPlayer', {'path': path});
      return res ?? false;
    } catch (e) {
      debugPrint('Error launching external audio player: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getAudioPlayerState() async {
    if (kIsWeb || !Platform.isAndroid) return {};
    init();
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getAudioPlayerState');
      return res != null ? Map<String, dynamic>.from(res) : {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, bool>> hasPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      return {'audio': true, 'phone': true, 'callLog': true, 'notifications': true, 'allGranted': true};
    }
    init();
    try {
      final res = await _channel.invokeMapMethod<String, bool>('hasPermissions');
      if (res != null) {
        return Map<String, bool>.from(res);
      }
    } catch (e) {
      debugPrint('Error checking call recorder permissions: $e');
    }
    return {'audio': false, 'phone': false, 'callLog': false, 'notifications': false, 'allGranted': false};
  }

  static Future<bool> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    init();
    try {
      final res = await _channel.invokeMethod<bool>('requestPermissions');
      return res ?? false;
    } catch (e) {
      debugPrint('Error requesting call recorder permissions: $e');
      return false;
    }
  }
}
