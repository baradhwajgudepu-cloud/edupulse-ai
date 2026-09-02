import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/ai_intelligence_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AIFiltersState {
  final String? academicYearId;
  final String? classId;
  final String? sectionId;

  const AIFiltersState({
    this.academicYearId,
    this.classId,
    this.sectionId,
  });

  AIFiltersState copyWith({
    String? academicYearId,
    String? classId,
    String? sectionId,
    bool clearClass = false,
    bool clearSection = false,
  }) {
    return AIFiltersState(
      academicYearId: academicYearId ?? this.academicYearId,
      classId: clearClass ? null : (classId ?? this.classId),
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
    );
  }
}

class AIFiltersNotifier extends StateNotifier<AIFiltersState> {
  AIFiltersNotifier() : super(const AIFiltersState());

  void setAcademicYear(String? ayId) {
    state = state.copyWith(academicYearId: ayId);
  }

  void setClass(String? classId) {
    state = state.copyWith(classId: classId, clearClass: classId == null, clearSection: true);
  }

  void setSection(String? sectionId) {
    state = state.copyWith(sectionId: sectionId, clearSection: sectionId == null);
  }

  void reset() {
    state = const AIFiltersState();
  }
}

final aiFiltersProvider = StateNotifierProvider<AIFiltersNotifier, AIFiltersState>((ref) {
  return AIFiltersNotifier();
});

final aiIntelligenceSummaryProvider = FutureProvider.autoDispose<AIIntelligenceSummaryModel?>((ref) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  final filters = ref.watch(aiFiltersProvider);
  final apiClient = ref.watch(apiClientProvider);

  final queryParams = <String>[];
  if (schoolId != null && schoolId.isNotEmpty) {
    queryParams.add('school_id=$schoolId');
  }
  if (filters.academicYearId != null) {
    queryParams.add('academic_year_id=${filters.academicYearId}');
  }
  if (filters.classId != null) {
    queryParams.add('class_id=${filters.classId}');
  }
  if (filters.sectionId != null) {
    queryParams.add('section_id=${filters.sectionId}');
  }

  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  final result = await apiClient.get(
    '/ai-intelligence/summary$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>? ?? {};
      return AIIntelligenceSummaryModel.fromJson(data);
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});
