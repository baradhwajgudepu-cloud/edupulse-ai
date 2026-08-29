import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_config/edupulse_config.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/observers/provider_observer.dart';
import 'core/providers/bootstrap_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/school_setup/presentation/providers/school_setup_providers.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    EduLogger.e(
      'Captured Flutter framework error: ${details.exception}',
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    EduLogger.e('Captured platform/asynchronous error: $error', error, stack);
    return true;
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      EduLogger.i('Firebase initialized successfully.');
    } catch (e) {
      EduLogger.e('Failed to initialize Firebase: $e', e);
    }

    final resolvedUrl = await BuildConfig.resolveApiBaseUrl();
    final buildConfig = BuildConfig.fromEnvironment(resolvedApiBaseUrl: resolvedUrl);
    buildConfig.printDiagnostics();

    final bootstrapResult = await BootstrapService.initialize();

    final container = ProviderContainer(
      observers: [AppProviderObserver()],
      overrides: [
        bootstrapResultProvider.overrideWithValue(bootstrapResult),
        buildConfigProvider.overrideWithValue(buildConfig),
        activeTenantIdProvider.overrideWith((ref) {
          // 1. Check if a school is selected
          final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
          if (selectedSchoolId != null) {
            final schoolsState = ref.watch(schoolsListProvider);
            final match = schoolsState.schools.where((s) => s.id == selectedSchoolId);
            if (match.isNotEmpty) {
              return match.first.tenantId;
            }
          }
          
          // 2. If no school is selected, fall back to selectedTenantIdProvider
          final selectedTenantId = ref.watch(selectedTenantIdProvider);
          if (selectedTenantId != null && selectedTenantId.isNotEmpty) {
            return selectedTenantId;
          }
          
          // 3. Fallback to build config tenant ID
          final config = ref.watch(buildConfigProvider);
          return config.tenantId;
        }),
        authTokenProvider.overrideWith((ref) {
          final sessionManager = ref.watch(sessionManagerProvider);
          final refreshDio = ref.watch(refreshDioProvider);
          return TokenProviderImpl(
            sessionManager,
            (refreshToken) async {
              final response = await refreshDio.post(
                'auth/refresh',
                data: {
                  'refresh_token': refreshToken,
                },
              );

              final payload = response.data as Map<String, dynamic>;
              final data = payload['data'] as Map<String, dynamic>;
              return SessionToken(
                accessToken: data['access_token'] as String,
                refreshToken: data['refresh_token'] as String,
                tokenType: data['token_type'] as String,
              );
            },
          );
        }),
      ],
    );

    // Trigger initial auth check
    await container.read(authStateProvider.notifier).checkAuth();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const EduPulseAdminApp(),
      ),
    );

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          js.context.callMethod('removeEduPulseSplash');
        } catch (e) {
          debugPrint('Error calling removeEduPulseSplash: $e');
        }
      });
    }
  }, (error, stackTrace) {
    EduLogger.e(
      'Captured uncaught async error in zone: $error',
      error,
      stackTrace,
    );
  });
}
