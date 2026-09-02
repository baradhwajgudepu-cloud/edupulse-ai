import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'results_download_helper.dart';

// 1. Results Filter State
class ResultsFiltersState {
  final String? academicYearId;
  final String? examinationId;
  final String? classId;
  final String? sectionId;

  const ResultsFiltersState({
    this.academicYearId,
    this.examinationId,
    this.classId,
    this.sectionId,
  });

  ResultsFiltersState copyWith({
    String? academicYearId,
    String? examinationId,
    String? classId,
    String? sectionId,
  }) {
    return ResultsFiltersState(
      academicYearId: academicYearId ?? this.academicYearId,
      examinationId: examinationId ?? this.examinationId,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
    );
  }
}

class ResultsFiltersNotifier extends StateNotifier<ResultsFiltersState> {
  ResultsFiltersNotifier() : super(const ResultsFiltersState());

  void setAcademicYear(String? id) {
    state = ResultsFiltersState(
      academicYearId: id,
      examinationId: null,
      classId: null,
      sectionId: null,
    );
  }

  void setExamination(String? id) {
    state = ResultsFiltersState(
      academicYearId: state.academicYearId,
      examinationId: id,
      classId: state.classId,
      sectionId: state.sectionId,
    );
  }

  void setClass(String? id) {
    state = ResultsFiltersState(
      academicYearId: state.academicYearId,
      examinationId: state.examinationId,
      classId: id,
      sectionId: null,
    );
  }

  void setSection(String? id) {
    state = ResultsFiltersState(
      academicYearId: state.academicYearId,
      examinationId: state.examinationId,
      classId: state.classId,
      sectionId: id,
    );
  }

  void reset() {
    state = const ResultsFiltersState();
  }
}

final resultsFiltersProvider =
    StateNotifierProvider<ResultsFiltersNotifier, ResultsFiltersState>((ref) {
  final notifier = ResultsFiltersNotifier();
  ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
    notifier.reset();
  });
  ref.listen<String?>(activeTenantIdProvider, (previous, next) {
    notifier.reset();
  });
  return notifier;
});

