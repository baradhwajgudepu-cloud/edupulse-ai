import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/homework_provider.dart';
import '../widgets/homework_list.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomework();
    });
  }

  void _loadHomework({bool isRefresh = false}) {
    final authState = ref.read(authStateProvider);
    if (authState is Authenticated) {
      final schoolId = authState.user.schools.firstOrNull ?? '16730f87-bf8d-44e0-acf9-4b055a778b58';
      ref.read(homeworkStateProvider.notifier).fetchHomework(
            schoolId: schoolId,
            isRefresh: isRefresh,
          );
    }
  }

  Future<void> _onRefresh() async {
    _loadHomework(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    ref.listen<HomeworkState>(homeworkStateProvider, (previous, next) {
      if (next is HomeworkSuccess && next.isFromCache) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              local?.translate('offline_cache_warning') ??
                  'Offline: Showing cached data',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final state = ref.watch(homeworkStateProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.dashboard),
              ),
        title: Text(local?.translate('homework') ?? 'Homework'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(context, state, theme, spacing, radius, local),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeworkState state,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    return switch (state) {
      HomeworkInitial() => const Center(child: CircularProgressIndicator()),
      HomeworkLoading() => const Center(child: CircularProgressIndicator()),
      HomeworkError(:final message) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.lg),
          child: Center(
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    SizedBox(height: spacing.md),
                    Text(
                      local?.translate('homework_error') ??
                          'Failed to load homework',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.lg),
                    ElevatedButton.icon(
                      onPressed: () => _loadHomework(),
                      icon: const Icon(Icons.refresh),
                      label: Text(local?.translate('retry') ?? 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      HomeworkEmpty() => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.lg),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: spacing.md),
                Text(
                  local?.translate('no_homework') ?? 'No homework assigned',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      HomeworkSuccess(:final homeworks) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.md),
          child: HomeworkList(homeworks: homeworks),
        ),
    };
  }
}
