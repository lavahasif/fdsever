import 'package:geolocator/geolocator.dart';
import '../models/trail_point.dart';
import '../models/visit_cluster.dart';

/// Service to analyze raw trail points and cluster them into stationary "Visits" or "Stops"
/// (e.g. Home, Workplace, Café, Park) with dwell duration.
class TrailClusterService {
  /// Distance threshold in meters to consider points part of the same stationary cluster.
  static const double clusterRadiusMeters = 80.0;

  /// Minimum dwell duration (in seconds) to qualify as an identified visit.
  static const int minDwellSeconds = 180; // 3 minutes

  /// Cluster a list of trail points into visits/stops.
  static List<VisitCluster> detectVisits(List<TrailPoint> points) {
    if (points.isEmpty) return [];

    // Sort chronologically ascending for clustering
    final sorted = List<TrailPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<VisitCluster> visits = [];
    int clusterId = 1;

    List<TrailPoint> currentCluster = [];

    void finalizeCluster() {
      if (currentCluster.isEmpty) return;

      final start = currentCluster.first.dateTime;
      final end = currentCluster.last.dateTime;
      final dwellSeconds = end.difference(start).inSeconds;

      // Qualify as a visit if dwell time >= minDwellSeconds or if contains stationary tags
      final hasStillActivity = currentCluster.any((p) => p.activity == 'still');
      if (dwellSeconds >= minDwellSeconds || (currentCluster.length >= 2 && hasStillActivity)) {
        // Calculate centroid
        double sumLat = 0;
        double sumLng = 0;
        for (final pt in currentCluster) {
          sumLat += pt.latitude;
          sumLng += pt.longitude;
        }
        final centerLat = sumLat / currentCluster.length;
        final centerLng = sumLng / currentCluster.length;

        // Choose most descriptive non-empty address
        String bestAddress = currentCluster.first.address;
        for (final pt in currentCluster) {
          if (pt.address.isNotEmpty && !pt.address.contains('Unknown')) {
            bestAddress = pt.address;
            break;
          }
        }

        visits.add(
          VisitCluster(
            id: clusterId++,
            locationName: bestAddress,
            centerLatitude: centerLat,
            centerLongitude: centerLng,
            startTime: start,
            endTime: end,
            pointsCount: currentCluster.length,
            points: List.from(currentCluster),
          ),
        );
      }
      currentCluster.clear();
    }

    for (final pt in sorted) {
      if (currentCluster.isEmpty) {
        currentCluster.add(pt);
      } else {
        final last = currentCluster.last;
        final dist = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          pt.latitude,
          pt.longitude,
        );

        if (dist <= clusterRadiusMeters) {
          currentCluster.add(pt);
        } else {
          finalizeCluster();
          currentCluster.add(pt);
        }
      }
    }

    finalizeCluster();

    // Return descending by start time for UI presentation
    return visits.reversed.toList();
  }

  /// Calculates total distance traveled along points in meters.
  static double calculateTotalDistanceMeters(List<TrailPoint> points) {
    if (points.length < 2) return 0.0;
    final sorted = List<TrailPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double total = 0.0;
    for (int i = 0; i < sorted.length - 1; i++) {
      total += Geolocator.distanceBetween(
        sorted[i].latitude,
        sorted[i].longitude,
        sorted[i + 1].latitude,
        sorted[i + 1].longitude,
      );
    }
    return total;
  }
}
