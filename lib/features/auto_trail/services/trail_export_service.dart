import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trail_point.dart';

/// Service for generating GPX, GeoJSON, and sharing trail locations.
class TrailExportService {
  /// Generates standard GPX 1.1 XML string for trail points.
  static String generateGpx(List<TrailPoint> points, {String name = 'Auto Trail Export'}) {
    final sorted = List<TrailPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Auto Trail - FDServer" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>$name</name>');
    buffer.writeln('    <time>${DateTime.now().toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>$name</name>');
    buffer.writeln('    <trkseg>');

    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
    for (final pt in sorted) {
      final timeStr = dateFormat.format(pt.dateTime.toUtc());
      buffer.writeln('      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">');
      buffer.writeln('        <time>$timeStr</time>');
      buffer.writeln('        <name>${_xmlEscape(pt.address)}</name>');
      if (pt.activity != null) {
        buffer.writeln('        <desc>Activity: ${pt.activity}</desc>');
      }
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  /// Generates GeoJSON FeatureCollection string.
  static String generateGeoJson(List<TrailPoint> points) {
    final features = points.map((p) => p.toGeoJsonFeature()).toList();

    // Also include a LineString feature if there are 2 or more points
    if (points.length >= 2) {
      final sorted = List<TrailPoint>.from(points)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': sorted.map((p) => [p.longitude, p.latitude]).toList(),
        },
        'properties': {
          'name': 'Auto Trail Route',
          'pointCount': points.length,
        },
      });
    }

    final geoJsonMap = {
      'type': 'FeatureCollection',
      'features': features,
    };
    return const JsonEncoder.withIndent('  ').convert(geoJsonMap);
  }

  /// Generates human-readable text summary of a day's trail.
  static String generateTextSummary(List<TrailPoint> points, DateTime date) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final buffer = StringBuffer();
    buffer.writeln('📍 Auto Trail Summary for $dateStr:');
    buffer.writeln('Total logged places: ${points.length}\n');

    final sorted = List<TrailPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final pt in sorted) {
      final timeStr = DateFormat('h:mm a').format(pt.dateTime);
      buffer.writeln('• $timeStr — ${pt.address}');
      buffer.writeln('  Maps: ${pt.googleMapsUrl}');
    }

    return buffer.toString();
  }

  /// Shares text content
  static Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }

  /// Shares a single location with address and Google Maps link.
  static Future<void> shareLocation(TrailPoint point) async {
    final timeStr = DateFormat('MMM d, yyyy · h:mm a').format(point.dateTime);
    final text = '📍 Visited on $timeStr\n${point.address}\n\nGoogle Maps: ${point.googleMapsUrl}';
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Location: ${point.address}'),
    );
  }

  /// Exports and shares the points as GPX or GeoJSON file.
  static Future<void> shareTrailFile({
    required List<TrailPoint> points,
    required String format, // 'gpx' or 'geojson'
    required DateTime date,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dateTag = DateFormat('yyyyMMdd').format(date);

    if (format.toLowerCase() == 'gpx') {
      final gpxContent = generateGpx(points, name: 'Trail_$dateTag');
      final file = File('${tempDir.path}/autotrail_$dateTag.gpx');
      await file.writeAsString(gpxContent);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/gpx+xml')],
          text: 'Auto Trail GPX export for $dateTag',
        ),
      );
    } else {
      final geoJsonContent = generateGeoJson(points);
      final file = File('${tempDir.path}/autotrail_$dateTag.geojson');
      await file.writeAsString(geoJsonContent);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/geo+json')],
          text: 'Auto Trail GeoJSON export for $dateTag',
        ),
      );
    }
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
