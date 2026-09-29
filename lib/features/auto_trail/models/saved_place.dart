import 'package:geolocator/geolocator.dart';

/// Represents a user-named favorite place or geofenced location
/// (e.g. "Home", "Office", "Iron Gym", "Cafe") used to automatically
/// tag stationary clusters in Auto Trail.
class SavedPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String icon; // 'home' | 'office' | 'gym' | 'cafe' | 'library' | 'pin'
  final DateTime createdAt;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100.0,
    this.icon = 'pin',
    required this.createdAt,
  });

  /// Computes distance in meters from given point to this saved place
  double distanceTo(double lat, double lng) {
    return Geolocator.distanceBetween(latitude, longitude, lat, lng);
  }

  /// Checks if coordinates fall within this place's radius
  bool isInside(double lat, double lng) {
    return distanceTo(lat, lng) <= radiusMeters;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'icon': icon,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory SavedPlace.fromMap(Map<String, dynamic> map) => SavedPlace(
        id: map['id'] as String,
        name: map['name'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 100.0,
        icon: map['icon'] as String? ?? 'pin',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  SavedPlace copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? icon,
    DateTime? createdAt,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
