import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_core/edupulse_core.dart';
import '../../data/models/fee_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/data/models/student_models.dart';

// --- 1. FEE TYPES PROVIDER ---
class FeeTypesState {
  final List<FeeType> types;
  final bool isLoading;
  final String? error;

  const FeeTypesState({
    required this.types,
    required this.isLoading,
    this.error,
  });

  FeeTypesState copyWith({
    List<FeeType>? types,
    bool? isLoading,
    String? error,
  }) {
    return FeeTypesState(
      types: types ?? this.types,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FeeTypesNotifier extends StateNotifier<FeeTypesState> {
  final BaseApiClient _apiClient;

  FeeTypesNotifier(this._apiClient)
      : super(const FeeTypesState(types: [], isLoading: false)) {
    fetchTypes();
  }

  Future<void> fetchTypes() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/fees/types',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => FeeType.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = state.copyWith(types: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<bool> createType(String name, String code, String? description) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/fees/types',
      data: {
        'name': name,
        'code': code,
        'description': description,
      },
      mapper: (json) => FeeType.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (type) {
        state = state.copyWith(types: [...state.types, type], isLoading: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteType(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.delete(
      '/fees/types/$id',
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          types: state.types.where((t) => t.id != id).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final feeTypesProvider = StateNotifierProvider<FeeTypesNotifier, FeeTypesState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FeeTypesNotifier(apiClient);
});

// --- 2. SCHOLARSHIPS PROVIDER ---
class ScholarshipsState {
  final List<Scholarship> scholarships;
  final bool isLoading;
  final String? error;

  const ScholarshipsState({
    required this.scholarships,
    required this.isLoading,
    this.error,
  });

  ScholarshipsState copyWith({
    List<Scholarship>? scholarships,
    bool? isLoading,
    String? error,
  }) {
    return ScholarshipsState(
      scholarships: scholarships ?? this.scholarships,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ScholarshipsNotifier extends StateNotifier<ScholarshipsState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  ScholarshipsNotifier(this._apiClient, this._schoolId)
      : super(const ScholarshipsState(scholarships: [], isLoading: false)) {
    fetchScholarships();
  }

  Future<void> fetchScholarships() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/fees/scholarships',
      options: Options(headers: {'X-School-ID': _schoolId}),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => Scholarship.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = state.copyWith(scholarships: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<bool> createScholarship(String name, ConcessionType concessionType, double value, String? description) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/fees/scholarships',
      options: Options(headers: {'X-School-ID': _schoolId}),
      data: {
        'name': name,
        'concession_type': concessionType.name,
        'value': value,
        'description': description,
      },
      mapper: (json) => Scholarship.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (scholarship) {
        state = state.copyWith(scholarships: [...state.scholarships, scholarship], isLoading: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteScholarship(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.delete(
      '/fees/scholarships/$id',
      options: Options(headers: {'X-School-ID': _schoolId}),
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          scholarships: state.scholarships.where((s) => s.id != id).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final scholarshipsProvider = StateNotifierProvider.family<ScholarshipsNotifier, ScholarshipsState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return ScholarshipsNotifier(apiClient, schoolId);
});

// --- 3. FEE STRUCTURES PROVIDER ---
class FeeStructuresState {
  final List<FeeStructure> structures;
  final bool isLoading;
  final String? error;

  const FeeStructuresState({
    required this.structures,
    required this.isLoading,
    this.error,
  });

  FeeStructuresState copyWith({
    List<FeeStructure>? structures,
    bool? isLoading,
    String? error,
  }) {
    return FeeStructuresState(
      structures: structures ?? this.structures,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FeeStructuresNotifier extends StateNotifier<FeeStructuresState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  FeeStructuresNotifier(this._apiClient, this._schoolId)
      : super(const FeeStructuresState(structures: [], isLoading: false)) {
    fetchStructures();
  }

  Future<void> fetchStructures() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/fees/structures',
      options: Options(headers: {'X-School-ID': _schoolId}),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => FeeStructure.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = state.copyWith(structures: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<bool> createStructure({
    required String feeTypeId,
    required String academicYearId,
    required String? classId, // null represents All Classes
    required double amount,
    required DateTime dueDate,
    String? description,
    FineRuleInput? fineRuleInput,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final Map<String, dynamic> payload = {
      'fee_type_id': feeTypeId,
      'academic_year_id': academicYearId,
      'class_id': classId,
      'amount': amount,
      'due_date': '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
      'description': description,
    };
    if (fineRuleInput != null) {
      payload['fine_rule'] = fineRuleInput.toJson();
    }

    final result = await _apiClient.post(
      '/fees/structures',
      options: Options(headers: {'X-School-ID': _schoolId}),
      data: payload,
      mapper: (json) => FeeStructure.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (structure) {
        state = state.copyWith(structures: [...state.structures, structure], isLoading: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteStructure(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.delete(
      '/fees/structures/$id',
      options: Options(headers: {'X-School-ID': _schoolId}),
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          structures: state.structures.where((s) => s.id != id).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final feeStructuresProvider = StateNotifierProvider.family<FeeStructuresNotifier, FeeStructuresState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return FeeStructuresNotifier(apiClient, schoolId);
});

// --- 4. FEES DASHBOARD METRICS PROVIDER ---
class FeesDashboardState {
  final DashboardMetrics? metrics;
  final CollectionAnalytics? analytics;
  final bool isLoading;
  final String? error;
  final bool isAiAvailable;

  const FeesDashboardState({
    this.metrics,
    this.analytics,
    required this.isLoading,
    this.error,
    required this.isAiAvailable,
  });

  FeesDashboardState copyWith({
    DashboardMetrics? metrics,
    CollectionAnalytics? analytics,
    bool? isLoading,
    String? error,
    bool? isAiAvailable,
  }) {
    return FeesDashboardState(
      metrics: metrics ?? this.metrics,
      analytics: analytics ?? this.analytics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAiAvailable: isAiAvailable ?? this.isAiAvailable,
    );
  }
}

class FeesDashboardNotifier extends StateNotifier<FeesDashboardState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  FeesDashboardNotifier(this._apiClient, this._schoolId)
      : super(const FeesDashboardState(isLoading: false, isAiAvailable: true)) {
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    state = state.copyWith(isLoading: true, error: null);

    // 1. Fetch core metrics (must succeed)
    final metricsResult = await _apiClient.get(
      '/fees/reports/dashboard',
      options: Options(headers: {'X-School-ID': _schoolId}),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return DashboardMetrics.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    if (metricsResult.isSuccess) {
      final metrics = metricsResult.dataOrNull!;

      // Core metrics succeeded. Now fetch AI analytics (can fail independently)
      final aiResult = await _apiClient.get(
        '/fees/ai/analytics',
        options: Options(headers: {'X-School-ID': _schoolId}),
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return CollectionAnalytics.fromJson(payload['data'] as Map<String, dynamic>);
        },
      );

      if (aiResult.isSuccess) {
        state = FeesDashboardState(
          metrics: metrics,
          analytics: aiResult.dataOrNull,
          isLoading: false,
          isAiAvailable: true,
        );
      } else {
        state = FeesDashboardState(
          metrics: metrics,
          analytics: null,
          isLoading: false,
          isAiAvailable: false,
        );
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: metricsResult.failureOrNull!.message,
      );
    }
  }
}

final feesDashboardProvider = StateNotifierProvider.family<FeesDashboardNotifier, FeesDashboardState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return FeesDashboardNotifier(apiClient, schoolId);
});

// --- 5. STUDENT SEARCH PROVIDER ---
class StudentSearchState {
  final List<StudentDto> students;
  final bool isLoading;
  final String? error;

  const StudentSearchState({
    required this.students,
    required this.isLoading,
    this.error,
  });

  StudentSearchState copyWith({
    List<StudentDto>? students,
    bool? isLoading,
    String? error,
  }) {
    return StudentSearchState(
      students: students ?? this.students,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StudentSearchNotifier extends StateNotifier<StudentSearchState> {
  final BaseApiClient _apiClient;
  final String _schoolId;

  StudentSearchNotifier(this._apiClient, this._schoolId)
      : super(const StudentSearchState(students: [], isLoading: false));

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const StudentSearchState(students: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/students',
      queryParameters: {
        'school_id': _schoolId,
        'search': query,
        'limit': 20,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => StudentDto.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = StudentSearchState(students: data, isLoading: false);
      },
      onFailure: (failure) {
        state = StudentSearchState(students: [], isLoading: false, error: failure.message);
      },
    );
  }
}

final studentSearchProvider = StateNotifierProvider.family<StudentSearchNotifier, StudentSearchState, String>((ref, schoolId) {
  final apiClient = ref.watch(apiClientProvider);
  return StudentSearchNotifier(apiClient, schoolId);
});

// --- 6. STUDENT LEDGER PROVIDER ---
class StudentLedgerState {
  final StudentLedger? ledger;
  final bool isLoading;
  final String? error;

  const StudentLedgerState({
    this.ledger,
    required this.isLoading,
    this.error,
  });

  StudentLedgerState copyWith({
    StudentLedger? ledger,
    bool? isLoading,
    String? error,
  }) {
    return StudentLedgerState(
      ledger: ledger ?? this.ledger,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StudentLedgerNotifier extends StateNotifier<StudentLedgerState> {
  final BaseApiClient _apiClient;
  final String _studentId;

  StudentLedgerNotifier(this._apiClient, this._studentId)
      : super(const StudentLedgerState(isLoading: false)) {
    fetchLedger();
  }

  Future<void> fetchLedger() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/fees/ledgers/$_studentId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return StudentLedger.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    result.when(
      onSuccess: (data) {
        state = StudentLedgerState(ledger: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final studentLedgerProvider = StateNotifierProvider.family<StudentLedgerNotifier, StudentLedgerState, String>((ref, studentId) {
  final apiClient = ref.watch(apiClientProvider);
  return StudentLedgerNotifier(apiClient, studentId);
});

// --- 7. FEE ASSIGNMENT CREATION PROVIDER ---
class FeeAssignmentCreationState {
  final bool isLoading;
  final String? error;
  final StudentFeeAssignment? assignment;

  const FeeAssignmentCreationState({
    required this.isLoading,
    this.error,
    this.assignment,
  });

  FeeAssignmentCreationState copyWith({
    bool? isLoading,
    String? error,
    StudentFeeAssignment? assignment,
  }) {
    return FeeAssignmentCreationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      assignment: assignment ?? this.assignment,
    );
  }
}

class FeeAssignmentCreationNotifier extends StateNotifier<FeeAssignmentCreationState> {
  final BaseApiClient _apiClient;

  FeeAssignmentCreationNotifier(this._apiClient)
      : super(const FeeAssignmentCreationState(isLoading: false));

  Future<bool> assignFee({
    required String studentId,
    required String feeStructureId,
    String? scholarshipId,
  }) async {
    state = const FeeAssignmentCreationState(isLoading: true);
    final result = await _apiClient.post(
      '/fees/assign',
      data: {
        'student_id': studentId,
        'fee_structure_id': feeStructureId,
        if (scholarshipId != null && scholarshipId.isNotEmpty) 'scholarship_id': scholarshipId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return StudentFeeAssignment.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (data) {
        state = FeeAssignmentCreationState(isLoading: false, assignment: data);
        return true;
      },
      onFailure: (failure) {
        state = FeeAssignmentCreationState(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final feeAssignmentCreationProvider = StateNotifierProvider<FeeAssignmentCreationNotifier, FeeAssignmentCreationState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FeeAssignmentCreationNotifier(apiClient);
});

class OutstandingReportState {
  final List<OutstandingFeeReportItem> items;
  final bool isLoading;
  final String? error;

  const OutstandingReportState({
    required this.items,
    required this.isLoading,
    this.error,
  });

  OutstandingReportState copyWith({
    List<OutstandingFeeReportItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return OutstandingReportState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class OutstandingReportNotifier extends StateNotifier<OutstandingReportState> {
  final BaseApiClient _apiClient;
  final String _schoolId;
  final String? _classId;
  final bool _onlyDefaulters;

  OutstandingReportNotifier(this._apiClient, this._schoolId, this._classId, this._onlyDefaulters)
      : super(const OutstandingReportState(items: [], isLoading: false)) {
    fetchReport();
  }

  Future<void> fetchReport() async {
    if (_schoolId.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/fees/reports/outstanding',
      queryParameters: {
        'school_id': _schoolId,
        if (_classId != null && _classId!.isNotEmpty) 'class_id': _classId,
        'only_defaulters': _onlyDefaulters.toString(),
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => OutstandingFeeReportItem.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = OutstandingReportState(items: data, isLoading: false);
      },
      onFailure: (failure) {
        state = OutstandingReportState(items: [], isLoading: false, error: failure.message);
      },
    );
  }
}

class OutstandingReportParams {
  final String schoolId;
  final String? classId;
  final bool onlyDefaulters;

  OutstandingReportParams({
    required this.schoolId,
    this.classId,
    required this.onlyDefaulters,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutstandingReportParams &&
          runtimeType == other.runtimeType &&
          schoolId == other.schoolId &&
          classId == other.classId &&
          onlyDefaulters == other.onlyDefaulters;

  @override
  int get hashCode => schoolId.hashCode ^ classId.hashCode ^ onlyDefaulters.hashCode;
}

final outstandingReportProvider = StateNotifierProvider.family<OutstandingReportNotifier, OutstandingReportState, OutstandingReportParams>((ref, params) {
  final apiClient = ref.watch(apiClientProvider);
  return OutstandingReportNotifier(apiClient, params.schoolId, params.classId, params.onlyDefaulters);
});
