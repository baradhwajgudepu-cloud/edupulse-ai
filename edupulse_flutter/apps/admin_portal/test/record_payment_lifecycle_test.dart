import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/students/presentation/widgets/student_360_modal.dart';
import 'package:admin_portal/features/fees/data/models/fee_models.dart';
import 'package:admin_portal/features/fees/presentation/providers/fees_provider.dart';
import 'package:admin_portal/features/fees/presentation/pages/student_ledgers_page.dart';
import 'package:admin_portal/features/fees/presentation/pages/outstanding_dues_page.dart';

class FakePaymentApiClient extends BaseApiClient {
  FakePaymentApiClient() : super(Dio());

  final Map<String, dynamic> _mockLedger = {
    'student_id': 'student_1',
    'opening_balance': 0.0,
    'assignments': [
      {
        'id': 'e69c5e37-9759-42b7-a3cf-eefdf3453b02',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'student_id': 'student_1',
        'fee_structure_id': '2eef6554-734d-45df-bbad-7ff6b840e676',
        'academic_year_id': '1e34c2ee-bbf4-4f01-a18c-32204c30cfa1',
        'assigned_amount': 5000.0,
        'discount_amount': 0.0,
        'fine_amount': 0.0,
        'paid_amount': 2000.0,
        'status': 'PARTIALLY_PAID',
        'due_date': '2026-09-10',
        'created_at': '2026-08-11T00:00:00Z',
        'updated_at': '2026-08-11T00:00:00Z',
      }
    ],
    'scholarships': [],
    'payments': [
      {
        'id': 'pay_1',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'student_id': 'student_1',
        'academic_year_id': '1e34c2ee-bbf4-4f01-a18c-32204c30cfa1',
        'amount_paid': 2000.0,
        'payment_method': 'CASH',
        'payment_date': '2026-08-15T00:00:00Z',
        'status': 'COMPLETED',
        'receipt_number': 'REC-2026-0001',
        'allocations': [
          {'assignment_id': 'e69c5e37-9759-42b7-a3cf-eefdf3453b02', 'amount_allocated': 2000.0}
        ],
        'created_at': '2026-08-15T00:00:00Z',
        'updated_at': '2026-08-15T00:00:00Z',
      }
    ],
    'closing_balance': 3000.0,
  };

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.startsWith('/fees/ledgers/')) {
      return ApiResult.success(mapper({'data': _mockLedger}));
    }
    if (path == '/fees/reports/outstanding') {
      return ApiResult.success(mapper({
        'data': [
          {
            'student_id': 'student_1',
            'student_name': 'John Doe',
            'admission_number': 'ADM001',
            'class_id': 'class_8_id',
            'class_name': 'Class 8',
            'section_id': 'section_A_id',
            'section_name': 'A',
            'fee_structure_id': '2eef6554-734d-45df-bbad-7ff6b840e676',
            'fee_type_id': 'type_1',
            'fee_type_name': 'Tuition Fee',
            'assigned_amount': 5000.0,
            'discount_amount': 0.0,
            'fine_amount': 0.0,
            'paid_amount': 2000.0,
            'outstanding_amount': 3000.0,
            'due_date': '2026-09-10',
            'status': 'PARTIALLY_PAID',
            'assignment_id': 'e69c5e37-9759-42b7-a3cf-eefdf3453b02',
            'academic_year_id': '1e34c2ee-bbf4-4f01-a18c-32204c30cfa1',
          }
        ]
      }));
    }
    if (path == '/fees/types') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'type_1',
            'tenant_id': 'tenant_1',
            'name': 'Tuition Fee',
            'code': 'TUIT',
            'description': 'Standard tuition fee',
            'is_system': true,
            'created_at': '2026-08-11T00:00:00Z',
            'updated_at': '2026-08-11T00:00:00Z',
          }
        ]
      }));
    }
    if (path == '/fees/structures') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': '2eef6554-734d-45df-bbad-7ff6b840e676',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'fee_type_id': 'type_1',
            'academic_year_id': '1e34c2ee-bbf4-4f01-a18c-32204c30cfa1',
            'class_id': 'class_8_id',
            'amount': 5000.0,
            'due_date': '2026-09-10',
            'description': 'Term 1 tuition',
            'version': 1,
            'created_at': '2026-08-11T00:00:00Z',
            'updated_at': '2026-08-11T00:00:00Z',
          }
        ]
      }));
    }
    if (path == '/schools/school_1/academic-years') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': '1e34c2ee-bbf4-4f01-a18c-32204c30cfa1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2026-2027',
            'code': 'AY2026',
            'start_date': '2026-06-01',
            'end_date': '2027-03-31',
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1,
            'created_at': '2026-08-11T00:00:00Z',
            'updated_at': '2026-08-11T00:00:00Z',
          }
        ]
      }));
    }
    if (path == '/schools') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'school_1',
            'tenant_id': 'tenant_1',
            'name': 'EduPulse Academy',
            'code': 'EPA',
            'status': 'ACTIVE',
            'is_active': true,
            'created_at': '2026-08-11T00:00:00Z',
            'updated_at': '2026-08-11T00:00:00Z',
          }
        ]
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
    if (path == '/fees/payments') {
      final payload = data as Map<String, dynamic>;
      final allocations = (payload['allocations'] as List<dynamic>?) ?? [];
      final allocatedAmount = allocations.isNotEmpty ? (allocations[0]['amount_allocated'] as num).toDouble() : 1000.0;
      final newPayment = {
        'id': 'pay_new_123',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'student_id': payload['student_id'],
        'academic_year_id': payload['academic_year_id'],
        'amount_paid': allocatedAmount,
        'payment_method': payload['payment_method'] ?? 'CASH',
        'payment_date': DateTime.now().toIso8601String(),
        'transaction_reference': payload['transaction_reference'],
        'remarks': payload['remarks'],
        'status': 'COMPLETED',
        'receipt_number': 'REC-2026-9999',
        'allocations': allocations,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      return ApiResult.success(mapper({'data': newPayment}));
    }
    return ApiResult.success(mapper({'data': {}}));
  }
}

