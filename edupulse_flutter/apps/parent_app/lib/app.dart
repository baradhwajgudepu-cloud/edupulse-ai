import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'core/router/app_router.dart';

class EduPulseApp extends ConsumerWidget {
  const EduPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'EduPulse AI',
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
