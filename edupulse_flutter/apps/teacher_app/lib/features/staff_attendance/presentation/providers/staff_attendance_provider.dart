import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/staff_attendance_entity.dart';
import '../../domain/repositories/staff_attendance_repository.dart';
import '../../data/datasource/staff_attendance_remote_datasource.dart';
import '../../data/repositories/staff_attendance_repository_impl.dart';

sealed class StaffAttendanceState {
  const StaffAttendanceState();
}

class StaffAttendanceInitial extends StaffAttendanceState {
  const StaffAttendanceInitial();
}

class StaffAttendanceLoading extends StaffAttendanceState {
  const StaffAttendanceLoading();
}

class StaffAttendanceNotCheckedIn extends StaffAttendanceState {
  const StaffAttendanceNotCheckedIn();
}

class StaffAttendanceCheckingIn extends StaffAttendanceState {
  final StaffAttendanceEntity? existingData;
  const StaffAttendanceCheckingIn({this.existingData});
}

class StaffAttendanceCheckedIn extends StaffAttendanceState {
  final StaffAttendanceEntity data;
  const StaffAttendanceCheckedIn(this.data);
}

class StaffAttendanceCheckingOut extends StaffAttendanceState {
  final StaffAttendanceEntity existingData;
  const StaffAttendanceCheckingOut(this.existingData);
}

class StaffAttendanceCheckedOut extends StaffAttendanceState {
  final StaffAttendanceEntity data;
  const StaffAttendanceCheckedOut(this.data);
}

class StaffAttendanceError extends StaffAttendanceState {
  final String message;
  final StaffAttendanceEntity? existingData;
  const StaffAttendanceError(this.message, {this.existingData});
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

  @override
  StaffAttendanceState build() {
    return const StaffAttendanceInitial();
  }
  
  Future<void> fetchTodayStatus({bool isSilent = false}) async {
    if (!isSilent) {
      state = const StaffAttendanceLoading();
    }
    final result = await _repository.getTodayStatus();
    result.when(
      onSuccess: (entity) {
        if (entity == null) {
          state = const StaffAttendanceNotCheckedIn();
        } else if (entity.status == 'CHECKED_IN') {
          state = StaffAttendanceCheckedIn(entity);
        } else if (entity.status == 'CHECKED_OUT') {
          state = StaffAttendanceCheckedOut(entity);
        } else {
          state = const StaffAttendanceNotCheckedIn();
        }
      },
      onFailure: (failure) {
        state = StaffAttendanceError(_mapFailureToMessage(failure));
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
    state = StaffAttendanceCheckingIn(existingData: existingData);

    try {
      final locResult = await _getCurrentLocation();
      if (locResult is LocationFailure) {
        state = StaffAttendanceError(locResult.message, existingData: existingData);
        return;
      }
      final successLoc = locResult as LocationSuccess;

      final result = await _repository.checkIn(
        latitude: successLoc.latitude,
        longitude: successLoc.longitude,
        isMocked: successLoc.isMocked,
      );

      await result.when(
        onSuccess: (entity) async {
          state = StaffAttendanceCheckedIn(entity);
        },
        onFailure: (failure) async {
          if (failure.type == ApiFailureType.network || failure.message.toLowerCase().contains('timeout')) {
            state = StaffAttendanceError(
              'Network timeout. Reconciling status with server...',
              existingData: existingData,
            );
            await _reconcileState(isCheckIn: true, fallbackError: _mapFailureToMessage(failure));
          } else {
            state = StaffAttendanceError(_mapFailureToMessage(failure), existingData: existingData);
          }
        },
      );
    } catch (e) {
      state = StaffAttendanceError('An unexpected error occurred during check-in.', existingData: existingData);
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
      state = const StaffAttendanceError('Cannot check out: no active check-in session found.');
      return;
    }
    state = StaffAttendanceCheckingOut(existingData);

    try {
      final locResult = await _getCurrentLocation();
      if (locResult is LocationFailure) {
        state = StaffAttendanceError(locResult.message, existingData: existingData);
        return;
      }
      final successLoc = locResult as LocationSuccess;

      final result = await _repository.checkOut(
        latitude: successLoc.latitude,
        longitude: successLoc.longitude,
        isMocked: successLoc.isMocked,
      );

      await result.when(
        onSuccess: (entity) async {
          state = StaffAttendanceCheckedOut(entity);
        },
        onFailure: (failure) async {
          if (failure.type == ApiFailureType.network || failure.message.toLowerCase().contains('timeout')) {
            state = StaffAttendanceError(
              'Network timeout. Reconciling status with server...',
              existingData: existingData,
            );
            await _reconcileState(isCheckIn: false, fallbackError: _mapFailureToMessage(failure));
          } else {
            state = StaffAttendanceError(_mapFailureToMessage(failure), existingData: existingData);
          }
        },
      );
    } catch (e) {
      state = StaffAttendanceError('An unexpected error occurred during check-out.', existingData: existingData);
    }
  }

  Future<void> _reconcileState({required bool isCheckIn, required String fallbackError}) async {
    final result = await _repository.getTodayStatus();
    result.when(
      onSuccess: (entity) {
        if (entity != null) {
          if (entity.status == 'CHECKED_IN') {
            state = StaffAttendanceCheckedIn(entity);
            return;
          } else if (entity.status == 'CHECKED_OUT') {
            state = StaffAttendanceCheckedOut(entity);
            return;
          }
        }
        state = StaffAttendanceError(
          'Check-${isCheckIn ? 'in' : 'out'} timed out and could not be verified on the server. Please try again.',
          existingData: isCheckIn ? null : stateOrNullEntity(),
        );
      },
      onFailure: (failure) {
        state = StaffAttendanceError(
          'Reconciliation failed: ${failure.message}. Original error: $fallbackError',
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
      
      return LocationSuccess(
        latitude: position.latitude,
        longitude: position.longitude,
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
  final bool isMocked;
  const LocationSuccess({
    required this.latitude,
    required this.longitude,
    required this.isMocked,
  });
}

class LocationFailure extends LocationResult {
  final String message;
  const LocationFailure(this.message);
}
