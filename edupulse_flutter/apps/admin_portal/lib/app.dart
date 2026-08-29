import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'core/routing/app_router.dart';
import 'core/routing/routes.dart';

class EduPulseAdminApp extends ConsumerWidget {
  const EduPulseAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen<bool>(sessionExpiredProvider, (previous, expired) {
      if (expired) {
        ref.read(authStateProvider.notifier).logout();
        router.go(AppRoutes.login);
        ref.read(sessionExpiredProvider.notifier).state = false;
      }
    });

    return MaterialApp.router(
      title: 'EduPulse Admin Portal',
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
