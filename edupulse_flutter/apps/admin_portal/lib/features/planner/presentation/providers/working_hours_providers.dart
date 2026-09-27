import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/timetable_models.dart';

typedef CapacityParams = ({
  String schoolId,
  String academicYearId,
  String? classId,
  String? sectionId,
});

final timetableCapacityProvider =
    FutureProvider.family<TimetableCapacitySummaryDto, CapacityParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  var url = '/working-hours/capacity?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}';
  if (params.classId != null && params.classId!.isNotEmpty) {
    url += '&class_id=${params.classId}';
  }
  if (params.sectionId != null && params.sectionId!.isNotEmpty) {
    url += '&section_id=${params.sectionId}';
  }

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>;
      return TimetableCapacitySummaryDto.fromJson(data);
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

typedef WorkingHoursParams = ({
  String schoolId,
  String academicYearId,
});

final extendedWorkingHoursProvider =
    FutureProvider.family<ExtendedWorkingHourDto, WorkingHoursParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  final url = '/working-hours?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}';

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>;
      return ExtendedWorkingHourDto.fromJson(data);
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class WorkingHoursActionState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const WorkingHoursActionState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });
}

class WorkingHoursActionNotifier extends StateNotifier<WorkingHoursActionState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  WorkingHoursActionNotifier(this._apiClient, this._ref)
      : super(const WorkingHoursActionState());

  Future<bool> updateWorkingHours(ExtendedWorkingHourDto dto) async {
    state = const WorkingHoursActionState(isLoading: true);

    final result = await _apiClient.put(
      '/working-hours?school_id=${dto.schoolId}&academic_year_id=${dto.academicYearId}',
      data: dto.toJson(),
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (data) {
        state = const WorkingHoursActionState(
          isLoading: false,
          successMessage: 'Working hours and timetable capacity updated successfully.',
        );
        _ref.invalidate(extendedWorkingHoursProvider);
        _ref.invalidate(timetableCapacityProvider);
        return true;
      },
      onFailure: (failure) {
        state = WorkingHoursActionState(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<TimetableRecalculationPreviewDto?> previewRecalculation({
    required String schoolId,
    required String academicYearId,
    List<BreakTimingDto>? breaks,
    int? periodDurationMinutes,
  }) async {
    final payload = <String, dynamic>{
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      if (breaks != null) 'breaks': breaks.map((b) => b.toJson()).toList(),
      if (periodDurationMinutes != null) 'period_duration_minutes': periodDurationMinutes,
    };

    final result = await _apiClient.post(
      '/working-hours/preview-recalculation?school_id=$schoolId&academic_year_id=$academicYearId',
      data: payload,
      mapper: (json) {
        final resMap = json as Map<String, dynamic>;
        final data = resMap['data'] as Map<String, dynamic>;
        return TimetableRecalculationPreviewDto.fromJson(data);
      },
    );

    return result.when(
      onSuccess: (data) => data,
      onFailure: (failure) {
        state = WorkingHoursActionState(isLoading: false, error: failure.message);
        return null;
      },
    );
  }

  Future<bool> applyRecalculatedTimings({
    required String schoolId,
    required String academicYearId,
    required bool approveExtension,
    String? newEndTime,
    List<BreakTimingDto>? breaks,
    int? periodDurationMinutes,
  }) async {
    state = const WorkingHoursActionState(isLoading: true);
    final payload = <String, dynamic>{
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'approve_extension': approveExtension,
      if (newEndTime != null) 'new_end_time': newEndTime,
      if (breaks != null) 'breaks': breaks.map((b) => b.toJson()).toList(),
      if (periodDurationMinutes != null) 'period_duration_minutes': periodDurationMinutes,
    };

    final result = await _apiClient.post(
      '/working-hours/apply-recalculated-timings',
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (data) {
        state = const WorkingHoursActionState(
          isLoading: false,
          successMessage: 'Timetable timings and break configuration updated successfully.',
        );
        _ref.invalidate(extendedWorkingHoursProvider);
        _ref.invalidate(timetableCapacityProvider);
        return true;
      },
      onFailure: (failure) {
        state = WorkingHoursActionState(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final workingHoursActionProvider =
    StateNotifierProvider<WorkingHoursActionNotifier, WorkingHoursActionState>((ref) {
  final client = ref.watch(apiClientProvider);
  return WorkingHoursActionNotifier(client, ref);
});
