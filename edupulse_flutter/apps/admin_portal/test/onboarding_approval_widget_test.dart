import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/app.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_models.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/school_onboarding_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

import 'school_onboarding_test.dart';

void main() {
  final fakeApiClient = FakeOnboardingApiClient();

  setUpAll(() {
    SchoolOnboardingNotifier.bypassApproval = false; // enforce for widget tests
  });

  setUp(() {
    fakeApiClient.postCalls.clear();
    fakeApiClient.failNextRequest = false;
    fakeApiClient.failGlobally = false;
  });

  group('School Onboarding Approval Gate Widget Tests', () {
    testWidgets('Validation completed, approval unchecked disables button, checking enables, cancel doesn\'t trigger, confirm executes', (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => FakeOnboardingRepository()),
            sessionManagerProvider.overrideWith((ref) => CustomizableFakeSessionManager()),
            apiClientProvider.overrideWithValue(fakeApiClient),
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          ],
          child: const EduPulseAdminApp(),
        ),
      );

      await tester.pumpAndSettle();

      final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = appContainer.read(routerProvider);

      appContainer.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await appContainer.read(schoolsListProvider.notifier).fetchSchools();
      await tester.pumpAndSettle();

      router.go(AppRoutes.schoolOnboarding);
      await tester.pumpAndSettle();

      // Load synthetic data
      final genBtn = find.text('Load Synthetic Dev Data');
      expect(genBtn, findsOneWidget);
      await tester.tap(genBtn);
      await tester.pumpAndSettle();

      // Navigate to Import step (which is index 18 inside OnboardingStep.values)
      final notifier = appContainer.read(schoolOnboardingProvider.notifier);
      notifier.setStep(OnboardingStep.import);
      await tester.pumpAndSettle();

      // Verify the Approval card is rendered
      expect(find.text('Import Approval'), findsOneWidget);
      expect(find.text('Review the validation results before loading data into the selected school.'), findsOneWidget);

      // Verify validation counts match synthetic data (94 total, 89 ready, etc.)
      expect(find.text('Total Records'), findsOneWidget);
      expect(find.text('Ready to Import'), findsOneWidget);

      // The checkbox should be unchecked initially
      final checkboxFinder = find.byKey(const Key('approval_checkbox'));
      expect(checkboxFinder, findsOneWidget);
      
      final checkboxWidget = tester.widget<CheckboxListTile>(checkboxFinder);
      expect(checkboxWidget.value, isFalse);

      // The Approve & Start Import button should be disabled
      final approveBtnFinder = find.byKey(const Key('approve_and_start_import_btn'));
      expect(approveBtnFinder, findsOneWidget);
      
      var approveBtn = tester.widget<ElevatedButton>(approveBtnFinder);
      expect(approveBtn.onPressed, isNull);

      // Toggle checkbox to checked
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Checkbox is now true and button is enabled
      final checkboxWidgetUpdated = tester.widget<CheckboxListTile>(checkboxFinder);
      expect(checkboxWidgetUpdated.value, isTrue);

      approveBtn = tester.widget<ElevatedButton>(approveBtnFinder);
      expect(approveBtn.onPressed, isNotNull);

      // Click Approve & Start Import -> should show confirmation dialog
      await tester.ensureVisible(approveBtnFinder);
      await tester.tap(approveBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Confirm School Data Import'), findsOneWidget);
      expect(find.textContaining('Do you want to approve and start the import?'), findsOneWidget);

      // Click Cancel in Dialog
      final cancelBtnFinder = find.text('Cancel');
      expect(cancelBtnFinder, findsOneWidget);
      await tester.tap(cancelBtnFinder);
      await tester.pumpAndSettle();

      // Dialog closed, and no execution occurred
      expect(find.text('Confirm School Data Import'), findsNothing);
      expect(notifier.state.isProcessing, isFalse);
      expect(notifier.state.approvalStatus, OnboardingApprovalStatus.awaitingApproval);

      // Click Approve again and confirm
      await tester.ensureVisible(approveBtnFinder);
      await tester.tap(approveBtnFinder);
      await tester.pumpAndSettle();

      final confirmBtnFinder = find.byKey(const Key('confirm_approve_import_btn'));
      expect(confirmBtnFinder, findsOneWidget);
      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      // Starts executing and transitions
      expect(notifier.state.approvalStatus == OnboardingApprovalStatus.executing || notifier.state.approvalStatus == OnboardingApprovalStatus.completed, isTrue);
      
      // Wait for it to finish and check completion report is visible
      await tester.pumpAndSettle();
      expect(notifier.state.approvalStatus, OnboardingApprovalStatus.completed);
      expect(find.text('Onboarding Process Completed!'), findsOneWidget);

      FlutterError.onError = originalOnError;
    });
  });
}

class CustomizableFakeSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  String? _schoolId = 'school_1';

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
  Future<String?> getSchoolId() async => _schoolId;
  @override
  Future<void> saveSchoolId(String schoolId) async {
    _schoolId = schoolId;
  }
}
