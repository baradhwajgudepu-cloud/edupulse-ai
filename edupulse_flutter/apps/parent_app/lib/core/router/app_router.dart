import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import 'app_shell.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/forgot_password_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
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
        ],
      ),
    ],
  );
});
