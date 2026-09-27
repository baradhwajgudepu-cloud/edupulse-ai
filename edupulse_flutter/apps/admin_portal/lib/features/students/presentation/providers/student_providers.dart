import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/student_models.dart';
import '../../data/models/student_360_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

class StudentFetchResult {
  final List<StudentDto> students;
  final int total;

  const StudentFetchResult({required this.students, required this.total});
}

class StudentListState {
  final List<StudentDto> students;
  final bool isLoading;
  final String? error;
  final String? schoolId;
  final String? academicYearId;
  final String? classId;
  final String? sectionId;
  final String? status;
  final String? attention;
  final String search;
  final int skip;
  final int limit;
  final bool hasMore;
  final int total;
  final bool isDeleting;
  final int deleteProgressCount;
  final int deleteTotalCount;

  const StudentListState({
    required this.students,
    required this.isLoading,
    this.error,
    this.schoolId,
    this.academicYearId,
    this.classId,
    this.sectionId,
    this.status,
    this.attention,
    required this.search,
    required this.skip,
    required this.limit,
    required this.hasMore,
    this.total = 0,
    this.isDeleting = false,
    this.deleteProgressCount = 0,
    this.deleteTotalCount = 0,
  });

  StudentListState copyWith({
    List<StudentDto>? students,
    bool? isLoading,
    String? error,
    String? schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? status,
    String? attention,
    bool clearAttention = false,
    bool clearAcademicYear = false,
    bool clearClass = false,
    bool clearSection = false,
    bool clearStatus = false,
    bool clearAllFilters = false,
    String? search,
    int? skip,
    int? limit,
    bool? hasMore,
    int? total,
    bool? isDeleting,
    int? deleteProgressCount,
    int? deleteTotalCount,
  }) {
    return StudentListState(
      students: students ?? this.students,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      schoolId: schoolId ?? this.schoolId,
      academicYearId: (clearAllFilters || clearAcademicYear) ? null : (academicYearId ?? this.academicYearId),
      classId: (clearAllFilters || clearClass) ? null : (classId ?? this.classId),
      sectionId: (clearAllFilters || clearSection) ? null : (sectionId ?? this.sectionId),
      status: (clearAllFilters || clearStatus) ? null : (status ?? this.status),
      attention: (clearAllFilters || clearAttention) ? null : (attention ?? this.attention),
      search: clearAllFilters ? '' : (search ?? this.search),
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      isDeleting: isDeleting ?? this.isDeleting,
      deleteProgressCount: deleteProgressCount ?? this.deleteProgressCount,
      deleteTotalCount: deleteTotalCount ?? this.deleteTotalCount,
    );
  }
}

