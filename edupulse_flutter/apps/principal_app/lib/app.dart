import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'package:edupulse_network/edupulse_network.dart';

class EduPulseApp extends ConsumerWidget {
  const EduPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Watch for JWT expiration triggers to automatically drop session context
    ref.listen<bool>(sessionExpiredProvider, (previous, expired) {
      if (expired) {
        ref.read(authStateProvider.notifier).logout();
        router.go(AppRoutes.login);
        ref.read(sessionExpiredProvider.notifier).state = false;
      }
    });

    return MaterialApp.router(
      title: 'EduPulse AI Principal',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: EduPulseTheme.lightTheme,
      darkTheme: EduPulseTheme.darkTheme,
      themeMode: ThemeMode.system,
      supportedLocales: const [
        Locale('en', ''),
        Locale('te', ''),
      ],
      localizationsDelegates: const [
        EduLocalization.delegate,
      ],
    );
  }
}
