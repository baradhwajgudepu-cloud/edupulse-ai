import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import 'app_shell.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/forgot_password_screen.dart';
import '../../features/auth/presentation/pages/reset_password_screen.dart';
import '../../features/auth/presentation/pages/force_change_password_screen.dart';
import '../../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../../features/attendance/presentation/pages/attendance_screen.dart';
import '../../features/homework/presentation/pages/homework_screen.dart';
import '../../features/fees/presentation/pages/fees_screen.dart';
import '../../features/report_cards/presentation/pages/report_cards_screen.dart';
import '../../features/exams/presentation/pages/exams_screen.dart';
import '../../features/announcements/presentation/pages/announcements_screen.dart';
import '../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../features/communication/presentation/pages/queries_list_screen.dart';
import '../../features/communication/presentation/pages/create_query_screen.dart';
import '../../features/communication/presentation/pages/conversation_screen.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/academics/presentation/pages/child_syllabus_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final goingToSplash = state.matchedLocation == AppRoutes.splash;
      final goingToLogin = state.matchedLocation == AppRoutes.login;
      final goingToForgot = state.matchedLocation == AppRoutes.forgotPassword;
      final goingToReset = state.matchedLocation == AppRoutes.resetPassword;
      final goingToForceChange = state.matchedLocation == AppRoutes.forceChangePassword;

      if (authState is AuthInitial) {
        return null;
      }

      if (authState is Unauthenticated || authState is AuthError) {
        if (goingToLogin || goingToForgot || goingToReset) return null;
        return AppRoutes.login;
      }

      if (authState is Authenticated) {
        if (authState.user.mustChangePassword) {
          if (!goingToForceChange) return AppRoutes.forceChangePassword;
          return null;
        }
        if (goingToLogin || goingToSplash || goingToForceChange) {
          return AppRoutes.dashboard;
        }
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? (state.extra as String?);
          return ResetPasswordScreen(initialToken: token);
        },
      ),
      GoRoute(
        path: AppRoutes.forceChangePassword,
        builder: (context, state) => const ForceChangePasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.attendance,
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.homework,
            builder: (context, state) => const HomeworkScreen(),
          ),
          GoRoute(
            path: AppRoutes.payFees,
            builder: (context, state) => const FeesScreen(),
          ),
          GoRoute(
            path: AppRoutes.reportCards,
            builder: (context, state) => const ReportCardsScreen(),
          ),
          GoRoute(
            path: AppRoutes.exams,
            builder: (context, state) => const ExamsScreen(),
          ),
          GoRoute(
            path: AppRoutes.announcements,
            builder: (context, state) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.communication,
            builder: (context, state) => const QueriesListScreen(),
          ),
          GoRoute(
            path: AppRoutes.createCommunication,
            builder: (context, state) => const CreateQueryScreen(),
          ),
          GoRoute(
            path: AppRoutes.communicationDetails,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ConversationScreen(requestId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.childSyllabus,
            builder: (context, state) {
              final studentId = state.uri.queryParameters['studentId'];
              final schoolId = state.uri.queryParameters['schoolId'];
              final academicYearId = state.uri.queryParameters['academicYearId'];
              return ChildSyllabusScreen(
                studentId: studentId,
                schoolId: schoolId,
                academicYearId: academicYearId,
              );
            },
          ),
        ],
      ),
    ],
  );
});
