import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/forgot_password_screen.dart';
import '../../features/auth/presentation/pages/reset_password_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/shell/presentation/admin_shell.dart';
import '../../features/users/presentation/pages/users_screen.dart';
import '../../features/users/presentation/pages/user_details_screen.dart';
import '../../features/school_setup/presentation/pages/schools_screen.dart';
import '../../features/school_setup/presentation/pages/school_details_screen.dart';
import '../../features/school_setup/presentation/pages/academic_years_screen.dart';
import '../../features/school_setup/presentation/pages/academic_year_details_screen.dart';
import '../../features/school_setup/presentation/pages/classes_screen.dart';
import '../../features/school_setup/presentation/pages/class_details_screen.dart';
import '../../features/school_setup/presentation/pages/sections_screen.dart';
import '../../features/school_setup/presentation/pages/section_details_screen.dart';
import '../../features/school_setup/presentation/pages/subjects_screen.dart';
import '../../features/school_setup/presentation/pages/subject_details_screen.dart';
import '../../features/students/presentation/pages/students_screen.dart';
import '../../features/students/presentation/pages/student_details_screen.dart';
import '../../features/bulk_import/presentation/pages/bulk_import_screen.dart';
import '../../features/bulk_import/presentation/pages/school_onboarding_screen.dart';
import '../../features/fees/presentation/pages/fees_dashboard_screen.dart';
import '../../features/fees/presentation/pages/student_fee_assignment_page.dart';
import '../../features/fees/presentation/pages/student_ledgers_page.dart';
import '../../features/fees/presentation/pages/outstanding_dues_page.dart';
import '../../features/students/data/models/student_models.dart';
import '../../features/migrations/presentation/pages/migration_center_screen.dart';
import '../../features/migrations/presentation/pages/student_migration_wizard_screen.dart';
import '../../features/migrations/presentation/pages/academic_setup_migration_wizard_screen.dart';
import '../../features/migrations/presentation/pages/guardian_mapping_migration_wizard_screen.dart';
import '../../features/migrations/presentation/pages/guardian_migration_wizard_screen.dart';
import '../../features/results/presentation/pages/results_dashboard_screen.dart';
import '../../features/results/presentation/pages/exam_types_screen.dart';
import '../../features/results/presentation/pages/examinations_setup_screen.dart';
import '../../features/results/presentation/pages/admin_marks_management_screen.dart';
import '../../features/results/presentation/pages/student_result_detail_screen.dart';
import '../../features/results/presentation/pages/report_card_management_screen.dart';
import '../../features/teachers/presentation/pages/teachers_screen.dart';
import '../../features/teachers/presentation/pages/teacher_details_screen.dart';
import '../../features/attendance/presentation/pages/attendance_screen.dart';
import '../../features/attendance/presentation/pages/attendance_session_details_screen.dart';

