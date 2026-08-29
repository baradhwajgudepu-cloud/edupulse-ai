import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/models/tenant_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class TenantsListState {
  final List<TenantDto> tenants;
  final bool isLoading;
  final String? error;

  const TenantsListState({
    required this.tenants,
    required this.isLoading,
    this.error,
  });

  TenantsListState copyWith({
    List<TenantDto>? tenants,
    bool? isLoading,
    String? error,
  }) {
    return TenantsListState(
      tenants: tenants ?? this.tenants,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TenantsListNotifier extends StateNotifier<TenantsListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  TenantsListNotifier(this._apiClient, this._ref)
      : super(const TenantsListState(tenants: [], isLoading: false));

  Future<void> fetchTenants() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/tenants',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => TenantDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    result.when(
      onSuccess: (tenants) {
        state = TenantsListState(tenants: tenants, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<ApiResult<TenantDto>> createTenant(TenantCreateRequest request) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/tenants',
      data: request.toJson(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TenantDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    await result.when(
      onSuccess: (newTenant) async {
        // Update selected tenant context
        _ref.read(selectedTenantIdProvider.notifier).state = newTenant.id;
        
        // Refresh tenants list
        await fetchTenants();
      },
      onFailure: (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
    return result;
  }

  Future<ApiResult<TenantDto>> updateTenant(String id, TenantUpdateRequest request) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.put(
      '/tenants/$id',
      data: request.toJson(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TenantDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    await result.when(
      onSuccess: (_) async {
        await fetchTenants();
      },
      onFailure: (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
    return result;
  }

  Future<ApiResult<TenantDto>> toggleTenantStatus(TenantDto tenant) async {
    final nextStatus = tenant.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    final request = TenantUpdateRequest(
      status: nextStatus,
      isActive: nextStatus == 'ACTIVE',
    );
    return updateTenant(tenant.id, request);
  }
}

final tenantsListProvider =
    StateNotifierProvider<TenantsListNotifier, TenantsListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TenantsListNotifier(apiClient, ref);
});

// Watcher to invalidate all tenant-dependent state upon tenant switch
final tenantSetupWatcherProvider = Provider<void>((ref) {
  ref.listen<String?>(selectedTenantIdProvider, (previous, next) async {
    // 1. Clear school and academic year contexts
    ref.read(selectedSchoolIdProvider.notifier).state = null;
    ref.read(selectedAcademicYearIdProvider.notifier).state = null;
    
    try {
      final session = ref.read(sessionManagerProvider);
      await session.saveSchoolId('');
    } catch (_) {}
    
    // 2. Fetch schools for the new tenant context
    ref.read(schoolsListProvider.notifier).fetchSchools();
  });
});
