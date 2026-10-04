import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_recording_item.dart';
import '../services/call_recorder_bridge.dart';

class CallRecorderProvider extends ChangeNotifier {
  static const String _keyAutoRecord = 'call_recorder_auto_record';
  static const String _keyGain = 'call_recorder_gain';
  static const String _keyVoip = 'call_recorder_voip';
  static const String _keySpeechEq = 'call_recorder_speech_eq';
  static const String _keyVolumeEscalation = 'call_recorder_volume_escalation';
  static const String _keyAccessibilityHook = 'call_recorder_accessibility_hook';

  bool _voipRecordEnabled = false;
  bool _voipCallActive = false;
  bool _accessibilityEnabled = true;

  // Option 1: C++ Speech EQ & Volume Escalation
  bool _speechEqEnabled = true;
  bool _volumeEscalationEnabled = true;

  // Option 2: Accessibility Service Call Recording Hook
  bool _accessibilityHookEnabled = true;

  bool _isRecording = false;
  double _durationSeconds = 0.0;
  int _bytesWritten = 0;
  String _currentFilePath = '';
  int _latestAmplitude = 0;
  String _callState = 'IDLE';
  String _incomingNumber = '';
  bool _autoRecordEnabled = true;
  double _gainMultiplier = 5.0;
  String _statusMessage = 'Ready';

  bool _hasAudioPermission = false;
  bool _hasPhonePermission = false;
  bool _hasCallLogPermission = false;

  // Audio Playback State
  bool _isAudioPlaying = false;
  String _currentlyPlayingPath = '';
  int _playbackPositionMs = 0;
  int _playbackDurationMs = 0;

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
  bool get voipRecordEnabled => _voipRecordEnabled;
  bool get voipCallActive => _voipCallActive;
  bool get accessibilityEnabled => _accessibilityEnabled;
  double get gainMultiplier => _gainMultiplier;
  String get statusMessage => _statusMessage;
  List<CallRecordingItem> get recordings => List.unmodifiable(_recordings);

  bool get speechEqEnabled => _speechEqEnabled;
  bool get volumeEscalationEnabled => _volumeEscalationEnabled;
  bool get accessibilityHookEnabled => _accessibilityHookEnabled;

  bool get hasAudioPermission => _hasAudioPermission;
  bool get hasPhonePermission => _hasPhonePermission;
  bool get hasCallLogPermission => _hasCallLogPermission;
  bool get allPermissionsGranted => _hasAudioPermission && _hasPhonePermission;

  // Audio Player getters
  bool get isAudioPlaying => _isAudioPlaying;
  String get currentlyPlayingPath => _currentlyPlayingPath;
  int get playbackPositionMs => _playbackPositionMs;
  int get playbackDurationMs => _playbackDurationMs;
  double get playbackProgress => _playbackDurationMs > 0
      ? (_playbackPositionMs / _playbackDurationMs).clamp(0.0, 1.0)
      : 0.0;

  bool isTrackPlaying(String path) => _isAudioPlaying && _currentlyPlayingPath == path;
  bool isTrackSelected(String path) => _currentlyPlayingPath == path;

  String get formattedDuration {
    final totalSec = _durationSeconds.toInt();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${_twoDigits(mins)}:${_twoDigits(secs)}';
  }

