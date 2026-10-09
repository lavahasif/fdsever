import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/meeting_recording.dart';
import '../models/recording_filter.dart';
import '../services/meeting_recorder_bridge.dart';

class MeetingRecorderProvider extends ChangeNotifier {
  final MeetingRecorderBridgeService _bridge = MeetingRecorderBridgeService();

  bool _isStandby = false;
  bool _isRecording = false;
  String _currentRecordingPath = '';
  int _recordingStartTimeMs = 0;
  int _latestAmplitude = 0;
  int _elapsedSeconds = 0;

  Timer? _elapsedTimer;
  StreamSubscription? _statusSub;
  StreamSubscription? _playbackSub;

  List<MeetingRecording> _recordings = [];
  bool _isLoading = false;

  RecordingFilter _filter = const RecordingFilter();

  // Playback state
  bool _isPlaying = false;
  int _playerCurrentMs = 0;
  int _playerDurationMs = 0;
  String _currentlyPlayingPath = '';

  MeetingRecorderProvider() {
    _init();
  }

  bool get isStandby => _isStandby;
  bool get isRecording => _isRecording;
  String get currentRecordingPath => _currentRecordingPath;
  int get latestAmplitude => _latestAmplitude;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isLoading => _isLoading;
  RecordingFilter get filter => _filter;

  bool get isPlaying => _isPlaying;
  int get playerCurrentMs => _playerCurrentMs;
  int get playerDurationMs => _playerDurationMs;
  String get currentlyPlayingPath => _currentlyPlayingPath;

  String get formattedElapsed {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<MeetingRecording> get recordings {
    var list = List<MeetingRecording>.from(_recordings);

    // 1. Text Search Filter (Title, Notes, Tags)
    if (_filter.searchQuery.trim().isNotEmpty) {
      final q = _filter.searchQuery.trim().toLowerCase();
      list = list.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.notes.toLowerCase().contains(q) ||
            r.tags.toLowerCase().contains(q);
      }).toList();
    }

    // 2. Date Range Filter
    if (_filter.fromDate != null) {
      final from = DateTime(
        _filter.fromDate!.year,
        _filter.fromDate!.month,
        _filter.fromDate!.day,
      );
      list = list.where((r) => r.startedAt.isAfter(from)).toList();
    }
    if (_filter.toDate != null) {
      final to = DateTime(
        _filter.toDate!.year,
        _filter.toDate!.month,
        _filter.toDate!.day,
        23,
        59,
        59,
      );
      list = list.where((r) => r.startedAt.isBefore(to)).toList();
    }

    // 3. Time of Day Filter
    if (_filter.timeOfDay != MeetingTimeOfDay.all) {
      list = list.where((r) {
        final h = r.startedAt.hour;
        switch (_filter.timeOfDay) {
          case MeetingTimeOfDay.morning:
            return h >= 5 && h < 12;
          case MeetingTimeOfDay.afternoon:
            return h >= 12 && h < 17;
          case MeetingTimeOfDay.evening:
            return h >= 17 && h < 21;
          case MeetingTimeOfDay.night:
            return h >= 21 || h < 5;
          case MeetingTimeOfDay.all:
            return true;
        }
      }).toList();
    }

    // 4. Trigger Filter
    if (_filter.triggerFilter != 'all') {
      list = list.where((r) => r.triggerType == _filter.triggerFilter).toList();
    }

    // 5. Sorting
    switch (_filter.sortBy) {
      case MeetingSortBy.dateDesc:
        list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        break;
      case MeetingSortBy.dateAsc:
        list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
        break;
      case MeetingSortBy.nameAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case MeetingSortBy.nameDesc:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case MeetingSortBy.durationDesc:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
      case MeetingSortBy.durationAsc:
        list.sort((a, b) => a.durationMs.compareTo(b.durationMs));
        break;
    }

