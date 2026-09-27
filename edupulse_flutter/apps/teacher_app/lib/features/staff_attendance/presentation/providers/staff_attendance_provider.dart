import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/staff_attendance_entity.dart';
import '../../domain/entities/school_geofence_entity.dart';
import '../../domain/repositories/staff_attendance_repository.dart';
import '../../data/datasource/staff_attendance_remote_datasource.dart';
import '../../data/repositories/staff_attendance_repository_impl.dart';
import '../../../../core/providers/school_context_provider.dart';

sealed class StaffAttendanceState {
  final SchoolGeofenceEntity? schoolGeofence;
  const StaffAttendanceState({this.schoolGeofence});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffAttendanceState && runtimeType == other.runtimeType);

  @override
  int get hashCode => runtimeType.hashCode;
}

class StaffAttendanceInitial extends StaffAttendanceState {
  const StaffAttendanceInitial({super.schoolGeofence});
}

class StaffAttendanceLoading extends StaffAttendanceState {
  const StaffAttendanceLoading({super.schoolGeofence});
}

class StaffAttendanceNotCheckedIn extends StaffAttendanceState {
  const StaffAttendanceNotCheckedIn({super.schoolGeofence});
}

class StaffAttendanceCheckingIn extends StaffAttendanceState {
  final StaffAttendanceEntity? existingData;
  const StaffAttendanceCheckingIn({super.schoolGeofence, this.existingData});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffAttendanceCheckingIn &&
          existingData == other.existingData);

  @override
  int get hashCode => Object.hash(runtimeType, existingData);
}

class StaffAttendanceCheckedIn extends StaffAttendanceState {
  final StaffAttendanceEntity data;
  const StaffAttendanceCheckedIn(this.data, {super.schoolGeofence});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffAttendanceCheckedIn && data == other.data);

  @override
  int get hashCode => Object.hash(runtimeType, data);
}

class StaffAttendanceCheckingOut extends StaffAttendanceState {
  final StaffAttendanceEntity existingData;
  const StaffAttendanceCheckingOut(this.existingData, {super.schoolGeofence});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffAttendanceCheckingOut &&
          existingData == other.existingData);

  @override
  int get hashCode => Object.hash(runtimeType, existingData);
}

class StaffAttendanceCheckedOut extends StaffAttendanceState {
  final StaffAttendanceEntity data;
  const StaffAttendanceCheckedOut(this.data, {super.schoolGeofence});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffAttendanceCheckedOut && data == other.data);

  @override
  int get hashCode => Object.hash(runtimeType, data);
}

class StaffAttendanceError extends StaffAttendanceState {
  final String message;
  final StaffAttendanceEntity? existingData;
  const StaffAttendanceError(this.message, {super.schoolGeofence, this.existingData});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffAttendanceError &&
          message == other.message &&
          existingData == other.existingData);

  @override
  int get hashCode => Object.hash(runtimeType, message, existingData);
}

final staffAttendanceRemoteDatasourceProvider = Provider<StaffAttendanceRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StaffAttendanceRemoteDatasource(apiClient);
});

final staffAttendanceRepositoryProvider = Provider<StaffAttendanceRepository>((ref) {
  final remote = ref.watch(staffAttendanceRemoteDatasourceProvider);
  return StaffAttendanceRepositoryImpl(remote);
});

final staffAttendanceStateProvider = NotifierProvider<StaffAttendanceNotifier, StaffAttendanceState>(() {
  return StaffAttendanceNotifier();
});

class StaffAttendanceNotifier extends Notifier<StaffAttendanceState> {
  StaffAttendanceRepository get _repository => ref.read(staffAttendanceRepositoryProvider);

  String? _getSchoolId([StaffAttendanceEntity? existing]) {
    final activeId = ref.read(activeSchoolIdProvider);
    if (activeId != null && activeId.isNotEmpty) return activeId;
    if (existing?.schoolId != null && existing!.schoolId.isNotEmpty) return existing.schoolId;
    return null;
  }

