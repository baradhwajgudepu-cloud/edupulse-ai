import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_config/edupulse_config.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'app.dart';
import 'core/observers/provider_observer.dart';
import 'core/providers/bootstrap_provider.dart';

void main() {
  // 1. Intercept Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    EduLogger.e(
      'Captured Flutter framework error: ${details.exception}',
      details.exception,
      details.stack,
    );
  };

  // 2. Intercept Platform/Asynchronous errors
  PlatformDispatcher.instance.onError = (error, stack) {
    EduLogger.e('Captured platform/asynchronous error: $error', error, stack);
    return true;
  };

  // 3. Catch all asynchronous errors in zoned execution
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Resolve API Base URL and load build configuration
    final resolvedUrl = await BuildConfig.resolveApiBaseUrl();
    final buildConfig = BuildConfig.fromEnvironment(resolvedApiBaseUrl: resolvedUrl);
    buildConfig.printDiagnostics();

    // Call bootstrap service to load databases, SharedPreferences, and configs
    final bootstrapResult = await BootstrapService.initialize();

    runApp(
      ProviderScope(
        observers: [AppProviderObserver()],
        overrides: [
          bootstrapResultProvider.overrideWithValue(bootstrapResult),
          buildConfigProvider.overrideWithValue(buildConfig),
          // Connect the concrete SessionManager token delegate to the networking layer
          authTokenProvider.overrideWith((ref) {
            final sessionManager = ref.watch(sessionManagerProvider);
            final refreshDio = ref.watch(refreshDioProvider);
            return TokenProviderImpl(
              sessionManager,
              (refreshToken) async {
                final response = await refreshDio.post(
                  '/auth/refresh',
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
        child: const EduPulseApp(),
      ),
    );
  }, (error, stackTrace) {
    EduLogger.e(
      'Captured uncaught async error in zone: $error',
      error,
      stackTrace,
    );
  });
}
