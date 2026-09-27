import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/curriculum_models.dart';

// State representing the curriculum setup status for a school
class CurriculumStatusState {
  final CurriculumStatusModel status;
  final bool isLoading;
  final bool isPopulating;
  final String? error;
  final String? successMessage;

  const CurriculumStatusState({
    required this.status,
    required this.isLoading,
    this.isPopulating = false,
    this.error,
    this.successMessage,
  });

  CurriculumStatusState copyWith({
    CurriculumStatusModel? status,
    bool? isLoading,
    bool? isPopulating,
    String? error,
    String? successMessage,
  }) {
    return CurriculumStatusState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      isPopulating: isPopulating ?? this.isPopulating,
      error: error,
      successMessage: successMessage,
    );
  }
}

class CurriculumStatusNotifier extends StateNotifier<CurriculumStatusState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  CurriculumStatusNotifier(this._apiClient, this._schoolId)
      : super(CurriculumStatusState(
          status: CurriculumStatusModel.empty(),
          isLoading: false,
        )) {
    fetchStatus();
  }

  Future<void> fetchStatus({String? academicYearId}) async {
    state = state.copyWith(isLoading: true, error: null);
    final queryParams = {'school_id': _schoolId};
    if (academicYearId != null) {
      queryParams['academic_year_id'] = academicYearId;
    }

    final result = await _apiClient.get(
      '/curriculum/status',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>? ?? {};
        return CurriculumStatusModel.fromJson(data);
      },
    );

    result.when(
      onSuccess: (statusModel) => state = state.copyWith(
        isLoading: false,
        status: statusModel,
        error: null,
      ),
      onFailure: (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    );
  }

  Future<bool> autoPopulateCurriculum({bool overrideExisting = false}) async {
    state = state.copyWith(isPopulating: true, error: null, successMessage: null);

    final result = await _apiClient.post(
      '/curriculum/auto-populate',
      queryParameters: {
        'school_id': _schoolId,
        'override_existing': overrideExisting.toString(),
      },
      data: <String, dynamic>{},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>? ?? {};
        return CurriculumPopulateResultModel.fromJson(data);
      },
    );

    return result.when(
      onSuccess: (res) {
        state = state.copyWith(
          isPopulating: false,
          successMessage: 'Curriculum automatically populated (${res.totalChaptersPopulated} chapters)',
        );
        fetchStatus();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isPopulating: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> deriveFromPreviousYear({
    required String sourceAcademicYearId,
    required String targetAcademicYearId,
    List<String>? classIds,
  }) async {
    state = state.copyWith(isPopulating: true, error: null, successMessage: null);

    final result = await _apiClient.post(
      '/curriculum/derive-previous',
      queryParameters: {'school_id': _schoolId},
      data: {
        'source_academic_year_id': sourceAcademicYearId,
        'target_academic_year_id': targetAcademicYearId,
        if (classIds != null) 'class_ids': classIds,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>? ?? {};
        return CurriculumPopulateResultModel.fromJson(data);
      },
    );

    return result.when(
      onSuccess: (res) {
        state = state.copyWith(
          isPopulating: false,
          successMessage: 'Curriculum derived from previous academic year successfully.',
        );
        fetchStatus();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isPopulating: false, error: failure.message);
        return false;
      },
    );
  }
}

// 1. Scoped Curriculum Status Provider (auto-cleans when school changes)
final curriculumStatusProvider = StateNotifierProvider.family<CurriculumStatusNotifier, CurriculumStatusState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return CurriculumStatusNotifier(apiClient, schoolId);
});

