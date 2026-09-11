import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class MockCanonicalApiClient implements BaseApiClient {
  final List<String> requestedUrls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic p1) mapper,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requestedUrls.add(path);

    if (path.contains('/attendance/dashboard') || path.contains('/attendance/alerts')) {
      return ApiResult.failure(
        const ApiFailure(
          message: 'HTTP 404: Obsolete route not found in production OpenAPI',
          statusCode: 404,
          type: ApiFailureType.server,
        ),
      );
    }

    if (path.contains('/attendances/sessions')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sess_1',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'academic_year_id': 'ay_1',
            'class_id': 'cls_1',
            'section_id': 'sec_1',
            'class_name': 'Grade 10',
            'section_name': 'Section A',
            'attendance_date': '2026-09-11',
            'session_type': 'FULL_DAY',
            'status': 'SUBMITTED',
            'is_active': true,
            'settings': {},
            'version': 1,
            'attendances': [
              for (int i = 1; i <= 90; i++)
                {
                  'id': 'att_p_$i',
                  'tenant_id': 'ten_1',
                  'school_id': 'sch_1',
                  'academic_year_id': 'ay_1',
                  'attendance_session_id': 'sess_1',
                  'student_id': 'stu_$i',
                  'student_name': 'Student $i',
                  'admission_number': 'ADM$i',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'class_name': 'Grade 10',
                  'section_name': 'Section A',
                  'attendance_date': '2026-09-11',
                  'attendance_status': 'PRESENT',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'UNKNOWN',
                  'parent_viewed': false,
                  'is_active': true,
                  'settings': {},
                  'ai_metrics': {},
                  'version': 1,
                },
              for (int i = 91; i <= 100; i++)
                {
                  'id': 'att_a_$i',
                  'tenant_id': 'ten_1',
                  'school_id': 'sch_1',
                  'academic_year_id': 'ay_1',
                  'attendance_session_id': 'sess_1',
                  'student_id': i == 91 ? 'stu_chronic' : 'stu_$i',
                  'student_name': i == 91 ? 'Chronic Absentee' : 'Student $i',
                  'admission_number': 'ADM$i',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'class_name': 'Grade 10',
                  'section_name': 'Section A',
                  'attendance_date': '2026-09-11',
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
          for (int d = 1; d <= 4; d++)
            {
              'id': 'sess_past_$d',
              'tenant_id': 'ten_1',
              'school_id': 'sch_1',
              'academic_year_id': 'ay_1',
              'class_id': 'cls_1',
              'section_id': 'sec_1',
              'class_name': 'Grade 10',
              'section_name': 'Section A',
              'attendance_date': '2026-09-0$d',
              'session_type': 'FULL_DAY',
              'status': 'SUBMITTED',
              'is_active': true,
              'settings': {},
              'version': 1,
              'attendances': [
                {
                  'id': 'att_past_${d}_chronic',
                  'tenant_id': 'ten_1',
                  'school_id': 'sch_1',
                  'academic_year_id': 'ay_1',
                  'attendance_session_id': 'sess_past_$d',
                  'student_id': 'stu_chronic',
                  'student_name': 'Chronic Absentee',
                  'admission_number': 'ADM91',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'class_name': 'Grade 10',
                  'section_name': 'Section A',
                  'attendance_date': '2026-09-0$d',
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

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'cls_1',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'name': 'Grade 10',
            'code': 'G10',
            'capacity': 100,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
          {
            'id': 'cls_2',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'name': 'Grade 11',
            'code': 'G11',
            'capacity': 50,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
        ],
      }));
    }

    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  group('Attendance Dashboard Canonical API Contract Tests', () {
    test('Queries canonical /attendances/sessions, /attendances/daily, /classes and never calls obsolete endpoints', () async {
      final mockClient = MockCanonicalApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      await notifier.fetchDashboard(date: DateTime(2026, 9, 11));

      final requested = mockClient.requestedUrls;

      // 1. Must contain canonical plural endpoints
      expect(
        requested.any((u) => u.startsWith('/attendances/sessions')),
        isTrue,
        reason: 'Should query /attendances/sessions',
      );
      expect(
        requested.any((u) => u.startsWith('/attendances/daily')),
        isTrue,
        reason: 'Should query /attendances/daily',
      );
      expect(
        requested.any((u) => u.startsWith('/classes')),
        isTrue,
        reason: 'Should query /classes',
      );

      // 2. Must NEVER call obsolete routes that return 404
      expect(
        requested.any((u) => u.contains('/attendance/dashboard')),
        isFalse,
        reason: 'Must not call obsolete /attendance/dashboard',
      );
      expect(
        requested.any((u) => u.contains('/attendance/alerts')),
        isFalse,
        reason: 'Must not call obsolete /attendance/alerts',
      );

      // 3. Verify deterministic stats computation
      final state = container.read(attendanceDashboardProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.stats, isNotNull);

      final stats = state.stats!;
      expect(stats.attendanceDate, equals('2026-09-11'));
      expect(stats.presentCount, equals(90));
      expect(stats.absentCount, equals(10));
      expect(stats.totalStudents, equals(100));
      expect(stats.attendancePercentage, equals(90.0));
      expect(stats.classesMarked, equals(1));
      expect(stats.classesPending, equals(1)); // Grade 11 is unmarked

      // 4. Verify alerts derivation
      expect(state.alerts.length, equals(2));
      final unmarkedAlert = state.alerts.firstWhere((a) => a.alertType == 'UNMARKED_CLASSES');
      expect(unmarkedAlert.title, contains('1 Class Pending Today'));

      final streakAlert = state.alerts.firstWhere((a) => a.alertType == 'CONSECUTIVE_ABSENCE');
      expect(streakAlert.title, contains('Chronic Absentee'));

      // 5. Verify low attendance students (< 75%)
      expect(stats.lowAttendanceStudents.isNotEmpty, isTrue);
      expect(stats.lowAttendanceStudents.any((s) => s['student_name'] == 'Chronic Absentee'), isTrue);
    });
  });
}