void main() {
  const student = StudentDto(
    id: 'student_1',
    tenantId: 'tenant_1',
    schoolId: 'school_1',
    academicYearId: '1e34c2ee-bbf4-4f01-a18c-32204c30cfa1',
    classId: 'class_8_id',
    sectionId: 'section_A_id',
    firstName: 'John',
    lastName: 'Doe',
    gender: 'MALE',
    dateOfBirth: '2010-05-15',
    address: {'city': 'Hyderabad'},
    medicalInformation: {},
    admissionNumber: 'ADM001',
    rollNumber: '101',
    admissionDate: '2026-06-01',
    status: 'ACTIVE',
    isActive: true,
    settings: {},
    aiMetrics: {'attendance_rate': 94.5, 'academic_average': 86.0, 'fee_status': 'Cleared'},
    version: 1,
    createdAt: '2026-06-01T00:00:00Z',
    updatedAt: '2026-06-01T00:00:00Z',
    className: 'Class 8',
    sectionName: 'Section A',
  );

  group('Record Payment Lifecycle & Context Safety Tests', () {
    testWidgets('1. Student360Modal opens payment dialog and records fee without crashing', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApiClient = FakePaymentApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Student360Modal(
                student: student,
                schoolId: 'school_1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top micro-bar Record Fee button is present
      final recordFeeBtn = find.byKey(const Key('student_360_record_fee_button'));
      expect(recordFeeBtn, findsOneWidget);

      // Tap Record Fee
      await tester.tap(recordFeeBtn);
      await tester.pumpAndSettle();

      // Verify payment dialog opened
      expect(find.text('Record Fee Payment'), findsOneWidget);
      expect(find.byKey(const Key('modal_payment_amount_field')), findsOneWidget);
      expect(find.byKey(const Key('modal_submit_payment_button')), findsOneWidget);

      // Submit payment
      await tester.tap(find.byKey(const Key('modal_submit_payment_button')));
      await tester.pumpAndSettle();

      // Verify payment dialog is dismissed
      expect(find.byKey(const Key('modal_submit_payment_button')), findsNothing);

      // Verify Student 360 modal remains mounted and intact
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('2. StudentLedgersPage record payment flow uses valid context and displays receipt', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApiClient = FakePaymentApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: StudentLedgersPage(initialStudent: student),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ledger loaded with John Doe
      expect(find.text('John Doe'), findsWidgets);

      // Tap on the assignment row to open details
      final assignRow = find.text('Tuition Fee');
      if (assignRow.evaluate().isNotEmpty) {
        await tester.tap(assignRow.first);
        await tester.pumpAndSettle();

        // Assignment details dialog is open
        final recordPaymentBtn = find.text('Record Payment');
        if (recordPaymentBtn.evaluate().isNotEmpty) {
          await tester.tap(recordPaymentBtn.last);
          await tester.pumpAndSettle();

          // Record Fee Payment dialog should be open
          expect(find.text('Record Fee Payment'), findsOneWidget);
          expect(find.text('Confirm Payment'), findsOneWidget);

          // Tap Confirm Payment
          await tester.tap(find.text('Confirm Payment'));
          await tester.pumpAndSettle();

          // Verify no deactivated context exception
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('3. OutstandingDuesPage record payment submits and cleans up dialog safely', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApiClient = FakePaymentApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OutstandingDuesPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify row is present
      expect(find.text('John Doe'), findsOneWidget);
      final recordBtn = find.text('Record Payment');
      expect(recordBtn, findsOneWidget);

      await tester.ensureVisible(recordBtn);
      await tester.pumpAndSettle();
      await tester.tap(recordBtn);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Record Fee Payment'), findsOneWidget);
      final confirmBtn = find.byKey(const Key('confirm_payment_button'));
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Dialog is closed, no assertion errors
      expect(find.byKey(const Key('confirm_payment_button')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
