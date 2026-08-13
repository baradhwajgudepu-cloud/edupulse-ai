import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/migrations/data/models/migration_models.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/presentation/providers/student_providers.dart';

// --- 1. MIGRATION JOB LIST PROVIDER ---
class MigrationJobListState {
  final List<ImportJobDto> jobs;
  final bool isLoading;
  final String? error;
  final String filterType; // 'ALL', 'STUDENTS', 'ACADEMIC_SETUP', 'GUARDIAN_MAPPING'

  const MigrationJobListState({
    required this.jobs,
    required this.isLoading,
    this.error,
    this.filterType = 'ALL',
  });

  MigrationJobListState copyWith({
    List<ImportJobDto>? jobs,
    bool? isLoading,
    String? error,
    String? filterType,
  }) {
    return MigrationJobListState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterType: filterType ?? this.filterType,
    );
  }
}

class MigrationJobListNotifier extends StateNotifier<MigrationJobListState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  MigrationJobListNotifier(this._apiClient, this._schoolId)
      : super(const MigrationJobListState(jobs: [], isLoading: false, filterType: 'ALL')) {
    fetchJobs();
  }

  Future<void> fetchJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    final Map<String, dynamic> qParams = {
      'school_id': _schoolId,
      'limit': 100,
    };
    if (state.filterType != 'ALL') {
      qParams['import_type'] = state.filterType;
    }
    final result = await _apiClient.get(
      '/import-jobs',
      queryParameters: qParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => ImportJobDto.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        if (!mounted) return;
        state = state.copyWith(jobs: data, isLoading: false);
      },
      onFailure: (failure) {
        if (!mounted) return;
        state = state.copyWith(jobs: [], isLoading: false, error: failure.message);
      },
    );
  }

  Future<void> changeFilter(String newFilter) async {
    if (state.filterType == newFilter) return;
    state = state.copyWith(filterType: newFilter);
    await fetchJobs();
  }
}

final migrationJobListProvider = StateNotifierProvider.family<
    MigrationJobListNotifier, MigrationJobListState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return MigrationJobListNotifier(apiClient, schoolId);
});



// --- 2. MIGRATION JOB DETAIL PROVIDER ---
class MigrationJobDetailState {
  final ImportJobDto? job;
  final bool isLoading;
  final String? error;

  const MigrationJobDetailState({
    this.job,
    required this.isLoading,
    this.error,
  });

