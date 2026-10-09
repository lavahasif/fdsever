import 'dart:async';
import 'package:flutter/services.dart';
import '../models/meeting_recording.dart';
import '../models/meeting_schedule.dart';

class MeetingRecorderBridgeService {
  static const MethodChannel _channel = MethodChannel('fdserver/meeting_recorder');
  static const EventChannel _statusChannel = EventChannel('fdserver/meeting_recorder_status');
  static const EventChannel _playbackChannel = EventChannel('fdserver/meeting_recorder_playback');

  static final MeetingRecorderBridgeService _instance = MeetingRecorderBridgeService._internal();
  factory MeetingRecorderBridgeService() => _instance;
  MeetingRecorderBridgeService._internal();

  Stream<Map<dynamic, dynamic>>? _statusStream;
  Stream<Map<dynamic, dynamic>> get statusStream {
    _statusStream ??= _statusChannel
        .receiveBroadcastStream()
        .map((event) => event is Map ? event : <dynamic, dynamic>{});
    return _statusStream!;
  }

  Stream<Map<dynamic, dynamic>>? _playbackStream;
  Stream<Map<dynamic, dynamic>> get playbackStream {
    _playbackStream ??= _playbackChannel
        .receiveBroadcastStream()
        .map((event) => event is Map ? event : <dynamic, dynamic>{});
    return _playbackStream!;
  }

  // --- Recorder & Standby Controls ---

  Future<bool> startStandby() async {
    try {
      final res = await _channel.invokeMethod<bool>('startStandby');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopStandby() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopStandby');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isStandbyActive() async {
    try {
      final res = await _channel.invokeMethod<bool>('isStandbyActive');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startRecording({String trigger = 'manual'}) async {
    try {
      final res = await _channel.invokeMethod<bool>('startRecording', {'trigger': trigger});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopRecording() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopRecording');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getRecordingStatus() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getRecordingStatus');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {
      'isStandby': false,
      'isRecording': false,
      'currentRecordingPath': '',
      'startTimeMs': 0,
      'latestAmplitude': 0,
    };
  }

  // --- Recordings Library ---

  Future<List<MeetingRecording>> getRecordings() async {
    try {
      final rawList = await _channel.invokeListMethod<dynamic>('getRecordings');
      if (rawList != null) {
        return rawList
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => MeetingRecording.fromMap(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> renameRecording(int id, String newTitle) async {
    try {
      final res = await _channel.invokeMethod<bool>('renameRecording', {
        'id': id,
        'newTitle': newTitle,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateRecordingNotes(int id, String notes, String tags) async {
    try {
      final res = await _channel.invokeMethod<bool>('updateRecordingNotes', {
        'id': id,
        'notes': notes,
        'tags': tags,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteRecording(int id) async {
    try {
      final res = await _channel.invokeMethod<bool>('deleteRecording', {'id': id});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  // --- Decoupled Focus Schedules ---

  Future<List<MeetingSchedule>> getSchedules() async {
    try {
      final rawList = await _channel.invokeListMethod<dynamic>('getSchedules');
      if (rawList != null) {
        return rawList
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => MeetingSchedule.fromMap(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<int> saveSchedule(MeetingSchedule schedule) async {
    try {
      final res = await _channel.invokeMethod<int>('saveSchedule', {
        'schedule': schedule.toMap(),
      });
      return res ?? -1;
    } catch (_) {
      return -1;
    }
  }

  Future<bool> deleteSchedule(int id) async {
    try {
      final res = await _channel.invokeMethod<bool>('deleteSchedule', {'id': id});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleSchedule(int id, bool isEnabled) async {
    try {
      final res = await _channel.invokeMethod<bool>('toggleSchedule', {
        'id': id,
        'isEnabled': isEnabled,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> previewAlarm({
    required String soundMode,
    String? ringtoneUri,
    double volume = 0.8,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('previewAlarm', {
        'soundMode': soundMode,
        'ringtoneUri': ringtoneUri,
        'volume': volume,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopAlarmPreview() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopAlarmPreview');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  // --- Audio Player ---

  Future<bool> playAudio(String path) async {
    try {
      final res = await _channel.invokeMethod<bool>('playAudio', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pauseAudio() async {
    try {
      final res = await _channel.invokeMethod<bool>('pauseAudio');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resumeAudio() async {
    try {
      final res = await _channel.invokeMethod<bool>('resumeAudio');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopAudio() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopAudio');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> seekAudio(int positionMs) async {
    try {
      final res = await _channel.invokeMethod<bool>('seekAudio', {'positionMs': positionMs});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