class StudentListNotifier extends StateNotifier<StudentListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  StudentListNotifier(this._apiClient, this._ref)
      : super(StudentListState(
          students: [],
          isLoading: false,
          search: '',
          skip: 0,
          limit: 10,
          hasMore: true,
          total: 0,
          schoolId: _ref.read(selectedSchoolIdProvider),
        )) {
    // Listen to changes in the selected school context
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        state = state.copyWith(
          schoolId: next,
          clearAllFilters: true,
          skip: 0,
          students: [],
        );
        fetchStudents();
      } else {
        state = state.copyWith(
          schoolId: null,
          clearAllFilters: true,
          students: [],
        );
      }
    });

    final initialSchoolId = _ref.read(selectedSchoolIdProvider);
    if (initialSchoolId != null) {
      Future.microtask(() => fetchStudents());
    }
  }

  Future<void> fetchStudents() async {
    if (!mounted) return;
    final activeSchoolId = _ref.read(selectedSchoolIdProvider);
    if (activeSchoolId == null) {
      state = state.copyWith(
        students: [],
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

    if (state.academicYearId != null) {
      queryParams['academic_year_id'] = state.academicYearId!;
    }
    if (state.classId != null) {
      queryParams['class_id'] = state.classId!;
    }
    if (state.sectionId != null) {
      queryParams['section_id'] = state.sectionId!;
    }
    if (state.status != null) {
      queryParams['status'] = state.status!;
    }
    if (state.attention != null && state.attention!.isNotEmpty) {
      queryParams['attention'] = state.attention!;
    }
    if (state.search.isNotEmpty) {
      queryParams['search'] = state.search;
    }

    final uri = Uri(path: '/students', queryParameters: queryParams);

    final result = await _apiClient.get(
      uri.toString(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        final meta = payload['meta'] as Map<dynamic, dynamic>?;
        final total = payload['total'] as int? ?? meta?['total'] as int? ?? list.length;
        return StudentFetchResult(
          students: list
              .map((item) => StudentDto.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList(),
          total: total,
        );
      },
    );

    if (!mounted) return;

    result.when(
      onSuccess: (fetchResult) {
        state = state.copyWith(
          students: fetchResult.students,
          total: fetchResult.total,
          isLoading: false,
          hasMore: fetchResult.students.length >= state.limit,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  void updateFilters({
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? status,
    String? search,
    String? attention,
    bool clearAttention = false,
    bool clearAcademicYear = false,
    bool clearClass = false,
    bool clearSection = false,
    bool clearStatus = false,
    bool clearAllFilters = false,
  }) {
    state = state.copyWith(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      status: status,
      search: search,
      attention: attention,
      clearAttention: clearAttention,
      clearAcademicYear: clearAcademicYear,
      clearClass: clearClass,
      clearSection: clearSection,
      clearStatus: clearStatus,
      clearAllFilters: clearAllFilters,
      skip: 0,
    );
    fetchStudents();
  }

  void clearAllFilters() {
    state = state.copyWith(
      clearAllFilters: true,
      skip: 0,
    );
    fetchStudents();
  }

  void setAttentionFilter(String? attention) {
    state = state.copyWith(
      attention: attention,
      clearAttention: attention == null,
      skip: 0,
    );
    fetchStudents();
  }


  void nextPage() {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(skip: state.skip + state.limit);
    fetchStudents();
  }

  void prevPage() {
    if (state.skip <= 0 || state.isLoading) return;
    final newSkip = (state.skip - state.limit).clamp(0, double.infinity).toInt();
    state = state.copyWith(skip: newSkip);
    fetchStudents();
  }

  Future<Map<String, int>> getSectionStudentCounts(String schoolId) async {
    int skip = 0;
    final Map<String, int> counts = {};
    while (true) {
      final result = await _apiClient.get(
        '/students?school_id=$schoolId&limit=100&skip=$skip',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>;
          return list.map((item) => StudentDto.fromJson(Map<String, dynamic>.from(item as Map))).toList();
        },
      );
      final students = result.when(
        onSuccess: (list) => list,
        onFailure: (_) => <StudentDto>[],
      );
      if (students.isEmpty) break;
      for (final s in students) {
        if (s.status == 'ACTIVE') {
          counts[s.sectionId] = (counts[s.sectionId] ?? 0) + 1;
        }
      }
      if (students.length < 100) break;
      skip += 100;
      if (skip >= 10000) break;
    }
    return counts;
  }

  Future<Map<String, dynamic>> bulkUpdateStatus(List<String> studentIds, String status) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      return {'successCount': 0, 'failures': ['No school campus selected']};
    }

    int successCount = 0;
    final List<String> failures = [];

    for (final id in studentIds) {
      final result = await _apiClient.put(
        '/students/$id?school_id=$schoolId',
        data: {'status': status},
        mapper: (json) => json,
      );
      result.when(
        onSuccess: (_) {
          successCount++;
        },
        onFailure: (failure) {
          failures.add('Student ID $id: ${failure.message}');
        },
      );
    }

    await fetchStudents();

    return {
      'successCount': successCount,
      'failures': failures,
    };
  }

  Future<Map<String, dynamic>> bulkMoveSection({
    required List<String> studentIds,
    required String academicYearId,
    required String classId,
    required String sectionId,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      return {'successCount': 0, 'failures': ['No school campus selected']};
    }

    final sectionsState = _ref.read(sectionsProvider(schoolId));
    final targetSection = sectionsState.sections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => const SectionDto(
        id: '',
        tenantId: '',
        schoolId: '',
        academicYearId: '',
        classId: '',
        name: 'Target Section',
        code: '',
        capacity: 40,
        sortOrder: 1,
        status: '',
        isActive: true,
        version: 1,
      ),
    );

    if (targetSection.id.isEmpty) {
      return {'successCount': 0, 'failures': ['Target section not found']};
    }

    final currentCounts = await getSectionStudentCounts(schoolId);
    int currentEnrollment = currentCounts[sectionId] ?? 0;
    final capacity = targetSection.capacity;

    int successCount = 0;
    final List<String> failures = [];

    for (final id in studentIds) {
      final student = state.students.firstWhere(
        (s) => s.id == id,
        orElse: () => StudentDto(
          id: id,
          tenantId: '',
          schoolId: schoolId,
          academicYearId: '',
          classId: '',
          sectionId: '',
          firstName: 'Student',
          lastName: 'Profile',
          gender: 'MALE',
          dateOfBirth: '',
          address: const {},
          medicalInformation: const {},
          admissionNumber: '',
          rollNumber: '',
          admissionDate: '',
          status: 'ACTIVE',
          isActive: true,
          settings: const {},
          aiMetrics: const {},
          version: 1,
          createdAt: '',
          updatedAt: '',
        ),
      );

      if (student.sectionId == sectionId) {
        successCount++;
        continue;
      }

      if (currentEnrollment >= capacity) {
        failures.add('${student.firstName} ${student.lastName} (No: ${student.admissionNumber}): Section "${targetSection.name}" capacity limit of $capacity reached.');
        continue;
      }

      final result = await _apiClient.put(
        '/students/$id?school_id=$schoolId',
        data: {
          'academic_year_id': academicYearId,
          'class_id': classId,
          'section_id': sectionId,
        },
        mapper: (json) => json,
      );

      result.when(
        onSuccess: (_) {
          successCount++;
          currentEnrollment++;
        },
        onFailure: (failure) {
          failures.add('${student.firstName} ${student.lastName} (No: ${student.admissionNumber}): ${failure.message}');
        },
      );
    }

    await fetchStudents();

    return {
      'successCount': successCount,
      'failures': failures,
    };
  }
  Future<Map<String, dynamic>> bulkDeleteStudents(List<String> studentIds) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      return {'successCount': 0, 'failures': ['No school campus selected'], 'successfulIds': <String>[], 'failedIds': <String>[]};
    }

    state = state.copyWith(
      isDeleting: true,
      deleteProgressCount: 0,
      deleteTotalCount: studentIds.length,
    );

    int successCount = 0;
    final List<String> failures = [];
    final List<String> successfulIds = [];
    final List<String> failedIds = [];

    int index = 0;
    Future<void> worker() async {
      while (true) {
        String? currentId;
        // Fetch next ID safely from local variable
        if (index < studentIds.length) {
          currentId = studentIds[index++];
        }
        
        if (currentId == null) break;

        final student = state.students.firstWhere(
          (s) => s.id == currentId,
          orElse: () => StudentDto(
            id: currentId!,
            tenantId: '',
            schoolId: schoolId,
            academicYearId: '',
            classId: '',
            sectionId: '',
            firstName: 'Student',
            lastName: 'Profile',
            gender: 'MALE',
            dateOfBirth: '',
            address: const {},
            medicalInformation: const {},
            admissionNumber: '',
            rollNumber: '',
            admissionDate: '',
            status: 'ACTIVE',
            isActive: true,
            settings: const {},
            aiMetrics: const {},
            version: 1,
            createdAt: '',
            updatedAt: '',
          ),
        );

        final result = await _apiClient.delete(
          '/students/$currentId?school_id=$schoolId',
          mapper: (json) => json,
        );

        result.when(
          onSuccess: (_) {
            successCount++;
            successfulIds.add(currentId!);
            // Optimistic local update
            final updatedStudents = state.students.where((s) => s.id != currentId).toList();
            final updatedTotal = (state.total - 1).clamp(0, double.infinity).toInt();
            state = state.copyWith(
              deleteProgressCount: state.deleteProgressCount + 1,
              students: updatedStudents,
              total: updatedTotal,
            );
          },
          onFailure: (failure) {
            failures.add('${student.firstName} ${student.lastName} (No: ${student.admissionNumber}): ${failure.message}');
            failedIds.add(currentId!);
            state = state.copyWith(
              deleteProgressCount: state.deleteProgressCount + 1,
            );
          },
        );
      }
    }

    final numWorkers = studentIds.length < 5 ? studentIds.length : 5;
    final workers = List.generate(numWorkers, (_) => worker());
    await Future.wait(workers);

    // If current page became completely empty, move backward in pagination skip offset
    if (state.students.isEmpty && state.skip > 0) {
      final newSkip = (state.skip - state.limit).clamp(0, double.infinity).toInt();
      state = state.copyWith(skip: newSkip);
    }

    // Run reconciliation fetch
    await fetchStudents();

    state = state.copyWith(
      isDeleting: false,
      deleteProgressCount: 0,
      deleteTotalCount: 0,
    );

    return {
      'successCount': successCount,
      'failures': failures,
      'successfulIds': successfulIds,
      'failedIds': failedIds,
    };
  }

  void updateLimit(int limit) {
    state = state.copyWith(limit: limit, skip: 0);
    fetchStudents();
  }
}

