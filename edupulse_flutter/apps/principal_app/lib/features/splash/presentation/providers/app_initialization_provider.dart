import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../../../core/providers/bootstrap_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

enum SplashNavigationTarget {
  initial,
  loading,
  login,
  dashboard,
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

    // Minimum delay for smooth logo animation transition
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final sessionManager = ref.read(sessionManagerProvider);
    final hasSession = await sessionManager.hasSession();

    if (!hasSession) {
      state = SplashNavigationTarget.login;
      return;
    }

    final validateSession = ref.read(validateSessionUseCaseProvider);
    final result = await validateSession();

    await result.when(
      onSuccess: (user) async {
        ref.read(authStateProvider.notifier).setAuthenticated(user);
        state = SplashNavigationTarget.dashboard;
      },
      onFailure: (failure) async {
        EduLogger.w(
            'Saved authentication session token has expired: ${failure.message}');
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
