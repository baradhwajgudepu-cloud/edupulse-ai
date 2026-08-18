import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/router/routes.dart';

class UnauthorizedScreen extends ConsumerWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is Unauthenticated) {
        context.go(AppRoutes.login);
      }
    });

    final authState = ref.watch(authStateProvider);
    String errorMessage = 'Access denied. Insufficient role permissions. You are not registered as a teacher.';
    if (authState is Unauthorized) {
      errorMessage = authState.message;
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius.lg),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gpp_bad_rounded,
                      size: 72,
                      color: theme.colorScheme.error,
                    ),
                    SizedBox(height: spacing.lg),
                    Text(
                      'Access Denied',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      errorMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.xl),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(local?.translate('logout') ?? 'Logout'),
                      onPressed: () {
                        ref.read(authStateProvider.notifier).clearSessionLocally();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.lg,
                          vertical: spacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.md),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
