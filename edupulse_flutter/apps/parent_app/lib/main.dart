import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
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

    // Call bootstrap service to load databases, SharedPreferences, and configs
    final bootstrapResult = await BootstrapService.initialize();

    runApp(
      ProviderScope(
        observers: [AppProviderObserver()],
        overrides: [
          bootstrapResultProvider.overrideWithValue(bootstrapResult),
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
