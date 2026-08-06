import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/app_initialization_provider.dart';
import '../../../../core/router/routes.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    // Trigger asynchronous bootstrapping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appInitializationProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final gradients =
        theme.extension<AppGradients>() ?? const AppGradients.standard();

    // Listen to initialization state
    ref.listen<AsyncValue<void>>(appInitializationProvider, (previous, next) {
      next.when(
        data: (_) {
          // Initialization succeeded, route to dashboard placeholder
          context.go(AppRoutes.dashboard);
        },
        error: (error, stackTrace) {
          // If bootstrap fails, show a snackbar or error banner (handled globally or here)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${local?.translate('error_loading') ?? 'Bootstrap failed'}: $error',
              ),
              backgroundColor: theme.colorScheme.error,
              action: SnackBarAction(
                label: local?.translate('retry') ?? 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  ref.read(appInitializationProvider.notifier).initialize();
                },
              ),
            ),
          );
        },
        loading: () {},
      );
    });

    final initState = ref.watch(appInitializationProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: gradients.primary,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // EduPulse Logo Text
                      Text(
                        local?.translate('app_title') ?? 'EduPulse AI',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        local?.translate('splash_tagline') ??
                            'Pulse of Education',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: spacing.xl),
                      // Initialization spinner / progress
                      initState.maybeWhen(
                        loading: () => const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                        error: (_, __) => Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 36,
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              // App version / Build number at footer
              Positioned(
                bottom: spacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${local?.translate('version') ?? 'Version'} 1.0.0 (Build 1)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