// 2. Examinations Loader
final resultsExaminationsProvider = FutureProvider.autoDispose<List<ExaminationDto>>((ref) async {
  final filters = ref.watch(resultsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);

  if (schoolId == null) return const [];
  
  final apiClient = ref.watch(apiClientProvider);
  final academicYearQuery = filters.academicYearId != null ? '&academic_year_id=${filters.academicYearId}' : '';
  
  final result = await apiClient.get(
    '/examinations?school_id=$schoolId$academicYearQuery',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) => ExaminationDto.fromJson(item as Map<String, dynamic>))
          .toList();
    },
  );

  return result.when(
    onSuccess: (exams) => exams,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 3. Roster Students Loader
final resultsStudentsProvider = FutureProvider.autoDispose<List<StudentDto>>((ref) async {
  final filters = ref.watch(resultsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);

  if (schoolId == null || filters.classId == null || filters.sectionId == null) {
    return const [];
  }

  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/students?school_id=$schoolId&class_id=${filters.classId}&section_id=${filters.sectionId}&limit=100',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) => StudentDto.fromJson(item as Map<String, dynamic>))
          .toList();
    },
  );

  return result.when(
    onSuccess: (students) {
      // Sort students numerically by roll number
      final sorted = List<StudentDto>.from(students);
      sorted.sort((a, b) {
        final aRoll = int.tryParse(a.rollNumber) ?? 99999;
        final bRoll = int.tryParse(b.rollNumber) ?? 99999;
        return aRoll.compareTo(bRoll);
      });
      return sorted;
    },
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 4. Report Cards Loader
final resultsReportCardsProvider = FutureProvider.autoDispose<List<ReportCardDto>>((ref) async {
  final filters = ref.watch(resultsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);

  if (schoolId == null || filters.classId == null || filters.sectionId == null) {
    return const [];
  }

  final apiClient = ref.watch(apiClientProvider);
  final academicYearQuery = filters.academicYearId != null ? '&academic_year_id=${filters.academicYearId}' : '';

  final result = await apiClient.get(
    '/report-cards?school_id=$schoolId&class_id=${filters.classId}&section_id=${filters.sectionId}$academicYearQuery',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) => ReportCardDto.fromJson(item as Map<String, dynamic>))
          .toList();
    },
  );

  return result.when(
    onSuccess: (cards) => cards,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 5. Dashboard State Stats Provider
class ResultsDashboardStats {
  final int totalStudents;
  final int completeResults;
  final int incompleteResults;
  final int draftCount;
  final int publishedCount;
  final int approvedCount;
  final int underReviewCount;

  const ResultsDashboardStats({
    required this.totalStudents,
    required this.completeResults,
    required this.incompleteResults,
    required this.draftCount,
    required this.publishedCount,
    required this.approvedCount,
    required this.underReviewCount,
  });
}

final resultsDashboardStatsProvider = Provider.autoDispose<ResultsDashboardStats?>((ref) {
  final studentsAsync = ref.watch(resultsStudentsProvider);
  final cardsAsync = ref.watch(resultsReportCardsProvider);

  if (!studentsAsync.hasValue || !cardsAsync.hasValue) {
    return null;
  }

  final students = studentsAsync.value ?? const [];
  final cards = cardsAsync.value ?? const [];

  final total = students.length;
  int complete = 0;
  int draft = 0;
  int published = 0;
  int approved = 0;
  int underReview = 0;

  for (final student in students) {
    final hasCard = cards.any((c) => c.studentId == student.id);
    if (hasCard) {
      complete++;
      final card = cards.firstWhere((c) => c.studentId == student.id);
      if (card.status == 'DRAFT') {
        draft++;
      } else if (card.status == 'PUBLISHED') {
        published++;
      } else if (card.status == 'APPROVED') {
        approved++;
      } else if (card.status == 'UNDER_REVIEW') {
        underReview++;
      }
    }
  }

  return ResultsDashboardStats(
    totalStudents: total,
    completeResults: complete,
    incompleteResults: total - complete,
    draftCount: draft,
    publishedCount: published,
    approvedCount: approved,
    underReviewCount: underReview,
  );
});

// 6. Student Result Detail Loader (Preview Endpoint)
final studentResultDetailProvider = FutureProvider.autoDispose.family<ReportCardPreviewDto, String>((ref, studentId) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) throw Exception('No school context selected');
  final filters = ref.watch(resultsFiltersProvider);

  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/report-cards/preview/$studentId',
    queryParameters: {
      'school_id': schoolId,
      if (filters.examinationId != null && filters.examinationId!.isNotEmpty)
        'examination_id': filters.examinationId,
    },
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return ReportCardPreviewDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );

  return result.when(
    onSuccess: (preview) => preview,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 6b. Student Academic History Loader (History Endpoint)
final studentAcademicHistoryProvider = FutureProvider.autoDispose.family<StudentAcademicHistoryDto, String>((ref, studentId) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) throw Exception('No school context selected');

  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/report-cards/history/$studentId',
    queryParameters: {
      'school_id': schoolId,
    },
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return StudentAcademicHistoryDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );

  return result.when(
    onSuccess: (history) => history,
    onFailure: (failure) => throw Exception(failure.message),
  );
});


// 7. Report Card Public Verification Lookup Provider
final reportCardVerificationProvider = FutureProvider.autoDispose.family<VerificationResponseDto, String>((ref, uuid) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/report-cards/verify/$uuid',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return VerificationResponseDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 8. Report Card Operations State & Notifier
class ReportCardOperationsState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final BulkClassGenerateResponseDto? bulkGenerateResult;
  final BulkReportCardActionResponseDto? bulkActionResult;

  const ReportCardOperationsState({
    required this.isLoading,
    this.error,
    this.successMessage,
    this.bulkGenerateResult,
    this.bulkActionResult,
  });

  ReportCardOperationsState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    BulkClassGenerateResponseDto? bulkGenerateResult,
    BulkReportCardActionResponseDto? bulkActionResult,
  }) {
    return ReportCardOperationsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      bulkGenerateResult: bulkGenerateResult,
      bulkActionResult: bulkActionResult,
    );
  }
}

