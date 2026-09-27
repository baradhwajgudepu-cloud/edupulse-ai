import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_admin/presentation/pages/school_administration_screen.dart';
import 'package:admin_portal/features/school_admin/presentation/providers/school_admin_providers.dart';
import 'package:admin_portal/features/school_admin/data/models/school_admin_models.dart';
import 'package:admin_portal/features/payroll/presentation/providers/payroll_providers.dart';
import 'package:admin_portal/features/payroll/data/models/payroll_models.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/teachers/presentation/widgets/teacher_360_modal.dart';
import 'package:admin_portal/features/teachers/data/models/teachers_models.dart';
import 'package:admin_portal/features/teachers/data/models/teacher_360_models.dart';
import 'package:admin_portal/features/teachers/presentation/providers/teachers_providers.dart';

class FakeAuthStateNotifier extends AuthStateNotifier {
  final UserEntity _initialUser;
  FakeAuthStateNotifier(this._initialUser);

  @override
  AuthState build() => Authenticated(_initialUser);
}

class FakeSchoolsListNotifier extends StateNotifier<SchoolsListState>
    implements SchoolsListNotifier {
  FakeSchoolsListNotifier(super.state);

  @override
  Future<void> fetchSchools() async {}
}

void main() {
  const schoolId = 'sch-test-1';

  const mockUser = UserEntity(
    id: 'usr-admin-1',
    firstName: 'Admin',
    lastName: 'Officer',
    email: 'admin@telangana-model.edu',
    tenantId: 'ten-test-1',
    isSuperuser: false,
    roles: ['PRINCIPAL'],
    schools: [schoolId],
    schoolNames: {schoolId: 'Telangana Model School'},
  );

  const mockSchool = SchoolDto(
    id: schoolId,
    tenantId: 'ten-test-1',
    name: 'Telangana Model School',
    code: 'TMS01',
    board: 'STATE',
    schoolType: 'K12',
    email: 'info@tms.edu',
    isActive: true,
    status: 'ACTIVE',
    version: 1,
  );

  final mockProfile = SchoolProfileDto.fromJson({
    'id': 'prof-1',
    'tenant_id': 'ten-test-1',
    'school_id': schoolId,
    'school_name': 'Telangana Model School',
    'school_code': 'TMS01',
    'email': 'info@tms.edu',
    'phone': '+91 98765 43210',
    'state': 'Telangana',
    'board': 'STATE',
    'udise_code': '36140500101',
    'udise_status': 'VERIFIED',
    'udise_verification_status': 'VERIFIED',
    'udise_verified_at': '2025-06-15T10:00:00Z',
    'udise_verified_by_name': 'District Educational Officer',
    'udise_notes': 'Authoritatively verified via Telangana DSE portal.',
    'custom_values': {'Transport Facility': 'Yes', 'Hostel Facility': 'No'},
  });

  const mockCompliance = ComplianceDashboardDto(
    schoolId: schoolId,
    schoolName: 'Telangana Model School',
    udiseCode: '36140500101',
    udiseConfigured: true,
    udiseVerificationStatus: 'VERIFIED',
    totalRecognitions: 2,
    activeRecognitions: 2,
    centralRecognitionsCount: 1,
    stateRecognitionsCount: 1,
    totalDocuments: 5,
    confidentialDocumentsCount: 2,
    expiringDocumentsCount: 1,
    expiredDocumentsCount: 0,
    payrollPolicyConfigured: true,
    payrollReady: true,
    teachersCount: 25,
    pendingPayrollCount: 0,
    approvedPayrollCount: 25,
  );

  final List<SchoolRecognitionDto> mockRecognitions = [
    SchoolRecognitionDto.fromJson({
      'id': 'rec-1',
      'tenant_id': 'ten-test-1',
      'school_id': schoolId,
      'authority_level': 'STATE',
      'authority_name': 'Telangana Directorate of School Education',
      'recognition_type': 'RECOGNITION',
      'recognition_number': 'DSE/HYD/REC/2024/481',
      'proceedings_order_number': 'Proc.Rc.No.481/B2/2024',
      'valid_from': '2024-06-01',
      'valid_until': '2029-05-31',
      'status': 'ACTIVE',
    }),
    SchoolRecognitionDto.fromJson({
      'id': 'rec-2',
      'tenant_id': 'ten-test-1',
      'school_id': schoolId,
      'authority_level': 'CENTRAL',
      'authority_name': 'Central Board of Secondary Education',
      'recognition_type': 'AFFILIATION',
      'recognition_number': 'CBSE/AFF/3630099',
      'valid_from': '2023-04-01',
      'valid_until': '2028-03-31',
      'status': 'ACTIVE',
    }),
  ];

  final List<SchoolDocumentDto> mockDocuments = [
    SchoolDocumentDto.fromJson({
      'id': 'doc-1',
      'school_id': schoolId,
      'title': 'State Recognition Proceedings Order',
      'category': 'RECOGNITION',
      'file_name': 'DSE_Recognition_2024.pdf',
      'file_size_bytes': 1048576,
      'mime_type': 'application/pdf',
      'confidentiality_level': 'CONFIDENTIAL',
      'is_password_protected': true,
      'expiry_date': '2029-05-31',
      'is_expiring_soon': false,
      'is_expired': false,
      'uploaded_by_name': 'DEO Officer',
    }),
    SchoolDocumentDto.fromJson({
      'id': 'doc-2',
      'school_id': schoolId,
      'title': 'Annual Fire Safety Certificate',
      'category': 'FIRE_SAFETY',
      'file_name': 'Fire_Safety_TMS_2025.pdf',
      'file_size_bytes': 524288,
      'mime_type': 'application/pdf',
      'confidentiality_level': 'STANDARD',
      'is_password_protected': false,
      'expiry_date': '2026-10-15',
      'is_expiring_soon': true,
      'days_until_expiry': 19,
      'is_expired': false,
      'uploaded_by_name': 'Safety Inspector',
    }),
  ];

  final mockExpiryMonitor = DocumentExpiryMonitorDto.fromJson({
    'total_monitored': 5,
    'expiring_soon_count': 1,
    'expired_count': 0,
    'alerts': [
      {
        'document_id': 'doc-2',
        'title': 'Annual Fire Safety Certificate',
        'category': 'FIRE_SAFETY',
        'expiry_date': '2026-10-15',
        'days_remaining': 19,
        'is_expired': false,
        'recommended_action': 'Initiate Fire Dept inspection for NOC renewal.',
      }
    ],
    'missing_mandatory_categories': <String>[],
  });

  final mockPolicy = PayrollPolicyDto.fromJson({
    'id': 'pol-1',
    'school_id': schoolId,
    'policy_name': 'Standard Telangana Working Days Policy',
    'calculation_basis': 'WORKING_DAYS',
    'standard_working_days': 24,
    'daily_rate_formula': 'GROSS_DIVIDED_BY_WORKING_DAYS',
    'half_day_deduction_factor': 0.50,
    'unpaid_leave_deduction_factor': 1.00,
    'late_grace_count': 3,
    'late_deduction_factor': 0.25,
    'is_active': true,
  });

  final mockPayrollSummary = MonthlyPayrollSummaryDto.fromJson({
    'school_id': schoolId,
    'month': 9,
    'year': 2026,
    'total_teachers': 1,
    'draft_count': 0,
    'approved_count': 1,
    'total_gross_disbursement': 60000.0,
    'total_attendance_deductions': 0.0,
    'total_statutory_deductions': 4200.0,
    'total_net_payable': 55800.0,
    'policy_name': 'Standard Telangana Working Days Policy',
    'items': [
      {
        'id': 'pay-item-1',
        'school_id': schoolId,
        'teacher_id': 't-101',
        'teacher_name': 'Dr. Srinivas Rao',
        'teacher_code': 'FAC-0101',
        'designation': 'Senior PGT Physics',
        'department': 'Science',
        'gross_salary': 60000.0,
        'daily_rate': 2500.0,
        'present_days': 22.0,
        'approved_leave_days': 2.0,
        'half_days': 0.0,
        'unpaid_absence_days': 0.0,
        'holidays_count': 4.0,
        'late_days': 0.0,
        'attendance_deductions': 0.0,
        'statutory_deductions': 4200.0,
        'net_payable': 55800.0,
        'status': 'APPROVED',
      }
    ],
  });

  final mockTeacherPayrollProfile = TeacherPayrollProfileDto.fromJson({
    'id': 'tpp-1',
    'school_id': schoolId,
    'teacher_id': 't-101',
    'teacher_name': 'Dr. Srinivas Rao',
    'teacher_code': 'FAC-0101',
    'designation': 'Senior PGT Physics',
    'department': 'Science',
    'monthly_gross_salary': 60000.0,
    'basic_salary': 35000.0,
    'hra_allowance': 14000.0,
    'special_allowance': 6000.0,
    'other_allowances': 5000.0,
    'provident_fund_deduction': 2500.0,
    'tax_deduction': 1700.0,
    'other_deductions': 0.0,
    'paid_leave_quota_per_year': 15,
    'bank_account_number': '987654321001',
    'bank_ifsc': 'SBIN0001234',
    'bank_name': 'State Bank of India',
    'effective_from': '2024-06-01',
    'is_active': true,
  });

  Widget createSubject({
    int initialTab = 0,
    int initialPayrollMonth = 9,
    int initialPayrollYear = 2026,
  }) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
        selectedSchoolIdProvider.overrideWith((ref) => schoolId),
        schoolsListProvider.overrideWith(
          (ref) => FakeSchoolsListNotifier(
            const SchoolsListState(schools: [mockSchool], isLoading: false),
          ),
        ),
        schoolDetailProvider(schoolId).overrideWith((ref) => Future.value(mockSchool)),
        schoolProfileProvider(schoolId).overrideWith((ref) => Future.value(mockProfile)),
        complianceDashboardProvider(schoolId).overrideWith((ref) => Future.value(mockCompliance)),
        schoolRecognitionsProvider(schoolId).overrideWith((ref) => Future.value(mockRecognitions)),
        schoolDocumentsProvider(schoolId).overrideWith((ref) => Future.value(mockDocuments)),
        documentExpiryMonitorProvider(schoolId).overrideWith((ref) => Future.value(mockExpiryMonitor)),
        documentAccessLogsProvider(schoolId).overrideWith((ref) => Future.value([])),
        schoolCustomFieldsProvider(schoolId).overrideWith((ref) => Future.value([])),
        payrollPoliciesProvider(schoolId).overrideWith((ref) => Future.value([mockPolicy])),
        monthlyPayrollSummaryProvider(
          const PayrollPeriodKey(schoolId: schoolId, month: 9, year: 2026),
        ).overrideWith((ref) => Future.value(mockPayrollSummary)),
        singleTeacherPayrollProfileProvider(
          const TeacherPayrollKey(schoolId: schoolId, teacherId: 't-101'),
        ).overrideWith((ref) => Future.value(mockTeacherPayrollProfile)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SchoolAdministrationScreen(
            initialTab: initialTab,
            initialPayrollMonth: initialPayrollMonth,
            initialPayrollYear: initialPayrollYear,
          ),
        ),
      ),
    );
  }

  group('School Administration Screen Widget Tests', () {
    testWidgets('Renders Overview tab with UDISE+ and compliance metric cards', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(initialTab: 0));
      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('School Administration & Compliance Center'), findsOneWidget);
      expect(find.text('OS v2.0 • Compliance Active'), findsOneWidget);

      // Verify Overview KPI Cards
      expect(find.text('UDISE+ Identifier'), findsOneWidget);
      expect(find.text('Active Recognitions'), findsOneWidget);
      expect(find.text('Document Vault'), findsOneWidget);
      expect(find.text('Payroll Readiness'), findsOneWidget);

      // Verify values
      expect(find.text('2 Active'), findsOneWidget);
      expect(find.text('5 Records'), findsOneWidget);
    });

    testWidgets('Renders UDISE+ Governance tab with verified official credentials', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(initialTab: 2));
      await tester.pumpAndSettle();

      expect(find.text('Unified District Information System for Education (UDISE+)'), findsOneWidget);
      expect(find.text('36140500101'), findsOneWidget);
      expect(find.text('✓ VERIFIED OFFICIAL'), findsOneWidget);
      expect(find.textContaining('Authoritatively verified via Telangana DSE portal.'), findsOneWidget);
    });

    testWidgets('Renders Affiliation & Recognition tab with multi-authority records', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(initialTab: 3));
      await tester.pumpAndSettle();

      expect(find.text('Governing Board & State Recognition Records'), findsOneWidget);
      expect(find.text('Telangana Directorate of School Education'), findsOneWidget);
      expect(find.text('Central Board of Secondary Education'), findsOneWidget);
      expect(find.text('Proc.Rc.No.481/B2/2024'), findsOneWidget);
      expect(find.text('CBSE/AFF/3630099'), findsOneWidget);
    });

    testWidgets('Renders Secure Documents Vault with AI expiry alerts and protected status', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(initialTab: 5));
      await tester.pumpAndSettle();

      expect(find.text('Institutional Documents & Secure Vault'), findsOneWidget);
      expect(find.textContaining('AI Compliance & Expiry Alerts'), findsOneWidget);
      expect(find.text('State Recognition Proceedings Order'), findsOneWidget);
      expect(find.text('Annual Fire Safety Certificate'), findsOneWidget);
      expect(find.text('PROTECTED'), findsOneWidget);
      expect(find.text('EXPIRES IN 19 DAYS'), findsOneWidget);
    });

    testWidgets('Renders Attendance-Based Payroll tab with calculation summary matrix', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(initialTab: 6));
      await tester.pumpAndSettle();

      expect(find.text('Attendance-Based Teacher Payroll Engine'), findsOneWidget);
      expect(find.text('Total Faculty'), findsOneWidget);
      expect(find.text('Gross Disbursement'), findsOneWidget);
      expect(find.text('Net Payable'), findsOneWidget);
      expect(find.text('Dr. Srinivas Rao'), findsOneWidget);
      expect(find.textContaining('Senior PGT Physics'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
    });

    testWidgets('Teacher 360 Tab 8 displays Teacher Payroll Profile when user is authorized', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockTeacher = TeacherDto.fromJson(const {
        'id': 't-101',
        'school_id': schoolId,
        'first_name': 'Srinivas',
        'last_name': 'Rao',
        'email': 'srinivas@tms.edu',
        'employee_id': 'FAC-0101',
        'designation': 'Senior PGT Physics',
        'department': 'Science',
        'status': 'ACTIVE',
        'employment_type': 'FULL_TIME',
        'joining_date': '2024-06-01',
        'salary': 60000.0,
      });

      final mockAnalytics = Teacher360Response.fromJson({
        'teacher': {
          'id': 't-101',
          'school_id': schoolId,
          'first_name': 'Srinivas',
          'last_name': 'Rao',
          'email': 'srinivas@tms.edu',
          'employee_id': 'FAC-0101',
          'designation': 'Senior PGT Physics',
          'department': 'Science',
          'status': 'ACTIVE',
          'employment_type': 'FULL_TIME',
          'joining_date': '2024-06-01',
          'salary': 60000.0,
        },
        'overview': {
          'total_classes': 4,
          'total_sections': 2,
          'weekly_periods': 20,
          'primary_subjects': ['Physics'],
          'class_teacher_of': ['Class 10-A'],
          'syllabus_completion_rate': 78.5,
          'expected_syllabus_rate': 75.0,
          'syllabus_pace_variance': 3.5,
          'syllabus_pace_status': 'ON_TRACK',
          'marks_submission_rate': 98.0,
          'attendance_rate': 91.7,
          'active_students_taught': 120,
        },
        'assignments': [],
        'syllabus_progress': [],
        'timetable': [],
        'attendance': {
          'has_data': true,
          'attendance_rate': 91.7,
          'present_days': 22,
          'absent_days': 0,
          'leave_days': 2,
          'total_recorded_days': 24,
          'monthly_trend': [],
          'recent_logs': [],
        },
        'homework': [],
        'exam_compliance': [],
        'workload': {
          'weekly_period_capacity': 25,
          'assigned_weekly_periods': 20,
          'utilization_rate': 80.0,
          'subject_distribution': [
            {'subject_name': 'Physics', 'weekly_periods': 14, 'percentage': 70.0},
            {'subject_name': 'Science Practical', 'weekly_periods': 6, 'percentage': 30.0},
          ],
          'class_distribution': [
            {'class_name': 'Class 10-A', 'weekly_periods': 10, 'percentage': 50.0},
            {'class_name': 'Class 12-A', 'weekly_periods': 10, 'percentage': 50.0},
          ],
        },
      });

      final widgetToTest = ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
          teacher360AnalyticsProvider(
            const Teacher360Key(schoolId: schoolId, teacherId: 't-101'),
          ).overrideWith((ref) => Future.value(mockAnalytics)),
          singleTeacherPayrollProfileProvider(
            const TeacherPayrollKey(schoolId: schoolId, teacherId: 't-101'),
          ).overrideWith((ref) => Future.value(mockTeacherPayrollProfile)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Teacher360Modal(
              teacher: mockTeacher,
              schoolId: schoolId,
            ),
          ),
        ),
      );

      await tester.pumpWidget(widgetToTest);
      await tester.pumpAndSettle();

      // Tap on Tab 8 (Workload & Profile)
      final workloadTabFinder = find.text('Workload & Profile');
      expect(workloadTabFinder, findsOneWidget);
      await tester.ensureVisible(workloadTabFinder);
      await tester.tap(workloadTabFinder);
      await tester.pumpAndSettle();

      // Verify that Teacher Compensation & Attendance Payroll Profile section is displayed
      expect(find.text('Teacher Compensation & Attendance Payroll Profile'), findsOneWidget);
      expect(find.text('PAYROLL ACTIVE'), findsOneWidget);
      expect(find.text('Monthly Gross'), findsOneWidget);
      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('987654321001'), findsOneWidget);
    });
  });
}