    return list;
  }

  Future<void> _init() async {
    _subscribeToEvents();
    await checkStatus();
    await loadRecordings();
  }

  void _subscribeToEvents() {
    _statusSub = _bridge.statusStream.listen((data) {
      _isStandby = data['isStandby'] == true;
      final wasRec = _isRecording;
      _isRecording = data['isRecording'] == true;
      _currentRecordingPath = data['currentRecordingPath']?.toString() ?? '';
      _recordingStartTimeMs = (data['startTimeMs'] as num?)?.toInt() ?? 0;
      _latestAmplitude = (data['latestAmplitude'] as num?)?.toInt() ?? 0;

      if (_isRecording) {
        _startTimer();
      } else {
        _stopTimer();
        if (wasRec) {
          loadRecordings();
        }
      }
      notifyListeners();
    });

    _playbackSub = _bridge.playbackStream.listen((data) {
      _isPlaying = data['isPlaying'] == true;
      _playerCurrentMs = (data['currentPositionMs'] as num?)?.toInt() ?? 0;
      _playerDurationMs = (data['durationMs'] as num?)?.toInt() ?? 0;
      _currentlyPlayingPath = data['filePath']?.toString() ?? '';
      notifyListeners();
    });
  }

  Future<void> checkStatus() async {
    final status = await _bridge.getRecordingStatus();
    _isStandby = status['isStandby'] == true;
    _isRecording = status['isRecording'] == true;
    _currentRecordingPath = status['currentRecordingPath']?.toString() ?? '';
    _recordingStartTimeMs = (status['startTimeMs'] as num?)?.toInt() ?? 0;
    _latestAmplitude = (status['latestAmplitude'] as num?)?.toInt() ?? 0;

    if (_isRecording) {
      _startTimer();
    } else {
      _stopTimer();
    }
    notifyListeners();
  }

  void _startTimer() {
    _elapsedTimer?.cancel();
    if (_recordingStartTimeMs > 0) {
      _elapsedSeconds = ((DateTime.now().millisecondsSinceEpoch - _recordingStartTimeMs) / 1000).toInt();
    } else {
      _elapsedSeconds = 0;
    }
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordingStartTimeMs > 0) {
        _elapsedSeconds = ((DateTime.now().millisecondsSinceEpoch - _recordingStartTimeMs) / 1000).toInt();
      } else {
        _elapsedSeconds++;
      }
      notifyListeners();
    });
  }

  void _stopTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _elapsedSeconds = 0;
  }

  Future<void> toggleStandby(bool enable) async {
    if (enable) {
      await _bridge.startStandby();
    } else {
      await _bridge.stopStandby();
    }
    await checkStatus();
  }

  Future<void> startRecordingManual() async {
    await _bridge.startRecording(trigger: 'manual');
    await checkStatus();
  }

  Future<void> stopRecordingManual() async {
    await _bridge.stopRecording();
    await checkStatus();
    await loadRecordings();
  }

  Future<void> loadRecordings() async {
    _isLoading = true;
    notifyListeners();
    _recordings = await _bridge.getRecordings();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> renameRecording(int id, String newTitle) async {
    final ok = await _bridge.renameRecording(id, newTitle.trim());
    if (ok) {
      final index = _recordings.indexWhere((r) => r.id == id);
      if (index >= 0) {
        _recordings[index] = _recordings[index].copyWith(title: newTitle.trim());
        notifyListeners();
      }
    }
    return ok;
  }

  Future<bool> updateNotesAndTags(int id, String notes, String tags) async {
    final ok = await _bridge.updateRecordingNotes(id, notes, tags);
    if (ok) {
      final index = _recordings.indexWhere((r) => r.id == id);
      if (index >= 0) {
        _recordings[index] = _recordings[index].copyWith(notes: notes, tags: tags);
        notifyListeners();
      }
    }
    return ok;
  }

  Future<bool> deleteRecording(int id) async {
    final ok = await _bridge.deleteRecording(id);
    if (ok) {
      final match = _recordings.where((r) => r.id == id).firstOrNull;
      if (match != null && _currentlyPlayingPath == match.filePath) {
        await stopPlayer();
      }
      _recordings.removeWhere((r) => r.id == id);
      notifyListeners();
    }
    return ok;
  }

  void setFilter(RecordingFilter newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  void resetFilter() {
    _filter = const RecordingFilter();
    notifyListeners();
  }

  // --- Player Methods ---

  bool isTrackPlaying(String path) => _isPlaying && _currentlyPlayingPath == path;
  bool isTrackActive(String path) => _currentlyPlayingPath == path;

  static String formatMs(int ms) {
    final totalSec = ms ~/ 1000;
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${mins >= 10 ? mins : "0$mins"}:${secs >= 10 ? secs : "0$secs"}';
  }

  Future<void> togglePlayAudio(String path) async {
    if (_currentlyPlayingPath == path) {
      if (_isPlaying) {
        await pausePlayer();
      } else {
        await _bridge.resumeAudio();
      }
    } else {
      await playAudio(path);
    }
  }

  Future<void> playAudio(String path) async {
    if (_currentlyPlayingPath == path && !_isPlaying) {
      await _bridge.resumeAudio();
    } else {
      _currentlyPlayingPath = path;
      _isPlaying = true;
      notifyListeners();
      final ok = await _bridge.playAudio(path);
      if (!ok) {
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  Future<void> pausePlayer() async {
    await _bridge.pauseAudio();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> stopPlayer() async {
    await _bridge.stopAudio();
    _isPlaying = false;
    _currentlyPlayingPath = '';
    _playerCurrentMs = 0;
    notifyListeners();
  }

  Future<void> seekPlayer(int positionMs) async {
    _playerCurrentMs = positionMs;
    notifyListeners();
    await _bridge.seekAudio(positionMs);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _playbackSub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }
}
