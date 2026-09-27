import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/timetable_models.dart';

typedef SectionTimetableParams = ({
  String schoolId,
  String academicYearId,
  String classId,
  String sectionId,
});

final sectionTimetableProvider =
    FutureProvider.family<List<TimetableDto>, SectionTimetableParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  final result = await apiClient.get(
    '/timetables/section-schedule?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&class_id=${params.classId}&section_id=${params.sectionId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>;
      return list
          .map((item) => TimetableDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (slots) => slots,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

typedef TeacherTimetableParams = ({
  String schoolId,
  String academicYearId,
  String teacherId,
});

final teacherTimetableProvider =
    FutureProvider.family<List<TimetableDto>, TeacherTimetableParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  final result = await apiClient.get(
    '/timetables/teacher-schedule?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&teacher_id=${params.teacherId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>;
      return list
          .map((item) => TimetableDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (slots) => slots,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class TimetableActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final bool isConflict;

  const TimetableActionState({
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
    this.isConflict = false,
  });
}

class TimetableActionNotifier extends StateNotifier<TimetableActionState> {
  final BaseApiClient _apiClient;

  TimetableActionNotifier(this._apiClient)
      : super(const TimetableActionState(isLoading: false));

  Future<bool> createSlot(Map<String, dynamic> data) async {
    state = const TimetableActionState(isLoading: true);
    final result = await _apiClient.post(
      '/timetables',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const TimetableActionState(
          isLoading: false,
          successMessage: 'Timetable slot created successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        final conflict = failure.statusCode == 422 ||
            failure.statusCode == 409 ||
            failure.message.contains('conflict') ||
            failure.message.contains('double');
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
          isConflict: conflict,
        );
        return false;
      },
    );
  }

  Future<bool> updateSlot(String id, String schoolId, Map<String, dynamic> data) async {
    state = const TimetableActionState(isLoading: true);
    final result = await _apiClient.put(
      '/timetables/$id?school_id=$schoolId',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const TimetableActionState(
          isLoading: false,
          successMessage: 'Timetable slot updated successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> deleteSlot(String id, String schoolId) async {
    state = const TimetableActionState(isLoading: true);
    final result = await _apiClient.delete(
      '/timetables/$id?school_id=$schoolId',
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const TimetableActionState(
          isLoading: false,
          successMessage: 'Timetable slot deleted successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> copyDay({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String sourceDay,
    required String targetDay,
  }) async {
    state = const TimetableActionState(isLoading: true);
    final result = await _apiClient.post(
      '/timetables/copy-day',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
        'source_day': sourceDay,
        'target_day': targetDay,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (data) {
        final message = (data is Map && data['message'] != null)
            ? data['message'] as String
            : 'Day schedule copied successfully.';
        state = TimetableActionState(
          isLoading: false,
          successMessage: message,
        );
        return true;
      },
      onFailure: (failure) {
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> copySection({
    required String schoolId,
    required String academicYearId,
    required String sourceClassId,
    required String sourceSectionId,
    required String targetClassId,
    required String targetSectionId,
  }) async {
    state = const TimetableActionState(isLoading: true);
    final result = await _apiClient.post(
      '/timetables/copy-section',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'source_class_id': sourceClassId,
        'source_section_id': sourceSectionId,
        'target_class_id': targetClassId,
        'target_section_id': targetSectionId,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (data) {
        final message = (data is Map && data['message'] != null)
            ? data['message'] as String
            : 'Section schedule copied successfully.';
        state = TimetableActionState(
          isLoading: false,
          successMessage: message,
        );
        return true;
      },
      onFailure: (failure) {
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> clearDay({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String dayOfWeek,
  }) async {
    state = const TimetableActionState(isLoading: true);
    final result = await _apiClient.post(
      '/timetables/clear-day',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
        'day_of_week': dayOfWeek,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (data) {
        final message = (data is Map && data['message'] != null)
            ? data['message'] as String
            : 'Day schedule cleared successfully.';
        state = TimetableActionState(
          isLoading: false,
          successMessage: message,
        );
        return true;
      },
      onFailure: (failure) {
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> bulkUpdateStatus({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String status,
  }) async {
    state = const TimetableActionState(isLoading: true);
    final result = await _apiClient.post(
      '/timetables/bulk-status',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
        'status': status,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (data) {
        final message = (data is Map && data['message'] != null)
            ? data['message'] as String
            : 'Timetable status updated to $status.';
        state = TimetableActionState(
          isLoading: false,
          successMessage: message,
        );
        return true;
      },
      onFailure: (failure) {
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<TimetableConflictDto> checkConflict(Map<String, dynamic> data) async {
    final result = await _apiClient.post(
      '/timetables/conflicts/check',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final map = payload['data'] as Map<String, dynamic>? ?? {};
        return TimetableConflictDto.fromJson(map);
      },
    );

    return result.when(
      onSuccess: (conflict) => conflict,
      onFailure: (failure) => TimetableConflictDto(
        hasConflict: false,
        conflictMessage: failure.message,
      ),
    );
  }

  Future<bool> moveSlot({
    required String sourceId,
    required DayOfWeek targetDayOfWeek,
    required int targetPeriodNumber,
    required String schoolId,
    required String academicYearId,
  }) async {
    state = const TimetableActionState(isLoading: true);
    final req = TimetableMoveRequest(
      sourceId: sourceId,
      targetDayOfWeek: targetDayOfWeek,
      targetPeriodNumber: targetPeriodNumber,
      schoolId: schoolId,
      academicYearId: academicYearId,
    );

    final result = await _apiClient.post(
      '/timetables/move',
      data: req.toJson(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>? ?? {};
        return TimetableMoveResponseDto.fromJson(data);
      },
    );

    return result.when(
      onSuccess: (resp) {
        state = TimetableActionState(
          isLoading: false,
          successMessage: resp.message,
        );
        return true;
      },
      onFailure: (failure) {
        final conflict = failure.statusCode == 422 ||
            failure.statusCode == 409 ||
            failure.message.toLowerCase().contains('conflict') ||
            failure.message.toLowerCase().contains('cannot');
        state = TimetableActionState(
          isLoading: false,
          errorMessage: failure.message,
          isConflict: conflict,
        );
        return false;
      },
    );
  }
}

final timetableActionProvider =
    StateNotifierProvider<TimetableActionNotifier, TimetableActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TimetableActionNotifier(apiClient);
});
