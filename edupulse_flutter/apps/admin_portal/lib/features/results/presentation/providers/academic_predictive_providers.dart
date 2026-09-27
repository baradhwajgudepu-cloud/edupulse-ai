import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../data/models/academic_predictive_models.dart';

class AcademicPredictiveState {
  final bool isLoading;
  final AcademicPredictiveAnalyticsModel? analytics;
  final String? errorMessage;
  final String? classId;
  final String? academicYearId;
  final String? subjectId;

  const AcademicPredictiveState({
    this.isLoading = false,
    this.analytics,
    this.errorMessage,
    this.classId,
    this.academicYearId,
    this.subjectId,
  });

  AcademicPredictiveState copyWith({
    bool? isLoading,
    AcademicPredictiveAnalyticsModel? analytics,
    String? errorMessage,
    bool clearError = false,
    String? classId,
    String? academicYearId,
    String? subjectId,
  }) {
    return AcademicPredictiveState(
      isLoading: isLoading ?? this.isLoading,
      analytics: analytics ?? this.analytics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      classId: classId ?? this.classId,
      academicYearId: academicYearId ?? this.academicYearId,
      subjectId: subjectId ?? this.subjectId,
    );
  }
}

class AcademicPredictiveNotifier extends StateNotifier<AcademicPredictiveState> {
  final Ref _ref;

  AcademicPredictiveNotifier(this._ref) : super(const AcademicPredictiveState());

  Future<void> fetchPredictiveIntelligence({
    String? classId,
    String? academicYearId,
    String? subjectId,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      state = state.copyWith(errorMessage: 'Please select a school first.');
      return;
    }

    final targetClassId = classId ?? state.classId;
    final targetAyId = academicYearId ?? state.academicYearId;
    final targetSubjectId = subjectId ?? state.subjectId;

    if (targetClassId == null || targetAyId == null) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      classId: targetClassId,
      academicYearId: targetAyId,
      subjectId: targetSubjectId,
    );

    try {
      final apiClient = _ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{
        'school_id': schoolId,
        'class_id': targetClassId,
        'academic_year_id': targetAyId,
      };
      if (targetSubjectId != null && targetSubjectId.isNotEmpty) {
        queryParams['subject_id'] = targetSubjectId;
      }

      final result = await apiClient.get(
        '/ai-intelligence/academic-predictive',
        queryParameters: queryParams,
        mapper: (json) => AcademicPredictiveAnalyticsModel.fromJson(
          json['data'] as Map<String, dynamic>? ?? json as Map<String, dynamic>,
        ),
      );

      result.when(
        onSuccess: (data) {
          state = state.copyWith(
            isLoading: false,
            analytics: data,
          );
        },
        onFailure: (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<StudentPredictiveAnalyticsModel?> fetchStudentPredictive({
    required String studentId,
    String? academicYearId,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return null;

    final targetAyId = academicYearId ?? state.academicYearId;

    try {
      final apiClient = _ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{
        'school_id': schoolId,
      };
      if (targetAyId != null) {
        queryParams['academic_year_id'] = targetAyId;
      }

      final result = await apiClient.get(
        '/ai-intelligence/student/$studentId/predictive',
        queryParameters: queryParams,
        mapper: (json) => StudentPredictiveAnalyticsModel.fromJson(
          json['data'] as Map<String, dynamic>? ?? json as Map<String, dynamic>,
        ),
      );

      return result.when(
        onSuccess: (data) => data,
        onFailure: (_) => null,
      );
    } catch (_) {
      return null;
    }
  }
}

final academicPredictiveProvider =
    StateNotifierProvider<AcademicPredictiveNotifier, AcademicPredictiveState>((ref) {
  return AcademicPredictiveNotifier(ref);
});

final studentPredictiveProvider = FutureProvider.family<StudentPredictiveAnalyticsModel?, String>((ref, studentId) async {
  final notifier = ref.read(academicPredictiveProvider.notifier);
  return notifier.fetchStudentPredictive(studentId: studentId);
});
