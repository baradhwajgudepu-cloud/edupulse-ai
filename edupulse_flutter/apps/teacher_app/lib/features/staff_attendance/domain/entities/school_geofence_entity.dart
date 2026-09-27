import 'package:equatable/equatable.dart';

class SchoolGeofenceEntity extends Equatable {
  final String schoolId;
  final bool enabled;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final bool isConfigured;

  const SchoolGeofenceEntity({
    required this.schoolId,
    required this.enabled,
    this.latitude,
    this.longitude,
    required this.radiusMeters,
    required this.isConfigured,
  });

  factory SchoolGeofenceEntity.fromJson(Map<String, dynamic> json) {
    return SchoolGeofenceEntity(
      schoolId: (json['school_id'] ?? json['id'] ?? '').toString(),
      enabled: json['enabled'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusMeters: (json['radius_meters'] ?? json['geofence_radius_meters'] as num?)?.toInt() ?? 100,
      isConfigured: json['is_configured'] as bool? ?? (json['latitude'] != null && json['longitude'] != null),
    );
  }

  @override
  List<Object?> get props => [schoolId, enabled, latitude, longitude, radiusMeters, isConfigured];
}
