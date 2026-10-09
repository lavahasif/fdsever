import 'package:flutter/foundation.dart';
import '../models/meeting_schedule.dart';
import '../services/meeting_recorder_bridge.dart';

class MeetingScheduleProvider extends ChangeNotifier {
  final MeetingRecorderBridgeService _bridge = MeetingRecorderBridgeService();

  List<MeetingSchedule> _schedules = [];
  bool _isLoading = false;
  bool _isPreviewingAlarm = false;

  MeetingScheduleProvider() {
    loadSchedules();
  }

  List<MeetingSchedule> get schedules => _schedules;
  bool get isLoading => _isLoading;
  bool get isPreviewingAlarm => _isPreviewingAlarm;

  Future<void> loadSchedules() async {
    _isLoading = true;
    notifyListeners();
    _schedules = await _bridge.getSchedules();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveSchedule(MeetingSchedule schedule) async {
    final id = await _bridge.saveSchedule(schedule);
    if (id > 0) {
      await loadSchedules();
      return true;
    }
    return false;
  }

  Future<bool> toggleSchedule(int id, bool enabled) async {
    final ok = await _bridge.toggleSchedule(id, enabled);
    if (ok) {
      final index = _schedules.indexWhere((s) => s.id == id);
      if (index >= 0) {
        _schedules[index] = _schedules[index].copyWith(isEnabled: enabled);
        notifyListeners();
      }
    }
    return ok;
  }

  Future<bool> deleteSchedule(int id) async {
    final ok = await _bridge.deleteSchedule(id);
    if (ok) {
      _schedules.removeWhere((s) => s.id == id);
      notifyListeners();
    }
    return ok;
  }

  Future<void> previewAlarm({
    required String soundMode,
    String? ringtoneUri,
    double volume = 0.8,
  }) async {
    _isPreviewingAlarm = true;
    notifyListeners();
    await _bridge.previewAlarm(
      soundMode: soundMode,
      ringtoneUri: ringtoneUri,
      volume: volume,
    );
  }

  Future<void> stopAlarmPreview() async {
    _isPreviewingAlarm = false;
    notifyListeners();
    await _bridge.stopAlarmPreview();
  }

  @override
  void dispose() {
    if (_isPreviewingAlarm) {
      _bridge.stopAlarmPreview();
    }
    super.dispose();
  }
}
