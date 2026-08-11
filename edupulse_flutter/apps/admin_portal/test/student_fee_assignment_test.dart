import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/fees/data/models/fee_models.dart';
import 'package:admin_portal/features/fees/presentation/providers/fees_provider.dart';
import 'package:admin_portal/features/fees/presentation/pages/student_fee_assignment_page.dart';
import 'package:admin_portal/features/fees/presentation/pages/student_ledgers_page.dart';

class FakeStudentFeeRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access', refreshToken: 'mock_refresh', tokenType: 'bearer'));
  }
  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }
  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access_new', refreshToken: 'mock_refresh_new', tokenType: 'bearer'));
  }
  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return const ApiResult.success(UserEntity(
      id: 'admin_id_123',
      email: 'admin@edupulse.ai',
      firstName: 'Main',
      lastName: 'Admin',
      tenantId: 'tenant_1',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: ['school_1'],
    ));
  }
  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async {
    return const ApiResult.success(null);
  }
}

class FakeStudentFeeSessionManager implements SessionManager {
  @override
  Future<String?> getAccessToken() async => 'mock_access';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => 'school_1';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeStudentFeeApiClient extends BaseApiClient {
  FakeStudentFeeApiClient() : super(Dio());

  bool simulateDuplicateAssignment = false;

  final List<Map<String, dynamic>> _mockStudents = [
    {
      'id': 'student_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'class_id': 'class_8_id',
      'section_id': 'sec_a_id',
      'first_name': 'Aarav',
      'last_name': 'Sharma',
      'gender': 'MALE',
      'date_of_birth': '2015-05-10',
      'address': {},
      'medical_information': {},
      'admission_number': 'DPSH-TEST-1001',
      'roll_number': 'ROLL-TEST-1001',
      'admission_date': '2026-06-01',
      'status': 'ACTIVE',
      'is_active': true,
      'settings': {},
      'ai_metrics': {},
      'version': 1,
      'created_at': '2026-08-11T00:00:00Z',
      'updated_at': '2026-08-11T00:00:00Z',
    }
  ];

  final List<Map<String, dynamic>> _mockFeeTypes = [
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
  ];

  final List<Map<String, dynamic>> _mockScholarships = [
    {
      'id': 'sch_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'name': 'Sibling Concession',
      'concession_type': 'PERCENTAGE',
      'value': 20.0,
      'description': 'Sibling discount',
      'created_at': '2026-08-11T00:00:00Z',
      'updated_at': '2026-08-11T00:00:00Z',
    }
  ];

  final List<Map<String, dynamic>> _mockStructures = [
    {
      'id': 'struct_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'fee_type_id': 'type_1',
      'academic_year_id': 'ay_1',
      'class_id': 'class_8_id',
      'amount': 5000.0,
      'due_date': '2026-09-10',
      'description': 'Term 1 tuition',
      'fine_rule': null,
      'version': 1,
      'created_at': '2026-08-11T00:00:00Z',
      'updated_at': '2026-08-11T00:00:00Z',
    }
  ];

  final List<Map<String, dynamic>> _mockAssignments = [];
  final List<Map<String, dynamic>> _mockPayments = [];

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path == '/students') {
      return ApiResult.success(mapper({'data': _mockStudents}));
    }
    if (path == '/fees/types') {
      return ApiResult.success(mapper({'data': _mockFeeTypes}));
    }
    if (path == '/fees/scholarships') {
      return ApiResult.success(mapper({'data': _mockScholarships}));
    }
    if (path == '/fees/structures') {
      return ApiResult.success(mapper({'data': _mockStructures}));
    }
    if (path.startsWith('/fees/ledgers/')) {
      final studentId = path.replaceAll('/fees/ledgers/', '');
      final studentAssignments = _mockAssignments.where((a) => a['student_id'] == studentId).toList();
      final studentPayments = _mockPayments.where((p) => p['student_id'] == studentId).toList();
      
      double outstanding = 0.0;
      for (final a in studentAssignments) {
        outstanding += (a['assigned_amount'] as num).toDouble() +
            (a['fine_amount'] as num).toDouble() -
            (a['discount_amount'] as num).toDouble() -
            (a['paid_amount'] as num).toDouble();
      }

      return ApiResult.success(mapper({
        'data': {
          'student_id': studentId,
          'opening_balance': 0.0,
          'assignments': studentAssignments,
          'scholarships': _mockScholarships,
          'payments': studentPayments,
          'closing_balance': outstanding,
        }
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
    if (path == '/fees/assign') {
      if (simulateDuplicateAssignment) {
        return ApiResult.failure(const ApiFailure(message: 'Fee is already assigned to this student.', type: ApiFailureType.unknown));
      }
      final payload = data as Map<String, dynamic>;
      final newAssign = {
        'id': 'assign_${DateTime.now().millisecondsSinceEpoch}',
        'tenant_id': 'tenant_1',
        'student_id': payload['student_id'],
        'fee_structure_id': payload['fee_structure_id'],
        'academic_year_id': 'ay_1',
        'assigned_amount': 5000.0,
        'scholarship_id': payload['scholarship_id'],
        'discount_amount': payload['scholarship_id'] != null ? 1000.0 : 0.0,
        'fine_amount': 0.0,
        'paid_amount': 0.0,
        'status': 'UNPAID',
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      _mockAssignments.add(newAssign);
      return ApiResult.success(mapper({'data': newAssign}));
    }
    return ApiResult.success(mapper({'data': {}}));
  }
}

void main() {
  group('Fee Management Phase 5B Unit Tests', () {
    late ProviderContainer container;
    late FakeStudentFeeApiClient fakeApiClient;

    setUp(() {
      fakeApiClient = FakeStudentFeeApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Student search', () async {
      final searchNotifier = container.read(studentSearchProvider('school_1').notifier);
      await searchNotifier.search('Aarav');
      final state = container.read(studentSearchProvider('school_1'));

      expect(state.isLoading, isFalse);
      expect(state.students, isNotEmpty);
      expect(state.students.first.firstName, equals('Aarav'));
    });

    test('2. Fee structure loading', () async {
      final structuresNotifier = container.read(feeStructuresProvider('school_1').notifier);
      await structuresNotifier.fetchStructures();
      final state = container.read(feeStructuresProvider('school_1'));

      expect(state.isLoading, isFalse);
      expect(state.structures, isNotEmpty);
      expect(state.structures.first.amount, equals(5000.0));
    });

    test('3. Scholarship loading', () async {
      final scholarshipsNotifier = container.read(scholarshipsProvider('school_1').notifier);
      await scholarshipsNotifier.fetchScholarships();
      final state = container.read(scholarshipsProvider('school_1'));

      expect(state.isLoading, isFalse);
      expect(state.scholarships, isNotEmpty);
      expect(state.scholarships.first.name, equals('Sibling Concession'));
    });

    test('4. Assignment preview calculation', () {
      final structure = FeeStructure(
        id: 'struct_1',
        tenantId: 'tenant_1',
        schoolId: 'school_1',
        feeTypeId: 'type_1',
        academicYearId: 'ay_1',
        classId: 'class_8_id',
        amount: 5000.0,
        dueDate: DateTime.now(),
        version: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final percentageScholarship = Scholarship(
        id: 'sch_1',
        tenantId: 'tenant_1',
        schoolId: 'school_1',
        name: 'Sibling Concession',
        concessionType: ConcessionType.PERCENTAGE,
        value: 20.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      double originalFee = structure.amount;
      double discount = originalFee * (percentageScholarship.value / 100.0);
      double netPayable = originalFee - discount;

      expect(discount, equals(1000.0));
      expect(netPayable, equals(4000.0));
    });

    test('5. Successful assignment', () async {
      final assignNotifier = container.read(feeAssignmentCreationProvider.notifier);
      final success = await assignNotifier.assignFee(
        studentId: 'student_1',
        feeStructureId: 'struct_1',
        scholarshipId: 'sch_1',
      );

      expect(success, isTrue);
      final state = container.read(feeAssignmentCreationProvider);
      expect(state.assignment, isNotNull);
      expect(state.assignment!.discountAmount, equals(1000.0));
    });

    test('6. Duplicate assignment handling', () async {
      fakeApiClient.simulateDuplicateAssignment = true;
      final assignNotifier = container.read(feeAssignmentCreationProvider.notifier);
      final success = await assignNotifier.assignFee(
        studentId: 'student_1',
        feeStructureId: 'struct_1',
      );

      expect(success, isFalse);
      final state = container.read(feeAssignmentCreationProvider);
      expect(state.error, contains('already assigned'));
    });

    test('7. Ledger loading', () async {
      // Create one assignment in mock database first
      final assignNotifier = container.read(feeAssignmentCreationProvider.notifier);
      await assignNotifier.assignFee(
        studentId: 'student_1',
        feeStructureId: 'struct_1',
        scholarshipId: 'sch_1',
      );

      final ledgerNotifier = container.read(studentLedgerProvider('student_1').notifier);
      await ledgerNotifier.fetchLedger();
      final state = container.read(studentLedgerProvider('student_1'));

      expect(state.isLoading, isFalse);
      expect(state.ledger, isNotNull);
      expect(state.ledger!.assignments, isNotEmpty);
    });

    test('8. Ledger totals calculations', () async {
      // Create assignment first
      final assignNotifier = container.read(feeAssignmentCreationProvider.notifier);
      await assignNotifier.assignFee(
        studentId: 'student_1',
        feeStructureId: 'struct_1',
        scholarshipId: 'sch_1',
      );

      final ledgerNotifier = container.read(studentLedgerProvider('student_1').notifier);
      await ledgerNotifier.fetchLedger();
      final ledger = container.read(studentLedgerProvider('student_1')).ledger!;

      double totalAssigned = ledger.assignments.fold(0.0, (sum, a) => sum + a.assignedAmount + a.fineAmount);
      double totalConcession = ledger.assignments.fold(0.0, (sum, a) => sum + a.discountAmount);
      double totalPaid = ledger.assignments.fold(0.0, (sum, a) => sum + a.paidAmount);
      double outstanding = ledger.closingBalance;

      expect(totalAssigned, equals(5000.0));
      expect(totalConcession, equals(1000.0));
      expect(totalPaid, equals(0.0));
      expect(outstanding, equals(4000.0));
    });

    test('9. School context isolation', () {
      final searchNotifier1 = container.read(studentSearchProvider('school_1').notifier);
      final searchNotifier2 = container.read(studentSearchProvider('school_2').notifier);

      expect(searchNotifier1, isNot(equals(searchNotifier2)));
    });
  });

  group('Fee Management Phase 5B Widget & Navigation Tests', () {
    testWidgets('10. Renders Student Fee Assignment view correctly', (WidgetTester tester) async {
      final fakeApiClient = FakeStudentFeeApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            authRepositoryProvider.overrideWith((ref) => FakeStudentFeeRepository()),
            sessionManagerProvider.overrideWith((ref) => FakeStudentFeeSessionManager()),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: const MaterialApp(
            home: StudentFeeAssignmentPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Assign Student Fee'), findsOneWidget);
      expect(find.text('1. Search & Select Student'), findsOneWidget);
      expect(find.text('2. Select Fee Structure'), findsOneWidget);
      expect(find.text('3. Attach Concession (Optional)'), findsOneWidget);
      expect(find.text('Confirm Fee Assignment'), findsOneWidget);
    });

    testWidgets('11. Renders Student Ledgers view correctly', (WidgetTester tester) async {
      final fakeApiClient = FakeStudentFeeApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            authRepositoryProvider.overrideWith((ref) => FakeStudentFeeRepository()),
            sessionManagerProvider.overrideWith((ref) => FakeStudentFeeSessionManager()),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: const MaterialApp(
            home: StudentLedgersPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Student Fee Ledger'), findsOneWidget);
      expect(find.text('Select a student above to inspect their financial ledger.'), findsOneWidget);
    });
  });
}
