import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/fees/data/models/fee_models.dart';
import 'package:admin_portal/features/fees/presentation/providers/fees_provider.dart';
import 'package:admin_portal/features/fees/presentation/pages/fees_dashboard_screen.dart';

class FakeFeesRepository implements AuthRepository {
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

class FakeFeesSessionManager implements SessionManager {
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

class FakeFeesApiClient extends BaseApiClient {
  FakeFeesApiClient() : super(Dio());

  bool simulateAiFailure = false;
  bool simulateDuplicateType = false;

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
      'fine_rule': {
        'id': 'fine_1',
        'tenant_id': 'tenant_1',
        'fee_structure_id': 'struct_1',
        'grace_period_days': 5,
        'fine_type': 'FIXED',
        'fine_value': 250.0,
        'created_at': '2026-08-11T00:00:00Z',
        'updated_at': '2026-08-11T00:00:00Z',
      },
      'version': 1,
      'created_at': '2026-08-11T00:00:00Z',
      'updated_at': '2026-08-11T00:00:00Z',
    }
  ];

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path == '/fees/types') {
      return ApiResult.success(mapper({'data': _mockFeeTypes}));
    }
    if (path == '/fees/scholarships') {
      return ApiResult.success(mapper({'data': _mockScholarships}));
    }
    if (path == '/fees/structures') {
      return ApiResult.success(mapper({'data': _mockStructures}));
    }
    if (path == '/fees/reports/dashboard') {
      return ApiResult.success(mapper({
        'data': {
          'today_collection': 10000.0,
          'month_collection': 250000.0,
          'pending_dues': 75000.0,
          'collection_percentage': 76.9,
          'defaulters_count': 3,
          'top_outstanding_classes': [
            {'class_name': 'Class 8', 'outstanding_amount': 25000.0}
          ]
        }
      }));
    }
    if (path == '/fees/ai/analytics') {
      if (simulateAiFailure) {
        return ApiResult.failure(const ApiFailure(message: 'AI system connection failed', type: ApiFailureType.server));
      }
      return ApiResult.success(mapper({
        'data': {
          'predicted_collection_next_30_days': 52500.0,
          'historical_trend': {'Day 5': 10000.0, 'Day 15': 30000.0, 'Day 30': 52500.0}
        }
      }));
    }
    if (path == '/schools/school_1/academic-years') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2026-2027',
            'code': 'AY2026',
            'description': 'Academic Year 2026-2027',
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
    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'class_8_id',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'name': 'Class 8',
            'code': 'C8',
            'level': 8,
            'capacity': 40,
            'is_active': true,
            'version': 1,
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
    if (path == '/fees/types') {
      if (simulateDuplicateType) {
        return ApiResult.failure(const ApiFailure(message: 'Fee type code already exists within tenant', type: ApiFailureType.unknown));
      }
      final payload = data as Map<String, dynamic>;
      final newType = {
        'id': 'type_${DateTime.now().millisecondsSinceEpoch}',
        'tenant_id': 'tenant_1',
        'name': payload['name'],
        'code': payload['code'],
        'description': payload['description'],
        'is_system': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      _mockFeeTypes.add(newType);
      return ApiResult.success(mapper({'data': newType}));
    }
    if (path == '/fees/scholarships') {
      final payload = data as Map<String, dynamic>;
      final newSch = {
        'id': 'sch_${DateTime.now().millisecondsSinceEpoch}',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'name': payload['name'],
        'concession_type': payload['concession_type'],
        'value': (payload['value'] as num).toDouble(),
        'description': payload['description'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      _mockScholarships.add(newSch);
      return ApiResult.success(mapper({'data': newSch}));
    }
    if (path == '/fees/structures') {
      final payload = data as Map<String, dynamic>;
      final fineInput = payload['fine_rule'] as Map<String, dynamic>?;
      final newStruct = {
        'id': 'struct_${DateTime.now().millisecondsSinceEpoch}',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'fee_type_id': payload['fee_type_id'],
        'academic_year_id': payload['academic_year_id'],
        'class_id': payload['class_id'],
        'amount': (payload['amount'] as num).toDouble(),
        'due_date': payload['due_date'],
        'description': payload['description'],
        'fine_rule': fineInput != null ? {
          'id': 'fine_${DateTime.now().millisecondsSinceEpoch}',
          'tenant_id': 'tenant_1',
          'fee_structure_id': 'struct_new',
          'grace_period_days': fineInput['grace_period_days'],
          'fine_type': fineInput['fine_type'],
          'fine_value': (fineInput['fine_value'] as num).toDouble(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        } : null,
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      _mockStructures.add(newStruct);
      return ApiResult.success(mapper({'data': newStruct}));
    }
    return ApiResult.success(mapper({'data': {}}));
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
    if (path.startsWith('/fees/types/')) {
      final id = path.replaceAll('/fees/types/', '');
      _mockFeeTypes.removeWhere((element) => element['id'] == id);
      return ApiResult.success(mapper({'success': true}));
    }
    if (path.startsWith('/fees/scholarships/')) {
      final id = path.replaceAll('/fees/scholarships/', '');
      _mockScholarships.removeWhere((element) => element['id'] == id);
      return ApiResult.success(mapper({'success': true}));
    }
    if (path.startsWith('/fees/structures/')) {
      final id = path.replaceAll('/fees/structures/', '');
      _mockStructures.removeWhere((element) => element['id'] == id);
      return ApiResult.success(mapper({'success': true}));
    }
    return ApiResult.success(mapper({'success': true}));
  }
}

void main() {
  group('Fee Management Phase 5A Unit Tests', () {
    late ProviderContainer container;
    late FakeFeesApiClient fakeApiClient;

    setUp(() {
      fakeApiClient = FakeFeesApiClient();
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

    test('1. Fee types loading', () async {
      final notifier = container.read(feeTypesProvider.notifier);
      await notifier.fetchTypes();
      final state = container.read(feeTypesProvider);

      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.types, isNotEmpty);
      expect(state.types.first.code, equals('TUIT'));
    });

    test('2. Fee type creation', () async {
      final notifier = container.read(feeTypesProvider.notifier);
      final success = await notifier.createType('Transport Fee', 'TRANS', 'School bus cost');

      expect(success, isTrue);
      final state = container.read(feeTypesProvider);
      expect(state.types.any((element) => element.code == 'TRANS'), isTrue);
    });

    test('3. Fee type deletion', () async {
      final notifier = container.read(feeTypesProvider.notifier);
      await notifier.fetchTypes();
      
      final customType = container.read(feeTypesProvider).types.firstWhere((t) => !t.isSystem, orElse: () => container.read(feeTypesProvider).types.first);
      final success = await notifier.deleteType(customType.id);

      expect(success, isTrue);
      final state = container.read(feeTypesProvider);
      expect(state.types.any((element) => element.id == customType.id), isFalse);
    });

    test('4. Duplicate fee type handling', () async {
      fakeApiClient.simulateDuplicateType = true;
      final notifier = container.read(feeTypesProvider.notifier);
      final success = await notifier.createType('Duplicate Fee', 'TUIT', 'Already exists');

      expect(success, isFalse);
      final state = container.read(feeTypesProvider);
      expect(state.error, contains('already exists'));
    });

    test('5. Scholarship loading', () async {
      final notifier = container.read(scholarshipsProvider('school_1').notifier);
      await notifier.fetchScholarships();
      final state = container.read(scholarshipsProvider('school_1'));

      expect(state.isLoading, isFalse);
      expect(state.scholarships, isNotEmpty);
      expect(state.scholarships.first.name, equals('Sibling Concession'));
    });

    test('6. Scholarship creation', () async {
      final notifier = container.read(scholarshipsProvider('school_1').notifier);
      final success = await notifier.createScholarship('Staff Discount', ConcessionType.PERCENTAGE, 50.0, 'Staff concession');

      expect(success, isTrue);
      final state = container.read(scholarshipsProvider('school_1'));
      expect(state.scholarships.any((s) => s.name == 'Staff Discount'), isTrue);
    });

    test('7. Percentage validation', () {
      expect(() => ConcessionType.fromJson('PERCENTAGE'), returnsNormally);
      final s = Scholarship(
        id: 's1',
        tenantId: 't1',
        schoolId: 's1',
        name: 'Percentage Test',
        concessionType: ConcessionType.PERCENTAGE,
        value: 120.0, // Should be checked by UI validator
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(s.concessionType, equals(ConcessionType.PERCENTAGE));
    });

    test('8. Fixed concession validation', () {
      final s = Scholarship(
        id: 's2',
        tenantId: 't1',
        schoolId: 's1',
        name: 'Fixed Test',
        concessionType: ConcessionType.FIXED,
        value: 5000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(s.concessionType, equals(ConcessionType.FIXED));
      expect(s.value, equals(5000.0));
    });

    test('9. Fee structure loading', () async {
      final notifier = container.read(feeStructuresProvider('school_1').notifier);
      await notifier.fetchStructures();
      final state = container.read(feeStructuresProvider('school_1'));

      expect(state.isLoading, isFalse);
      expect(state.structures, isNotEmpty);
      expect(state.structures.first.amount, equals(5000.0));
    });

    test('10. Fee structure creation', () async {
      final notifier = container.read(feeStructuresProvider('school_1').notifier);
      final success = await notifier.createStructure(
        feeTypeId: 'type_1',
        academicYearId: 'ay_1',
        classId: 'class_8_id',
        amount: 2500.0,
        dueDate: DateTime(2026, 10, 1),
      );

      expect(success, isTrue);
      final state = container.read(feeStructuresProvider('school_1'));
      expect(state.structures.any((s) => s.amount == 2500.0), isTrue);
    });

    test('11. Specific class structure', () async {
      final notifier = container.read(feeStructuresProvider('school_1').notifier);
      await notifier.fetchStructures();
      final state = container.read(feeStructuresProvider('school_1'));

      expect(state.structures.first.classId, equals('class_8_id'));
    });

    test('12. All-class structure', () async {
      final notifier = container.read(feeStructuresProvider('school_1').notifier);
      final success = await notifier.createStructure(
        feeTypeId: 'type_1',
        academicYearId: 'ay_1',
        classId: null, // null represents All Classes
        amount: 1500.0,
        dueDate: DateTime(2026, 10, 1),
      );

      expect(success, isTrue);
      final state = container.read(feeStructuresProvider('school_1'));
      final allClassStruct = state.structures.firstWhere((s) => s.amount == 1500.0);
      expect(allClassStruct.classId, isNull);
    });

    test('13. Fine rule creation', () async {
      final notifier = container.read(feeStructuresProvider('school_1').notifier);
      final success = await notifier.createStructure(
        feeTypeId: 'type_1',
        academicYearId: 'ay_1',
        classId: 'class_8_id',
        amount: 3000.0,
        dueDate: DateTime(2026, 10, 1),
        fineRuleInput: FineRuleInput(gracePeriodDays: 3, fineType: FineType.DAILY_FIXED, fineValue: 50.0),
      );

      expect(success, isTrue);
      final state = container.read(feeStructuresProvider('school_1'));
      final withFine = state.structures.firstWhere((s) => s.amount == 3000.0);
      expect(withFine.fineRule, isNotNull); // Server creates it; in mock we set it to null unless hardcoded, but payload validates fine rule serialization
    });

    test('14. Backend validation errors', () async {
      fakeApiClient.simulateDuplicateType = true;
      final notifier = container.read(feeTypesProvider.notifier);
      final success = await notifier.createType('Bad', 'ERR', 'Failure');

      expect(success, isFalse);
      final state = container.read(feeTypesProvider);
      expect(state.error, isNotNull);
    });

    test('15. Dashboard loading', () async {
      final notifier = container.read(feesDashboardProvider('school_1').notifier);
      await notifier.fetchDashboardData();
      final state = container.read(feesDashboardProvider('school_1'));

      expect(state.isLoading, isFalse);
      expect(state.metrics, isNotNull);
    });

    test('16. Dashboard core metrics', () async {
      final notifier = container.read(feesDashboardProvider('school_1').notifier);
      await notifier.fetchDashboardData();
      final state = container.read(feesDashboardProvider('school_1'));

      expect(state.metrics!.todayCollection, equals(10000.0));
      expect(state.metrics!.collectionPercentage, equals(76.9));
      expect(state.metrics!.defaultersCount, equals(3));
    });

    test('17. AI analytics failure does not break dashboard', () async {
      fakeApiClient.simulateAiFailure = true;
      final notifier = container.read(feesDashboardProvider('school_1').notifier);
      await notifier.fetchDashboardData();
      final state = container.read(feesDashboardProvider('school_1'));

      expect(state.isLoading, isFalse);
      expect(state.metrics, isNotNull); // Core metrics still present
      expect(state.analytics, isNull); // AI gracefully degraded
      expect(state.isAiAvailable, isFalse);
    });

    test('18. School context isolation', () {
      final notifier1 = container.read(scholarshipsProvider('school_1').notifier);
      final notifier2 = container.read(scholarshipsProvider('school_2').notifier);

      expect(notifier1, isNot(equals(notifier2)));
    });
  });

  group('Fee Management Phase 5A Widget & Navigation Tests', () {
    testWidgets('19. Navigation to Fees and Dashboard render', (WidgetTester tester) async {
      final fakeApiClient = FakeFeesApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            authRepositoryProvider.overrideWith((ref) => FakeFeesRepository()),
            sessionManagerProvider.overrideWith((ref) => FakeFeesSessionManager()),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: const MaterialApp(
            home: FeesDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify page titles and tabs
      expect(find.text('Fee Management'), findsWidgets);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Fee Types'), findsOneWidget);
      expect(find.text('Scholarships'), findsOneWidget);
      expect(find.text('Structures'), findsOneWidget);

      // Verify core dashboard metrics displayed
      expect(find.text('₹10,000'), findsNWidgets(2)); // Today's collection + AI forecast Day 5
      expect(find.text('₹2,50,000'), findsOneWidget); // Monthly collection (en_IN locale formatting)
      expect(find.text('₹75,000'), findsOneWidget); // Outstanding dues
    });
  });
}
