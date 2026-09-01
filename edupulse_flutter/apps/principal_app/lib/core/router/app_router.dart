import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import 'app_shell.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/forgot_password_screen.dart';
import '../../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../../features/fees/presentation/pages/fees_screen.dart';
import '../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/students/presentation/pages/student_list_screen.dart';
import '../../features/students/presentation/pages/student_detail_screen.dart';
import '../../features/teachers/presentation/pages/teacher_list_screen.dart';
import '../../features/teachers/presentation/pages/teacher_detail_screen.dart';
import '../../features/analytics/presentation/pages/analytics_dashboard_screen.dart';
import '../../features/report_cards/presentation/pages/report_card_management_screen.dart';
import '../../features/staff_attendance/presentation/pages/teacher_attendance_screen.dart';
import '../../features/staff_attendance/presentation/pages/teacher_attendance_detail_screen.dart';
import '../../features/staff_attendance/presentation/pages/teacher_attendance_history_screen.dart';
import '../../features/staff_attendance/presentation/pages/geofence_configuration_screen.dart';
import '../../features/leave_requests/presentation/pages/teacher_leave_requests_screen.dart';
import '../../features/leave_requests/presentation/pages/teacher_leave_detail_screen.dart';
import '../../features/leave_requests/presentation/pages/teacher_leave_history_screen.dart';
import '../../features/communication/presentation/pages/queries_inbox_screen.dart';
import '../../features/communication/presentation/pages/conversation_screen.dart';
import '../../features/planner/presentation/pages/school_planner_screen.dart';
import '../../features/academics/presentation/pages/manage_exams_screen.dart';
import '../../features/fees/presentation/pages/outstanding_dues_detail_screen.dart';

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
            path: AppRoutes.fees,
            builder: (context, state) => const FeesScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.students,
            builder: (context, state) => const StudentListScreen(),
          ),
          GoRoute(
            path: AppRoutes.studentDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StudentDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: AppRoutes.teachers,
            builder: (context, state) => const TeacherListScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TeacherDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (context, state) => const AnalyticsDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.reportCards,
            builder: (context, state) => const ReportCardManagementScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherAttendance,
            builder: (context, state) => const TeacherAttendanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherAttendanceDetail,
            builder: (context, state) {
              final id = state.pathParameters['teacherId']!;
              return TeacherAttendanceDetailScreen(teacherId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.teacherAttendanceHistory,
            builder: (context, state) {
              final id = state.pathParameters['teacherId']!;
              return TeacherAttendanceHistoryScreen(teacherId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.geofence,
            builder: (context, state) => const GeofenceConfigurationScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherLeaves,
            builder: (context, state) => const TeacherLeaveRequestsScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherLeaveDetail,
            builder: (context, state) {
              final id = state.pathParameters['leaveId']!;
              return TeacherLeaveDetailScreen(leaveId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.teacherLeaveHistory,
            builder: (context, state) {
              final id = state.pathParameters['teacherId']!;
              return TeacherLeaveHistoryScreen(teacherId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.communication,
            builder: (context, state) {
              final studentId = state.uri.queryParameters['studentId'];
              return QueriesInboxScreen(studentId: studentId);
            },
          ),
          GoRoute(
            path: AppRoutes.communicationDetails,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PrincipalConversationScreen(requestId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.planner,
            builder: (context, state) => const SchoolPlannerScreen(),
          ),
          GoRoute(
            path: AppRoutes.manageExams,
            builder: (context, state) => const ManageExamsScreen(),
          ),
          GoRoute(
            path: AppRoutes.outstandingDetails,
            builder: (context, state) {
              final classId = state.uri.queryParameters['classId'];
              final className = state.uri.queryParameters['className'] ?? 'Class';
              return OutstandingDuesDetailScreen(classId: classId, className: className);
            },
          ),
        ],
      ),
    ],
  );
});
