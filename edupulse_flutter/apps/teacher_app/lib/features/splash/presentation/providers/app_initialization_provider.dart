import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../../core/providers/bootstrap_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

enum SplashNavigationTarget {
  initial,
  loading,
  login,
  home,
  unauthorized,
  error,
}

class AppInitializationNotifier
    extends AutoDisposeNotifier<SplashNavigationTarget> {
  @override
  SplashNavigationTarget build() {
    return SplashNavigationTarget.initial;
  }

  Future<void> initializeAndCheckSession() async {
    state = SplashNavigationTarget.loading;

    final bootResult = ref.read(bootstrapResultProvider);
    if (!bootResult.success) {
      state = SplashNavigationTarget.error;
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    final sessionManager = ref.read(sessionManagerProvider);
    final hasSession = await sessionManager.hasSession();

    if (!hasSession) {
      state = SplashNavigationTarget.login;
      return;
    }

    final validateSession = ref.read(validateSessionUseCaseProvider);
    
    ApiResult<UserEntity> result;
    try {
      result = await validateSession().timeout(
        const Duration(seconds: 3),
        onTimeout: () => const ApiResult.failure(
          ApiFailure(
            message: 'Session validation timed out.',
            type: ApiFailureType.network,
            statusCode: 408,
          ),
        ),
      );
    } catch (e) {
      result = ApiResult.failure(
        ApiFailure(
          message: 'Session validation failed: ${e.toString()}',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }

    await result.when(
      onSuccess: (user) async {
        final isTeacher = user.isSuperuser || 
            user.roles.map((r) => r.toUpperCase()).contains('TEACHER');

        if (!isTeacher) {
          EduLogger.w('User is not a teacher during startup session check. Roles: ${user.roles}');
          ref.read(authStateProvider.notifier).setUnauthorized('Access denied. Insufficient role permissions. You are not registered as a teacher.');
          state = SplashNavigationTarget.unauthorized;
          return;
        }

        ref.read(authStateProvider.notifier).setAuthenticated(user);
        state = SplashNavigationTarget.home;
      },
      onFailure: (failure) async {
        EduLogger.w(
            'Saved authentication session token has expired or validation failed: ${failure.message}');
        await sessionManager.clearSession();
        state = SplashNavigationTarget.login;
      },
    );
  }
}

final appInitializationProvider = NotifierProvider.autoDispose<
    AppInitializationNotifier, SplashNavigationTarget>(
  AppInitializationNotifier.new,
);
