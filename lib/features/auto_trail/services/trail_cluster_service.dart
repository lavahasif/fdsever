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

    void finalizeCluster({DateTime? nextPointTime}) {
      if (currentCluster.isEmpty) return;

      final start = currentCluster.first.dateTime;
      DateTime end = currentCluster.last.dateTime;

      // If nextPointTime is known, the user remained at this cluster until departing
      if (nextPointTime != null && nextPointTime.isAfter(end)) {
        end = nextPointTime;
      } else if (currentCluster.length == 1) {
        // Only stationary stops are treated as ongoing or dwellable visits
        final isStationary = currentCluster.any((p) => p.activity == 'still' || p.activity == 'manual');
        if (isStationary) {
          final now = DateTime.now();
          if (now.isAfter(start) && now.difference(start).inHours < 24) {
            end = now;
          } else {
            end = start.add(const Duration(minutes: 5));
          }
        }
      }

      final dwellSeconds = end.difference(start).inSeconds;

      // Qualify as a visit/stop:
      // 1. Dwell time >= 2 minutes (120s) OR
      // 2. Contains still/stationary activity OR
      // 3. Multi-point cluster OR
      // 4. Standalone stop location
      final isStationary = currentCluster.any((p) => p.activity == 'still' || p.activity == 'manual');
      final isTransit = currentCluster.every((p) => p.activity == 'in_vehicle' || p.activity == 'on_bicycle' || p.activity == 'running');

      final bool isEligible;
      if (isTransit && currentCluster.length == 1 && dwellSeconds < 300) {
        // Transient moving waypoint, not a stationary visit
        isEligible = false;
      } else {
        isEligible = dwellSeconds >= 120 ||
            currentCluster.length >= 2 ||
            isStationary;
      }

      if (isEligible) {
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

    for (int i = 0; i < sorted.length; i++) {
      final pt = sorted[i];
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
          // Departed to a new place: finalize current cluster with pt.dateTime as departure
          finalizeCluster(nextPointTime: pt.dateTime);
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
