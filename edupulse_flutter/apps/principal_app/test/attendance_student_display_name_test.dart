import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:principal_app/features/attendance/data/models/attendance_model.dart';
import 'package:principal_app/features/attendance/data/repositories/attendance_repository.dart';
import 'package:principal_app/features/attendance/data/datasources/attendance_datasource.dart';
import 'package:principal_app/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:principal_app/features/attendance/presentation/pages/attendance_screen.dart';

class FakeSessionManager implements SessionManager {
  @override
  Future<String?> getSchoolId() async => 'school-123';
  @override
  Future<String?> getTenantId() async => 'tenant-123';
  @override
  Future<String?> getAccessToken() async => 'fake-token';
  @override
  Future<String?> getRefreshToken() async => 'fake-refresh';
  @override
  Future<String?> getTenantName() async => 'Test Tenant';
  @override
  Future<String?> getSchoolName() async => 'Test School';
  @override
  Future<void> saveTenantId(String tenantId) async {}
  @override
  Future<void> saveTenantName(String tenantName) async {}
  @override
  Future<void> saveSchoolName(String schoolName) async {}
  @override
  Future<void> saveSchoolId(String schoolId) async {}
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}
  @override
  Future<bool> hasSession() async => true;
}

class FakeAttendanceDatasource extends AttendanceDatasource {
  final List<Map<String, dynamic>> mockData;
  FakeAttendanceDatasource(this.mockData) : super(FakeApiClient());

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getDailyAttendance({
    required String schoolId,
    required String date,
  }) async {
    return ApiResult.success(mockData);
  }
}

class FakeApiClient extends Fake implements BaseApiClient {}

void main() {
  group('AttendanceRecord Model Tests', () {
    test('AttendanceRecord.fromJson parses student_name, admission_number, roll_number, status', () {
      final json = {
        'id': 'rec-1',
        'student_id': '67d9ad8c-29b3-46e9-8c68-f9056d4e4a00',
        'status': 'ABSENT',
        'attendance_status': 'ABSENT',
        'attendance_date': '2026-09-15',
        'class_id': 'cls-1',
        'section_id': 'sec-1',
        'student_name': 'Vikram Katta',
        'admission_number': 'ADM20265347',
        'roll_number': '17',
      };

      final record = AttendanceRecord.fromJson(json);

      expect(record.id, equals('rec-1'));
      expect(record.studentId, equals('67d9ad8c-29b3-46e9-8c68-f9056d4e4a00'));
      expect(record.status, equals('ABSENT'));
      expect(record.studentName, equals('Vikram Katta'));
      expect(record.admissionNumber, equals('ADM20265347'));
      expect(record.rollNumber, equals('17'));
    });

    test('AttendanceRecord.fromJson handles missing student_name and admission_number gracefully', () {
      final json = {
        'id': 'rec-2',
        'student_id': '67d9ad8c-29b3-46e9-8c68-f9056d4e4a00',
        'attendance_status': 'PRESENT',
        'attendance_date': '2026-09-15',
        'class_id': 'cls-1',
        'section_id': 'sec-1',
      };

      final record = AttendanceRecord.fromJson(json);

      expect(record.studentName, isNull);
      expect(record.admissionNumber, isNull);
      expect(record.rollNumber, isNull);
      expect(record.status, equals('PRESENT'));
    });
  });

  group('AttendanceScreen Display Name Widget Tests', () {
    testWidgets('renders student full name and admission number instead of UUIDs', (tester) async {
      final mockAttendanceRecords = [
        {
          'id': 'rec-1',
          'student_id': '67d9ad8c-29b3-46e9-8c68-f9056d4e4a00',
          'status': 'ABSENT',
          'attendance_status': 'ABSENT',
          'attendance_date': '2026-09-15',
          'class_id': 'cls-1',
          'section_id': 'sec-1',
          'student_name': 'Vikram Katta',
          'admission_number': 'ADM20265347',
          'roll_number': '17',
        },
        {
          'id': 'rec-2',
          'student_id': '11111111-2222-3333-4444-555555555555',
          'status': 'PRESENT',
          'attendance_status': 'PRESENT',
          'attendance_date': '2026-09-15',
          'class_id': 'cls-1',
          'section_id': 'sec-1',
          'student_name': null,
          'admission_number': null,
          'roll_number': null,
        }
      ];

      final fakeDatasource = FakeAttendanceDatasource(mockAttendanceRecords);
      final fakeRepository = AttendanceRepository(fakeDatasource);
      final fakeSession = FakeSessionManager();

      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceRepositoryProvider.overrideWithValue(fakeRepository),
            attendanceStateProvider.overrideWith(
              (ref) => AttendanceNotifier(fakeRepository, fakeSession),
            ),
          ],
          child: const MaterialApp(
            home: AttendanceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Vikram Katta must be displayed
      expect(find.text('Vikram Katta'), findsOneWidget);

      // 2. Admission number must be displayed
      expect(find.text('Admission No: ADM20265347'), findsOneWidget);

      // 3. Raw UUID must NOT be displayed
      expect(find.textContaining('67d9ad8c-29b3-46e9-8c68-f9056d4e4a00'), findsNothing);
      expect(find.textContaining('Student #67d9ad'), findsNothing);

      // 4. Missing name fallback must be displayed
      expect(find.text('Student name unavailable'), findsOneWidget);
    });
  });
}
