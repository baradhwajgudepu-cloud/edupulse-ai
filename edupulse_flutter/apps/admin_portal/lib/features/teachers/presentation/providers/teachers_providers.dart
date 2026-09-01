import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/teachers_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class TeacherFetchResult {
  final List<TeacherDto> teachers;
  final int total;

  const TeacherFetchResult({required this.teachers, required this.total});
}

class TeacherListState {
  final List<TeacherDto> teachers;
  final bool isLoading;
  final String? error;
  final String? schoolId;
  final String? department;
  final String? designation;
  final String? status;
  final String search;
  final int skip;
  final int limit;
  final bool hasMore;
  final int total;

  const TeacherListState({
    required this.teachers,
    required this.isLoading,
    this.error,
    this.schoolId,
    this.department,
    this.designation,
    this.status,
    required this.search,
    required this.skip,
    required this.limit,
    required this.hasMore,
    this.total = 0,
  });

  TeacherListState copyWith({
    List<TeacherDto>? teachers,
    bool? isLoading,
    String? error,
    String? schoolId,
    String? department,
    String? designation,
    String? status,
    String? search,
    int? skip,
    int? limit,
    bool? hasMore,
    int? total,
  }) {
    return TeacherListState(
      teachers: teachers ?? this.teachers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      schoolId: schoolId ?? this.schoolId,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      status: status ?? this.status,
      search: search ?? this.search,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
    );
  }
}