  MigrationJobDetailState copyWith({
    ImportJobDto? job,
    bool? isLoading,
    String? error,
  }) {
    return MigrationJobDetailState(
      job: job ?? this.job,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MigrationJobDetailNotifier extends StateNotifier<MigrationJobDetailState> {
  final BaseApiClient _apiClient;
  final String _jobId;

  MigrationJobDetailNotifier(this._apiClient, this._jobId)
      : super(const MigrationJobDetailState(isLoading: false)) {
    fetchJob();
  }

  Future<void> fetchJob() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/import-jobs/$_jobId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    result.when(
      onSuccess: (data) {
        if (!mounted) return;
        state = MigrationJobDetailState(job: data, isLoading: false);
      },
      onFailure: (failure) {
        if (!mounted) return;
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final migrationJobDetailProvider = StateNotifierProvider.family<
    MigrationJobDetailNotifier, MigrationJobDetailState, String>((ref, jobId) {
  final apiClient = ref.watch(apiClientProvider);
  return MigrationJobDetailNotifier(apiClient, jobId);
});


// --- 3. MIGRATION JOB ROWS PROVIDER ---
class MigrationJobRowsState {
  final List<ImportJobRowDto> rows;
  final bool isLoading;
  final String? error;
  final int skip;
  final int limit;
  final bool hasMore;

  const MigrationJobRowsState({
    required this.rows,
    required this.isLoading,
    this.error,
    required this.skip,
    required this.limit,
    required this.hasMore,
  });

  MigrationJobRowsState copyWith({
    List<ImportJobRowDto>? rows,
    bool? isLoading,
    String? error,
    int? skip,
    int? limit,
    bool? hasMore,
  }) {
    return MigrationJobRowsState(
      rows: rows ?? this.rows,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class MigrationJobRowsNotifier extends StateNotifier<MigrationJobRowsState> {
  final BaseApiClient _apiClient;
  final String _jobId;

  MigrationJobRowsNotifier(this._apiClient, this._jobId)
      : super(const MigrationJobRowsState(
            rows: [], isLoading: false, skip: 0, limit: 100, hasMore: true)) {
    fetchRows();
  }

  Future<void> fetchRows({bool loadMore = false}) async {
    if (state.isLoading) return;
    if (loadMore && !state.hasMore) return;

    final nextSkip = loadMore ? state.skip + state.limit : 0;
    state = state.copyWith(isLoading: true, error: null);

    final result = await _apiClient.get(
      '/import-jobs/$_jobId/rows',
      queryParameters: {
        'skip': nextSkip,
        'limit': state.limit,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => ImportJobRowDto.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        if (!mounted) return;
        state = MigrationJobRowsState(
          rows: loadMore ? [...state.rows, ...data] : data,
          isLoading: false,
          skip: nextSkip,
          limit: state.limit,
          hasMore: data.length >= state.limit,
        );
      },
      onFailure: (failure) {
        if (!mounted) return;
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final migrationJobRowsProvider = StateNotifierProvider.family<
    MigrationJobRowsNotifier, MigrationJobRowsState, String>((ref, jobId) {
  final apiClient = ref.watch(apiClientProvider);
  return MigrationJobRowsNotifier(apiClient, jobId);
});


// --- 4. STUDENT MIGRATION CONTROLLER ---
class StudentMigrationWizardState {
  final int currentStep; // 0: Context, 1: CSV, 2: Validate, 3: Review, 4: Execute, 5: Complete
  final String? selectedSchoolId;
  final String? selectedAcademicYearId;
  final String? fileName;
  final Uint8List? fileBytes;
  final String? jobId;
  final ImportJobDto? activeJob;
  final bool isActionInProgress;
  final String? errorMessage;
  final List<ImportJobRowDto> validationErrors;

  const StudentMigrationWizardState({
    required this.currentStep,
    this.selectedSchoolId,
    this.selectedAcademicYearId,
    this.fileName,
    this.fileBytes,
    this.jobId,
    this.activeJob,
    required this.isActionInProgress,
    this.errorMessage,
    required this.validationErrors,
  });

  StudentMigrationWizardState copyWith({
    int? currentStep,
    String? selectedSchoolId,
    String? selectedAcademicYearId,
    String? fileName,
    Uint8List? fileBytes,
    String? jobId,
    ImportJobDto? activeJob,
    bool? isActionInProgress,
    String? errorMessage,
    List<ImportJobRowDto>? validationErrors,
  }) {
    return StudentMigrationWizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedSchoolId: selectedSchoolId ?? this.selectedSchoolId,
      selectedAcademicYearId: selectedAcademicYearId ?? this.selectedAcademicYearId,
      fileName: fileName ?? this.fileName,
      fileBytes: fileBytes ?? this.fileBytes,
      jobId: jobId ?? this.jobId,
      activeJob: activeJob ?? this.activeJob,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }

  factory StudentMigrationWizardState.initial() {
    return const StudentMigrationWizardState(
      currentStep: 0,
      isActionInProgress: false,
      validationErrors: [],
    );
  }
}

class StudentMigrationWizardController extends StateNotifier<StudentMigrationWizardState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  StudentMigrationWizardController(this._apiClient, this._ref)
      : super(StudentMigrationWizardState.initial());

  void reset() {
    state = StudentMigrationWizardState.initial();
  }

  Future<bool> preloadJob(String jobId) async {
    state = state.copyWith(isActionInProgress: true, errorMessage: null);
    final result = await _apiClient.get(
      '/import-jobs/$jobId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return await result.when(
      onSuccess: (job) async {
        if (!mounted) return false;
        int targetStep = 0;
        switch (job.status) {
          case 'DRAFT':
            targetStep = 1; // Go to CSV selection step
            break;
          case 'VALIDATING':
          case 'VALIDATED':
            targetStep = 2; // Go to Validation step
            break;
          case 'RUNNING':
            targetStep = 4; // Go to execution step
            break;
          case 'COMPLETED':
          case 'COMPLETED_WITH_ERRORS':
          case 'FAILED':
          case 'CANCELLED':
            targetStep = 5; // Go to final step
            break;
          default:
            targetStep = 0;
        }

        state = state.copyWith(
          jobId: job.id,
          activeJob: job,
          selectedSchoolId: job.schoolId,
          selectedAcademicYearId: job.jobMetadata['academic_year_id'] as String?,
          fileName: job.sourceFilename,
          currentStep: targetStep,
          isActionInProgress: false,
        );

        if (job.status == 'VALIDATED' ||
            job.status == 'COMPLETED' ||
            job.status == 'COMPLETED_WITH_ERRORS') {
          await fetchValidationErrors();
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(
          isActionInProgress: false,
          errorMessage: 'Failed to preload job: ${failure.message}',
        );
        return false;
      },
    );
  }

  void updateContext(String schoolId, String academicYearId) {
    state = state.copyWith(
      selectedSchoolId: schoolId,
      selectedAcademicYearId: academicYearId,
    );
  }

  void updateSelectedFile(String name, Uint8List bytes) {
    state = state.copyWith(
      fileName: name,
      fileBytes: bytes,
      errorMessage: null,
    );
  }

  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<bool> createImportJob() async {
    if (state.selectedSchoolId == null || state.selectedAcademicYearId == null || state.fileName == null) {
      state = state.copyWith(errorMessage: 'Required context metadata is missing.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs',
      data: {
        'school_id': state.selectedSchoolId,
        'import_type': 'STUDENTS',
        'source_filename': state.fileName,
        'total_rows': 0,
        'job_metadata': {
          'academic_year_id': state.selectedAcademicYearId,
        },
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          jobId: job.id,
          activeJob: job,
          isActionInProgress: false,
        );
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> validateCsvFile() async {
    if (state.jobId == null || state.fileBytes == null || state.fileName == null) {
      state = state.copyWith(errorMessage: 'Job parameters or file payload is missing.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        state.fileBytes!,
        filename: state.fileName!,
      ),
    });

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/validate',
      data: formData,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return await result.when(
      onSuccess: (job) async {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        await fetchValidationErrors();
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<void> fetchValidationErrors() async {
    if (state.jobId == null) return;

    final result = await _apiClient.get(
      '/import-jobs/${state.jobId}/rows',
      queryParameters: {'skip': 0, 'limit': 100},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => ImportJobRowDto.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        if (!mounted) return;
        final errors = data.where((r) => r.status == 'failed').toList();
        state = state.copyWith(validationErrors: errors);
      },
      onFailure: (failure) {
        if (!mounted) return;
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<bool> executeMigration() async {
    if (state.jobId == null) {
      state = state.copyWith(errorMessage: 'No active job ID found.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/start',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        if (state.selectedSchoolId != null) {
          _ref.invalidate(migrationJobListProvider(state.selectedSchoolId!));
          // Invalidate relevant student registry lists upon execution completes
          _ref.invalidate(studentListProvider);
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> cancelMigration() async {
    if (state.jobId == null) return false;
    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/cancel',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        if (state.selectedSchoolId != null) {
          _ref.invalidate(migrationJobListProvider(state.selectedSchoolId!));
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final studentMigrationWizardProvider = StateNotifierProvider<
    StudentMigrationWizardController, StudentMigrationWizardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StudentMigrationWizardController(apiClient, ref);
});


// --- 5. ACADEMIC SETUP MIGRATION CONTROLLER ---
class AcademicSetupMigrationWizardState {
  final int currentStep; // 0: Context, 1: CSV, 2: Validate, 3: Review, 4: Execute, 5: Complete
  final String? selectedSchoolId;
  final String? selectedAcademicYearId;
  final String? fileName;
  final Uint8List? fileBytes;
  final String? jobId;
  final ImportJobDto? activeJob;
  final bool isActionInProgress;
  final String? errorMessage;
  final List<ImportJobRowDto> validationErrors;

  const AcademicSetupMigrationWizardState({
    required this.currentStep,
    this.selectedSchoolId,
    this.selectedAcademicYearId,
    this.fileName,
    this.fileBytes,
    this.jobId,
    this.activeJob,
    required this.isActionInProgress,
    this.errorMessage,
    required this.validationErrors,
  });

  AcademicSetupMigrationWizardState copyWith({
    int? currentStep,
    String? selectedSchoolId,
    String? selectedAcademicYearId,
    String? fileName,
    Uint8List? fileBytes,
    String? jobId,
    ImportJobDto? activeJob,
    bool? isActionInProgress,
    String? errorMessage,
    List<ImportJobRowDto>? validationErrors,
  }) {
    return AcademicSetupMigrationWizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedSchoolId: selectedSchoolId ?? this.selectedSchoolId,
      selectedAcademicYearId: selectedAcademicYearId ?? this.selectedAcademicYearId,
      fileName: fileName ?? this.fileName,
      fileBytes: fileBytes ?? this.fileBytes,
      jobId: jobId ?? this.jobId,
      activeJob: activeJob ?? this.activeJob,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }

  factory AcademicSetupMigrationWizardState.initial() {
    return const AcademicSetupMigrationWizardState(
      currentStep: 0,
      isActionInProgress: false,
      validationErrors: [],
    );
  }
}

class AcademicSetupMigrationWizardController extends StateNotifier<AcademicSetupMigrationWizardState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AcademicSetupMigrationWizardController(this._apiClient, this._ref)
      : super(AcademicSetupMigrationWizardState.initial());

  void reset() {
    state = AcademicSetupMigrationWizardState.initial();
  }

  Future<bool> preloadJob(String jobId) async {
    state = state.copyWith(isActionInProgress: true, errorMessage: null);
    final result = await _apiClient.get(
      '/import-jobs/$jobId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return await result.when(
      onSuccess: (job) async {
        if (!mounted) return false;
        int targetStep = 0;
        switch (job.status) {
          case 'DRAFT':
            targetStep = 1;
            break;
          case 'VALIDATING':
          case 'VALIDATED':
            targetStep = 2;
            break;
          case 'RUNNING':
            targetStep = 4;
            break;
          case 'COMPLETED':
          case 'COMPLETED_WITH_ERRORS':
          case 'FAILED':
          case 'CANCELLED':
            targetStep = 5;
            break;
          default:
            targetStep = 0;
        }

        state = state.copyWith(
          jobId: job.id,
          activeJob: job,
          selectedSchoolId: job.schoolId,
          selectedAcademicYearId: job.jobMetadata['academic_year_id'] as String?,
          fileName: job.sourceFilename,
          currentStep: targetStep,
          isActionInProgress: false,
        );

        if (job.status == 'VALIDATED' ||
            job.status == 'COMPLETED' ||
            job.status == 'COMPLETED_WITH_ERRORS') {
          await fetchValidationErrors();
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(
          isActionInProgress: false,
          errorMessage: 'Failed to preload job: ${failure.message}',
        );
        return false;
      },
    );
  }

  void updateContext(String schoolId, String academicYearId) {
    state = state.copyWith(
      selectedSchoolId: schoolId,
      selectedAcademicYearId: academicYearId,
    );
  }

  void updateSelectedFile(String name, Uint8List bytes) {
    state = state.copyWith(
      fileName: name,
      fileBytes: bytes,
      errorMessage: null,
    );
  }

  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<bool> createImportJob() async {
    if (state.selectedSchoolId == null || state.fileName == null) {
      state = state.copyWith(errorMessage: 'Required context metadata is missing.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs',
      data: {
        'school_id': state.selectedSchoolId,
        'import_type': 'ACADEMIC_SETUP',
        'source_filename': state.fileName,
        'total_rows': 0,
        'job_metadata': {
          if (state.selectedAcademicYearId != null)
            'academic_year_id': state.selectedAcademicYearId,
        },
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          jobId: job.id,
          activeJob: job,
          isActionInProgress: false,
        );
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> validateCsvFile() async {
    if (state.jobId == null || state.fileBytes == null || state.fileName == null) {
      state = state.copyWith(errorMessage: 'Job parameters or file payload is missing.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        state.fileBytes!,
        filename: state.fileName!,
      ),
    });

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/validate',
      data: formData,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return await result.when(
      onSuccess: (job) async {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        await fetchValidationErrors();
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<void> fetchValidationErrors() async {
    if (state.jobId == null) return;

    final result = await _apiClient.get(
      '/import-jobs/${state.jobId}/rows',
      queryParameters: {'skip': 0, 'limit': 100},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => ImportJobRowDto.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        if (!mounted) return;
        final errors = data.where((r) => r.status == 'failed').toList();
        state = state.copyWith(validationErrors: errors);
      },
      onFailure: (failure) {
        if (!mounted) return;
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<bool> executeMigration() async {
    if (state.jobId == null) {
      state = state.copyWith(errorMessage: 'No active job ID found.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/start',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        if (state.selectedSchoolId != null) {
          _ref.invalidate(migrationJobListProvider(state.selectedSchoolId!));
          _ref.invalidate(academicYearsProvider(state.selectedSchoolId!));
          _ref.invalidate(classesProvider(state.selectedSchoolId!));
          _ref.invalidate(sectionsProvider(state.selectedSchoolId!));
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> cancelMigration() async {
    if (state.jobId == null) return false;
    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/cancel',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        if (state.selectedSchoolId != null) {
          _ref.invalidate(migrationJobListProvider(state.selectedSchoolId!));
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final academicSetupMigrationWizardProvider = StateNotifierProvider<
    AcademicSetupMigrationWizardController, AcademicSetupMigrationWizardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AcademicSetupMigrationWizardController(apiClient, ref);
});


// --- 6. GUARDIAN MAPPING MIGRATION CONTROLLER ---
class GuardianMappingMigrationWizardState {
  final int currentStep; // 0: Context, 1: CSV, 2: Validate, 3: Review, 4: Execute, 5: Complete
  final String? selectedSchoolId;
  final String? fileName;
  final Uint8List? fileBytes;
  final String? jobId;
  final ImportJobDto? activeJob;
  final bool isActionInProgress;
  final String? errorMessage;
  final List<ImportJobRowDto> validationErrors;

  const GuardianMappingMigrationWizardState({
    required this.currentStep,
    this.selectedSchoolId,
    this.fileName,
    this.fileBytes,
    this.jobId,
    this.activeJob,
    required this.isActionInProgress,
    this.errorMessage,
    required this.validationErrors,
  });

  GuardianMappingMigrationWizardState copyWith({
    int? currentStep,
    String? selectedSchoolId,
    String? fileName,
    Uint8List? fileBytes,
    String? jobId,
    ImportJobDto? activeJob,
    bool? isActionInProgress,
    String? errorMessage,
    List<ImportJobRowDto>? validationErrors,
  }) {
    return GuardianMappingMigrationWizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedSchoolId: selectedSchoolId ?? this.selectedSchoolId,
      fileName: fileName ?? this.fileName,
      fileBytes: fileBytes ?? this.fileBytes,
      jobId: jobId ?? this.jobId,
      activeJob: activeJob ?? this.activeJob,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }

  factory GuardianMappingMigrationWizardState.initial() {
    return const GuardianMappingMigrationWizardState(
      currentStep: 0,
      isActionInProgress: false,
      validationErrors: [],
    );
  }
}

class GuardianMappingMigrationWizardController extends StateNotifier<GuardianMappingMigrationWizardState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  GuardianMappingMigrationWizardController(this._apiClient, this._ref)
      : super(GuardianMappingMigrationWizardState.initial());

  void reset() {
    state = GuardianMappingMigrationWizardState.initial();
  }

  Future<bool> preloadJob(String jobId) async {
    state = state.copyWith(isActionInProgress: true, errorMessage: null);
    final result = await _apiClient.get(
      '/import-jobs/$jobId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return await result.when(
      onSuccess: (job) async {
        if (!mounted) return false;
        int targetStep = 0;
        switch (job.status) {
          case 'DRAFT':
            targetStep = 1;
            break;
          case 'VALIDATING':
          case 'VALIDATED':
            targetStep = 2;
            break;
          case 'RUNNING':
            targetStep = 4;
            break;
          case 'COMPLETED':
          case 'COMPLETED_WITH_ERRORS':
          case 'FAILED':
          case 'CANCELLED':
            targetStep = 5;
            break;
          default:
            targetStep = 0;
        }

        state = state.copyWith(
          jobId: job.id,
          activeJob: job,
          selectedSchoolId: job.schoolId,
          fileName: job.sourceFilename,
          currentStep: targetStep,
          isActionInProgress: false,
        );

        if (job.status == 'VALIDATED' ||
            job.status == 'COMPLETED' ||
            job.status == 'COMPLETED_WITH_ERRORS') {
          await fetchValidationErrors();
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(
          isActionInProgress: false,
          errorMessage: 'Failed to preload job: ${failure.message}',
        );
        return false;
      },
    );
  }

  void updateContext(String schoolId) {
    state = state.copyWith(
      selectedSchoolId: schoolId,
    );
  }

  void updateSelectedFile(String name, Uint8List bytes) {
    state = state.copyWith(
      fileName: name,
      fileBytes: bytes,
      errorMessage: null,
    );
  }

  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<bool> createImportJob() async {
    if (state.selectedSchoolId == null || state.fileName == null) {
      state = state.copyWith(errorMessage: 'Required context metadata is missing.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs',
      data: {
        'school_id': state.selectedSchoolId,
        'import_type': 'GUARDIAN_MAPPING',
        'source_filename': state.fileName,
        'total_rows': 0,
        'job_metadata': {},
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          jobId: job.id,
          activeJob: job,
          isActionInProgress: false,
        );
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> validateCsvFile() async {
    if (state.jobId == null || state.fileBytes == null || state.fileName == null) {
      state = state.copyWith(errorMessage: 'Job parameters or file payload is missing.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        state.fileBytes!,
        filename: state.fileName!,
      ),
    });

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/validate',
      data: formData,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return await result.when(
      onSuccess: (job) async {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        await fetchValidationErrors();
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<void> fetchValidationErrors() async {
    if (state.jobId == null) return;

    final result = await _apiClient.get(
      '/import-jobs/${state.jobId}/rows',
      queryParameters: {'skip': 0, 'limit': 100},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => ImportJobRowDto.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        if (!mounted) return;
        final errors = data.where((r) => r.status == 'failed').toList();
        state = state.copyWith(validationErrors: errors);
      },
      onFailure: (failure) {
        if (!mounted) return;
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<bool> executeMigration() async {
    if (state.jobId == null) {
      state = state.copyWith(errorMessage: 'No active job ID found.');
      return false;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/start',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        if (state.selectedSchoolId != null) {
          _ref.invalidate(migrationJobListProvider(state.selectedSchoolId!));
          _ref.invalidate(studentListProvider);
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> cancelMigration() async {
    if (state.jobId == null) return false;
    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    final result = await _apiClient.post(
      '/import-jobs/${state.jobId}/cancel',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ImportJobDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (job) {
        if (!mounted) return false;
        state = state.copyWith(
          activeJob: job,
          isActionInProgress: false,
        );
        if (state.selectedSchoolId != null) {
          _ref.invalidate(migrationJobListProvider(state.selectedSchoolId!));
        }
        return true;
      },
      onFailure: (failure) {
        if (!mounted) return false;
        state = state.copyWith(isActionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final guardianMappingMigrationWizardProvider = StateNotifierProvider<
    GuardianMappingMigrationWizardController, GuardianMappingMigrationWizardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GuardianMappingMigrationWizardController(apiClient, ref);
});