  @override
  StaffAttendanceState build() {
    return const StaffAttendanceInitial();
  }
  
  Future<void> fetchTodayStatus({bool isSilent = false}) async {
    if (!isSilent) {
      state = StaffAttendanceLoading(schoolGeofence: state.schoolGeofence);
    }

    final schoolId = _getSchoolId();
    SchoolGeofenceEntity? geofence = state.schoolGeofence;
    if (schoolId != null && schoolId.isNotEmpty) {
      final gfResult = await _repository.getSchoolGeofence(schoolId);
      gfResult.when(
        onSuccess: (data) => geofence = data,
        onFailure: (_) {},
      );
    }

    final result = await _repository.getTodayStatus();
    result.when(
      onSuccess: (entity) {
        if (entity == null) {
          state = StaffAttendanceNotCheckedIn(schoolGeofence: geofence);
        } else if (entity.status == 'CHECKED_IN') {
          state = StaffAttendanceCheckedIn(entity, schoolGeofence: geofence);
        } else if (entity.status == 'CHECKED_OUT') {
          state = StaffAttendanceCheckedOut(entity, schoolGeofence: geofence);
        } else {
          state = StaffAttendanceNotCheckedIn(schoolGeofence: geofence);
        }
      },
      onFailure: (failure) {
        state = StaffAttendanceError(_mapFailureToMessage(failure), schoolGeofence: geofence);
      },
    );
  }

