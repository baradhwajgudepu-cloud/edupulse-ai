import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ReportsFilters {
  final String? classId;
  final String? sectionId;
  final String? academicYearId;
  final String? subjectId;
  final String? examinationId;
  final String? grade;

  const ReportsFilters({
    this.classId,
    this.sectionId,
    this.academicYearId,
    this.subjectId,
    this.examinationId,
    this.grade,
  });

  ReportsFilters copyWith({
    String? classId,
    String? sectionId,
    String? academicYearId,
    String? subjectId,
    String? examinationId,
    String? grade,
    bool clearClass = false,
    bool clearSection = false,
    bool clearSubject = false,
    bool clearExam = false,
    bool clearGrade = false,
  }) {
    return ReportsFilters(
      classId: clearClass ? null : (classId ?? this.classId),
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      academicYearId: academicYearId ?? this.academicYearId,
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      examinationId: clearExam ? null : (examinationId ?? this.examinationId),
      grade: clearGrade ? null : (grade ?? this.grade),
    );
  }
}

class ReportsFiltersNotifier extends StateNotifier<ReportsFilters> {
  ReportsFiltersNotifier() : super(const ReportsFilters());

  void updateClass(String? classId) {
    if (classId == null) {
      state = state.copyWith(clearClass: true, clearSection: true, clearSubject: true, clearGrade: true);
    } else {
      state = state.copyWith(classId: classId, clearSection: true, clearSubject: true, clearGrade: true);
    }
  }

  void updateSection(String? sectionId) {
    if (sectionId == null) {
      state = state.copyWith(clearSection: true, clearGrade: true);
    } else {
      state = state.copyWith(sectionId: sectionId, clearGrade: true);
    }
  }

  void updateAcademicYear(String? ayId) {
    state = state.copyWith(academicYearId: ayId, clearGrade: true);
  }

  void updateSubject(String? subjectId) {
    if (subjectId == null) {
      state = state.copyWith(clearSubject: true, clearGrade: true);
    } else {
      state = state.copyWith(subjectId: subjectId, clearGrade: true);
    }
  }

  void updateExam(String? examId) {
    if (examId == null) {
      state = state.copyWith(clearExam: true, clearGrade: true);
    } else {
      state = state.copyWith(examinationId: examId, clearGrade: true);
    }
  }

  void updateGrade(String? grade) {
    if (grade == null) {
      state = state.copyWith(clearGrade: true);
    } else {
      state = state.copyWith(grade: grade);
    }
  }
  
  void reset() {
    state = const ReportsFilters();
  }
}

final reportsFiltersProvider = StateNotifierProvider<ReportsFiltersNotifier, ReportsFilters>((ref) {
  return ReportsFiltersNotifier();
});

final reportsDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  
  final authState = ref.watch(authStateProvider);
  bool isTenantScopedAdmin = false;
  if (authState is Authenticated) {
    isTenantScopedAdmin = authState.user.isSuperuser || 
        authState.user.roles.any((r) => 
            r.toUpperCase() == 'SUPER_ADMIN' || 
            r.toUpperCase() == 'TENANT_ADMIN' || 
            r.toUpperCase() == 'CHAIRMAN');
  }

  if (schoolId == null) {
    if (isTenantScopedAdmin) {
      final apiClient = ref.watch(apiClientProvider);
      final result = await apiClient.get(
        '/reports/tenant/overview',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>;
        },
      );
      return result.when(
        onSuccess: (data) => data,
        onFailure: (failure) => throw Exception(failure.message),
      );
    }
    return {};
  }

  final apiClient = ref.watch(apiClientProvider);
  
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  
  final result = await apiClient.get(
    '/reports/dashboard$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as Map<String, dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsAcademicProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return {};

  final apiClient = ref.watch(apiClientProvider);
  
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  if (filters.subjectId != null) queryParams.add('subject_id=${filters.subjectId}');
  if (filters.examinationId != null) queryParams.add('examination_id=${filters.examinationId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  
  final result = await apiClient.get(
    '/reports/academic$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as Map<String, dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsExaminationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return [];

  final apiClient = ref.watch(apiClientProvider);
  
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  
  final result = await apiClient.get(
    '/reports/examinations$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as List<dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsAttendanceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return {};

  final apiClient = ref.watch(apiClientProvider);
  
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  
  final result = await apiClient.get(
    '/reports/attendance$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as Map<String, dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsFeesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return {};

  final apiClient = ref.watch(apiClientProvider);
  
  final queryParams = <String>[];
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  
  final result = await apiClient.get(
    '/reports/fees$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as Map<String, dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsAIIntelligenceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  
  final authState = ref.watch(authStateProvider);
  bool isTenantScopedAdmin = false;
  if (authState is Authenticated) {
    isTenantScopedAdmin = authState.user.isSuperuser || 
        authState.user.roles.any((r) => 
            r.toUpperCase() == 'SUPER_ADMIN' || 
            r.toUpperCase() == 'TENANT_ADMIN' || 
            r.toUpperCase() == 'CHAIRMAN');
  }

  if (schoolId == null && !isTenantScopedAdmin) {
    return {};
  }

  final apiClient = ref.watch(apiClientProvider);
  
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  
  final result = await apiClient.get(
    '/reports/ai-intelligence$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as Map<String, dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsStudentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null || filters.classId == null || filters.sectionId == null) {
    return const [];
  }
  
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/students?school_id=$schoolId&class_id=${filters.classId}&section_id=${filters.sectionId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? const [];
      return list;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsStudentAcademicHistoryProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, studentId) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return {};

  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/report-cards/history/$studentId?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as Map<String, dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsDetailedStudentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return const [];

  final apiClient = ref.watch(apiClientProvider);
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  final result = await apiClient.get(
    '/reports/students$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as List<dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsDetailedTeachersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return const [];

  final apiClient = ref.watch(apiClientProvider);
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  final result = await apiClient.get(
    '/reports/teachers$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as List<dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final reportsDetailedClassesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final filters = ref.watch(reportsFiltersProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return const [];

  final apiClient = ref.watch(apiClientProvider);
  final queryParams = <String>[];
  if (filters.academicYearId != null) queryParams.add('academic_year_id=${filters.academicYearId}');
  if (filters.classId != null) queryParams.add('class_id=${filters.classId}');
  if (filters.sectionId != null) queryParams.add('section_id=${filters.sectionId}');
  
  final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
  final result = await apiClient.get(
    '/reports/classes$queryString',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as List<dynamic>;
    },
  );
  
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final tenantOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/reports/tenant/overview',
    mapper: (json) => json as Map<String, dynamic>,
  );

  return result.when(
    onSuccess: (data) {
      final payload = data['data'] as Map<String, dynamic>;
      return payload;
    },
    onFailure: (failure) => throw Exception(failure.message),
  );
});
