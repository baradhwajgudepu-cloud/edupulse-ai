import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/forgot_password_screen.dart';
import '../../features/shell/presentation/pages/home_screen.dart';
import '../../features/shell/presentation/pages/unauthorized_screen.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/my_classes/presentation/pages/my_classes_screen.dart';
import '../../features/my_classes/presentation/pages/class_detail_screen.dart';
import '../../features/my_classes/presentation/pages/student_roster_screen.dart';
import '../../features/my_classes/presentation/pages/student_detail_screen.dart';
import '../../features/my_classes/domain/entities/teacher_class_group.dart';
import '../../features/my_classes/domain/entities/student.dart';
import '../../features/attendance/presentation/pages/attendance_marking_screen.dart';
import '../../features/homework/presentation/pages/homework_list_screen.dart';
import '../../features/homework/presentation/pages/homework_detail_screen.dart';
import '../../features/homework/presentation/pages/homework_form_screen.dart';
import '../../features/homework/presentation/pages/homework_copy_screen.dart';
import '../../features/marks/presentation/pages/marks_select_screen.dart';
import '../../features/marks/presentation/pages/marks_board_screen.dart';
import '../../features/marks/presentation/pages/marks_review_screen.dart';
import '../../features/results/presentation/pages/results_screen.dart';
import '../../features/results/presentation/pages/student_result_screen.dart';
import '../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../features/staff_attendance/presentation/pages/staff_attendance_screen.dart';
import '../../features/teacher_leave/presentation/pages/teacher_leave_screen.dart';
import '../../features/teacher_leave/presentation/pages/teacher_leave_form_screen.dart';
import '../../features/teacher_leave/presentation/pages/teacher_leave_detail_screen.dart';
import '../../features/communication/presentation/pages/queries_inbox_screen.dart';
import '../../features/communication/presentation/pages/conversation_screen.dart';
import '../../features/teacher_ai/presentation/pages/class_analysis_screen.dart';
import '../../features/teacher_ai/presentation/pages/homework_generate_screen.dart';
import '../../features/events/presentation/pages/events_screen.dart';
import '../../features/events/presentation/pages/event_detail_screen.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/student_directory/presentation/pages/student_directory_screen.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final goingToSplash = state.matchedLocation == AppRoutes.splash;
      final goingToLogin = state.matchedLocation == AppRoutes.login;
      final goingToForgot = state.matchedLocation == AppRoutes.forgotPassword;
      final goingToUnauthorized = state.matchedLocation == AppRoutes.unauthorized;

      if (authState is AuthInitial) {
        return null;
      }

      if (authState is Unauthenticated || authState is AuthError) {
        if (goingToLogin || goingToForgot) return null;
        return AppRoutes.login;
      }

      if (authState is Unauthorized) {
        if (goingToUnauthorized) return null;
        return AppRoutes.unauthorized;
      }

      if (authState is Authenticated) {
        if (goingToLogin || goingToSplash || goingToUnauthorized) {
          return AppRoutes.home;
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
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.unauthorized,
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      GoRoute(
        path: AppRoutes.myClasses,
        builder: (context, state) => const MyClassesScreen(),
      ),
      GoRoute(
        path: AppRoutes.classDetail,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final classId = queryParams['classId'] ?? '';
          final sectionId = queryParams['sectionId'] ?? '';
          final className = queryParams['className'] ?? '';
          final sectionName = queryParams['sectionName'] ?? '';
          final group = state.extra as TeacherClassGroupEntity?;
          return ClassDetailScreen(
            classId: classId,
            sectionId: sectionId,
            className: className,
            sectionName: sectionName,
            group: group,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.studentRoster,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final classId = queryParams['classId'] ?? '';
          final sectionId = queryParams['sectionId'] ?? '';
          final className = queryParams['className'] ?? '';
          final sectionName = queryParams['sectionName'] ?? '';
          return StudentRosterScreen(
            classId: classId,
            sectionId: sectionId,
            className: className,
            sectionName: sectionName,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.studentDetail,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final studentId = queryParams['studentId'] ?? '';
          final student = state.extra as StudentEntity?;
          return StudentDetailScreen(
            studentId: studentId,
            student: student,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.attendance,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final timetableId = queryParams['timetableId'] ?? '';
          final dateStr = queryParams['date'] ?? '';
          return AttendanceMarkingScreen(
            timetableId: timetableId,
            dateStr: dateStr,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.homework,
        builder: (context, state) => const HomeworkListScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeworkCreate,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final timetableId = queryParams['timetableId'];
          final tsaId = queryParams['tsaId'];
          final subjectId = queryParams['subjectId'];
          final classId = queryParams['classId'];
          final sectionId = queryParams['sectionId'];
          final initialTitle = queryParams['initialTitle'];
          final initialDescription = queryParams['initialDescription'];
          final initialEstimatedMinutes = queryParams['initialEstimatedMinutes'] != null
              ? int.tryParse(queryParams['initialEstimatedMinutes']!)
              : null;
          return HomeworkFormScreen(
            timetableId: timetableId,
            teacherSubjectAssignmentId: tsaId,
            subjectId: subjectId,
            classId: classId,
            sectionId: sectionId,
            initialTitle: initialTitle,
            initialDescription: initialDescription,
            initialEstimatedMinutes: initialEstimatedMinutes,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.homeworkDetail,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final id = queryParams['id'] ?? '';
          return HomeworkDetailScreen(homeworkId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.homeworkEdit,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final id = queryParams['id'] ?? '';
          return HomeworkFormScreen(homeworkId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.homeworkCopy,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final id = queryParams['id'] ?? '';
          return HomeworkCopyScreen(homeworkId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.marks,
        builder: (context, state) => const MarksSelectScreen(),
      ),
      GoRoute(
        path: AppRoutes.marksEntry,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final examScheduleId = queryParams['examScheduleId'] ?? '';
          final examName = queryParams['examName'] ?? '';
          final subjectName = queryParams['subjectName'] ?? '';
          final className = queryParams['className'] ?? '';
          final maxMarks = int.tryParse(queryParams['maxMarks'] ?? '100') ?? 100;
          final passMarks = int.tryParse(queryParams['passMarks'] ?? '35') ?? 35;
          final teacherSubjectAssignmentId = queryParams['teacherSubjectAssignmentId'] ?? '';
          return MarksBoardScreen(
            examScheduleId: examScheduleId,
            examName: examName,
            subjectName: subjectName,
            className: className,
            maxMarks: maxMarks,
            passMarks: passMarks,
            teacherSubjectAssignmentId: teacherSubjectAssignmentId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.marksReview,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final examScheduleId = queryParams['examScheduleId'] ?? '';
          final examName = queryParams['examName'] ?? '';
          final subjectName = queryParams['subjectName'] ?? '';
          final className = queryParams['className'] ?? '';
          final maxMarks = int.tryParse(queryParams['maxMarks'] ?? '100') ?? 100;
          final passMarks = int.tryParse(queryParams['passMarks'] ?? '35') ?? 35;
          final teacherSubjectAssignmentId = queryParams['teacherSubjectAssignmentId'] ?? '';
          return MarksReviewScreen(
            examScheduleId: examScheduleId,
            examName: examName,
            subjectName: subjectName,
            className: className,
            maxMarks: maxMarks,
            passMarks: passMarks,
            teacherSubjectAssignmentId: teacherSubjectAssignmentId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentResult,
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          final studentId = queryParams['studentId'] ?? '';
          final classId = queryParams['classId'] ?? '';
          final sectionId = queryParams['sectionId'] ?? '';
          return StudentResultScreen(
            studentId: studentId,
            classId: classId,
            sectionId: sectionId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffAttendance,
        builder: (context, state) => const StaffAttendanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherLeaveList,
        builder: (context, state) => const TeacherLeaveScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherLeaveCreate,
        builder: (context, state) => const TeacherLeaveFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherLeaveDetail,
        builder: (context, state) {
          final leaveId = state.pathParameters['id'] ?? '';
          return TeacherLeaveDetailScreen(leaveId: leaveId);
        },
      ),
      GoRoute(
        path: AppRoutes.communication,
        builder: (context, state) => const QueriesInboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.communicationDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TeacherConversationScreen(requestId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.classAnalysis,
        builder: (context, state) => const ClassAnalysisScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeworkGenerate,
        builder: (context, state) => const HomeworkGenerateScreen(),
      ),
      GoRoute(
        path: AppRoutes.events,
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return EventDetailScreen(eventId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentDirectory,
        builder: (context, state) => const StudentDirectoryScreen(),
      ),
    ],
  );
});