final studentListProvider =
    StateNotifierProvider<StudentListNotifier, StudentListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StudentListNotifier(apiClient, ref);
});

final studentDetailProvider =
    FutureProvider.family<StudentDto, String>((ref, id) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) {
    throw Exception('No active school campus selected.');
  }

  final result = await apiClient.get(
    '/students/$id?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return StudentDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (student) => student,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final studentGuardianProvider =
    FutureProvider.family<List<StudentGuardianDto>, String>((ref, studentId) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  final result = await apiClient.get(
    '/student-guardians?student_id=$studentId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>;
      return list
          .map((item) => StudentGuardianDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (mappings) async {
      final enriched = await Future.wait(
        mappings.map((m) async {
          if (m.guardian != null) return m;
          try {
            final q = schoolId != null ? '?school_id=$schoolId' : '';
            final gRes = await apiClient.get(
              '/guardians/${m.guardianId}$q',
              mapper: (json) {
                final payload = json as Map<String, dynamic>;
                return GuardianDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
              },
            );
            return gRes.when(
              onSuccess: (guardian) => m.copyWith(guardian: guardian),
              onFailure: (_) => m,
            );
          } catch (_) {
            return m;
          }
        }),
      );
      return enriched;
    },
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class StudentActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final bool isConflict;
  final dynamic lastData;
  final StudentDto? createdStudent;

  const StudentActionState({
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
    this.isConflict = false,
    this.lastData,
    this.createdStudent,
  });
}

class StudentActionNotifier extends StateNotifier<StudentActionState> {
  final BaseApiClient _apiClient;

  StudentActionNotifier(this._apiClient)
      : super(const StudentActionState(isLoading: false));

  Future<bool> execute({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    String? successMsg,
  }) async {
    state = const StudentActionState(isLoading: true);
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
      onSuccess: (resData) {
        StudentDto? student;
        if (resData is Map<String, dynamic> && resData['data'] is Map<String, dynamic>) {
          try {
            student = StudentDto.fromJson(Map<String, dynamic>.from(resData['data'] as Map));
          } catch (_) {}
        }
        state = StudentActionState(
          isLoading: false,
          successMessage: successMsg ?? 'Action completed successfully.',
          lastData: resData,
          createdStudent: student,
        );
        return true;
      },
      onFailure: (failure) {
        final conflict = failure.statusCode == 409 ||
            failure.message.contains('conflict') ||
            failure.message.contains('version');

        state = StudentActionState(
          isLoading: false,
          errorMessage: conflict
              ? 'This student record has been modified by another user. Reloading the latest details...'
              : failure.message,
          isConflict: conflict,
        );
        return false;
      },
    );
  }

  Future<StudentDto?> createStudent(Map<String, dynamic> data) async {
    state = const StudentActionState(isLoading: true);

    final result = await _apiClient.post(
      '/students',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final studentData = payload['data'] as Map<String, dynamic>;
        return StudentDto.fromJson(studentData);
      },
    );

    return result.when(
      onSuccess: (student) {
        state = StudentActionState(
          isLoading: false,
          successMessage: 'Student admitted successfully',
          createdStudent: student,
          lastData: student,
        );
        return student;
      },
      onFailure: (failure) {
        final conflict = failure.statusCode == 409 ||
            failure.message.contains('conflict') ||
            failure.message.contains('version');

        state = StudentActionState(
          isLoading: false,
          errorMessage: failure.message,
          isConflict: conflict,
        );
        return null;
      },
    );
  }

  Future<bool> uploadStudentPhoto({
    required String schoolId,
    required String studentId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    state = const StudentActionState(isLoading: true);

    try {
      final multipart = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      );
      final formData = FormData.fromMap({
        'file': multipart,
      });

      final result = await _apiClient.post(
        '/students/$studentId/photo?school_id=$schoolId',
        data: formData,
        mapper: (json) => json,
      );

      return result.when(
        onSuccess: (res) {
          state = const StudentActionState(
            isLoading: false,
            successMessage: 'Profile photo updated successfully',
          );
          return true;
        },
        onFailure: (failure) {
          state = StudentActionState(
            isLoading: false,
            errorMessage: failure.message,
          );
          return false;
        },
      );
    } catch (e) {
      state = StudentActionState(
        isLoading: false,
        errorMessage: 'Failed to upload photo: $e',
      );
      return false;
    }
  }

  Future<bool> deleteStudentPhoto({
    required String schoolId,
    required String studentId,
  }) async {
    state = const StudentActionState(isLoading: true);

    final result = await _apiClient.delete(
      '/students/$studentId/photo?school_id=$schoolId',
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const StudentActionState(
          isLoading: false,
          successMessage: 'Profile photo removed',
        );
        return true;
      },
      onFailure: (failure) {
        state = StudentActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }
}

final studentActionProvider =
    StateNotifierProvider<StudentActionNotifier, StudentActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StudentActionNotifier(apiClient);
});