  Future<void> checkIn() async {
    final current = state;
    if (current is StaffAttendanceCheckingIn || current is StaffAttendanceCheckingOut) {
      return; // prevent duplicate operations
    }
    
    StaffAttendanceEntity? existingData;
    if (current is StaffAttendanceCheckedIn) {
      existingData = current.data;
    } else if (current is StaffAttendanceError) {
      existingData = current.existingData;
    }
    final geofence = current.schoolGeofence;
    state = StaffAttendanceCheckingIn(schoolGeofence: geofence, existingData: existingData);

    try {
      final locResult = await _getCurrentLocation();
      if (locResult is LocationFailure) {
        state = StaffAttendanceError(locResult.message, schoolGeofence: geofence, existingData: existingData);
        return;
      }
      final successLoc = locResult as LocationSuccess;

      // Ensure school geofence is available
      SchoolGeofenceEntity? activeGf = geofence;
      if (activeGf == null) {
        final schoolId = _getSchoolId(existingData);
        if (schoolId != null && schoolId.isNotEmpty) {
          final gfResult = await _repository.getSchoolGeofence(schoolId);
          activeGf = gfResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => null,
          );
        }
      }

      final verifiedGf = activeGf;
      // Geofence enforcement when enabled
      if (verifiedGf != null && verifiedGf.enabled) {
        if (!verifiedGf.isConfigured || verifiedGf.latitude == null || verifiedGf.longitude == null) {
          state = StaffAttendanceError(
            'School attendance location is not configured. Please contact administration.',
            schoolGeofence: verifiedGf,
            existingData: existingData,
          );
          return;
        }

        if (successLoc.isMocked) {
          state = StaffAttendanceError(
            'Mocked GPS location detected. Attendance cannot be verified using simulated location providers.',
            schoolGeofence: verifiedGf,
            existingData: existingData,
          );
          return;
        }

        final distance = Geolocator.distanceBetween(
          successLoc.latitude,
          successLoc.longitude,
          verifiedGf.latitude!,
          verifiedGf.longitude!,
        );

        final tolerance = math.min(successLoc.accuracy, math.min(15.0, verifiedGf.radiusMeters * 0.1));
        if (distance > verifiedGf.radiusMeters + tolerance) {
          state = StaffAttendanceError(
            'You are outside the school attendance location. Please move within the permitted area and try again. (Distance: ${distance.toStringAsFixed(1)}m, Allowed: ${verifiedGf.radiusMeters}m)',
            schoolGeofence: verifiedGf,
            existingData: existingData,
          );
          return;
        }
      }

      final result = await _repository.checkIn(
        latitude: successLoc.latitude,
        longitude: successLoc.longitude,
        accuracy: successLoc.accuracy,
        isMocked: successLoc.isMocked,
      );

      await result.when(
        onSuccess: (entity) async {
          state = StaffAttendanceCheckedIn(entity, schoolGeofence: verifiedGf);
        },
        onFailure: (failure) async {
          if (failure.type == ApiFailureType.network || failure.message.toLowerCase().contains('timeout')) {
            state = StaffAttendanceError(
              'Network timeout. Reconciling status with server...',
              schoolGeofence: verifiedGf,
              existingData: existingData,
            );
            await _reconcileState(isCheckIn: true, fallbackError: _mapFailureToMessage(failure));
          } else {
            state = StaffAttendanceError(_mapFailureToMessage(failure), schoolGeofence: verifiedGf, existingData: existingData);
          }
        },
      );
    } catch (e) {
      state = StaffAttendanceError('An unexpected error occurred during check-in.', schoolGeofence: geofence, existingData: existingData);
    }
  }

  Future<void> checkOut() async {
    final current = state;
    if (current is StaffAttendanceCheckingIn || current is StaffAttendanceCheckingOut) {
      return; // prevent duplicate operations
    }

    StaffAttendanceEntity? existingData;
    if (current is StaffAttendanceCheckedIn) {
      existingData = current.data;
    } else if (current is StaffAttendanceError) {
      existingData = current.existingData;
    }
    
    if (existingData == null) {
      state = StaffAttendanceError('Cannot check out: no active check-in session found.', schoolGeofence: current.schoolGeofence);
      return;
    }
    final geofence = current.schoolGeofence;
    state = StaffAttendanceCheckingOut(existingData, schoolGeofence: geofence);

    try {
      final locResult = await _getCurrentLocation();
      if (locResult is LocationFailure) {
        state = StaffAttendanceError(locResult.message, schoolGeofence: geofence, existingData: existingData);
        return;
      }
      final successLoc = locResult as LocationSuccess;

      // Ensure school geofence is available
      SchoolGeofenceEntity? activeGf = geofence;
      if (activeGf == null) {
        final schoolId = _getSchoolId(existingData);
        if (schoolId != null && schoolId.isNotEmpty) {
          final gfResult = await _repository.getSchoolGeofence(schoolId);
          activeGf = gfResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => null,
          );
        }
      }

      final verifiedGf = activeGf;
      // Geofence enforcement when enabled
      if (verifiedGf != null && verifiedGf.enabled) {
        if (!verifiedGf.isConfigured || verifiedGf.latitude == null || verifiedGf.longitude == null) {
          state = StaffAttendanceError(
            'School attendance location is not configured. Please contact administration.',
            schoolGeofence: verifiedGf,
            existingData: existingData,
          );
          return;
        }

        if (successLoc.isMocked) {
          state = StaffAttendanceError(
            'Mocked GPS location detected. Attendance cannot be verified using simulated location providers.',
            schoolGeofence: verifiedGf,
            existingData: existingData,
          );
          return;
        }

        final distance = Geolocator.distanceBetween(
          successLoc.latitude,
          successLoc.longitude,
          verifiedGf.latitude!,
          verifiedGf.longitude!,
        );

        final tolerance = math.min(successLoc.accuracy, math.min(15.0, verifiedGf.radiusMeters * 0.1));
        if (distance > verifiedGf.radiusMeters + tolerance) {
          state = StaffAttendanceError(
            'You are outside the school attendance location. Please move within the permitted area and try again. (Distance: ${distance.toStringAsFixed(1)}m, Allowed: ${verifiedGf.radiusMeters}m)',
            schoolGeofence: verifiedGf,
            existingData: existingData,
          );
          return;
        }
      }

      final result = await _repository.checkOut(
        latitude: successLoc.latitude,
        longitude: successLoc.longitude,
        accuracy: successLoc.accuracy,
        isMocked: successLoc.isMocked,
      );

      await result.when(
        onSuccess: (entity) async {
          state = StaffAttendanceCheckedOut(entity, schoolGeofence: verifiedGf);
        },
        onFailure: (failure) async {
          if (failure.type == ApiFailureType.network || failure.message.toLowerCase().contains('timeout')) {
            state = StaffAttendanceError(
              'Network timeout. Reconciling status with server...',
              schoolGeofence: verifiedGf,
              existingData: existingData,
            );
            await _reconcileState(isCheckIn: false, fallbackError: _mapFailureToMessage(failure));
          } else {
            state = StaffAttendanceError(_mapFailureToMessage(failure), schoolGeofence: verifiedGf, existingData: existingData);
          }
        },
      );
    } catch (e) {
      state = StaffAttendanceError('An unexpected error occurred during check-out.', schoolGeofence: geofence, existingData: existingData);
    }
  }

  Future<void> _reconcileState({required bool isCheckIn, required String fallbackError}) async {
    final result = await _repository.getTodayStatus();
    result.when(
      onSuccess: (entity) {
        if (entity != null) {
          if (entity.status == 'CHECKED_IN') {
            state = StaffAttendanceCheckedIn(entity, schoolGeofence: state.schoolGeofence);
            return;
          } else if (entity.status == 'CHECKED_OUT') {
            state = StaffAttendanceCheckedOut(entity, schoolGeofence: state.schoolGeofence);
            return;
          }
        }
        state = StaffAttendanceError(
          'Check-${isCheckIn ? 'in' : 'out'} timed out and could not be verified on the server. Please try again.',
          schoolGeofence: state.schoolGeofence,
          existingData: isCheckIn ? null : stateOrNullEntity(),
        );
      },
      onFailure: (failure) {
        state = StaffAttendanceError(
          'Reconciliation failed: ${failure.message}. Original error: $fallbackError',
          schoolGeofence: state.schoolGeofence,
          existingData: isCheckIn ? null : stateOrNullEntity(),
        );
      },
    );
  }

  StaffAttendanceEntity? stateOrNullEntity() {
    final current = state;
    if (current is StaffAttendanceCheckedIn) return current.data;
    if (current is StaffAttendanceCheckedOut) return current.data;
    if (current is StaffAttendanceCheckingOut) return current.existingData;
    if (current is StaffAttendanceError) return current.existingData;
    return null;
  }

  Future<LocationResult> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFailure('Location services are turned off. Please enable location services and try again.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationFailure('Location permission is required for staff attendance.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationFailure('Location permission has been permanently denied. Please enable it from device settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Validate location accuracy (reject if accuracy is worse than 100 meters)
      if (position.accuracy > 100.0) {
        return LocationFailure(
          'GPS accuracy is too low (${position.accuracy.toStringAsFixed(0)}m). Please wait for a better GPS fix and try again.',
        );
      }

      // Validate freshness (reject if location timestamp is older than 2 minutes)
      final age = DateTime.now().difference(position.timestamp);
      if (age.inMinutes > 2) {
        return const LocationFailure('Location data is stale. Please try again.');
      }
      
      return LocationSuccess(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isMocked: position.isMocked,
      );
    } catch (e) {
      return const LocationFailure('Unable to retrieve location. Please check device settings.');
    }
  }

  String _mapFailureToMessage(ApiFailure failure) {
    if (failure.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    if (failure.statusCode == 403) {
      return 'You are not authorized to use staff attendance.';
    }
    if (failure.statusCode == 404) {
      return 'Teacher attendance profile could not be found.';
    }
    if (failure.statusCode == 409) {
      return failure.message;
    }
    if (failure.statusCode == 422) {
      return failure.message;
    }
    if (failure.statusCode == 500) {
      return 'Something went wrong on the server. Please try again.';
    }
    if (failure.type == ApiFailureType.network) {
      return 'Unable to confirm attendance right now.';
    }
    return failure.message;
  }
}

sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMocked;
  const LocationSuccess({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMocked,
  });
}

class LocationFailure extends LocationResult {
  final String message;
  const LocationFailure(this.message);
}
