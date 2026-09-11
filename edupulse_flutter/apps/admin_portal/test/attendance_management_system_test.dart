import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/auth/portal_permissions.dart';
import 'package:admin_portal/features/attendance/presentation/pages/attendance_screen.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_dashboard_view.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_register_view.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_upload_wizard.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_imports_view.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_audit_trail_view.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class MockSessionManager implements SessionManager {
  String? cachedTenantId = 'tenant_1';
  String? cachedSchoolId = 'school_1';

  @override
  Future<String?> getTenantId() async => cachedTenantId;
  @override
  Future<void> saveTenantId(String tenantId) async => cachedTenantId = tenantId;

  @override
  Future<String?> getTenantName() async => 'Telangana Educational Society';
  @override
  Future<void> saveTenantName(String tenantName) async {}

  @override
  Future<String?> getSchoolName() async => 'Telangana Model School';
  @override
  Future<void> saveSchoolName(String schoolName) async {}

  @override
  Future<String?> getAccessToken() async => 'mock_access_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh_token';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => cachedSchoolId;
  @override
  Future<void> saveSchoolId(String schoolId) async => cachedSchoolId = schoolId;
}

class MockAttendanceApiClient extends BaseApiClient {
  MockAttendanceApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {'id': 'ay_1', 'tenant_id': 'tenant_1', 'school_id': 'school_1', 'name': '2026-2027', 'code': 'AY26', 'is_current': true, 'status': 'ACTIVE', 'version': 1}
        ]
      }));
    }

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {'id': 'class_1', 'tenant_id': 'tenant_1', 'school_id': 'school_1', 'academic_year_id': 'ay_1', 'name': 'Grade 10', 'code': 'G10', 'capacity': 120, 'status': 'ACTIVE', 'is_active': true, 'version': 1},
          {'id': 'class_2', 'tenant_id': 'tenant_1', 'school_id': 'school_1', 'academic_year_id': 'ay_1', 'name': 'Grade 9', 'code': 'G9', 'capacity': 40, 'status': 'ACTIVE', 'is_active': true, 'version': 1},
        ]
      }));
    }

    if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
          {'id': 'sec_1', 'tenant_id': 'tenant_1', 'school_id': 'school_1', 'class_id': 'class_1', 'name': 'Section A', 'code': 'G10-A', 'capacity': 40, 'status': 'ACTIVE', 'is_active': true, 'version': 1}
        ]
      }));
    }

    if (path.contains('/attendances/sessions')) {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'session_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'class_name': 'Grade 10',
            'section_name': 'Section A',
            'attendance_date': todayStr,
            'session_type': 'FULL_DAY',
            'status': 'SUBMITTED',
            'is_active': true,
            'settings': {},
            'version': 1,
            'attendances': [
              for (int i = 1; i <= 111; i++)
                {
                  'id': 'att_p_$i',
                  'tenant_id': 'tenant_1',
                  'school_id': 'school_1',
                  'academic_year_id': 'ay_1',
                  'attendance_session_id': 'session_1',
                  'student_id': 'stud_$i',
                  'student_name': i == 1 ? 'Aarav Reddy' : 'Student $i',
                  'admission_number': 'ADM${i.toString().padLeft(3, "0")}',
                  'class_id': 'class_1',
                  'section_id': 'sec_1',
                  'class_name': 'Grade 10',
                  'section_name': 'Section A',
                  'attendance_date': todayStr,
                  'attendance_status': 'PRESENT',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'UNKNOWN',
                  'parent_viewed': false,
                  'is_active': true,
                  'settings': {},
                  'ai_metrics': {},
                  'version': 1,
                },
              for (int i = 112; i <= 117; i++)
                {
                  'id': 'att_a_$i',
                  'tenant_id': 'tenant_1',
                  'school_id': 'school_1',
                  'academic_year_id': 'ay_1',
                  'attendance_session_id': 'session_1',
                  'student_id': i == 112 ? 'stud_risk_1' : 'stud_$i',
                  'student_name': i == 112 ? 'Rahul Sharma' : 'Student $i',
                  'admission_number': i == 112 ? 'ADM2026010' : 'ADM${i.toString().padLeft(3, "0")}',
                  'class_id': 'class_1',
                  'section_id': 'sec_1',
                  'class_name': 'Grade 10',
                  'section_name': 'Section A',
                  'attendance_date': todayStr,
                  'attendance_status': 'ABSENT',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'ILLNESS',
                  'parent_viewed': false,
                  'is_active': true,
                  'settings': {},
                  'ai_metrics': {},
                  'version': 1,
                },
              for (int i = 118; i <= 120; i++)
                {
                  'id': 'att_l_$i',
                  'tenant_id': 'tenant_1',
                  'school_id': 'school_1',
                  'academic_year_id': 'ay_1',
                  'attendance_session_id': 'session_1',
                  'student_id': 'stud_$i',
                  'student_name': 'Student $i',
                  'admission_number': 'ADM${i.toString().padLeft(3, "0")}',
                  'class_id': 'class_1',
                  'section_id': 'sec_1',
                  'class_name': 'Grade 10',
                  'section_name': 'Section A',
                  'attendance_date': todayStr,
                  'attendance_status': 'LATE',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'TRAFFIC_DELAY',
                  'parent_viewed': false,
                  'is_active': true,
                  'settings': {},
                  'ai_metrics': {},
                  'version': 1,
                },
            ],
          },
          for (int d = 1; d <= 4; d++)
            {
              'id': 'session_past_$d',
              'tenant_id': 'tenant_1',
              'school_id': 'school_1',
              'academic_year_id': 'ay_1',
              'class_id': 'class_1',
              'section_id': 'sec_1',
              'class_name': 'Grade 10',
              'section_name': 'Section A',
              'attendance_date': DateTime.now().subtract(Duration(days: d)).toIso8601String().substring(0, 10),
              'session_type': 'FULL_DAY',
              'status': 'SUBMITTED',
              'is_active': true,
              'settings': {},
              'version': 1,
              'attendances': [
                for (int i = 1; i <= 110; i++)
                  {
                    'id': 'att_past_${d}_$i',
                    'tenant_id': 'tenant_1',
                    'school_id': 'school_1',
                    'academic_year_id': 'ay_1',
                    'attendance_session_id': 'session_past_$d',
                    'student_id': 'stud_$i',
                    'student_name': i == 1 ? 'Aarav Reddy' : 'Student $i',
                    'admission_number': 'ADM${i.toString().padLeft(3, "0")}',
                    'class_id': 'class_1',
                    'section_id': 'sec_1',
                    'class_name': 'Grade 10',
                    'section_name': 'Section A',
                    'attendance_date': DateTime.now().subtract(Duration(days: d)).toIso8601String().substring(0, 10),
                    'attendance_status': 'PRESENT',
                    'attendance_source': 'MANUAL',
                    'attendance_reason': 'UNKNOWN',
                    'parent_viewed': false,
                    'is_active': true,
                    'settings': {},
                    'ai_metrics': {},
                    'version': 1,
                  },
                {
                  'id': 'att_past_${d}_risk',
                  'tenant_id': 'tenant_1',
                  'school_id': 'school_1',
                  'academic_year_id': 'ay_1',
                  'attendance_session_id': 'session_past_$d',
                  'student_id': 'stud_risk_1',
                  'student_name': 'Rahul Sharma',
                  'admission_number': 'ADM2026010',
                  'class_id': 'class_1',
                  'section_id': 'sec_1',
                  'class_name': 'Grade 10',
                  'section_name': 'Section A',
                  'attendance_date': DateTime.now().subtract(Duration(days: d)).toIso8601String().substring(0, 10),
                  'attendance_status': 'ABSENT',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'ILLNESS',
                  'parent_viewed': false,
                  'is_active': true,
                  'settings': {},
                  'ai_metrics': {},
                  'version': 1,
                },
              ],
            },
        ],
      }));
    }

    if (path.contains('/attendances/daily')) {
      return ApiResult.success(mapper({'data': []}));
    }

    if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'stud_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'admission_number': 'ADM001',
            'roll_number': '1',
            'first_name': 'Aarav',
            'last_name': 'Reddy',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'status': 'ACTIVE',
            'is_active': true,
          },
          {
            'id': 'stud_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'admission_number': 'ADM002',
            'roll_number': '2',
            'first_name': 'Diya',
            'last_name': 'Patel',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'status': 'ACTIVE',
            'is_active': true,
          }
        ]
      }));
    }

    if (path.contains('/teacher-subject-assignments')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'tsa_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'sub_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'assignment_type': 'PRIMARY',
            'priority': 1,
            'weekly_periods': 5,
            'workload_percentage': 20.0,
            'effective_from': '2026-06-01',
            'is_class_teacher': true,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1
          }
        ]
      }));
    }

    if (path.contains('/attendance/daily/session') || path.contains('/attendances/daily/session')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'session_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'class_id': 'class_1',
          'section_id': 'sec_1',
          'academic_year_id': 'ay_1',
          'attendance_date': '2026-09-05',
          'session_type': 'FULL_DAY',
          'status': 'DRAFT',
          'total_students': 2,
          'present_count': 2,
          'absent_count': 0,
          'late_count': 0,
          'excused_count': 0,
          'half_day_count': 0,
          'is_locked': false,
          'created_at': '2026-09-05T08:00:00Z',
          'attendances': [],
        }
      }));
    }

    if (path.contains('/attendance/register') || path.contains('/attendances/register')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'att_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'attendance_session_id': 'session_1',
            'student_id': 'stud_1',
            'student_name': 'Aarav Reddy',
            'admission_number': 'ADM001',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'class_name': 'Grade 10',
            'section_name': 'Section A',
            'attendance_date': '2026-09-05',
            'session_type': 'FULL_DAY',
            'attendance_status': 'PRESENT',
            'attendance_source': 'MANUAL',
            'attendance_reason': 'UNKNOWN',
            'remarks': 'On time',
            'is_active': true,
            'version': 1,
            'settings': {},
            'ai_metrics': {},
          }
        ],
        'meta': {'total': 1, 'skip': 0, 'limit': 50}
      }));
    }

    if (path.contains('/attendance/imports') || path.contains('/attendances/imports') || path.contains('/import-jobs')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'job_101',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'filename': 'attendance_sept_2026.csv',
            'status': 'COMPLETED',
            'total_rows': 240,
            'successful_rows': 238,
            'failed_rows': 2,
            'created_at': '2026-09-05T09:30:00Z',
            'error_summary': {'failed_rows': 2}
          }
        ],
        'meta': {'total': 1}
      }));
    }

    if (path.contains('/attendance/audit-logs') || path.contains('/attendances/audit-logs')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'audit_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'student_id': 'stud_1',
            'student_name': 'Aarav Reddy',
            'admission_number': 'ADM001',
            'class_name': 'Grade 10',
            'section_name': 'Section A',
            'attendance_date': '2026-09-05',
            'session_type': 'FULL_DAY',
            'old_status': 'ABSENT',
            'new_status': 'PRESENT',
            'action': 'UPDATE',
            'changed_by': 'user_1',
            'changed_by_name': 'Principal Rao',
            'changed_by_role': 'PRINCIPAL',
            'timestamp': '2026-09-05T10:15:00Z',
            'source': 'MANUAL',
            'reason': 'Medical certificate verified',
          }
        ],
        'meta': {'total': 1}
      }));
    }

    return ApiResult.success(mapper({'data': []}));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({'status': 'success', 'data': {'success': true}}));
  }
}