class ReportCardOperationsNotifier extends StateNotifier<ReportCardOperationsState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  ReportCardOperationsNotifier(this._apiClient, this._ref)
      : super(const ReportCardOperationsState(isLoading: false));

  Future<bool> generateSingle({
    required String studentId,
    required String schoolId,
    String? remarks,
    String? academicYearId,
    String? examinationId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/generate',
      data: {
        'student_id': studentId,
        'school_id': schoolId,
        if (academicYearId != null && academicYearId.isNotEmpty) 'academic_year_id': academicYearId,
        if (examinationId != null && examinationId.isNotEmpty) 'examination_id': examinationId,
        'settings': {
          'generated_from_live_data': true,
          'show_attendance': true,
          'language': 'en',
        },
        'teacher_remarks': remarks,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(resultsReportCardsProvider);
        _ref.invalidate(resultsDashboardStatsProvider);
        state = state.copyWith(isLoading: false, successMessage: 'Report card generated successfully.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> bulkGenerate({
    required String classId,
    required String sectionId,
    required String schoolId,
    String? academicYearId,
    String? examinationId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/generate/class',
      data: {
        'class_id': classId,
        'section_id': sectionId,
        'school_id': schoolId,
        if (academicYearId != null && academicYearId.isNotEmpty) 'academic_year_id': academicYearId,
        if (examinationId != null && examinationId.isNotEmpty) 'examination_id': examinationId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return BulkClassGenerateResponseDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (data) {
        _ref.invalidate(resultsReportCardsProvider);
        _ref.invalidate(resultsDashboardStatsProvider);
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Bulk generation completed: ${data.generatedCount} generated.',
          bulkGenerateResult: data,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> bulkApprove({
    required List<String> reportCardIds,
    required String schoolId,
  }) async {
    if (reportCardIds.isEmpty) return false;
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/bulk-approve',
      data: {
        'report_card_ids': reportCardIds,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return BulkReportCardActionResponseDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (data) {
        _ref.invalidate(resultsReportCardsProvider);
        _ref.invalidate(resultsDashboardStatsProvider);
        state = state.copyWith(
          isLoading: false,
          successMessage: '${data.successCount} report cards approved successfully.',
          bulkActionResult: data,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> bulkPublish({
    required List<String> reportCardIds,
    required String schoolId,
  }) async {
    if (reportCardIds.isEmpty) return false;
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/bulk-publish',
      data: {
        'report_card_ids': reportCardIds,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return BulkReportCardActionResponseDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (data) {
        _ref.invalidate(resultsReportCardsProvider);
        _ref.invalidate(resultsDashboardStatsProvider);
        state = state.copyWith(
          isLoading: false,
          successMessage: '${data.successCount} report cards published successfully.',
          bulkActionResult: data,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> submitForReview({
    required String id,
    required String schoolId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/$id/submit-review',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(resultsReportCardsProvider);
        state = state.copyWith(isLoading: false, successMessage: 'Report card submitted for review.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> approve({
    required String id,
    required String schoolId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/$id/approve',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(resultsReportCardsProvider);
        state = state.copyWith(isLoading: false, successMessage: 'Report card approved successfully.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> publish({
    required String classId,
    required String sectionId,
    required String schoolId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/publish',
      queryParameters: {
        'class_id': classId,
        'section_id': sectionId,
        'school_id': schoolId,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(resultsReportCardsProvider);
        state = state.copyWith(isLoading: false, successMessage: 'Approved report cards published.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> lock({
    required String id,
    required String schoolId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/$id/lock',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(resultsReportCardsProvider);
        state = state.copyWith(isLoading: false, successMessage: 'Report card locked.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> unlock({
    required String id,
    required String schoolId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.post(
      '/report-cards/$id/unlock',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(resultsReportCardsProvider);
        state = state.copyWith(isLoading: false, successMessage: 'Report card unlocked.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> downloadPdf({
    required String studentId,
    required String schoolId,
    required String studentName,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.get<List<int>>(
      '/report-cards/download/$studentId',
      queryParameters: {'school_id': schoolId},
      options: Options(responseType: ResponseType.bytes),
      mapper: (json) => json as List<int>,
    );

    return result.when(
      onSuccess: (bytes) {
        downloadBytes('${studentName.replaceAll(' ', '_')}_ReportCard.pdf', bytes, 'application/pdf');
        state = state.copyWith(isLoading: false, successMessage: 'PDF downloaded.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> viewPdf({
    required String studentId,
    required String schoolId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _apiClient.get<List<int>>(
      '/report-cards/download/$studentId',
      queryParameters: {'school_id': schoolId},
      options: Options(responseType: ResponseType.bytes),
      mapper: (json) => json as List<int>,
    );

    return result.when(
      onSuccess: (bytes) {
        viewBytes(bytes, 'application/pdf');
        state = state.copyWith(isLoading: false, successMessage: 'PDF loaded in viewer.');
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final reportCardOperationsProvider =
    StateNotifierProvider.autoDispose<ReportCardOperationsNotifier, ReportCardOperationsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportCardOperationsNotifier(apiClient, ref);
});
