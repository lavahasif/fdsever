import 'package:geolocator/geolocator.dart';
import '../models/saved_place.dart';
import '../models/story_item.dart';
import '../models/trail_point.dart';
import '../models/visit_cluster.dart';

/// Synthesizes raw trail points and visit clusters into a cohesive,
/// chronological daily story narrative.
class DailyStoryService {
  /// Generates the day's lifelog story from points, clusters, and user-saved places.
  static List<StoryTimelineItem> generateStory({
    required List<TrailPoint> points,
    required List<VisitCluster> visits,
    required List<SavedPlace> savedPlaces,
  }) {
    if (points.isEmpty) return [];

    final List<StoryTimelineItem> items = [];

    // Sort chronologically ascending
    final sortedPoints = List<TrailPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sortedVisits = List<VisitCluster>.from(visits)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (sortedVisits.isEmpty) {
      // No stationary visits detected - generate pure transit story
      final totalDist = _calculateDistance(sortedPoints);
      final primaryAct = _detectPrimaryActivity(sortedPoints);
      items.add(
        StoryTimelineItem(
          id: 'transit_all_day',
          type: StoryItemType.transit,
          startTime: sortedPoints.first.dateTime,
          endTime: sortedPoints.last.dateTime,
          distanceMeters: totalDist,
          primaryActivity: primaryAct,
          pointsCount: sortedPoints.length,
        ),
      );
      return items;
    }

    // Process sequence: Check gap before first visit
    final firstVisit = sortedVisits.first;
    final pointsBeforeFirst = sortedPoints
        .where((p) => p.dateTime.isBefore(firstVisit.startTime))
        .toList();

    if (pointsBeforeFirst.length >= 2) {
      final dist = _calculateDistance(pointsBeforeFirst);
      if (dist >= 100) {
        items.add(
          StoryTimelineItem(
            id: 'transit_before_${firstVisit.id}',
            type: StoryItemType.transit,
            startTime: pointsBeforeFirst.first.dateTime,
            endTime: pointsBeforeFirst.last.dateTime,
            distanceMeters: dist,
            primaryActivity: _detectPrimaryActivity(pointsBeforeFirst),
            pointsCount: pointsBeforeFirst.length,
          ),
        );
      }
    }

    // Interleave visits and inter-visit transits
    for (int i = 0; i < sortedVisits.length; i++) {
      final currentVisit = sortedVisits[i];

      // Match visit against saved places
      final matchedPlace = _findMatchingSavedPlace(
        currentVisit.centerLatitude,
        currentVisit.centerLongitude,
        savedPlaces,
      );

      items.add(
        StoryTimelineItem(
          id: 'visit_${currentVisit.id}',
          type: StoryItemType.visit,
          startTime: currentVisit.startTime,
          endTime: currentVisit.endTime,
          visit: currentVisit,
          placeName: matchedPlace?.name ?? currentVisit.locationName,
          placeIcon: matchedPlace?.icon ?? 'pin',
          pointsCount: currentVisit.pointsCount,
        ),
      );

      // Check gap between this visit and next visit
      if (i < sortedVisits.length - 1) {
        final nextVisit = sortedVisits[i + 1];
        final betweenPoints = sortedPoints
            .where((p) =>
                p.dateTime.isAfter(currentVisit.endTime) &&
                p.dateTime.isBefore(nextVisit.startTime))
            .toList();

        final dist = _calculateDistance(betweenPoints);
        final directDist = Geolocator.distanceBetween(
          currentVisit.centerLatitude,
          currentVisit.centerLongitude,
          nextVisit.centerLatitude,
          nextVisit.centerLongitude,
        );

        final effectiveDist = dist > 0 ? dist : directDist;

        if (effectiveDist >= 150) {
          items.add(
            StoryTimelineItem(
              id: 'transit_${currentVisit.id}_to_${nextVisit.id}',
              type: StoryItemType.transit,
              startTime: currentVisit.endTime,
              endTime: nextVisit.startTime,
              distanceMeters: effectiveDist,
              primaryActivity: betweenPoints.isNotEmpty
                  ? _detectPrimaryActivity(betweenPoints)
                  : 'in_vehicle',
              pointsCount: betweenPoints.length,
            ),
          );
        }
      }
    }

    // Check gap after last visit
    final lastVisit = sortedVisits.last;
    final pointsAfterLast = sortedPoints
        .where((p) => p.dateTime.isAfter(lastVisit.endTime))
        .toList();

    if (pointsAfterLast.length >= 2) {
      final dist = _calculateDistance(pointsAfterLast);
      if (dist >= 100) {
        items.add(
          StoryTimelineItem(
            id: 'transit_after_${lastVisit.id}',
            type: StoryItemType.transit,
            startTime: pointsAfterLast.first.dateTime,
            endTime: pointsAfterLast.last.dateTime,
            distanceMeters: dist,
            primaryActivity: _detectPrimaryActivity(pointsAfterLast),
            pointsCount: pointsAfterLast.length,
          ),
        );
      }
    }

    return items;
  }

  static SavedPlace? _findMatchingSavedPlace(
    double lat,
    double lng,
    List<SavedPlace> savedPlaces,
  ) {
    for (final place in savedPlaces) {
      if (place.isInside(lat, lng)) {
        return place;
      }
    }
    return null;
  }

  static double _calculateDistance(List<TrailPoint> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  static String _detectPrimaryActivity(List<TrailPoint> points) {
    if (points.isEmpty) return 'still';
    final counts = <String, int>{};
    for (final p in points) {
      final act = p.activity;
      if (act != null && act != 'still' && act != 'manual') {
        counts[act] = (counts[act] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return 'walking';

    String bestActivity = 'walking';
    int maxCount = 0;
    counts.forEach((act, cnt) {
      if (cnt > maxCount) {
        maxCount = cnt;
        bestActivity = act;
      }
    });
    return bestActivity;
  }
}
