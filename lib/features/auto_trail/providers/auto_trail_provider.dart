import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/trail_database.dart';
import '../models/saved_place.dart';
import '../models/story_item.dart';
import '../models/trail_point.dart';
import '../models/visit_cluster.dart';
import '../services/auto_trail_permission_service.dart';
import '../services/auto_trail_service.dart';
import '../services/daily_story_service.dart';
import '../services/trail_analytics_service.dart';
import '../services/trail_cluster_service.dart';
import '../services/trail_export_service.dart';

class AutoTrailProvider extends ChangeNotifier {
  final AutoTrailService _service = AutoTrailService.instance;
  final TrailDatabase _db = TrailDatabase.instance;

  bool _isServiceRunning = false;
  bool _isLoading = true;
  AutoTrailPermissionStatus _permissionStatus = AutoTrailPermissionStatus.denied;

  DateTime _selectedDate = DateTime.now();
  List<TrailPoint> _points = [];
  List<VisitCluster> _visits = [];
  List<SavedPlace> _savedPlaces = [];
  List<StoryTimelineItem> _storyItems = [];
  List<DateTime> _availableDates = [];
  TrailPoint? _selectedPoint;
  String _searchQuery = '';
  String _currentActivity = 'still';
  Map<String, dynamic> _globalStats = {};
  double _dayDistanceMeters = 0.0;

  // ─── Feature 1: Weekly Heatmap Calendar ───────────────────────────────
  Map<DateTime, int> _heatmapData = {};

  // ─── Feature 2: Speed & Movement Analytics ────────────────────────────
  Map<String, dynamic> _speedAnalytics = {};

  // ─── Feature 3: Visit Frequency Counter ───────────────────────────────
  Map<String, int> _visitFrequency = {};

  // ─── Feature 4: Night Owl Detector ────────────────────────────────────
  List<TrailPoint> _nightOwlPoints = [];

  // ─── Feature 5: Commute Time Estimator ────────────────────────────────
  Map<String, dynamic> _commuteData = {};

  // ─── Feature 6: Location Streak Counter ───────────────────────────────
  int _trackingStreak = 0;

  // ─── Feature 7: Place Dwell Leaderboard ───────────────────────────────
  List<Map<String, dynamic>> _dwellLeaderboard = [];

  // ─── Feature 8: Activity Breakdown ────────────────────────────────────
  Map<String, double> _activityPercentages = {};

  // ─── Feature 9: Trail Distance Milestones ─────────────────────────────
  Map<String, dynamic> _distanceMilestones = {};

  StreamSubscription? _serviceSubscription;

  // Getters
  bool get isServiceRunning => _isServiceRunning;
  bool get isLoading => _isLoading;
  AutoTrailPermissionStatus get permissionStatus => _permissionStatus;
  DateTime get selectedDate => _selectedDate;
  List<TrailPoint> get points => _points;
  List<VisitCluster> get visits => _visits;
  List<SavedPlace> get savedPlaces => _savedPlaces;
  List<StoryTimelineItem> get storyItems => _storyItems;
  List<DateTime> get availableDates => _availableDates;
  TrailPoint? get selectedPoint => _selectedPoint;
  String get searchQuery => _searchQuery;
  String get currentActivity => _currentActivity;
  Map<String, dynamic> get globalStats => _globalStats;
  double get dayDistanceMeters => _dayDistanceMeters;

  // Analytics Getters (Features 1-10)
  Map<DateTime, int> get heatmapData => _heatmapData;
  Map<String, dynamic> get speedAnalytics => _speedAnalytics;
  Map<String, int> get visitFrequency => _visitFrequency;
  List<TrailPoint> get nightOwlPoints => _nightOwlPoints;
  bool get hasNightActivity => _nightOwlPoints.isNotEmpty;
  Map<String, dynamic> get commuteData => _commuteData;
  int get trackingStreak => _trackingStreak;
  List<Map<String, dynamic>> get dwellLeaderboard => _dwellLeaderboard;
  Map<String, double> get activityPercentages => _activityPercentages;
  Map<String, dynamic> get distanceMilestones => _distanceMilestones;

  bool get hasBackgroundPermission =>
      _permissionStatus == AutoTrailPermissionStatus.allGranted;

  AutoTrailProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    await _service.initialize();
    _isServiceRunning = await _service.isRunning();
    _permissionStatus = await AutoTrailPermissionService.checkStatus();

    _serviceSubscription = _service.onServiceUpdate().listen((data) {
      if (data == null) return;
      final event = data['event'] as String?;
      if (event == 'new_point') {
        final pointMap = data['point'] as Map<String, dynamic>?;
        if (pointMap != null) {
          final pt = TrailPoint.fromMap(pointMap);
          _onNewPointReceived(pt);
        }
      } else if (event == 'activity_change') {
        _currentActivity = data['activity'] as String? ?? 'unknown';
        notifyListeners();
      }
    });

