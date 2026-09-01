import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';

class UsersListState {
  final List<UserResponseDto> users;
  final bool isLoading;
  final String? error;
  final int skip;
  final int limit;
  final bool hasMore;

  const UsersListState({
    required this.users,
    required this.isLoading,
    this.error,
    required this.skip,
    required this.limit,
    required this.hasMore,
  });

  UsersListState copyWith({
    List<UserResponseDto>? users,
    bool? isLoading,
    String? error,
    int? skip,
    int? limit,
    bool? hasMore,
  }) {
    return UsersListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class UsersListNotifier extends StateNotifier<UsersListState> {
  final BaseApiClient _apiClient;

  UsersListNotifier(this._apiClient)
      : super(const UsersListState(
          users: [],
          isLoading: false,
          skip: 0,
          limit: 20,
          hasMore: true,
        ));

  Future<void> fetchUsers({bool reset = false}) async {
    if (state.isLoading) return;

    final newSkip = reset ? 0 : state.skip;
    state = state.copyWith(isLoading: true, error: null);

    final result = await _apiClient.get(
      '/identity/users?skip=$newSkip&limit=${state.limit}',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => UserResponseDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    result.when(
      onSuccess: (fetchedUsers) {
        final currentUsers = reset ? <UserResponseDto>[] : state.users;
        final updatedUsers = [...currentUsers, ...fetchedUsers];
        state = state.copyWith(
          users: updatedUsers,
          isLoading: false,
          skip: newSkip + fetchedUsers.length,
          hasMore: fetchedUsers.length >= state.limit,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
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
