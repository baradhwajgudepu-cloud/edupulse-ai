import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'routes.dart';
import '../auth/portal_permissions.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/forgot_password_screen.dart';
import '../../features/auth/presentation/pages/reset_password_screen.dart';
import '../../features/auth/presentation/pages/privacy_policy_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/shell/presentation/admin_shell.dart';
import '../../features/users/presentation/pages/users_screen.dart';
import '../../features/users/presentation/pages/user_details_screen.dart';
import '../../features/roles_permissions/presentation/pages/roles_permissions_screen.dart';
import '../../features/school_setup/presentation/pages/school_setup_center_screen.dart';
import '../../features/school_admin/presentation/pages/school_administration_screen.dart';
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
import '../../features/fees/presentation/pages/salaries_screen.dart';
import '../../features/fees/presentation/pages/expenses_screen.dart';
import '../../features/school_setup/presentation/pages/rooms_screen.dart';
import '../../features/students/data/models/student_models.dart';
import '../../features/migrations/presentation/pages/migration_center_screen.dart';
import '../../features/migrations/presentation/pages/student_migration_wizard_screen.dart';
import '../../features/migrations/presentation/pages/academic_setup_migration_wizard_screen.dart';
import '../../features/migrations/presentation/pages/guardian_mapping_migration_wizard_screen.dart';
import '../../features/migrations/presentation/pages/guardian_migration_wizard_screen.dart';
import '../../features/results/presentation/pages/results_dashboard_screen.dart';
import '../../features/results/presentation/pages/exam_types_screen.dart';
import '../../features/results/presentation/pages/examinations_setup_screen.dart';
import '../../features/results/presentation/pages/examination_dashboard_screen.dart';
import '../../features/results/presentation/pages/admin_marks_management_screen.dart';
import '../../features/results/presentation/pages/marks_import_wizard_screen.dart';
import '../../features/results/presentation/pages/student_result_detail_screen.dart';
import '../../features/results/presentation/pages/report_card_management_screen.dart';
import '../../features/teachers/presentation/pages/teachers_screen.dart';
import '../../features/teachers/presentation/pages/teacher_details_screen.dart';
import '../../features/teachers/presentation/pages/teacher_assignments_screen.dart';
import '../../features/planner/presentation/pages/timetable_management_screen.dart';
import '../../features/attendance/presentation/pages/attendance_screen.dart';
import '../../features/attendance/presentation/pages/attendance_session_details_screen.dart';


// School Planner imports
import '../../features/planner/presentation/pages/planner_calendar_screen.dart';
import '../../features/planner/presentation/pages/planner_events_screen.dart';
import '../../features/planner/presentation/pages/planner_announcements_screen.dart';
import '../../features/planner/presentation/pages/planner_circulars_screen.dart';
import '../../features/planner/presentation/pages/planner_exams_screen.dart';
import '../../features/planner/presentation/pages/planner_schedule_screen.dart';
import '../../features/planner/presentation/pages/syllabus_editor_screen.dart';
import '../../features/planner/presentation/pages/academic_planning_analytics_screen.dart';
import '../../features/guardians/presentation/pages/guardians_screen.dart';
import '../../features/guardians/presentation/pages/guardian_details_screen.dart';
import '../../features/promotions/presentation/pages/promotions_screen.dart';
import '../../features/tenant_setup/presentation/pages/tenants_screen.dart';
import '../presentation/pages/access_denied_screen.dart';
import '../../features/reports/presentation/pages/reports_dashboard_screen.dart';
import '../../features/communication_analytics/presentation/pages/communication_analytics_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../features/ai_intelligence/presentation/pages/ai_intelligence_dashboard_screen.dart';


