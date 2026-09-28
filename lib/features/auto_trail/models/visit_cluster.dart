import 'trail_point.dart';

/// Represents a clustered "visit" or "stop" where the user remained within a small area
/// for an extended duration (e.g. at home, coffee shop, gym, office).
class VisitCluster {
  final int id;
  final String locationName;
  final double centerLatitude;
  final double centerLongitude;
  final DateTime startTime;
  final DateTime endTime;
  final int pointsCount;
  final List<TrailPoint> points;

  const VisitCluster({
    required this.id,
    required this.locationName,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.startTime,
    required this.endTime,
    required this.pointsCount,
    required this.points,
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

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$centerLatitude,$centerLongitude';
}