class TeacherListNotifier extends StateNotifier<TeacherListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  TeacherListNotifier(this._apiClient, this._ref)
      : super(TeacherListState(
          teachers: [],
          isLoading: false,
          search: '',
          skip: 0,
          limit: 10,
          hasMore: true,
          total: 0,
          schoolId: _ref.read(selectedSchoolIdProvider),
        )) {
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        state = state.copyWith(
          schoolId: next,
          skip: 0,
          teachers: [],
        );
        fetchTeachers();
      } else {
        state = state.copyWith(
          schoolId: null,
          teachers: [],
        );
      }
    });

    final initialSchoolId = _ref.read(selectedSchoolIdProvider);
    if (initialSchoolId != null) {
      Future.microtask(() => fetchTeachers());
    }
  }

  Future<void> fetchTeachers() async {
    if (!mounted) return;
    final activeSchoolId = _ref.read(selectedSchoolIdProvider);
    if (activeSchoolId == null) {
      state = state.copyWith(
        teachers: [],
        isLoading: false,
        error: 'Please select a school campus first.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    final queryParams = <String, String>{
      'school_id': activeSchoolId,
      'skip': state.skip.toString(),
      'limit': state.limit.toString(),
    };

    if (state.department != null && state.department!.isNotEmpty) {
      queryParams['department'] = state.department!;
    }
    if (state.designation != null && state.designation!.isNotEmpty) {
      queryParams['designation'] = state.designation!;
    }
    if (state.status != null && state.status!.isNotEmpty) {
      queryParams['status'] = state.status!;
    }
    if (state.search.isNotEmpty) {
      queryParams['search'] = state.search;
    }

    final uri = Uri(path: '/teachers', queryParameters: queryParams);

    final result = await _apiClient.get(
      uri.toString(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        final meta = payload['meta'] as Map<dynamic, dynamic>?;
        final total = payload['total'] as int? ?? meta?['total'] as int? ?? list.length;
        return TeacherFetchResult(
          teachers: list
              .map((item) => TeacherDto.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList(),
          total: total,
        );
      },
    );

    if (!mounted) return;

    result.when(
      onSuccess: (fetchResult) {
        state = state.copyWith(
          teachers: fetchResult.teachers,
          total: fetchResult.total,
          isLoading: false,
          hasMore: fetchResult.teachers.length >= state.limit,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  void updateFilters({
    String? department,
    String? designation,
    String? status,
    String? search,
  }) {
    state = state.copyWith(
      department: department,
      designation: designation,
      status: status,
      search: search ?? state.search,
      skip: 0,
    );
    fetchTeachers();
  }

  void nextPage() {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(skip: state.skip + state.limit);
    fetchTeachers();
  }

  void prevPage() {
    if (state.skip <= 0 || state.isLoading) return;
    final newSkip = (state.skip - state.limit).clamp(0, double.infinity).toInt();
    state = state.copyWith(skip: newSkip);
    fetchTeachers();
  }

  void updateLimit(int limit) {
    state = state.copyWith(limit: limit, skip: 0);
    fetchTeachers();
  }
}

final teachersListProvider =
    StateNotifierProvider<TeacherListNotifier, TeacherListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TeacherListNotifier(apiClient, ref);
});

final teacherDetailProvider =
    FutureProvider.family<TeacherDto, String>((ref, id) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) {
    throw Exception('No active school campus selected.');
  }

  final result = await apiClient.get(
    '/teachers/$id?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return TeacherDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (teacher) => teacher,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final teacherAssignmentsProvider =
    FutureProvider.family<List<TeacherSubjectAssignmentDto>, String>((ref, teacherId) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) {
    throw Exception('No active school campus selected.');
  }

  final result = await apiClient.get(
    '/teacher-subject-assignments?school_id=$schoolId&teacher_id=$teacherId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>;
      return list
          .map((item) => TeacherSubjectAssignmentDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (assignments) => assignments,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class TeacherActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final bool isConflict;

  const TeacherActionState({
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
    this.isConflict = false,
  });
}

class TeacherActionNotifier extends StateNotifier<TeacherActionState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  TeacherActionNotifier(this._apiClient, this._ref)
      : super(const TeacherActionState(isLoading: false));

  Future<bool> execute({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    String? successMsg,
    String? invalidationId,
  }) async {
    state = const TeacherActionState(isLoading: true);
    ApiResult<dynamic> result;

    if (method == 'POST') {
      result = await _apiClient.post(path, data: data, mapper: (json) => json);
    } else if (method == 'PUT') {
      result = await _apiClient.put(path, data: data, mapper: (json) => json);
    } else if (method == 'DELETE') {
      result = await _apiClient.delete(path, mapper: (json) => json);
    } else {
      throw UnsupportedError('Method $method not supported.');
    }

    return result.when(
      onSuccess: (_) {
        state = TeacherActionState(
          isLoading: false,
          successMessage: successMsg ?? 'Action completed successfully.',
        );
        
        // Invalidate list
        _ref.invalidate(teachersListProvider);
        if (invalidationId != null) {
          _ref.invalidate(teacherDetailProvider(invalidationId));
        }
        
        return true;
      },
      onFailure: (failure) {
        final conflict = failure.statusCode == 409 ||
            failure.message.contains('conflict') ||
            failure.message.contains('already exists') ||
            failure.message.contains('version');

        state = TeacherActionState(
          isLoading: false,
          errorMessage: failure.message,
          isConflict: conflict,
        );
        return false;
      },
    );
  }
}

final teacherActionProvider =
    StateNotifierProvider<TeacherActionNotifier, TeacherActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TeacherActionNotifier(apiClient, ref);
});

class AssignmentActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;

  const AssignmentActionState({
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
  });
}

class AssignmentActionNotifier extends StateNotifier<AssignmentActionState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AssignmentActionNotifier(this._apiClient, this._ref)
      : super(const AssignmentActionState(isLoading: false));

  Future<bool> execute({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    String? successMsg,
    required String teacherId,
  }) async {
    state = const AssignmentActionState(isLoading: true);
    ApiResult<dynamic> result;

    if (method == 'POST') {
      result = await _apiClient.post(path, data: data, mapper: (json) => json);
    } else if (method == 'PUT') {
      result = await _apiClient.put(path, data: data, mapper: (json) => json);
    } else if (method == 'DELETE') {
      result = await _apiClient.delete(path, mapper: (json) => json);
    } else {
      throw UnsupportedError('Method $method not supported.');
    }

    return result.when(
      onSuccess: (_) {
        state = AssignmentActionState(
          isLoading: false,
          successMessage: successMsg ?? 'Action completed successfully.',
        );
        
        // Invalidate specific teacher's assignments
        _ref.invalidate(teacherAssignmentsProvider(teacherId));
        return true;
      },
      onFailure: (failure) {
        state = AssignmentActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }
}

final assignmentActionProvider =
    StateNotifierProvider<AssignmentActionNotifier, AssignmentActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AssignmentActionNotifier(apiClient, ref);
});