/// Pure redirect logic for GoRouter, evaluating authentication and authorization guards.
String? appRouterRedirect({
  required AuthState authState,
  required String matchedLocation,
}) {
  final loc = matchedLocation;
  if (loc == AppRoutes.privacyPolicy) {
    return null;
  }
  final isPublicAuthRoute = loc == AppRoutes.login ||
      loc == AppRoutes.forgotPassword ||
      loc == AppRoutes.resetPassword ||
      loc.startsWith('${AppRoutes.resetPassword}/');

  String? result;
  String redirectReason = 'NONE';

  if (authState is AuthInitial || authState is AuthLoading) {
    result = null;
  } else if (authState is AccountLocked) {
    if (!isPublicAuthRoute) {
      result = AppRoutes.login;
      redirectReason = 'Locked account redirected to login';
    }
  } else if (authState is AuthError) {
    if (isAccountLockedError(message: authState.message)) {
      if (!isPublicAuthRoute) {
        result = AppRoutes.login;
        redirectReason = 'Locked account (AuthError) redirected to login';
      }
    } else {
      // Authorization, Transient, and Operational Errors:
      // An AuthError (including HTTP 403, ACCESS_DENIED, 500, or network timeouts)
      // represents an authorization or operational failure, NOT a terminated session.
      // It must NEVER redirect an authenticated user to /login.
      result = null;
    }
  } else if (authState is! Authenticated) {
    if (!isPublicAuthRoute) {
      result = AppRoutes.login;
      redirectReason = 'Unauthenticated access to protected route';
    }
  } else {
    if (isPublicAuthRoute || loc == '/' || loc == '/staff') {
      result = (loc == '/staff') ? AppRoutes.teachers : AppRoutes.dashboard;
      redirectReason = (loc == '/staff') ? 'Staff route alias redirected to teachers' : 'Authenticated user redirected from public route';
    } else {
      final user = authState.user;
      final permissions = PortalPermissions.fromUser(user);

      // Platform-only routes: Tenants is accessible ONLY to SUPER_ADMIN
      if (loc.startsWith(AppRoutes.tenants) && !permissions.canManageTenants) {
        result = AppRoutes.unauthorized;
        redirectReason = 'Restricted Tenant module accessed by non-superadmin (Access Denied / 403)';
      } else if (!permissions.canAccessRoute(loc)) {
        result = AppRoutes.dashboard;
        redirectReason = 'Insufficient role/permissions for route: $loc';
      }
    }
  }

  if (result != null) {
    debugPrint('[AUTH ROUTER REDIRECT]');
    debugPrint('timestamp: ${DateTime.now().toUtc().toIso8601String()}');
    debugPrint('from URI: $matchedLocation');
    debugPrint('to URI: $result');
    debugPrint('auth state: ${authState.runtimeType}');
    debugPrint('reason: $redirectReason');
    if (result == AppRoutes.login) {
      debugPrintStack(label: '[TENANT ROUTE → LOGIN STACK]');
    }
    AuthIncidentLogger.log('ROUTER_REDIRECT', {
      'from': matchedLocation,
      'to': result,
      'authState': authState.runtimeType.toString(),
      'reason': redirectReason,
    });
  }

  return result;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) => appRouterRedirect(
      authState: authState,
      matchedLocation: state.matchedLocation,
    ),
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
          String? token = state.uri.queryParameters['token'];
          if (token == null || token.isEmpty) {
            if (state.uri.hasFragment) {
              final fragmentUri = Uri.tryParse(state.uri.fragment);
              if (fragmentUri != null) {
                token = fragmentUri.queryParameters['token'];
              }
            }
          }
          final isManual = state.uri.queryParameters['mode'] == 'manual';
          return ResetPasswordScreen(
            initialToken: token,
            initialManualMode: isManual,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),

        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) => AppRoutes.dashboard,
          ),
          GoRoute(
            path: '/staff',
            redirect: (context, state) => AppRoutes.teachers,
          ),
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.tenants,
            builder: (context, state) => const TenantsScreen(),
          ),
          GoRoute(
            path: AppRoutes.unauthorized,
            builder: (context, state) => const AccessDeniedScreen(),
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
            path: AppRoutes.rolesPermissions,
            builder: (context, state) => const RolesPermissionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.schools,
            builder: (context, state) => const SchoolsScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolSetup,
            builder: (context, state) => const SchoolSetupCenterScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolAdministration,
            builder: (context, state) {
              final tabStr = state.uri.queryParameters['tab'];
              final tabIndex = int.tryParse(tabStr ?? '') ?? 0;
              return SchoolAdministrationScreen(initialTab: tabIndex);
            },
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
            path: AppRoutes.rooms,
            builder: (context, state) => const RoomsScreen(),
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
            path: AppRoutes.teacherAssignments,
            builder: (context, state) => const TeacherAssignmentsScreen(),
          ),
          GoRoute(
            path: AppRoutes.students,
            builder: (context, state) {
              final initialFilter = state.uri.queryParameters['filter'] ?? state.uri.queryParameters['attention'];
              return StudentsScreen(
                key: ValueKey('students_screen_${initialFilter ?? 'all'}'),
                initialFilter: initialFilter,
              );
            },
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
            builder: (context, state) => const AttendanceScreen(initialTab: 0),
          ),
          GoRoute(
            path: AppRoutes.attendanceMark,
            builder: (context, state) {
              final classId = state.uri.queryParameters['class_id'];
              final sectionId = state.uri.queryParameters['section_id'];
              final dateStr = state.uri.queryParameters['date'];
              final ayId = state.uri.queryParameters['ay_id'];
              DateTime? parsedDate;
              if (dateStr != null && dateStr.isNotEmpty) {
                try {
                  parsedDate = DateTime.parse(dateStr);
                } catch (_) {}
              }
              return AttendanceScreen(
                initialTab: 1,
                initialMarkClassId: classId,
                initialMarkSectionId: sectionId,
                initialMarkDate: parsedDate,
                initialMarkAyId: ayId,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.attendanceRegister,
            builder: (context, state) {
              final status = state.uri.queryParameters['status'];
              final classId = state.uri.queryParameters['class_id'];
              final sectionId = state.uri.queryParameters['section_id'];
              final dateStr = state.uri.queryParameters['date'];
              final startStr = state.uri.queryParameters['start_date'];
              final endStr = state.uri.queryParameters['end_date'];
              DateTime? parsedDate;
              DateTime? parsedStart;
              DateTime? parsedEnd;
              if (dateStr != null && dateStr.isNotEmpty) {
                try {
                  parsedDate = DateTime.parse(dateStr);
                } catch (_) {}
              }
              if (startStr != null && startStr.isNotEmpty) {
                try {
                  parsedStart = DateTime.parse(startStr);
                } catch (_) {}
              }
              if (endStr != null && endStr.isNotEmpty) {
                try {
                  parsedEnd = DateTime.parse(endStr);
                } catch (_) {}
              }
              return AttendanceScreen(
                initialTab: 2,
                initialStatus: status,
                initialClassId: classId,
                initialSectionId: sectionId,
                initialDate: parsedDate,
                initialStartDate: parsedStart ?? parsedDate,
                initialEndDate: parsedEnd ?? parsedDate,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.attendanceUpload,
            builder: (context, state) => const AttendanceScreen(initialTab: 3),
          ),
          GoRoute(
            path: AppRoutes.attendanceBulkUpload,
            builder: (context, state) => const AttendanceScreen(initialTab: 3),
          ),
          GoRoute(
            path: AppRoutes.attendanceImports,
            builder: (context, state) => const AttendanceScreen(initialTab: 4),
          ),
          GoRoute(
            path: AppRoutes.attendanceImportHistory,
            builder: (context, state) => const AttendanceScreen(initialTab: 4),
          ),
          GoRoute(
            path: AppRoutes.attendanceAudit,
            builder: (context, state) => const AttendanceScreen(initialTab: 5),
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
            path: AppRoutes.salaries,
            builder: (context, state) => const SalariesScreen(),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: AppRoutes.results,
            builder: (context, state) => const ResultsDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.resultsPublishing,
            builder: (context, state) => const ResultsDashboardScreen(initialSection: 'publishing'),
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
            path: AppRoutes.examinationDashboard,
            builder: (context, state) {
              final examId = state.pathParameters['examId']!;
              final tabIndex = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return ExaminationDashboardScreen(examId: examId, initialTabIndex: tabIndex);
            },
          ),
          GoRoute(
            path: AppRoutes.examinationDetail,
            builder: (context, state) {
              final examId = state.pathParameters['id']!;
              final tabIndex = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return ExaminationDashboardScreen(examId: examId, initialTabIndex: tabIndex);
            },
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
            path: AppRoutes.marksImport,
            builder: (context, state) {
              final examId = state.uri.queryParameters['exam_id'];
              final classId = state.uri.queryParameters['class_id'];
              final sectionId = state.uri.queryParameters['section_id'];
              final ayId = state.uri.queryParameters['ay_id'];
              return MarksImportWizardScreen(
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
            path: AppRoutes.timetables,
            builder: (context, state) => TimetableManagementScreen(
              initialTeacherId: state.uri.queryParameters['teacher_id'],
              initialClassId: state.uri.queryParameters['class_id'],
              initialSectionId: state.uri.queryParameters['section_id'],
            ),
          ),
          GoRoute(
            path: AppRoutes.syllabusEditor,
            builder: (context, state) => SyllabusEditorScreen(
              initialClassId: state.uri.queryParameters['class_id'],
              initialSubjectId: state.uri.queryParameters['subject_id'],
            ),
          ),
          GoRoute(
            path: AppRoutes.academicPlanning,
            builder: (context, state) => const AcademicPlanningAnalyticsScreen(),
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

