import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/shell/presentation/admin_shell.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/promotions/presentation/pages/promotions_screen.dart';

class FakeTestSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

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

class FakePromotionsApiClient extends BaseApiClient {
  bool simulatePreview = false;

  FakePromotionsApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/schools/school_1/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2026-2027',
            'code': 'AY26-27',
            'start_date': '2026-06-01',
            'end_date': '2027-04-30',
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1
          },
          {
            'id': 'ay_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2027-2028',
            'code': 'AY27-28',
            'start_date': '2027-06-01',
            'end_date': '2028-04-30',
            'status': 'ACTIVE',
            'is_current': false,
            'version': 1
          }
        ]
      }));
    }

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'class_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'name': 'Class 10',
            'code': 'CLASS-10',
            'level': 10,
            'category': 'HIGH',
            'capacity': 40,
            'next_class_id': 'class_2',
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1
          },
          {
            'id': 'class_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_2',
            'name': 'Class 11',
            'code': 'CLASS-11',
            'level': 11,
            'category': 'HIGH',
            'capacity': 40,
            'next_class_id': null,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1
          }
        ]
      }));
    }

    if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sec_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'name': 'A',
            'code': 'SEC-10A',
            'capacity': 10,
            'sort_order': 1,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1
          },
          {
            'id': 'sec_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_2',
            'class_id': 'class_2',
            'name': 'A',
            'code': 'SEC-11A',
            'capacity': 10,
            'sort_order': 1,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1
          }
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not mocked', type: ApiFailureType.unknown));
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
    if (path.contains('/classes/class_1/promote')) {
      return ApiResult.success(mapper({
        'data': {
          'total_students': 1,
          'eligible': 1,
          'conditional': 0,
          'detained': 0,
          'graduated': 0,
          'blocked': 0,
          'promoted_students': [
            {
              'student_id': 'student_1',
              'name': 'Promo Student',
              'previous_section_id': 'sec_1',
              'new_section_id': 'sec_2',
              'status': 'PROMOTED'
            }
          ],
          'failures': [],
          'settings': {
            'last_promotion_execution': '2026-08-14T20:00:00Z'
          }
        }
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not mocked', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakePromotionsApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakePromotionsApiClient();
  });

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Student Promotion UI Feature Tests', () {
    testWidgets('1. Sidebar navigates to Promotions', (tester) async {
      setupViewport(tester);
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AdminShell(child: child),
            routes: [
              GoRoute(path: '/dashboard', builder: (context, state) => const Scaffold(body: Text('Dashboard Page'))),
              GoRoute(path: '/promotions', builder: (context, state) => const Scaffold(body: Text('Promotions Page'))),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
            apiClientProvider.overrideWithValue(fakeApiClient),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final promotionsTile = find.widgetWithText(ListTile, 'Promotions');
      expect(promotionsTile, findsOneWidget);
      await tester.tap(promotionsTile);
      await tester.pumpAndSettle();

      expect(find.text('Promotions Page'), findsOneWidget);
    });

    testWidgets('2. Promotions screen loads configuration dropdowns and mapping grid', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const PromotionsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Student Promotions & Rollover'), findsOneWidget);
      expect(find.byKey(const Key('promotion_source_ay_dropdown')), findsOneWidget);
      
      // Tap Source Academic Year
      await tester.tap(find.byKey(const Key('promotion_source_ay_dropdown')));
      await tester.pumpAndSettle();
      
      // Select Source AY
      await tester.tap(find.text('2026-2027').last);
      await tester.pumpAndSettle();

      // Tap Source Class
      await tester.tap(find.byKey(const Key('promotion_source_class_dropdown')));
      await tester.pumpAndSettle();
      
      // Select Source Class
      await tester.tap(find.text('Class 10').last);
      await tester.pumpAndSettle();

      // Should auto-resolve and show promotion target next class info
      expect(find.textContaining('Promotion Target: Class 11 (Code: CLASS-11)'), findsOneWidget);

      // Select Target Academic Year
      await tester.tap(find.byKey(const Key('promotion_target_ay_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027-2028 (Active)').last);
      await tester.pumpAndSettle();

      // Sections mapping grid should be visible
      expect(find.textContaining('Map each section of Class 10 to a section of Class 11:'), findsOneWidget);
      expect(find.text('Section A'), findsOneWidget);
    });

    testWidgets('3. Previewing promotion renders metrics breakdown', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const PromotionsScreen()));
      await tester.pumpAndSettle();

      // 1. Select Source AY
      await tester.tap(find.byKey(const Key('promotion_source_ay_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-2027').last);
      await tester.pumpAndSettle();

      // 2. Select Source Class
      await tester.tap(find.byKey(const Key('promotion_source_class_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class 10').last);
      await tester.pumpAndSettle();

      // 3. Select Target AY
      await tester.tap(find.byKey(const Key('promotion_target_ay_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027-2028 (Active)').last);
      await tester.pumpAndSettle();

      // 4. Select Section mapping
      await tester.tap(find.byKey(const Key('section_map_sec_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Section A (Cap: 10)').last);
      await tester.pumpAndSettle();

      // 5. Tap Preview
      final previewBtn = find.byKey(const Key('btn_preview_promotion'));
      expect(previewBtn, findsOneWidget);
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      // 6. Renders results
      expect(find.text('Promotion Preview Results'), findsOneWidget);
      expect(find.text('Promoted'), findsWidgets);
      expect(find.text('Promo Student'), findsOneWidget);
    });
  });
}
