import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:dio/dio.dart';
import 'package:admin_portal/features/students/presentation/widgets/student_avatar.dart';
import 'package:admin_portal/features/students/presentation/providers/student_providers.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';

class MockCall {
  final String method;
  final String path;
  final dynamic data;
  const MockCall(this.method, this.path, [this.data]);
}

class MockApiClient extends BaseApiClient {
  MockApiClient() : super(Dio());

  String? lastPath;
  String? lastMethod;
  dynamic lastData;
  final List<MockCall> history = [];

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastData = data;
    history.add(MockCall('POST', path, data));
    return ApiResult.success(mapper({
      'success': true,
      'data': {
        'id': 'stud-123',
        'tenant_id': 'tenant-1',
        'school_id': 'school-1',
        'academic_year_id': 'ay-1',
        'class_id': 'class-1',
        'section_id': 'sec-1',
        'first_name': 'Jahnavi',
        'last_name': 'Avula',
        'gender': 'FEMALE',
        'date_of_birth': '2010-05-15',
        'admission_number': 'ADM001',
        'roll_number': '12',
        'admission_date': '2026-06-01',
        'status': 'ACTIVE',
        'is_active': true,
        'address': {},
        'medical_information': {},
        'settings': {},
        'ai_metrics': {},
        'version': 1,
        'created_at': '2026-06-01T00:00:00Z',
        'updated_at': '2026-06-01T00:00:00Z',
      }
    }));
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    lastMethod = 'PUT';
    lastPath = path;
    lastData = data;
    history.add(MockCall('PUT', path, data));
    return ApiResult.success(mapper({
      'success': true,
      'data': {
        'id': 'stud-123',
        'tenant_id': 'tenant-1',
        'school_id': 'school-1',
        'academic_year_id': 'ay-1',
        'class_id': 'class-1',
        'section_id': 'sec-1',
        'first_name': 'Jahnavi',
        'last_name': 'Avula',
        'gender': 'FEMALE',
        'date_of_birth': '2010-05-15',
        'admission_number': 'ADM001',
        'roll_number': '12',
        'admission_date': '2026-06-01',
        'status': 'ACTIVE',
        'is_active': true,
        'address': {},
        'medical_information': {},
        'settings': {},
        'ai_metrics': {},
        'version': 1,
        'created_at': '2026-06-01T00:00:00Z',
        'updated_at': '2026-06-01T00:00:00Z',
      }
    }));
  }

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    lastMethod = 'DELETE';
    lastPath = path;
    lastData = data;
    history.add(MockCall('DELETE', path, data));
    return ApiResult.success(mapper({'success': true}));
  }
}