// 2. Syllabus / Chapters List for School Provider
final schoolSyllabusListProvider = FutureProvider.family<List<CurriculumChapterItemModel>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/syllabuses',
    queryParameters: {
      'school_id': schoolId,
      'limit': 500,
    },
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list.map((item) => CurriculumChapterItemModel.fromJson(item as Map<String, dynamic>)).toList();
    },
  );

  return result.when(
    onSuccess: (chapters) => chapters,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 3. Class-Specific Syllabus Query & Provider
class ClassSyllabusQuery {
  final String schoolId;
  final String? academicYearId;
  final String classId;

  const ClassSyllabusQuery({
    required this.schoolId,
    this.academicYearId,
    required this.classId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSyllabusQuery &&
          runtimeType == other.runtimeType &&
          schoolId == other.schoolId &&
          academicYearId == other.academicYearId &&
          classId == other.classId;

  @override
  int get hashCode =>
      schoolId.hashCode ^ (academicYearId?.hashCode ?? 0) ^ classId.hashCode;
}

final classSyllabusListProvider = FutureProvider.family<List<CurriculumChapterItemModel>, ClassSyllabusQuery>((ref, query) async {
  final apiClient = ref.watch(apiClientProvider);
  final queryParams = <String, dynamic>{
    'school_id': query.schoolId,
    'class_id': query.classId,
    'limit': 500,
  };
  if (query.academicYearId != null && query.academicYearId!.isNotEmpty) {
    queryParams['academic_year_id'] = query.academicYearId;
  }
  final result = await apiClient.get(
    '/syllabuses',
    queryParameters: queryParams,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list.map((item) => CurriculumChapterItemModel.fromJson(item as Map<String, dynamic>)).toList();
    },
  );

  return result.when(
    onSuccess: (chapters) => chapters,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 4. Syllabus Editor Action Service
class SyllabusEditorService {
  final BaseApiClient _apiClient;

  SyllabusEditorService(this._apiClient);

  Future<bool> addTopic({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String unitName,
    required String chapterName,
    required String topicName,
    int estimatedPeriods = 4,
    int sequenceOrder = 1,
    String? description,
  }) async {
    final code = 'SYLL_${DateTime.now().millisecondsSinceEpoch}';
    final result = await _apiClient.post(
      '/syllabuses',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      data: {
        'class_id': classId,
        'subject_id': subjectId,
        'syllabus_code': code,
        'unit_name': unitName,
        'chapter_name': chapterName,
        'topic_name': topicName,
        'description': description,
        'sequence_order': sequenceOrder,
        'estimated_periods': estimatedPeriods,
        'coverage_status': 'PENDING',
        'lifecycle_status': 'PLANNED',
      },
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<bool> updateTopic({
    required String schoolId,
    required String syllabusId,
    String? topicName,
    int? estimatedPeriods,
    int? sequenceOrder,
    String? coverageStatus,
    String? lifecycleStatus,
    String? description,
  }) async {
    final result = await _apiClient.put(
      '/syllabuses/$syllabusId',
      queryParameters: {'school_id': schoolId},
      data: {
        if (topicName != null) 'topic_name': topicName,
        if (estimatedPeriods != null) 'estimated_periods': estimatedPeriods,
        if (sequenceOrder != null) 'sequence_order': sequenceOrder,
        if (coverageStatus != null) 'coverage_status': coverageStatus,
        if (lifecycleStatus != null) 'lifecycle_status': lifecycleStatus,
        if (description != null) 'description': description,
      },
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<bool> deleteTopic({
    required String schoolId,
    required String syllabusId,
  }) async {
    final result = await _apiClient.delete(
      '/syllabuses/$syllabusId',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<bool> updateChapter({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String oldChapterName,
    required String newChapterName,
    String? unitName,
    int? estimatedPeriods,
  }) async {
    final result = await _apiClient.put(
      '/syllabuses/chapter/update',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      data: {
        'class_id': classId,
        'subject_id': subjectId,
        'old_chapter_name': oldChapterName,
        'new_chapter_name': newChapterName,
        if (unitName != null) 'unit_name': unitName,
        if (estimatedPeriods != null) 'estimated_periods': estimatedPeriods,
      },
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<bool> deleteChapter({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String chapterName,
    String? unitName,
  }) async {
    final result = await _apiClient.delete(
      '/syllabuses/chapter',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      data: {
        'class_id': classId,
        'subject_id': subjectId,
        'chapter_name': chapterName,
        if (unitName != null) 'unit_name': unitName,
      },
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<bool> renameUnit({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String oldUnitName,
    required String newUnitName,
  }) async {
    final result = await _apiClient.put(
      '/syllabuses/unit/rename',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      data: {
        'class_id': classId,
        'subject_id': subjectId,
        'old_unit_name': oldUnitName,
        'new_unit_name': newUnitName,
      },
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<bool> deleteUnit({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String unitName,
  }) async {
    final result = await _apiClient.delete(
      '/syllabuses/unit',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      data: {
        'class_id': classId,
        'subject_id': subjectId,
        'unit_name': unitName,
      },
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<bool> deleteClassSubject({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
  }) async {
    final result = await _apiClient.delete(
      '/syllabuses/class-subject',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      data: {
        'class_id': classId,
        'subject_id': subjectId,
      },
      mapper: (json) => json,
    );
    return result.when(onSuccess: (_) => true, onFailure: (_) => false);
  }

  Future<AIDraftSyllabusResponseDto?> generateAIDraftSyllabus({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    int numUnits = 2,
    int chaptersPerUnit = 2,
  }) async {
    final result = await _apiClient.post(
      '/curriculum/ai-draft-syllabus',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'subject_id': subjectId,
        'num_units': numUnits,
        'chapters_per_unit': chaptersPerUnit,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>? ?? {};
        return AIDraftSyllabusResponseDto.fromJson(data);
      },
    );
    return result.when(
      onSuccess: (data) => data,
      onFailure: (_) => null,
    );
  }

  Future<bool> approveAIDraftSyllabus({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required List<AIDraftSyllabusTopicDto> topics,
  }) async {
    final result = await _apiClient.post(
      '/curriculum/ai-draft-syllabus/approve',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'subject_id': subjectId,
        'topics': topics.map((t) => t.toJson()).toList(),
      },
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) => true,
      onFailure: (_) => false,
    );
  }
}

final syllabusEditorServiceProvider = Provider<SyllabusEditorService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SyllabusEditorService(apiClient);
});

