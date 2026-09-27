import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../data/datasource/teacher_syllabus_datasource.dart';
import '../../data/models/teacher_syllabus_models.dart';
import '../../../../core/providers/school_context_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/domain/entities/dashboard_data.dart';

class TeacherSyllabusQuery {
  final String classId;
  final String sectionId;
  final String subjectId;

  const TeacherSyllabusQuery({
    required this.classId,
    required this.sectionId,
    required this.subjectId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherSyllabusQuery &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          sectionId == other.sectionId &&
          subjectId == other.subjectId;

  @override
  int get hashCode => classId.hashCode ^ sectionId.hashCode ^ subjectId.hashCode;
}

class TeacherSyllabusState {
  final bool isLoading;
  final bool isSaving;
  final List<TeacherSyllabusItem> items;
  final Map<String, TeacherCoverageProgressItem> progressMap;
  final TeacherSyllabusPrediction? prediction;
  final String? errorMessage;
  final String filter; // 'ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED'

  const TeacherSyllabusState({
    this.isLoading = false,
    this.isSaving = false,
    this.items = const [],
    this.progressMap = const {},
    this.prediction,
    this.errorMessage,
    this.filter = 'ALL',
  });

  TeacherSyllabusState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<TeacherSyllabusItem>? items,
    Map<String, TeacherCoverageProgressItem>? progressMap,
    TeacherSyllabusPrediction? prediction,
    String? errorMessage,
    String? filter,
  }) {
    return TeacherSyllabusState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      items: items ?? this.items,
      progressMap: progressMap ?? this.progressMap,
      prediction: prediction ?? this.prediction,
      errorMessage: errorMessage,
      filter: filter ?? this.filter,
    );
  }

  List<TeacherSyllabusItem> get filteredItems {
    if (filter == 'ALL') return items;
    return items.where((item) {
      final prog = progressMap[item.id];
      final status = (prog?.status ?? item.coverageStatus).toUpperCase();
      if (filter == 'COMPLETED') return status == 'COMPLETED';
      if (filter == 'IN_PROGRESS') return status == 'IN_PROGRESS' || status == 'ONGOING';
      if (filter == 'PENDING') return status == 'PENDING' || status == 'NOT_STARTED' || status == 'PLANNED';
      return true;
    }).toList();
  }

  int get completedCount {
    return items.where((i) {
      final p = progressMap[i.id];
      return (p?.status ?? i.coverageStatus).toUpperCase() == 'COMPLETED';
    }).length;
  }

  int get inProgressCount {
    return items.where((i) {
      final p = progressMap[i.id];
      final st = (p?.status ?? i.coverageStatus).toUpperCase();
      return st == 'IN_PROGRESS' || st == 'ONGOING';
    }).length;
  }

  int get pendingCount {
    return items.where((i) {
      final p = progressMap[i.id];
      final st = (p?.status ?? i.coverageStatus).toUpperCase();
      return st != 'COMPLETED' && st != 'IN_PROGRESS' && st != 'ONGOING';
    }).length;
  }
}

final teacherSyllabusDatasourceProvider = Provider<TeacherSyllabusRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TeacherSyllabusRemoteDatasource(apiClient);
});

class TeacherSyllabusNotifier extends StateNotifier<TeacherSyllabusState> {
  final TeacherSyllabusRemoteDatasource _datasource;
  final Ref _ref;
  final TeacherSyllabusQuery _query;

  TeacherSyllabusNotifier(this._datasource, this._ref, this._query)
      : super(const TeacherSyllabusState(isLoading: true)) {
    load();
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = state.copyWith(isLoading: false, errorMessage: 'User is not authenticated.');
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    String? academicYearId;
    if (dashboardState is DashboardSuccess) {
      academicYearId = dashboardState.data.academicYear.id;
    } else if (dashboardState is DashboardRefreshing) {
      academicYearId = dashboardState.data.academicYear.id;
    }

    final schoolId = _ref.read(activeSchoolIdProvider) ??
        (authState.user.schools.isNotEmpty ? authState.user.schools.first : null);

    if (schoolId == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'No active school context found.');
      return;
    }

