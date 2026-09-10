import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';

class UsersListState {
  final List<UserResponseDto> users;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int skip;
  final int limit;
  final int totalCount;
  final bool hasMore;
  final String searchQuery;
  final String? selectedRole;
  final String? selectedStatus;
  final String? selectedSchoolId;
  final int requestToken;

  const UsersListState({
    required this.users,
    required this.isLoading,
    this.isLoadingMore = false,
    this.error,
    required this.skip,
    required this.limit,
    this.totalCount = 0,
    required this.hasMore,
    this.searchQuery = '',
    this.selectedRole,
    this.selectedStatus,
    this.selectedSchoolId,
    this.requestToken = 0,
  });

  bool get isFiltered =>
      searchQuery.isNotEmpty ||
      selectedRole != null ||
      selectedStatus != null ||
      selectedSchoolId != null;

  UsersListState copyWith({
    List<UserResponseDto>? users,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? skip,
    int? limit,
    int? totalCount,
    bool? hasMore,
    String? searchQuery,
    String? selectedRole,
    bool clearRole = false,
    String? selectedStatus,
    bool clearStatus = false,
    String? selectedSchoolId,
    bool clearSchool = false,
    int? requestToken,
  }) {
    return UsersListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRole: clearRole ? null : (selectedRole ?? this.selectedRole),
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      selectedSchoolId: clearSchool ? null : (selectedSchoolId ?? this.selectedSchoolId),
      requestToken: requestToken ?? this.requestToken,
    );
  }
}

class UsersListNotifier extends StateNotifier<UsersListState> {
  final BaseApiClient _apiClient;
  int _currentToken = 0;

  UsersListNotifier(this._apiClient)
      : super(const UsersListState(
          users: [],
          isLoading: false,
          isLoadingMore: false,
          skip: 0,
          limit: 20,
          totalCount: 0,
          hasMore: true,
        ));

  Future<void> fetchUsers({bool reset = false}) async {
    if (!reset && (state.isLoading || state.isLoadingMore)) return;

    final newSkip = reset ? 0 : state.skip;
    final token = ++_currentToken;

    if (reset) {
      state = state.copyWith(
        users: const [],
        isLoading: true,
        error: null,
        requestToken: token,
        skip: 0,
      );
    } else {
      state = state.copyWith(isLoadingMore: true, error: null, requestToken: token);
    }

    // Build URL query parameters
    final params = <String>[
      'skip=$newSkip',
      'limit=${state.limit}',
    ];
    if (state.searchQuery.isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(state.searchQuery)}');
    }
    if (state.selectedRole != null && state.selectedRole!.isNotEmpty) {
      params.add('role=${Uri.encodeQueryComponent(state.selectedRole!)}');
    }
    if (state.selectedStatus != null && state.selectedStatus!.isNotEmpty) {
      params.add('status=${Uri.encodeQueryComponent(state.selectedStatus!)}');
    }
    if (state.selectedSchoolId != null && state.selectedSchoolId!.isNotEmpty) {
      params.add('school_id=${Uri.encodeQueryComponent(state.selectedSchoolId!)}');
    }

    final queryString = params.join('&');
    final result = await _apiClient.get(
      '/identity/users?$queryString',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = (payload['data'] as List<dynamic>?) ?? [];
        final users = list
            .map((item) => UserResponseDto.fromJson(item as Map<String, dynamic>))
            .toList();
        final meta = payload['meta'] as Map<String, dynamic>?;
        final total = meta?['total'] as int? ?? payload['total_count'] as int?;
        return (users: users, total: total);
      },
    );

    // Stale response guard
    if (token != _currentToken) return;

    result.when(
      onSuccess: (data) {
        final fetchedUsers = data.users;
        final currentUsers = reset ? <UserResponseDto>[] : state.users;
        final updatedUsers = [...currentUsers, ...fetchedUsers];
        final totalCount = data.total ?? (reset ? fetchedUsers.length : updatedUsers.length);
        
        state = state.copyWith(
          users: updatedUsers,
          isLoading: false,
          isLoadingMore: false,
          skip: newSkip + fetchedUsers.length,
          totalCount: totalCount,
          hasMore: updatedUsers.length < totalCount && fetchedUsers.length >= state.limit,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: failure.message,
        );
      },
    );
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query.trim());
    fetchUsers(reset: true);
  }

  void setRoleFilter(String? role) {
    state = state.copyWith(selectedRole: role, clearRole: role == null);
    fetchUsers(reset: true);
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(selectedStatus: status, clearStatus: status == null);
    fetchUsers(reset: true);
  }

  void setSchoolFilter(String? schoolId) {
    state = state.copyWith(selectedSchoolId: schoolId, clearSchool: schoolId == null);
    fetchUsers(reset: true);
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      clearRole: true,
      clearStatus: true,
      clearSchool: true,
    );
    fetchUsers(reset: true);
  }
}