  static String formatMs(int ms) {
    final totalSec = ms ~/ 1000;
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
    _gainMultiplier = prefs.getDouble(_keyGain) ?? 5.0;
    _voipRecordEnabled = prefs.getBool(_keyVoip) ?? false;
    _speechEqEnabled = prefs.getBool(_keySpeechEq) ?? true;
    _volumeEscalationEnabled = prefs.getBool(_keyVolumeEscalation) ?? true;
    _accessibilityHookEnabled = prefs.getBool(_keyAccessibilityHook) ?? true;
    await syncRecordingOptions();

    CallRecorderBridge.onCallStateChanged = (state, number) {
      _callState = state;
      _incomingNumber = number;
      if (state == 'OFFHOOK') {
        _statusMessage = number.isNotEmpty && number != 'Unknown'
            ? 'Call in Progress ($number)'
            : 'Cellular Call Active';
      } else if (state == 'RINGING') {
        _statusMessage = 'Incoming Call Ringing ($number)';
      } else {
        _statusMessage = 'Phone Idle';
      }
      notifyListeners();
    };

    CallRecorderBridge.onRecorderStatus = (status) {
      if (status == 'VOIP_CALL_STARTED') {
        _voipCallActive = true;
        _statusMessage = 'VoIP Call Detected - Recording';
      } else if (status == 'VOIP_CALL_ENDED') {
        _voipCallActive = false;
        _statusMessage = 'VoIP Call Ended';
      } else if (status.startsWith('RECORDING_FINISHED:')) {
        _statusMessage = 'Recording Saved';
        refreshRecordings();
      } else if (status == 'RECORDING_ACTIVE') {
        _statusMessage = 'Call Recording Active';
      } else if (status == 'MIC_UNAVAILABLE') {
        _statusMessage = 'Microphone unavailable. Please grant permissions and ensure mic is free.';
      } else if (status == 'PERMISSION_DENIED') {
        _statusMessage = 'Microphone permission denied. Tap Grant Permissions.';
      } else if (status == 'MIC_SILENCED_OR_MUTED') {
        _statusMessage = 'Microphone temporarily silenced by telecom HAL.';
      } else if (status == 'MIC_SILENCE_DETECTED') {
        _statusMessage = '⚠ Silence detected! Speakerphone enabled automatically. If still silent, your device may block mic during calls.';
      } else if (status == 'MIC_INTERRUPTED_BY_OEM') {
        _statusMessage = 'Microphone capture interrupted by OEM audio routing.';
      } else {
        _statusMessage = status;
      }
      notifyListeners();
    };

    CallRecorderBridge.onAudioPlaybackStateChanged = (status) {
      _isAudioPlaying = status['isPlaying'] as bool? ?? false;
      _playbackPositionMs = (status['currentPositionMs'] as num?)?.toInt() ?? 0;
      _playbackDurationMs = (status['durationMs'] as num?)?.toInt() ?? 0;
      _currentlyPlayingPath = status['filePath']?.toString() ?? '';
      notifyListeners();
    };

    await checkPermissions();
    await syncAutoRecordConfig();
    if (_voipRecordEnabled && _hasAudioPermission) {
      await CallRecorderBridge.setVoipRecording(true, gain: _gainMultiplier);
    }
    await checkInitialState();
    await refreshRecordings();

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollRecordingStats();
    });
  }

  Future<bool> checkPermissions() async {
    final perms = await CallRecorderBridge.hasPermissions();
    _hasAudioPermission = perms['audio'] ?? false;
    _hasPhonePermission = perms['phone'] ?? false;
    _hasCallLogPermission = perms['callLog'] ?? false;
    _accessibilityEnabled = await CallRecorderBridge.isAccessibilityEnabled();
    notifyListeners();
    return allPermissionsGranted;
  }

  Future<bool> openAccessibilitySettings() async {
    final ok = await CallRecorderBridge.openAccessibilitySettings();
    await Future.delayed(const Duration(seconds: 1));
    await checkPermissions();
    return ok;
  }

  Future<bool> requestPermissions() async {
    final granted = await CallRecorderBridge.requestPermissions();
    await checkPermissions();
    return granted;
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

  Future<void> setVoipRecordEnabled(bool enabled) async {
    if (enabled) {
      await checkPermissions();
      if (!_hasAudioPermission) {
        final granted = await requestPermissions();
        if (!granted) {
          _statusMessage = 'Microphone permission required for VoIP recording';
          notifyListeners();
          return;
        }
      }
    }
    final ok = await CallRecorderBridge.setVoipRecording(enabled, gain: _gainMultiplier);
    if (!ok && enabled) {
      _statusMessage = 'Could not start VoIP monitor';
      notifyListeners();
      return;
    }
    _voipRecordEnabled = enabled;
    if (!enabled) _voipCallActive = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVoip, enabled);
    _statusMessage = enabled ? 'VoIP recording armed' : 'VoIP recording off';
    notifyListeners();
  }

  Future<void> setGainMultiplier(double gain) async {
    _gainMultiplier = gain;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGain, gain);
    await syncAutoRecordConfig();
    notifyListeners();
  }

  Future<void> syncRecordingOptions() async {
    await CallRecorderBridge.setRecordingOptions(
      speechEq: _speechEqEnabled,
      volumeEscalation: _volumeEscalationEnabled,
      accessibilityHook: _accessibilityHookEnabled,
    );
  }

  Future<void> setSpeechEqEnabled(bool enabled) async {
    _speechEqEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpeechEq, enabled);
    await syncRecordingOptions();
    notifyListeners();
  }

  Future<void> setVolumeEscalationEnabled(bool enabled) async {
    _volumeEscalationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVolumeEscalation, enabled);
    await syncRecordingOptions();
    notifyListeners();
  }

  Future<void> setAccessibilityHookEnabled(bool enabled) async {
    _accessibilityHookEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAccessibilityHook, enabled);
    await syncRecordingOptions();
    notifyListeners();
  }

  Future<bool> startManualRecording({String? phoneNumber}) async {
    await checkPermissions();
    if (!allPermissionsGranted) {
      final granted = await requestPermissions();
      if (!granted) {
        _statusMessage = 'Microphone permission required to record';
        notifyListeners();
        return false;
      }
    }

    final success = await CallRecorderBridge.startRecording(
      gain: _gainMultiplier,
      phoneNumber: phoneNumber,
    );
    if (success) {
      _isRecording = true;
      _statusMessage = 'Recording Started';
      notifyListeners();
    } else {
      _statusMessage = 'Could not start recording. Tap Grant Permissions or try again.';
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

  // ── Audio Playback Controls ───────────────────────────────────────────────
  Future<void> togglePlay(String path) async {
    if (_currentlyPlayingPath == path) {
      if (_isAudioPlaying) {
        await CallRecorderBridge.pauseAudio();
      } else {
        await CallRecorderBridge.resumeAudio();
      }
    } else {
      _currentlyPlayingPath = path;
      _isAudioPlaying = true;
      notifyListeners();
      final ok = await CallRecorderBridge.playAudio(path);
      if (!ok) {
        _isAudioPlaying = false;
        notifyListeners();
      }
    }
  }

  Future<void> pauseAudio() async {
    await CallRecorderBridge.pauseAudio();
  }

  Future<void> stopAudio() async {
    await CallRecorderBridge.stopAudio();
    _isAudioPlaying = false;
    _currentlyPlayingPath = '';
    _playbackPositionMs = 0;
    _playbackDurationMs = 0;
    notifyListeners();
  }

  Future<void> seekAudio(int positionMs) async {
    _playbackPositionMs = positionMs;
    notifyListeners();
    await CallRecorderBridge.seekAudio(positionMs);
  }

  Future<bool> openWithExternalPlayer(String path) async {
    return await CallRecorderBridge.openWithExternalPlayer(path);
  }

  // ── Metadata Management ───────────────────────────────────────────────────
  Future<bool> updateRecordingMetadata({
    required String path,
    required String phoneNumber,
    String contactName = '',
    String notes = '',
  }) async {
    final ok = await CallRecorderBridge.updateRecordingMetadata(
      path: path,
      phoneNumber: phoneNumber,
      contactName: contactName,
      notes: notes,
    );
    if (ok) {
      final index = _recordings.indexWhere((r) => r.path == path);
      if (index != -1) {
        _recordings[index] = _recordings[index].copyWith(
          phoneNumber: phoneNumber,
          contactName: contactName,
          notes: notes,
        );
        notifyListeners();
      }
    }
    return ok;
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
    final list = await CallRecorderBridge.listRecordings();
    _recordings = list;
    notifyListeners();
  }

  Future<bool> deleteRecording(String path) async {
    if (_currentlyPlayingPath == path) {
      await stopAudio();
    }
    final success = await CallRecorderBridge.deleteRecording(path);
    if (success) {
      await refreshRecordings();
    }
    return success;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    CallRecorderBridge.stopAudio();
    super.dispose();
  }
}