const mockPrincipalPermissions = PortalPermissions(
  isSuperAdmin: false,
  isTenantAdmin: false,
  isPrincipal: true,
  isTeacher: false,
  roles: {'PRINCIPAL'},
  schoolIds: ['school_1'],
  tenantId: 'tenant_1',
);

const mockTeacherPermissions = PortalPermissions(
  isSuperAdmin: false,
  isTenantAdmin: false,
  isPrincipal: false,
  isTeacher: true,
  roles: {'TEACHER'},
  schoolIds: ['school_1'],
  tenantId: 'tenant_1',
);

Widget createTestApp({
  required Widget child,
  PortalPermissions permissions = mockPrincipalPermissions,
}) {
  return ProviderScope(
    overrides: [
      sessionManagerProvider.overrideWithValue(MockSessionManager()),
      apiClientProvider.overrideWithValue(MockAttendanceApiClient()),
      selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      portalPermissionsProvider.overrideWith((ref) => permissions),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EduPulse Attendance Management Production Tests', () {
    testWidgets('1. AttendanceScreen renders all 6 tabs for Principal/Admin', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const AttendanceScreen(initialTab: 0),
        permissions: mockPrincipalPermissions,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Management'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Mark Attendance'), findsOneWidget);
      expect(find.text('Attendance Register'), findsOneWidget);
      expect(find.text('Bulk Upload'), findsOneWidget);
      expect(find.text('Import History'), findsOneWidget);
      expect(find.text('Audit Trail'), findsOneWidget);
    });

    testWidgets('2. AttendanceScreen scopes tabs strictly for Teacher (3 tabs only)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const AttendanceScreen(initialTab: 0),
        permissions: mockTeacherPermissions,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Mark Attendance'), findsOneWidget);
      expect(find.text('Attendance Register'), findsOneWidget);

      // Bulk Upload, Import History, and Audit Trail must NOT be shown to teachers
      expect(find.text('Bulk Upload'), findsNothing);
      expect(find.text('Import History'), findsNothing);
      expect(find.text('Audit Trail'), findsNothing);
    });

    testWidgets('3. Overview tab renders KPI metrics, active alerts, and 7-day trend', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const AttendanceDashboardView(),
        permissions: mockPrincipalPermissions,
      ));
      await tester.pumpAndSettle();

      // Header and analytics
      expect(find.text('Daily Attendance Overview'), findsOneWidget);
      expect(find.text('Active Attendance Alerts (2)'), findsOneWidget);
      expect(find.text('STREAK ABSENCE'), findsOneWidget);
      expect(find.text('UNMARKED'), findsOneWidget);

      // KPI cards
      expect(find.text('92.5%'), findsWidgets);
      expect(find.text('Present Students'), findsOneWidget);
      expect(find.text('111 / 120'), findsOneWidget);
      expect(find.text('7-Day Attendance Trend'), findsOneWidget);
      expect(find.text('Class-wise Attendance'), findsOneWidget);
      expect(find.text('Students Below 75% Attendance'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsWidgets);
    });

    testWidgets('4. Attendance Register renders search, filters, and Export CSV button', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const AttendanceRegisterView(),
        permissions: mockPrincipalPermissions,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Register Filters'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Aarav Reddy'), findsOneWidget);
      expect(find.text('PRESENT'), findsWidgets);
    });

    testWidgets('5. Bulk Upload Wizard renders steps, template button, and conflict options', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const AttendanceUploadWizard(),
        permissions: mockPrincipalPermissions,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Attendance Upload Wizard'), findsOneWidget);
      expect(find.text('Download CSV Template'), findsOneWidget);
      expect(find.text('Click to select file (.xlsx, .xls, .csv)'), findsOneWidget);
    });

    testWidgets('6. Import History renders past jobs and Error CSV download', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const AttendanceImportsView(),
        permissions: mockPrincipalPermissions,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Import History'), findsOneWidget);
      expect(find.text('attendance_sept_2026.csv'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('Error CSV'), findsOneWidget);
    });

    testWidgets('7. Audit Trail renders immutable logs, actor roles, and status changes', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        child: const AttendanceAuditTrailView(),
        permissions: mockPrincipalPermissions,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Audit Trail'), findsOneWidget);
      expect(find.text('Aarav Reddy'), findsOneWidget);
      expect(find.text('Principal Rao'), findsOneWidget);
      expect(find.text('PRINCIPAL'), findsOneWidget);
      expect(find.text('UPDATE'), findsOneWidget);
      expect(find.text('Medical certificate verified'), findsOneWidget);
    });

    testWidgets('8. Zero RenderFlex overflows on compact mobile layout (412x915)', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? caughtDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        debugPrint('=== CAUGHT FLUTTER ERROR ===');
        debugPrint(details.toString());
        debugPrint('=============================');
      };

      await tester.pumpWidget(createTestApp(
        child: const AttendanceScreen(initialTab: 0),
        permissions: mockPrincipalPermissions,
      ));
      await tester.pumpAndSettle();

      FlutterError.onError = oldHandler;

      expect(caughtDetails, isNull);
      expect(find.text('Attendance Management'), findsOneWidget);
    });
  });
}
