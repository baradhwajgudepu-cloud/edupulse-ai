import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../students/data/models/student_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class GuardianFetchResult {
  final List<GuardianDto> guardians;
  final int total;

  const GuardianFetchResult({required this.guardians, required this.total});
}

class GuardianListState {
  final List<GuardianDto> guardians;
  final bool isLoading;
  final String? error;
  final String? schoolId;
  final String? status;
  final String search;
  final int skip;
  final int limit;
  final bool hasMore;
  final int total;

  const GuardianListState({
    required this.guardians,
    required this.isLoading,
    this.error,
    this.schoolId,
    this.status,
    required this.search,
    required this.skip,
    required this.limit,
    required this.hasMore,
    this.total = 0,
  });

  GuardianListState copyWith({
    List<GuardianDto>? guardians,
    bool? isLoading,
    String? error,
    String? schoolId,
    String? status,
    String? search,
    int? skip,
    int? limit,
    bool? hasMore,
    int? total,
  }) {
    return GuardianListState(
      guardians: guardians ?? this.guardians,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      schoolId: schoolId ?? this.schoolId,
      status: status ?? this.status,
      search: search ?? this.search,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
    );
  }
}

class GuardianListNotifier extends StateNotifier<GuardianListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  GuardianListNotifier(this._apiClient, this._ref)
      : super(GuardianListState(
          guardians: [],
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
          guardians: [],
        );
        fetchGuardians();
      } else {
        state = state.copyWith(
          schoolId: null,
          guardians: [],
        );
      }
    });

    final initialSchoolId = _ref.read(selectedSchoolIdProvider);
    if (initialSchoolId != null) {
      Future.microtask(() => fetchGuardians());
    }
  }

  Future<void> fetchGuardians() async {
    if (!mounted) return;
    final activeSchoolId = _ref.read(selectedSchoolIdProvider);
    if (activeSchoolId == null) {
      state = state.copyWith(
        guardians: [],
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

    if (state.status != null && state.status!.isNotEmpty) {
      queryParams['status'] = state.status!;
    }
    if (state.search.isNotEmpty) {
      queryParams['search'] = state.search;
    }

    final uri = Uri(path: '/guardians', queryParameters: queryParams);

    final result = await _apiClient.get(
      uri.toString(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        final meta = payload['meta'] as Map<dynamic, dynamic>?;
        final total = payload['total'] as int? ?? meta?['total'] as int? ?? list.length;
        return GuardianFetchResult(
          guardians: list
              .map((item) => GuardianDto.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList(),
          total: total,
        );
      },
    );

    if (!mounted) return;

    result.when(
      onSuccess: (fetchResult) {
        state = state.copyWith(
          guardians: fetchResult.guardians,
          total: fetchResult.total,
          isLoading: false,
          hasMore: fetchResult.guardians.length >= state.limit,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  void updateFilters({
    String? status,
    String? search,
  }) {
    state = state.copyWith(
      status: status,
      search: search ?? state.search,
      skip: 0,
    );
    fetchGuardians();
  }

  void nextPage() {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(skip: state.skip + state.limit);
    fetchGuardians();
  }

  void prevPage() {
    if (state.skip == 0 || state.isLoading) return;
    final nextSkip = state.skip - state.limit;
    state = state.copyWith(skip: nextSkip < 0 ? 0 : nextSkip);
    fetchGuardians();
  }
}

final guardianListProvider =
    StateNotifierProvider<GuardianListNotifier, GuardianListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GuardianListNotifier(apiClient, ref);
});

// Detail Provider
final guardianDetailProvider =
    FutureProvider.family<GuardianDto, String>((ref, id) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) {
    throw Exception('No school campus selected.');
  }

  final uri = Uri(path: '/guardians/$id', queryParameters: {'school_id': schoolId});
  final result = await apiClient.get(
    uri.toString(),
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

// Mappings Provider
final guardianMappingsProvider =
    FutureProvider.family<List<StudentGuardianDto>, String>((ref, guardianId) async {
  final apiClient = ref.watch(apiClientProvider);
  final academicYearId = ref.watch(selectedAcademicYearIdProvider);
  final queryParams = <String, String>{
    'guardian_id': guardianId,
  };
  if (academicYearId != null && academicYearId.isNotEmpty) {
    queryParams['academic_year_id'] = academicYearId;
  }
  final uri = Uri(path: '/student-guardians', queryParameters: queryParams);

  final result = await apiClient.get(
    uri.toString(),
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>;
      return list
          .map((item) => StudentGuardianDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (mappings) => mappings,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class GuardianPhotoKey {
  final String guardianId;
  final String schoolId;
  final String? version;

  const GuardianPhotoKey({
    required this.guardianId,
    required this.schoolId,
    this.version,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuardianPhotoKey &&
          runtimeType == other.runtimeType &&
          guardianId == other.guardianId &&
          schoolId == other.schoolId &&
          version == other.version;

  @override
  int get hashCode =>
      guardianId.hashCode ^ schoolId.hashCode ^ (version?.hashCode ?? 0);
}

final guardianAvatarBytesProvider =
    FutureProvider.family<Uint8List?, GuardianPhotoKey>((ref, key) async {
  if (key.guardianId.isEmpty || key.schoolId.isEmpty) return null;
  final apiClient = ref.watch(apiClientProvider);

  final versionQuery = key.version != null ? '&v=${Uri.encodeComponent(key.version!)}' : '';
  final result = await apiClient.get<Uint8List?>(
    '/guardians/${key.guardianId}/photo?school_id=${key.schoolId}$versionQuery',
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

// Actions Provider
class GuardianActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final bool isConflict;

  const GuardianActionState({
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
    this.isConflict = false,
  });
}

class GuardianActionNotifier extends StateNotifier<GuardianActionState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  GuardianActionNotifier(this._apiClient, this._ref)
      : super(const GuardianActionState(isLoading: false));

  Future<bool> execute({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    String? successMsg,
    String? invalidationId,
  }) async {
    state = const GuardianActionState(isLoading: true);
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
        state = GuardianActionState(
          isLoading: false,
          successMessage: successMsg ?? 'Action completed successfully.',
        );

        _ref.invalidate(guardianListProvider);
        if (invalidationId != null) {
          _ref.invalidate(guardianDetailProvider(invalidationId));
          _ref.invalidate(guardianMappingsProvider(invalidationId));
        }

        return true;
      },
      onFailure: (failure) {
        final conflict = failure.statusCode == 409 ||
            failure.message.contains('conflict') ||
            failure.message.contains('already exists') ||
            failure.message.contains('version') ||
            failure.message.contains('primary');

        state = GuardianActionState(
          isLoading: false,
          errorMessage: failure.message,
          isConflict: conflict,
        );
        return false;
      },
    );
  }

  Future<bool> uploadGuardianPhoto({
    required String schoolId,
    required String guardianId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    state = const GuardianActionState(isLoading: true);

    try {
      final multipart = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      );
      final formData = FormData.fromMap({
        'file': multipart,
      });

      final result = await _apiClient.post(
        '/guardians/$guardianId/photo?school_id=$schoolId',
        data: formData,
        mapper: (json) => json,
      );

      return result.when(
        onSuccess: (res) {
          state = const GuardianActionState(
            isLoading: false,
            successMessage: 'Guardian photo updated successfully',
          );
          _ref.invalidate(guardianDetailProvider(guardianId));
          _ref.invalidate(guardianListProvider);
          return true;
        },
        onFailure: (failure) {
          state = GuardianActionState(
            isLoading: false,
            errorMessage: failure.message,
          );
          return false;
        },
      );
    } catch (e) {
      state = GuardianActionState(
        isLoading: false,
        errorMessage: 'Failed to upload photo: $e',
      );
      return false;
    }
  }

  Future<bool> deleteGuardianPhoto({
    required String schoolId,
    required String guardianId,
  }) async {
    state = const GuardianActionState(isLoading: true);

    final result = await _apiClient.delete(
      '/guardians/$guardianId/photo?school_id=$schoolId',
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const GuardianActionState(
          isLoading: false,
          successMessage: 'Guardian photo removed',
        );
        _ref.invalidate(guardianDetailProvider(guardianId));
        _ref.invalidate(guardianListProvider);
        return true;
      },
      onFailure: (failure) {
        state = GuardianActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }
}

final guardianActionsProvider =
    StateNotifierProvider<GuardianActionNotifier, GuardianActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GuardianActionNotifier(apiClient, ref);
});