void main() {
  group('Student Avatar & Profile Photo DP Suite', () {
    test('Derives correct 2-letter uppercase initials', () {
      expect(StudentAvatar.getInitials('Jahnavi', 'Avula'), 'JA');
      expect(StudentAvatar.getInitials('Jahnavi', ''), 'JA');
      expect(StudentAvatar.getInitials('J', ''), 'J');
      expect(StudentAvatar.getInitials('', 'Avula'), 'AV');
      expect(StudentAvatar.getInitials('', ''), 'ST');
      expect(StudentAvatar.getInitials(null, null), 'ST');
      expect(StudentAvatar.getInitials('  John  ', '  Doe  '), 'JD');
      expect(StudentAvatar.getInitials('A', 'B'), 'AB');
    });

    testWidgets('StudentAvatar displays clean initials avatar when no photo exists', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StudentAvatar(
                firstName: 'Jahnavi',
                lastName: 'Avula',
                radius: 20,
              ),
            ),
          ),
        ),
      );

      expect(find.text('JA'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('StudentAvatar displays image when previewBytes provided', (tester) async {
      // 1x1 transparent PNG bytes
      final sampleBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StudentAvatar(
                firstName: 'Jahnavi',
                lastName: 'Avula',
                previewBytes: sampleBytes,
                radius: 24,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('StudentAvatar streams bytes from studentAvatarBytesProvider', (tester) async {
      final sampleBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final overrides = [
        studentAvatarBytesProvider(
          const StudentPhotoKey(studentId: 'stud-1', schoolId: 'school-1'),
        ).overrideWith((ref) async => sampleBytes),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: Scaffold(
              body: StudentAvatar(
                studentId: 'stud-1',
                schoolId: 'school-1',
                photoUrl: '/api/v1/students/stud-1/photo?school_id=school-1',
                firstName: 'Jahnavi',
                lastName: 'Avula',
                radius: 20,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('StudentAvatar falls back to initials when studentAvatarBytesProvider returns null', (tester) async {
      final overrides = [
        studentAvatarBytesProvider(
          const StudentPhotoKey(studentId: 'stud-2', schoolId: 'school-1'),
        ).overrideWith((ref) async => null),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: Scaffold(
              body: StudentAvatar(
                studentId: 'stud-2',
                schoolId: 'school-1',
                photoUrl: '/api/v1/students/stud-2/photo?school_id=school-1',
                firstName: 'Rahul',
                lastName: 'Sharma',
                radius: 20,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('RS'), findsOneWidget);
    });

    testWidgets('StudentAvatar renders external HTTP URLs via NetworkImage', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StudentAvatar(
                photoUrl: 'https://images.unsplash.com/photo-student.jpg',
                firstName: 'Anita',
                lastName: 'Desai',
                radius: 22,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    test('StudentActionNotifier uploadStudentPhoto posts multipart formData', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final ok = await notifier.uploadStudentPhoto(
        schoolId: 'sch-1',
        studentId: 'stud-1',
        fileBytes: fakeBytes,
        fileName: 'profile.png',
      );

      expect(ok, true);
      expect(mockClient.lastPath, '/students/stud-1/photo?school_id=sch-1');
      expect(mockClient.lastData is FormData, true);
    });

    test('StudentActionNotifier deleteStudentPhoto sends DELETE request', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      final ok = await notifier.deleteStudentPhoto(
        schoolId: 'sch-1',
        studentId: 'stud-1',
      );

      expect(ok, true);
      expect(mockClient.lastPath, '/students/stud-1/photo?school_id=sch-1');
    });

    test('StudentActionNotifier createStudent parses StudentDto', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      final student = await notifier.createStudent({
        'first_name': 'Jahnavi',
        'last_name': 'Avula',
      });

      expect(student, isNotNull);
      expect(student!.firstName, 'Jahnavi');
      expect(student.lastName, 'Avula');
    });

    test('Operation A: uploadStudentPhoto is completely independent and does not touch placement', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final ok = await notifier.uploadStudentPhoto(
        schoolId: 'sch-1',
        studentId: 'stud-1',
        fileBytes: fakeBytes,
        fileName: 'profile.png',
      );

      expect(ok, true);
      expect(mockClient.history.length, 1);
      expect(mockClient.history[0].method, 'POST');
      expect(mockClient.history[0].path, '/students/stud-1/photo?school_id=sch-1');
      // Verify no student placement was included
      expect(mockClient.lastData is FormData, true);
      final formData = mockClient.lastData as FormData;
      expect(formData.fields.any((f) => f.key == 'class_id'), false);
      expect(formData.fields.any((f) => f.key == 'section_id'), false);
      expect(formData.fields.any((f) => f.key == 'academic_year_id'), false);
      // Verify no PUT to /students was invoked
      expect(mockClient.history.any((c) => c.method == 'PUT'), false);
    });

    test('Operation A: deleteStudentPhoto is completely independent and does not touch placement', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      final ok = await notifier.deleteStudentPhoto(
        schoolId: 'sch-1',
        studentId: 'stud-1',
      );

      expect(ok, true);
      expect(mockClient.history.length, 1);
      expect(mockClient.history[0].method, 'DELETE');
      expect(mockClient.history[0].path, '/students/stud-1/photo?school_id=sch-1');
      // No PUT request was made
      expect(mockClient.history.any((c) => c.method == 'PUT'), false);
    });

    test('Operation C: Profile attributes update without placement changes omits academic IDs', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      final initialStudent = StudentDto(
        id: 'stud-1',
        tenantId: 'tenant-1',
        schoolId: 'sch-1',
        academicYearId: 'ay-2026',
        classId: 'class-8',
        sectionId: 'sec-b',
        firstName: 'Jahnavi',
        lastName: 'Avula',
        gender: 'FEMALE',
        dateOfBirth: '2010-05-15',
        admissionNumber: 'ADM001',
        rollNumber: '12',
        admissionDate: '2026-06-01',
        status: 'ACTIVE',
        isActive: true,
        address: const {},
        medicalInformation: const {},
        settings: const {},
        aiMetrics: const {},
        version: 1,
        createdAt: '2026-06-01T00:00:00Z',
        updatedAt: '2026-06-01T00:00:00Z',
      );

      // User changes only first_name (placement unchanged)
      const selectedAyId = 'ay-2026';
      const selectedClassId = 'class-8';
      const selectedSectionId = 'sec-b';
      final placementChanged = selectedAyId != initialStudent.academicYearId ||
          selectedClassId != initialStudent.classId ||
          selectedSectionId != initialStudent.sectionId;

      expect(placementChanged, false);

      final updateData = <String, dynamic>{
        'first_name': 'Jahnavi Modified',
        'last_name': initialStudent.lastName,
        'gender': initialStudent.gender,
        'date_of_birth': initialStudent.dateOfBirth,
        'school_id': 'sch-1',
        'status': 'ACTIVE',
        'version': 1,
        if (placementChanged) ...{
          'academic_year_id': selectedAyId,
          'class_id': selectedClassId,
          'section_id': selectedSectionId,
        },
      };

      expect(updateData.containsKey('academic_year_id'), false);
      expect(updateData.containsKey('class_id'), false);
      expect(updateData.containsKey('section_id'), false);

      final success = await notifier.execute(
        method: 'PUT',
        path: '/students/${initialStudent.id}?school_id=sch-1',
        data: updateData,
      );

      expect(success, true);
      expect(mockClient.lastMethod, 'PUT');
      final sentData = mockClient.lastData as Map<String, dynamic>;
      expect(sentData['first_name'], 'Jahnavi Modified');
      expect(sentData.containsKey('academic_year_id'), false);
      expect(sentData.containsKey('class_id'), false);
      expect(sentData.containsKey('section_id'), false);
    });

    test('Operation B: Placement update includes academic IDs when placement genuinely changes', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      final initialStudent = StudentDto(
        id: 'stud-1',
        tenantId: 'tenant-1',
        schoolId: 'sch-1',
        academicYearId: 'ay-2026',
        classId: 'class-8',
        sectionId: 'sec-b',
        firstName: 'Jahnavi',
        lastName: 'Avula',
        gender: 'FEMALE',
        dateOfBirth: '2010-05-15',
        admissionNumber: 'ADM001',
        rollNumber: '12',
        admissionDate: '2026-06-01',
        status: 'ACTIVE',
        isActive: true,
        address: const {},
        medicalInformation: const {},
        settings: const {},
        aiMetrics: const {},
        version: 1,
        createdAt: '2026-06-01T00:00:00Z',
        updatedAt: '2026-06-01T00:00:00Z',
      );

      // User changes section from B to C
      const selectedAyId = 'ay-2026';
      const selectedClassId = 'class-8';
      const selectedSectionId = 'sec-c';
      final placementChanged = selectedAyId != initialStudent.academicYearId ||
          selectedClassId != initialStudent.classId ||
          selectedSectionId != initialStudent.sectionId;

      expect(placementChanged, true);

      final updateData = <String, dynamic>{
        'first_name': initialStudent.firstName,
        'last_name': initialStudent.lastName,
        'school_id': 'sch-1',
        'status': 'ACTIVE',
        'version': 1,
        if (placementChanged) ...{
          'academic_year_id': selectedAyId,
          'class_id': selectedClassId,
          'section_id': selectedSectionId,
        },
      };

      expect(updateData['academic_year_id'], 'ay-2026');
      expect(updateData['class_id'], 'class-8');
      expect(updateData['section_id'], 'sec-c');

      final success = await notifier.execute(
        method: 'PUT',
        path: '/students/${initialStudent.id}?school_id=sch-1',
        data: updateData,
      );

      expect(success, true);
      expect(mockClient.lastMethod, 'PUT');
      final sentData = mockClient.lastData as Map<String, dynamic>;
      expect(sentData['academic_year_id'], 'ay-2026');
      expect(sentData['class_id'], 'class-8');
      expect(sentData['section_id'], 'sec-c');
    });

    test('Backend Idempotence: Passing existing placement succeeds without duplicate error', () async {
      final mockClient = MockApiClient();
      final notifier = StudentActionNotifier(mockClient);

      // Even if existing placement is passed explicitly:
      final payload = {
        'first_name': 'Jahnavi',
        'academic_year_id': 'ay-1',
        'class_id': 'class-1',
        'section_id': 'sec-1',
      };

      final success = await notifier.execute(
        method: 'PUT',
        path: '/students/stud-123?school_id=school-1',
        data: payload,
      );

      expect(success, true);
      expect(mockClient.lastMethod, 'PUT');
      final sentData = mockClient.lastData as Map<String, dynamic>;
      expect(sentData['class_id'], 'class-1');
      expect(sentData['section_id'], 'sec-1');
    });
  });
}