    try {
      final results = await Future.wait([
        _datasource.getSyllabusItems(
          schoolId: schoolId,
          classId: _query.classId,
          subjectId: _query.subjectId,
          academicYearId: academicYearId,
        ),
        if (academicYearId != null)
          _datasource.getSectionProgress(
            schoolId: schoolId,
            academicYearId: academicYearId,
            sectionId: _query.sectionId,
            subjectId: _query.subjectId,
          )
        else
          Future.value(const ApiResult<List<TeacherCoverageProgressItem>>.success([])),
        if (academicYearId != null)
          _datasource.getPrediction(
            schoolId: schoolId,
            academicYearId: academicYearId,
            classId: _query.classId,
            subjectId: _query.subjectId,
            sectionId: _query.sectionId,
          )
        else
          Future.value(const ApiResult<TeacherSyllabusPrediction?>.success(null)),
      ]);

      final syllabusResult = results[0] as ApiResult<List<TeacherSyllabusItem>>;
      final progressResult = results[1] as ApiResult<List<TeacherCoverageProgressItem>>;
      final predictionResult = results[2] as ApiResult<TeacherSyllabusPrediction?>;

      List<TeacherSyllabusItem> items = [];
      Map<String, TeacherCoverageProgressItem> progressMap = {};
      TeacherSyllabusPrediction? prediction;
      String? error;

      syllabusResult.when(
        onSuccess: (data) => items = data,
        onFailure: (f) => error = f.message,
      );

      progressResult.when(
        onSuccess: (data) {
          for (final p in data) {
            progressMap[p.syllabusId] = p;
          }
        },
        onFailure: (_) {},
      );

      predictionResult.when(
        onSuccess: (data) => prediction = data,
        onFailure: (_) {},
      );

      state = state.copyWith(
        isLoading: false,
        items: items,
        progressMap: progressMap,
        prediction: prediction,
        errorMessage: error,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load syllabus: $e',
      );
    }
  }

  Future<bool> recordProgress({
    required String syllabusId,
    required String status,
    required double completionPercentage,
    String? remarks,
  }) async {
    state = state.copyWith(isSaving: true);

    final authState = _ref.read(authStateProvider);
    final schoolId = _ref.read(activeSchoolIdProvider) ??
        (authState is Authenticated && authState.user.schools.isNotEmpty
            ? authState.user.schools.first
            : null);

    final dashboardState = _ref.read(dashboardStateProvider);
    String? academicYearId;
    String? teacherId;
    if (dashboardState is DashboardSuccess) {
      academicYearId = dashboardState.data.academicYear.id;
      teacherId = dashboardState.data.teacherProfile.id;
    } else if (dashboardState is DashboardRefreshing) {
      academicYearId = dashboardState.data.academicYear.id;
      teacherId = dashboardState.data.teacherProfile.id;
    }

    if (schoolId == null || academicYearId == null) {
      state = state.copyWith(isSaving: false, errorMessage: 'Missing school or academic year context.');
      return false;
    }

    final nowIso = DateTime.now().toIso8601String();
    final result = await _datasource.recordSectionProgress(
      schoolId: schoolId,
      academicYearId: academicYearId,
      syllabusId: syllabusId,
      sectionId: _query.sectionId,
      teacherId: teacherId,
      status: status,
      completionPercentage: completionPercentage,
      startedAt: status != 'NOT_STARTED' ? nowIso : null,
      completedAt: status == 'COMPLETED' ? nowIso : null,
      remarks: remarks,
    );

    return result.when(
      onSuccess: (savedItem) async {
        final updatedMap = Map<String, TeacherCoverageProgressItem>.from(state.progressMap);
        updatedMap[syllabusId] = savedItem;

        state = state.copyWith(
          isSaving: false,
          progressMap: updatedMap,
        );

        // Refresh prediction to reflect new pace and estimated completion
        final predResult = await _datasource.getPrediction(
          schoolId: schoolId,
          academicYearId: academicYearId!,
          classId: _query.classId,
          subjectId: _query.subjectId,
          sectionId: _query.sectionId,
        );

        predResult.when(
          onSuccess: (newPred) {
            state = state.copyWith(prediction: newPred);
          },
          onFailure: (_) {},
        );

        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to record progress: ${failure.message}',
        );
        return false;
      },
    );
  }
}

final teacherSyllabusProvider = StateNotifierProvider.family<
    TeacherSyllabusNotifier, TeacherSyllabusState, TeacherSyllabusQuery>(
  (ref, query) {
    final datasource = ref.watch(teacherSyllabusDatasourceProvider);
    return TeacherSyllabusNotifier(datasource, ref, query);
  },
);
