import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_assets/edupulse_assets.dart';
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
  bool _navigationTriggered = false;
  bool _initializationFinished = false;
  SplashNavigationTarget? _pendingNavigationTarget;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appInitializationProvider.notifier).initializeAndCheckSession();
    });
  }

  void _checkNavigation() {
    if (_navigationTriggered) return;
    if (!_initializationFinished || _pendingNavigationTarget == null) return;

    _navigationTriggered = true;
    _navigate(_pendingNavigationTarget!);
  }

  void _navigate(SplashNavigationTarget target) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final local = EduLocalization.of(context);
    final theme = Theme.of(context);
    
    switch (target) {
      case SplashNavigationTarget.home:
        context.go(AppRoutes.home);
        break;
      case SplashNavigationTarget.login:
        context.go(AppRoutes.login);
        break;
      case SplashNavigationTarget.unauthorized:
        context.go(AppRoutes.unauthorized);
        break;
      case SplashNavigationTarget.error:
        _navigationTriggered = false;
        _initializationFinished = false;
        _pendingNavigationTarget = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              local?.translate('error_loading') ?? 'Bootstrap initialization failed.',
            ),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(
              label: local?.translate('retry') ?? 'Retry',
              textColor: Colors.white,
              onPressed: () {
                ref.read(appInitializationProvider.notifier).initializeAndCheckSession();
              },
            ),
          ),
        );
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    ref.listen<SplashNavigationTarget>(appInitializationProvider,
        (previous, next) {
      if (next != SplashNavigationTarget.loading && next != SplashNavigationTarget.initial) {
        if (mounted) {
          setState(() {
            _initializationFinished = true;
            _pendingNavigationTarget = next;
          });
          _checkNavigation();
        }
      }
    });

    final initState = ref.watch(appInitializationProvider);
    final isLoading = initState == SplashNavigationTarget.loading ||
        initState == SplashNavigationTarget.initial;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      EduPulseAssets.logo,
                      package: EduPulseAssets.package,
                      width: 220,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: spacing.xl),
                    if (isLoading)
                      CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    if (initState == SplashNavigationTarget.error)
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 36,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: spacing.lg,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${local?.translate('version') ?? 'Version'} 1.0.0 (Build 1)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black38,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
