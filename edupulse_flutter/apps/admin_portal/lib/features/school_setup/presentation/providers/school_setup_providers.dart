import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/models/school_setup_models.dart';

// 1. Selected School State Provider
final selectedSchoolIdProvider = StateProvider<String?>((ref) => null);

// 2. Selected Academic Year Provider (Used as context for Class, Section, Subject setups)
final selectedAcademicYearIdProvider = StateProvider<String?>((ref) => null);

// 3. Schools List Provider
class SchoolsListState {
  final List<SchoolDto> schools;
  final bool isLoading;
  final String? error;

  const SchoolsListState({
    required this.schools,
    required this.isLoading,
    this.error,
  });

  SchoolsListState copyWith({
    List<SchoolDto>? schools,
    bool? isLoading,
    String? error,
  }) {
    return SchoolsListState(
      schools: schools ?? this.schools,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SchoolsListNotifier extends StateNotifier<SchoolsListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  SchoolsListNotifier(this._apiClient, this._ref)
      : super(const SchoolsListState(schools: [], isLoading: false));

  Future<void> fetchSchools() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/schools',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = (payload['data'] as List<dynamic>?) ?? [];
        return list
            .map((item) => SchoolDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    await result.when(
      onSuccess: (schools) async {
        state = SchoolsListState(schools: schools, isLoading: false);
        if (schools.isNotEmpty) {
          try {
            final sessionManager = _ref.read(sessionManagerProvider);
            final persistedId = await sessionManager.getSchoolId();
            
            String? targetSchoolId;
            if (persistedId != null && schools.any((s) => s.id == persistedId)) {
              targetSchoolId = persistedId;
            } else {
              targetSchoolId = schools.first.id;
            }
            
            if (_ref.read(selectedSchoolIdProvider) != targetSchoolId) {
              _ref.read(selectedSchoolIdProvider.notifier).state = targetSchoolId;
            }
            await sessionManager.saveSchoolId(targetSchoolId);
          } catch (e) {
            // Fallback for environments where platform channels are not mocked (e.g. unit tests)
            final targetSchoolId = schools.first.id;
            if (_ref.read(selectedSchoolIdProvider) != targetSchoolId) {
              _ref.read(selectedSchoolIdProvider.notifier).state = targetSchoolId;
            }
          }
        } else {
          if (_ref.read(selectedSchoolIdProvider) != null) {
            _ref.read(selectedSchoolIdProvider.notifier).state = null;
          }
          final sessionManager = _ref.read(sessionManagerProvider);
          try {
            await sessionManager.saveSchoolId('');
          } catch (_) {}
        }
      },
      onFailure: (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final schoolsListProvider =
    StateNotifierProvider<SchoolsListNotifier, SchoolsListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SchoolsListNotifier(apiClient, ref);
});

// School Detail Provider
final schoolDetailProvider =
    FutureProvider.family<SchoolDto, String>((ref, id) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$id',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return SchoolDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );
  return result.when(
    onSuccess: (school) => school,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 4. Academic Years Provider
class AcademicYearsState {
  final List<AcademicYearDto> years;
  final bool isLoading;
  final String? error;

  const AcademicYearsState({
    required this.years,
    required this.isLoading,
    this.error,
  });

  AcademicYearsState copyWith({
    List<AcademicYearDto>? years,
    bool? isLoading,
    String? error,
  }) {
    return AcademicYearsState(
      years: years ?? this.years,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AcademicYearsNotifier extends StateNotifier<AcademicYearsState> {
  final BaseApiClient _apiClient;
  final String _schoolId;
  final Ref _ref;

  AcademicYearsNotifier(this._apiClient, this._schoolId, this._ref)
      : super(const AcademicYearsState(years: [], isLoading: false));

  Future<void> fetchYears() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/schools/$_schoolId/academic-years',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => AcademicYearDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    result.when(
      onSuccess: (years) {
        state = AcademicYearsState(years: years, isLoading: false);
        // Default select current or first academic year
        if (years.isNotEmpty && _ref.read(selectedAcademicYearIdProvider) == null) {
          final current = years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
          _ref.read(selectedAcademicYearIdProvider.notifier).state = current.id;
        }
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final academicYearsProvider = StateNotifierProvider.family<
    AcademicYearsNotifier, AcademicYearsState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return AcademicYearsNotifier(apiClient, schoolId, ref);
});

final academicYearDetailProvider = FutureProvider.family<AcademicYearDto,
    ({String schoolId, String id})>((ref, arg) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/${arg.schoolId}/academic-years/${arg.id}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return AcademicYearDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );
  return result.when(
    onSuccess: (ay) => ay,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 5. Classes Provider
class ClassesState {
  final List<ClassDto> classes;
  final bool isLoading;
  final String? error;

  const ClassesState({
    required this.classes,
    required this.isLoading,
    this.error,
  });

  ClassesState copyWith({
    List<ClassDto>? classes,
    bool? isLoading,
    String? error,
  }) {
    return ClassesState(
      classes: classes ?? this.classes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ClassesNotifier extends StateNotifier<ClassesState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  ClassesNotifier(this._apiClient, this._schoolId)
      : super(const ClassesState(classes: [], isLoading: false));

  Future<void> fetchClasses({String? academicYearId}) async {
    state = state.copyWith(isLoading: true, error: null);
    var url = '/classes?school_id=$_schoolId';
    if (academicYearId != null) {
      url += '&academic_year_id=$academicYearId';
    }
    final result = await _apiClient.get(
      url,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => ClassDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    result.when(
      onSuccess: (classes) {
        state = ClassesState(classes: classes, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final classesProvider = StateNotifierProvider.family<ClassesNotifier,
    ClassesState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return ClassesNotifier(apiClient, schoolId);
});

final classDetailProvider = FutureProvider.family<ClassDto,
    ({String schoolId, String id})>((ref, arg) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/classes/${arg.id}?school_id=${arg.schoolId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return ClassDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );
  return result.when(
    onSuccess: (c) => c,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 6. Sections Provider
class SectionsState {
  final List<SectionDto> sections;
  final bool isLoading;
  final String? error;

  const SectionsState({
    required this.sections,
    required this.isLoading,
    this.error,
  });

  SectionsState copyWith({
    List<SectionDto>? sections,
    bool? isLoading,
    String? error,
  }) {
    return SectionsState(
      sections: sections ?? this.sections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SectionsNotifier extends StateNotifier<SectionsState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  SectionsNotifier(this._apiClient, this._schoolId)
      : super(const SectionsState(sections: [], isLoading: false));

  Future<void> fetchSections({String? academicYearId, String? classId}) async {
    state = state.copyWith(isLoading: true, error: null);
    var url = '/sections?school_id=$_schoolId';
    if (academicYearId != null) url += '&academic_year_id=$academicYearId';
    if (classId != null) url += '&class_id=$classId';

    final result = await _apiClient.get(
      url,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => SectionDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    result.when(
      onSuccess: (sections) {
        state = SectionsState(sections: sections, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final sectionsProvider = StateNotifierProvider.family<SectionsNotifier,
    SectionsState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return SectionsNotifier(apiClient, schoolId);
});

final sectionDetailProvider = FutureProvider.family<SectionDto,
    ({String schoolId, String id})>((ref, arg) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/sections/${arg.id}?school_id=${arg.schoolId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return SectionDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );
  return result.when(
    onSuccess: (s) => s,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 7. Subjects Provider
class SubjectsState {
  final List<SubjectDto> subjects;
  final bool isLoading;
  final String? error;

  const SubjectsState({
    required this.subjects,
    required this.isLoading,
    this.error,
  });

  SubjectsState copyWith({
    List<SubjectDto>? subjects,
    bool? isLoading,
    String? error,
  }) {
    return SubjectsState(
      subjects: subjects ?? this.subjects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SubjectsNotifier extends StateNotifier<SubjectsState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  SubjectsNotifier(this._apiClient, this._schoolId)
      : super(const SubjectsState(subjects: [], isLoading: false));

  Future<void> fetchSubjects({String? academicYearId}) async {
    state = state.copyWith(isLoading: true, error: null);
    var url = '/subjects?school_id=$_schoolId';
    if (academicYearId != null) url += '&academic_year_id=$academicYearId';

    final result = await _apiClient.get(
      url,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => SubjectDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    result.when(
      onSuccess: (subjects) {
        state = SubjectsState(subjects: subjects, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final subjectsProvider = StateNotifierProvider.family<SubjectsNotifier,
    SubjectsState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return SubjectsNotifier(apiClient, schoolId);
});

final subjectDetailProvider = FutureProvider.family<SubjectDto,
    ({String schoolId, String id})>((ref, arg) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/subjects/${arg.id}?school_id=${arg.schoolId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return SubjectDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );
  return result.when(
    onSuccess: (s) => s,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// 8. Lifecycle Mutator Action Provider
class SetupActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final bool isConflict;

  const SetupActionState({
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
    this.isConflict = false,
  });
}

class SetupActionNotifier extends StateNotifier<SetupActionState> {
  final BaseApiClient _apiClient;

  SetupActionNotifier(this._apiClient)
      : super(const SetupActionState(isLoading: false));

  Future<bool> execute({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    String? successMsg,
  }) async {
    state = const SetupActionState(isLoading: true);
    ApiResult<dynamic> result;

    if (method == 'POST') {
      result = await _apiClient.post(path, data: data, mapper: (json) => json);
    } else if (method == 'PUT') {
      result = await _apiClient.put(path, data: data, mapper: (json) => json);
    } else if (method == 'DELETE') {
      result = await _apiClient.delete(path, mapper: (json) => json);
    } else {
      throw UnsupportedError('Method $method is not supported.');
    }

    return result.when(
      onSuccess: (_) {
        state = SetupActionState(
          isLoading: false,
          successMessage: successMsg ?? 'Action completed successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        final conflict = failure.statusCode == 409 ||
            (failure.message.contains('conflict') ||
                failure.message.contains('version'));
        state = SetupActionState(
          isLoading: false,
          errorMessage: conflict
              ? 'This record was modified by another user. Reloading details...'
              : failure.message,
          isConflict: conflict,
        );
        return false;
      },
    );
  }
}

final setupActionProvider =
    StateNotifierProvider<SetupActionNotifier, SetupActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SetupActionNotifier(apiClient);
});