final usersListProvider =
    StateNotifierProvider<UsersListNotifier, UsersListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UsersListNotifier(apiClient);
});

final userDetailProvider =
    FutureProvider.family<UserResponseDto, String>((ref, id) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/identity/users/$id',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return UserResponseDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );
  return result.when(
    onSuccess: (user) => user,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

sealed class UserActionState {
  const UserActionState();
}

class UserActionIdle extends UserActionState {
  const UserActionIdle();
}

class UserActionLoading extends UserActionState {
  const UserActionLoading();
}

class UserActionSuccess extends UserActionState {
  final String message;
  const UserActionSuccess(this.message);
}

class UserActionError extends UserActionState {
  final String message;
  const UserActionError(this.message);
}

class UserActionNotifier extends StateNotifier<UserActionState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  UserActionNotifier(this._apiClient, this._ref) : super(const UserActionIdle());

  Future<void> activateUser(String userId) async {
    state = const UserActionLoading();
    final result = await _apiClient.put(
      '/identity/users/$userId/activate',
      mapper: (_) {},
    );
    result.when(
      onSuccess: (_) {
        state = const UserActionSuccess('User activated successfully.');
        _ref.invalidate(userDetailProvider(userId));
        _ref.read(usersListProvider.notifier).fetchUsers(reset: true);
      },
      onFailure: (failure) {
        state = UserActionError(failure.message);
      },
    );
  }

  Future<void> deactivateUser(String userId) async {
    state = const UserActionLoading();
    final result = await _apiClient.put(
      '/identity/users/$userId/deactivate',
      mapper: (_) {},
    );
    result.when(
      onSuccess: (_) {
        state = const UserActionSuccess('User deactivated successfully.');
        _ref.invalidate(userDetailProvider(userId));
        _ref.read(usersListProvider.notifier).fetchUsers(reset: true);
      },
      onFailure: (failure) {
        state = UserActionError(failure.message);
      },
    );
  }

  Future<void> resetPassword(String userId) async {
    state = const UserActionLoading();
    final result = await _apiClient.post(
      '/identity/users/$userId/reset-password',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>;
      },
    );
    result.when(
      onSuccess: (data) {
        final tempPassword = data['temporary_password'] as String;
        state = UserActionSuccess('Password reset successfully. Temporary password: $tempPassword');
        _ref.invalidate(userDetailProvider(userId));
        _ref.read(usersListProvider.notifier).fetchUsers(reset: true);
      },
      onFailure: (failure) {
        state = UserActionError(failure.message);
      },
    );
  }

  Future<void> unlockUser(String userId) async {
    state = const UserActionLoading();
    final result = await _apiClient.post(
      '/identity/users/$userId/unlock',
      mapper: (_) {},
    );
    result.when(
      onSuccess: (_) {
        state = const UserActionSuccess('User unlocked successfully.');
        _ref.invalidate(userDetailProvider(userId));
        _ref.read(usersListProvider.notifier).fetchUsers(reset: true);
      },
      onFailure: (failure) {
        state = UserActionError(failure.message);
      },
    );
  }
}

final userActionProvider =
    StateNotifierProvider<UserActionNotifier, UserActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserActionNotifier(apiClient, ref);
});
