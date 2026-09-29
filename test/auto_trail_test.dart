import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fdserver/features/auto_trail/models/trail_point.dart';
import 'package:fdserver/features/auto_trail/models/visit_cluster.dart';
import 'package:fdserver/features/auto_trail/services/trail_cluster_service.dart';
import 'package:fdserver/features/auto_trail/services/trail_export_service.dart';

void main() {
  group('Auto Trail Model & Utility Tests', () {
    test('TrailPoint toMap and fromMap round-trip', () {
      final point = TrailPoint(
        id: 1,
        latitude: 25.2048,
        longitude: 55.2708,
        address: 'Downtown Dubai, UAE',
        timestamp: 1700000000000,
        accuracy: 12.5,
        activity: 'walking',
      );

      final map = point.toMap();
      final reconstructed = TrailPoint.fromMap(map);

      expect(reconstructed.id, 1);
      expect(reconstructed.latitude, 25.2048);
      expect(reconstructed.longitude, 55.2708);
      expect(reconstructed.address, 'Downtown Dubai, UAE');
      expect(reconstructed.timestamp, 1700000000000);
      expect(reconstructed.accuracy, 12.5);
      expect(reconstructed.activity, 'walking');
      expect(reconstructed.googleMapsUrl, contains('query=25.2048,55.2708'));
    });

    test('TrailExportService produces valid GPX XML', () {
      final points = [
        TrailPoint(
          id: 1,
          latitude: 25.1972,
          longitude: 55.2744,
          address: 'Burj Khalifa',
          timestamp: 1700000000000,
          activity: 'still',
        ),
        TrailPoint(
          id: 2,
          latitude: 25.1985,
          longitude: 55.2796,
          address: 'Dubai Mall',
          timestamp: 1700000600000,
          activity: 'walking',
        ),
      ];

      final gpx = TrailExportService.generateGpx(points);
      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('lat="25.1972" lon="55.2744"'));
      expect(gpx, contains('Burj Khalifa'));
      expect(gpx, contains('Dubai Mall'));
    });

    test('TrailExportService produces valid GeoJSON', () {
      final points = [
        TrailPoint(
          id: 1,
          latitude: 25.1972,
          longitude: 55.2744,
          address: 'Burj Khalifa',
          timestamp: 1700000000000,
        ),
        TrailPoint(
          id: 2,
          latitude: 25.1985,
          longitude: 55.2796,
          address: 'Dubai Mall',
          timestamp: 1700000600000,
        ),
      ];

      final geoJsonStr = TrailExportService.generateGeoJson(points);
      final parsed = jsonDecode(geoJsonStr) as Map<String, dynamic>;
      expect(parsed['type'], 'FeatureCollection');
      final features = parsed['features'] as List;
      expect(features.length, 3); // 2 points + 1 LineString route
    });

    test('TrailClusterService detects stationary visits', () {
      final baseTime = DateTime(2026, 9, 27, 10, 0);

      // 3 points close to each other over 15 minutes
      final stationaryPoints = [
        TrailPoint(
          id: 1,
          latitude: 25.2048,
          longitude: 55.2708,
          address: 'Home Café',
          timestamp: baseTime.millisecondsSinceEpoch,
          activity: 'still',
        ),
        TrailPoint(
          id: 2,
          latitude: 25.20482,
          longitude: 55.27083,
          address: 'Home Café',
          timestamp: baseTime.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
          activity: 'still',
        ),
        TrailPoint(
          id: 3,
          latitude: 25.20481,
          longitude: 55.27081,
          address: 'Home Café',
          timestamp: baseTime.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
          activity: 'still',
        ),
      ];

      final visits = TrailClusterService.detectVisits(stationaryPoints);
      expect(visits.length, 1);
      expect(visits.first.locationName, 'Home Café');
      expect(visits.first.pointsCount, 3);
      expect(visits.first.duration.inMinutes, 15);
      expect(visits.first.durationString, contains('15m'));
    });

    test('TrailClusterService detects single-point stationary stay when battery saver drops duplicate points', () {
      final baseTime = DateTime(2026, 9, 27, 10, 0);

      // Point 1: At office, stationary for 45 minutes before departure to another place
      final singlePointStop = [
        TrailPoint(
          id: 1,
          latitude: 25.2048,
          longitude: 55.2708,
          address: 'Office Hub',
          timestamp: baseTime.millisecondsSinceEpoch,
          activity: 'still',
        ),
        TrailPoint(
          id: 2,
          latitude: 25.2500, // 5km away, departed 45 mins later
          longitude: 55.3000,
          address: 'Highway East',
          timestamp: baseTime.add(const Duration(minutes: 45)).millisecondsSinceEpoch,
          activity: 'in_vehicle',
        ),
      ];

      final visits = TrailClusterService.detectVisits(singlePointStop);
      expect(visits.isNotEmpty, isTrue);
      expect(visits.first.locationName, 'Office Hub');
      expect(visits.first.duration.inMinutes, 45);
    });
  });
}
