/// Represents a single passive location coordinate logged by Auto Trail.
class TrailPoint {
  final int? id;
  final double latitude;
  final double longitude;
  final String address;
  final int timestamp; // epoch milliseconds
  final double? accuracy;
  final String? activity; // still, walking, in_vehicle, etc.

  const TrailPoint({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
    this.accuracy,
    this.activity,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// Formatted short coordinates string
  String get coordsString =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// Google Maps query link
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': timestamp,
      if (accuracy != null) 'accuracy': accuracy,
      if (activity != null) 'activity': activity,
    };
  }

  factory TrailPoint.fromMap(Map<String, dynamic> map) {
    return TrailPoint(
      id: map['id'] as int?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: (map['address'] as String?) ?? 'Unknown location',
      timestamp: map['timestamp'] as int,
      accuracy: map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
      activity: map['activity'] as String?,
    );
  }

  TrailPoint copyWith({
    int? id,
    double? latitude,
    double? longitude,
    String? address,
    int? timestamp,
    double? accuracy,
    String? activity,
  }) {
    return TrailPoint(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      activity: activity ?? this.activity,
    );
  }

  /// Converts point into GeoJSON Feature
  Map<String, dynamic> toGeoJsonFeature() {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'properties': {
        'id': id,
        'address': address,
        'timestamp': timestamp,
        'isoDate': dateTime.toIso8601String(),
        'accuracy': accuracy,
        'activity': activity,
        'mapsUrl': googleMapsUrl,
      },
    };
  }

  @override
  String toString() =>
      'TrailPoint(id: $id, lat: $latitude, lng: $longitude, addr: $address, time: $dateTime)';
}