final guardianDetailsProvider =
    FutureProvider.family<GuardianDto, String>((ref, id) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) {
    throw Exception('No active school campus selected.');
  }

  final result = await apiClient.get(
    '/guardians/$id?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return GuardianDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (guardian) => guardian,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final guardianUserStatusProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, guardianId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/identity/provision/status/$guardianId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return Map<String, dynamic>.from(payload['data'] as Map);
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final linkedStudentsProvider =
    FutureProvider.family<List<StudentDto>, String>((ref, userEmail) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return const [];

  // 1. Get Guardian
  final guardianResult = await apiClient.get(
    '/guardians?school_id=$schoolId&search=$userEmail',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>;
      return list
          .map((item) => GuardianDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  final guardians = guardianResult.when(
    onSuccess: (list) => list,
    onFailure: (failure) => throw Exception(failure.message),
  );

  if (guardians.isEmpty) return const [];
  final guardianId = guardians.first.id;

  // 2. Get Mappings
  final mappingResult = await apiClient.get(
    '/student-guardians?guardian_id=$guardianId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>;
      return list
          .map((item) => StudentGuardianDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  final mappings = mappingResult.when(
    onSuccess: (list) => list,
    onFailure: (failure) => throw Exception(failure.message),
  );

  if (mappings.isEmpty) return const [];

  // 3. Get Student Profiles
  final List<StudentDto> students = [];
  for (final map in mappings) {
    final studentResult = await apiClient.get(
      '/students/${map.studentId}?school_id=$schoolId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return StudentDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
      },
    );
    studentResult.when(
      onSuccess: (student) => students.add(student),
      onFailure: (_) {}, // Skip failed loads gracefully
    );
  }

  return students;
});

class Student360Key {
  final String schoolId;
  final String studentId;

  const Student360Key({required this.schoolId, required this.studentId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student360Key &&
          runtimeType == other.runtimeType &&
          schoolId == other.schoolId &&
          studentId == other.studentId;

  @override
  int get hashCode => schoolId.hashCode ^ studentId.hashCode;
}

final student360AnalyticsProvider =
    FutureProvider.autoDispose.family<Student360Analytics, Student360Key>((ref, key) async {
  final apiClient = ref.watch(apiClientProvider);
  final activeSchoolId = key.schoolId.isNotEmpty
      ? key.schoolId
      : (ref.watch(selectedSchoolIdProvider) ?? '');

  final result = await apiClient.get(
    '/students/${key.studentId}/analytics?school_id=$activeSchoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>?;
      if (data == null) {
        return Student360Analytics.empty(key.studentId, activeSchoolId);
      }
      return Student360Analytics.fromJson(data);
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) {
      return Student360Analytics.empty(key.studentId, activeSchoolId);
    },
  );
});

class StudentPhotoKey {
  final String studentId;
  final String schoolId;
  final String? version;

  const StudentPhotoKey({
    required this.studentId,
    required this.schoolId,
    this.version,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentPhotoKey &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          schoolId == other.schoolId &&
          version == other.version;

  @override
  int get hashCode =>
      studentId.hashCode ^ schoolId.hashCode ^ (version?.hashCode ?? 0);
}

final studentAvatarBytesProvider =
    FutureProvider.family<Uint8List?, StudentPhotoKey>((ref, key) async {
  if (key.studentId.isEmpty || key.schoolId.isEmpty) return null;
  final apiClient = ref.watch(apiClientProvider);

  final versionQuery = key.version != null ? '&v=${Uri.encodeComponent(key.version!)}' : '';
  final result = await apiClient.get<Uint8List?>(
    '/students/${key.studentId}/photo?school_id=${key.schoolId}$versionQuery',
    options: Options(responseType: ResponseType.bytes),
    mapper: (data) {
      if (data is List<int>) {
        return Uint8List.fromList(data);
      }
      return null;
    },
  );

  return result.when(
    onSuccess: (bytes) => bytes,
    onFailure: (_) => null,
  );
});