    await refreshData();
    await loadAnalytics();
    _isLoading = false;
    notifyListeners();
  }

  void _onNewPointReceived(TrailPoint point) {
    final ptDate = point.dateTime;
    if (ptDate.year == _selectedDate.year &&
        ptDate.month == _selectedDate.month &&
        ptDate.day == _selectedDate.day) {
      _points.insert(0, point);
      _recalculateVisitsAndStats();
      notifyListeners();
    }
    _loadDistinctDates();
    _loadGlobalStats();
  }

  Future<void> refreshData() async {
    _isServiceRunning = await _service.isRunning();
    _permissionStatus = await AutoTrailPermissionService.checkStatus();
    _savedPlaces = await _db.getAllSavedPlaces();

    if (_searchQuery.trim().isNotEmpty) {
      _points = await _db.searchPoints(_searchQuery);
    } else {
      _points = await _db.getPointsByDay(_selectedDate);
    }

    _recalculateVisitsAndStats();
    await _loadDistinctDates();
    await _loadGlobalStats();
    notifyListeners();
  }

  /// Loads all analytics features
  Future<void> loadAnalytics() async {
    try {
      _heatmapData = await TrailAnalyticsService.getWeeklyHeatmapData();
      _speedAnalytics = TrailAnalyticsService.computeSpeedAnalytics(_points);
      if (_savedPlaces.isNotEmpty) {
        _visitFrequency = await TrailAnalyticsService.getVisitFrequency(_savedPlaces);
      }
      _nightOwlPoints = TrailAnalyticsService.getNightOwlPoints(_points);
      _commuteData = await TrailAnalyticsService.estimateCommute(_savedPlaces);
      _trackingStreak = await TrailAnalyticsService.getTrackingStreak();
      if (_savedPlaces.isNotEmpty) {
        _dwellLeaderboard = await TrailAnalyticsService.getPlaceDwellLeaderboard(_savedPlaces);
      }
      _activityPercentages = TrailAnalyticsService.getActivityPercentages(_points);
      _distanceMilestones = await TrailAnalyticsService.getDistanceMilestones();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }

  void _recalculateVisitsAndStats() {
    _visits = TrailClusterService.detectVisits(_points);
    _dayDistanceMeters = TrailClusterService.calculateTotalDistanceMeters(_points);
    _storyItems = DailyStoryService.generateStory(
      points: _points,
      visits: _visits,
      savedPlaces: _savedPlaces,
    );
    _speedAnalytics = TrailAnalyticsService.computeSpeedAnalytics(_points);
    _nightOwlPoints = TrailAnalyticsService.getNightOwlPoints(_points);
    _activityPercentages = TrailAnalyticsService.getActivityPercentages(_points);
  }

  Future<void> saveNamedPlace(SavedPlace place) async {
    await _db.insertSavedPlace(place);
    await refreshData();
  }

  Future<void> deleteNamedPlace(String id) async {
    await _db.deleteSavedPlace(id);
    await refreshData();
  }

  SavedPlace? getMatchingSavedPlace(double lat, double lng) {
    for (final p in _savedPlaces) {
      if (p.isInside(lat, lng)) return p;
    }
    return null;
  }

  Future<void> _loadDistinctDates() async {
    _availableDates = await _db.getDistinctDays();
  }

  Future<void> _loadGlobalStats() async {
    _globalStats = await _db.getStats();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    _searchQuery = '';
    _selectedPoint = null;
    refreshData();
  }

  void selectPoint(TrailPoint? point) {
    _selectedPoint = point;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _selectedPoint = null;
    refreshData();
  }

  Future<void> checkPermissions() async {
    _permissionStatus = await AutoTrailPermissionService.checkStatus();
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    _permissionStatus = await AutoTrailPermissionService.requestAllPermissions();
    notifyListeners();
  }

  Future<void> toggleService() async {
    if (_isServiceRunning) {
      _service.stopService();
      _isServiceRunning = false;
    } else {
      if (!hasBackgroundPermission) {
        final status = await AutoTrailPermissionService.requestAllPermissions();
        _permissionStatus = status;
        if (!hasBackgroundPermission &&
            _permissionStatus != AutoTrailPermissionStatus.foregroundOnly) {
          notifyListeners();
          return;
        }
      }
      try {
        final started = await _service.startService();
        _isServiceRunning = started;
      } catch (e) {
        _isServiceRunning = false;
        notifyListeners();
      }
    }
    notifyListeners();
  }

  /// Feature 10: Record location with optional note
  Future<TrailPoint?> recordCurrentLocation({String? note}) async {
    var pt = await _service.recordCurrentLocationNow();
    if (pt != null) {
      if (note != null && note.trim().isNotEmpty) {
        pt = TrailAnalyticsService.attachNote(pt, note);
        await _db.insertPoint(pt);
      }
      _onNewPointReceived(pt);
    }
    return pt;
  }

  Future<void> deletePoint(int id) async {
    await _db.deletePoint(id);
    if (_selectedPoint?.id == id) {
      _selectedPoint = null;
    }
    await refreshData();
  }

  Future<void> clearAllHistory() async {
    await _db.clearAllPoints();
    _points.clear();
    _visits.clear();
    _selectedPoint = null;
    await refreshData();
  }

  Future<void> openInGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> sharePoint(TrailPoint point) async {
    await TrailExportService.shareLocation(point);
  }

  Future<void> exportDayTrail(String format) async {
    if (_points.isEmpty) return;
    await TrailExportService.shareTrailFile(
      points: _points,
      format: format,
      date: _selectedDate,
    );
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }
}