// School Planner imports
import '../../features/planner/presentation/pages/planner_calendar_screen.dart';
import '../../features/planner/presentation/pages/planner_events_screen.dart';
import '../../features/planner/presentation/pages/planner_announcements_screen.dart';
import '../../features/planner/presentation/pages/planner_circulars_screen.dart';
import '../../features/planner/presentation/pages/planner_exams_screen.dart';
import '../../features/planner/presentation/pages/planner_schedule_screen.dart';
import '../../features/guardians/presentation/pages/guardians_screen.dart';
import '../../features/guardians/presentation/pages/guardian_details_screen.dart';
import '../../features/promotions/presentation/pages/promotions_screen.dart';
import '../../features/tenant_setup/presentation/pages/tenants_screen.dart';
import '../../features/reports/presentation/pages/reports_dashboard_screen.dart';
import '../../features/communication_analytics/presentation/pages/communication_analytics_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../features/ai_intelligence/presentation/pages/ai_intelligence_dashboard_screen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isPublicAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.forgotPassword ||
          loc == AppRoutes.resetPassword;

      if (authState is AuthInitial) {
        return null;
      }

      final isLoggedIn = authState is Authenticated;

      if (!isLoggedIn) {
        if (!isPublicAuthRoute) {
          return AppRoutes.login;
        }
      } else {
        if (isPublicAuthRoute || loc == '/') {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
    routes: [
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
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(initialToken: token);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),

        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.tenants,
            builder: (context, state) => const TenantsScreen(),
          ),
          GoRoute(
            path: AppRoutes.users,
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: AppRoutes.userDetail,
            builder: (context, state) => UserDetailsScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.schools,
            builder: (context, state) => const SchoolsScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolDetail,
            builder: (context, state) => SchoolDetailsScreen(
              schoolId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.academicYears,
            builder: (context, state) => const AcademicYearsScreen(),
          ),
          GoRoute(
            path: AppRoutes.academicYearDetail,
            builder: (context, state) => AcademicYearDetailsScreen(
              schoolId: state.pathParameters['schoolId']!,
              ayId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.classes,
            builder: (context, state) {
              return const ClassesScreen();
            },
          ),
          GoRoute(
            path: AppRoutes.classDetail,
            builder: (context, state) {
              final schoolId = state.uri.queryParameters['school_id'] ?? '';
              return ClassDetailsScreen(
                schoolId: schoolId,
                classId: state.pathParameters['id']!,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.sections,
            builder: (context, state) => const SectionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.sectionDetail,
            builder: (context, state) {
              final schoolId = state.uri.queryParameters['school_id'] ?? '';
              return SectionDetailsScreen(
                schoolId: schoolId,
                sectionId: state.pathParameters['id']!,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.subjects,
            builder: (context, state) => const SubjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.subjectDetail,
            builder: (context, state) {
              final schoolId = state.uri.queryParameters['school_id'] ?? '';
              return SubjectDetailsScreen(
                schoolId: schoolId,
                subjectId: state.pathParameters['id']!,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.students,
            builder: (context, state) => const StudentsScreen(),
          ),
          GoRoute(
            path: AppRoutes.studentDetail,
            builder: (context, state) {
              final schoolId = state.uri.queryParameters['school_id'] ?? '';
              return StudentDetailsScreen(
                schoolId: schoolId,
                studentId: state.pathParameters['id']!,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.teachers,
            builder: (context, state) => const TeachersScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherDetail,
            builder: (context, state) => TeacherDetailsScreen(
              teacherId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.attendance,
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.attendanceSessionDetail,
            builder: (context, state) => AttendanceSessionDetailsScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.guardians,
            builder: (context, state) => const GuardiansScreen(),
          ),
          GoRoute(
            path: AppRoutes.guardianDetail,
            builder: (context, state) => GuardianDetailsScreen(
              guardianId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.promotions,
            builder: (context, state) => const PromotionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.bulkImport,
            builder: (context, state) => const BulkImportScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolOnboarding,
            builder: (context, state) => const SchoolOnboardingScreen(),
          ),
          GoRoute(
            path: AppRoutes.fees,
            builder: (context, state) => const FeesDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.feesAssign,
            builder: (context, state) => const StudentFeeAssignmentPage(),
          ),
          GoRoute(
            path: AppRoutes.feesLedger,
            builder: (context, state) {
              final student = state.extra as StudentDto?;
              return StudentLedgersPage(initialStudent: student);
            },
          ),
          GoRoute(
            path: AppRoutes.feesOutstanding,
            builder: (context, state) {
              final classId = state.uri.queryParameters['class_id'];
              final onlyDefaulters = state.uri.queryParameters['only_defaulters'] == 'true';
              return OutstandingDuesPage(
                classId: classId,
                onlyDefaulters: onlyDefaulters,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.results,
            builder: (context, state) => const ResultsDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.examTypes,
            builder: (context, state) => const ExamTypesScreen(),
          ),
          GoRoute(
            path: AppRoutes.examinations,
            builder: (context, state) => const ExaminationsSetupScreen(),
          ),
          GoRoute(
            path: AppRoutes.marksManagement,
            builder: (context, state) {
              final examId = state.uri.queryParameters['exam_id'];
              final classId = state.uri.queryParameters['class_id'];
              final sectionId = state.uri.queryParameters['section_id'];
              final ayId = state.uri.queryParameters['ay_id'];
              return AdminMarksManagementScreen(
                initialExamId: examId,
                initialClassId: classId,
                initialSectionId: sectionId,
                initialAcademicYearId: ayId,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.studentResultDetail,
            builder: (context, state) => StudentResultDetailScreen(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.reportCards,
            builder: (context, state) => const ReportCardManagementScreen(),
          ),
          GoRoute(
            path: AppRoutes.reportCardDetail,
            builder: (context, state) => StudentResultDetailScreen(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.migrations,
            builder: (context, state) => const MigrationCenterScreen(),
          ),
          GoRoute(
            path: AppRoutes.migrationNew,
            builder: (context, state) => const StudentMigrationWizardScreen(),
          ),
          GoRoute(
            path: AppRoutes.migrationDetail,
            builder: (context, state) {
              final jobId = state.pathParameters['jobId']!;
              return StudentMigrationWizardScreen(jobId: jobId);
            },
          ),
          GoRoute(
            path: AppRoutes.academicSetupMigrationNew,
            builder: (context, state) => const AcademicSetupMigrationWizardScreen(),
          ),
          GoRoute(
            path: AppRoutes.academicSetupMigrationDetail,
            builder: (context, state) {
              final jobId = state.pathParameters['jobId']!;
              return AcademicSetupMigrationWizardScreen(jobId: jobId);
            },
          ),
          GoRoute(
            path: AppRoutes.guardianMappingMigrationNew,
            builder: (context, state) => const GuardianMappingMigrationWizardScreen(),
          ),
          GoRoute(
            path: AppRoutes.guardianMappingMigrationDetail,
            builder: (context, state) {
              final jobId = state.pathParameters['jobId']!;
              return GuardianMappingMigrationWizardScreen(jobId: jobId);
            },
          ),
          GoRoute(
            path: AppRoutes.guardianMigrationNew,
            builder: (context, state) => const GuardianMigrationWizardScreen(),
          ),
          GoRoute(
            path: AppRoutes.guardianMigrationDetail,
            builder: (context, state) {
              final jobId = state.pathParameters['jobId']!;
              return GuardianMigrationWizardScreen(jobId: jobId);
            },
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.connectAnalytics,
            builder: (context, state) => const CommunicationAnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.plannerCalendar,
            builder: (context, state) => const PlannerCalendarScreen(),
          ),
          GoRoute(
            path: AppRoutes.plannerEvents,
            builder: (context, state) => const PlannerEventsScreen(),
          ),
          GoRoute(
            path: AppRoutes.plannerAnnouncements,
            builder: (context, state) => const PlannerAnnouncementsScreen(),
          ),
          GoRoute(
            path: AppRoutes.plannerCirculars,
            builder: (context, state) => const PlannerCircularsScreen(),
          ),
          GoRoute(
            path: AppRoutes.plannerExams,
            builder: (context, state) => const PlannerExamsScreen(),
          ),
          GoRoute(
            path: AppRoutes.plannerSchedule,
            builder: (context, state) => const PlannerScheduleScreen(),
          ),
          GoRoute(
            path: AppRoutes.aiIntelligence,
            builder: (context, state) => const AIIntelligenceDashboardScreen(),
          ),
        ],
      ),
    ],
  );
});

