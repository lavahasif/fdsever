import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_recording_item.dart';
import '../services/call_recorder_bridge.dart';

class CallRecorderProvider extends ChangeNotifier {
  static const String _keyAutoRecord = 'call_recorder_auto_record';
  static const String _keyGain = 'call_recorder_gain';

  bool _isRecording = false;
  double _durationSeconds = 0.0;
  int _bytesWritten = 0;
  String _currentFilePath = '';
  int _latestAmplitude = 0;
  String _callState = 'IDLE';
  String _incomingNumber = '';
  bool _autoRecordEnabled = true;
  double _gainMultiplier = 1.8;
  String _statusMessage = 'Ready';

  List<CallRecordingItem> _recordings = [];
  Timer? _pollingTimer;

  bool get isRecording => _isRecording;
  double get durationSeconds => _durationSeconds;
  int get bytesWritten => _bytesWritten;
  String get currentFilePath => _currentFilePath;
  int get latestAmplitude => _latestAmplitude;
  String get callState => _callState;
  String get incomingNumber => _incomingNumber;
  bool get autoRecordEnabled => _autoRecordEnabled;
  double get gainMultiplier => _gainMultiplier;
  String get statusMessage => _statusMessage;
  List<CallRecordingItem> get recordings => List.unmodifiable(_recordings);

  String get formattedDuration {
    final totalSec = _durationSeconds.toInt();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${_twoDigits(mins)}:${_twoDigits(secs)}';
  }

  static String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';

  CallRecorderProvider() {
    _init();
  }

  Future<void> _init() async {
    CallRecorderBridge.init();

    final prefs = await SharedPreferences.getInstance();
    _autoRecordEnabled = prefs.getBool(_keyAutoRecord) ?? true;
    _gainMultiplier = prefs.getDouble(_keyGain) ?? 1.8;

    CallRecorderBridge.onCallStateChanged = (state, number) {
      _callState = state;
      _incomingNumber = number;
      if (state == 'OFFHOOK') {
        _statusMessage = 'Cellular Call Active';
      } else if (state == 'RINGING') {
        _statusMessage = 'Incoming Call Ringing ($number)';
      } else {
        _statusMessage = 'Phone Idle';
      }
      notifyListeners();
    };

    CallRecorderBridge.onRecorderStatus = (status) {
      if (status.startsWith('RECORDING_FINISHED:')) {
        _statusMessage = 'Recording Saved';
        refreshRecordings();
      } else if (status == 'RECORDING_ACTIVE') {
        _statusMessage = 'Acoustic Call Recording Active';
      } else if (status == 'MIC_INTERRUPTED_BY_OEM') {
        _statusMessage = '⚠️ Android or this device has made microphone capture unavailable during the call.';
      } else {
        _statusMessage = status;
      }
      notifyListeners();
    };

    await syncAutoRecordConfig();
    await checkInitialState();
    await refreshRecordings();

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollRecordingStats();
    });
  }

  Future<void> checkInitialState() async {
    _isRecording = await CallRecorderBridge.isRecording();
    _callState = await CallRecorderBridge.getCallState();
    notifyListeners();
  }

  Future<void> syncAutoRecordConfig() async {
    await CallRecorderBridge.setAutoRecord(_autoRecordEnabled, gain: _gainMultiplier);
  }

  Future<void> setAutoRecordEnabled(bool enabled) async {
    _autoRecordEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoRecord, enabled);
    await syncAutoRecordConfig();
    notifyListeners();
  }

  Future<void> setGainMultiplier(double gain) async {
    _gainMultiplier = gain;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGain, gain);
    await syncAutoRecordConfig();
    notifyListeners();
  }

  Future<bool> startManualRecording() async {
    final success = await CallRecorderBridge.startRecording(gain: _gainMultiplier);
    if (success) {
      _isRecording = true;
      _statusMessage = 'Recording Started';
      notifyListeners();
    }
    return success;
  }

  Future<bool> stopManualRecording() async {
    final success = await CallRecorderBridge.stopRecording();
    if (success) {
      _isRecording = false;
      _statusMessage = 'Recording Stopped';
      await refreshRecordings();
      notifyListeners();
    }
    return success;
  }

  Future<void> _pollRecordingStats() async {
    if (!_isRecording) {
      final rec = await CallRecorderBridge.isRecording();
      if (rec != _isRecording) {
        _isRecording = rec;
        notifyListeners();
      }
      return;
    }

    final stats = await CallRecorderBridge.getRecordingStats();
    if (stats.isNotEmpty) {
      _isRecording = stats['isRecording'] as bool? ?? false;
      _durationSeconds = (stats['durationSeconds'] as num?)?.toDouble() ?? 0.0;
      _bytesWritten = (stats['bytesWritten'] as num?)?.toInt() ?? 0;
      _currentFilePath = stats['filePath']?.toString() ?? '';
      _latestAmplitude = (stats['amplitude'] as num?)?.toInt() ?? 0;
      notifyListeners();
    }
  }

  Future<void> refreshRecordings() async {
    _recordings = await CallRecorderBridge.listRecordings();
    notifyListeners();
  }

  Future<bool> deleteRecording(String path) async {
    final success = await CallRecorderBridge.deleteRecording(path);
    if (success) {
      await refreshRecordings();
    }
    return success;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
