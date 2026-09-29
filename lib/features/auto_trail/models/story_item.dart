import 'visit_cluster.dart';

enum StoryItemType {
  visit,
  transit,
}

/// Represents an item in the chronological Daily Lifelog Story.
class StoryTimelineItem {
  final String id;
  final StoryItemType type;
  final DateTime startTime;
  final DateTime endTime;

  // Visit specifics
  final VisitCluster? visit;
  final String? placeName;
  final String? placeIcon; // 'home' | 'office' | 'gym' | 'cafe' | 'pin'

  // Transit specifics
  final double distanceMeters;
  final String primaryActivity; // 'in_vehicle' | 'on_bicycle' | 'walking' | 'running' | 'still'
  final int pointsCount;

  const StoryTimelineItem({
    required this.id,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.visit,
    this.placeName,
    this.placeIcon,
    this.distanceMeters = 0.0,
    this.primaryActivity = 'still',
    this.pointsCount = 0,
  });

  Duration get duration => endTime.difference(startTime);

  String get durationString {
    final d = duration;
    if (d.inHours > 0) {
      final mins = d.inMinutes.remainder(60);
      return mins > 0 ? '${d.inHours}h ${mins}m' : '${d.inHours}h';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m';
    }
    return '${d.inSeconds}s';
  }

  String get distanceString {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }
}
