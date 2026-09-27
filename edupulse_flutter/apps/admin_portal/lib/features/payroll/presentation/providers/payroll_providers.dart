import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/payroll_models.dart';

// -------------------------------------------------------------
// Keys for Family Providers
// -------------------------------------------------------------

class PayrollPeriodKey {
  final String schoolId;
  final int month;
  final int year;
  final String? policyId;

  const PayrollPeriodKey({
    required this.schoolId,
    required this.month,
    required this.year,
    this.policyId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayrollPeriodKey &&
          runtimeType == other.runtimeType &&
          schoolId == other.schoolId &&
          month == other.month &&
          year == other.year &&
          policyId == other.policyId;

  @override
  int get hashCode => schoolId.hashCode ^ month.hashCode ^ year.hashCode ^ policyId.hashCode;
}

class TeacherPayrollKey {
  final String schoolId;
  final String teacherId;

  const TeacherPayrollKey({required this.schoolId, required this.teacherId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherPayrollKey &&
          runtimeType == other.runtimeType &&
          schoolId == other.schoolId &&
          teacherId == other.teacherId;

  @override
  int get hashCode => schoolId.hashCode ^ teacherId.hashCode;
}

// -------------------------------------------------------------
// Read Providers
// -------------------------------------------------------------

final payrollPoliciesProvider =
    FutureProvider.family<List<PayrollPolicyDto>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/payroll/policies?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => PayrollPolicyDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final teacherPayrollProfilesProvider =
    FutureProvider.family<List<TeacherPayrollProfileDto>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/payroll/profiles?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => TeacherPayrollProfileDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final singleTeacherPayrollProfileProvider =
    FutureProvider.family<TeacherPayrollProfileDto, TeacherPayrollKey>((ref, key) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/payroll/teachers/${key.teacherId}?school_id=${key.schoolId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return TeacherPayrollProfileDto.fromJson(
          Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final monthlyPayrollSummaryProvider =
    FutureProvider.family<MonthlyPayrollSummaryDto, PayrollPeriodKey>((ref, key) async {
  final apiClient = ref.watch(apiClientProvider);
  final polParam = key.policyId != null ? '&policy_id=${key.policyId}' : '';
  final getResult = await apiClient.get(
    '/payroll/monthly-summary?school_id=${key.schoolId}&month=${key.month}&year=${key.year}$polParam',
    mapper: (json) {
      final res = json as Map<String, dynamic>;
      return MonthlyPayrollSummaryDto.fromJson(
          Map<String, dynamic>.from(res['data'] as Map));
    },
  );

  return getResult.when(
    onSuccess: (data) => data,
    onFailure: (_) async {
      // Fallback to calculate POST if needed
      final payload = {
        'school_id': key.schoolId,
        'month': key.month,
        'year': key.year,
        if (key.policyId != null) 'policy_id': key.policyId,
      };

      final calcResult = await apiClient.post(
        '/payroll/calculate',
        data: payload,
        mapper: (json) {
          final res = json as Map<String, dynamic>;
          return MonthlyPayrollSummaryDto.fromJson(
              Map<String, dynamic>.from(res['data'] as Map));
        },
      );

      return calcResult.when(
        onSuccess: (data) => data,
        onFailure: (failure) => throw Exception(failure.message),
      );
    },
  );
});

final payrollAuditLogsProvider =
    FutureProvider.family<List<PayrollAuditLogDto>, String>((ref, payrollId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/payroll/$payrollId/audit',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => PayrollAuditLogDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// -------------------------------------------------------------
// Action Notifier
// -------------------------------------------------------------

class PayrollActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const PayrollActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  PayrollActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return PayrollActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class PayrollActionNotifier extends StateNotifier<PayrollActionState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  PayrollActionNotifier(this._apiClient, this._ref)
      : super(const PayrollActionState());

  Future<bool> savePolicy(String schoolId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/payroll/policies?school_id=$schoolId',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(payrollPoliciesProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Payroll policy saved successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> saveTeacherProfile(String schoolId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/payroll/profiles?school_id=$schoolId',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(teacherPayrollProfilesProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Teacher compensation profile updated',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> approvePayroll(String payrollId, PayrollPeriodKey periodKey) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/payroll/$payrollId/approve',
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(monthlyPayrollSummaryProvider(periodKey));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Teacher payroll approved and finalized for disbursement',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final payrollActionProvider =
    StateNotifierProvider<PayrollActionNotifier, PayrollActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PayrollActionNotifier(apiClient, ref);
});
