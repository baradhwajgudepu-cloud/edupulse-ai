import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/students/presentation/widgets/student_360_modal.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

/// Fake API client that returns strict operational data without mock defaults.
class FakeStudent360ApiClient extends BaseApiClient {
  FakeStudent360ApiClient() : super(Dio());

  final Map<String, Map<String, dynamic>> analyticsMap = {};
  final Map<String, Map<String, dynamic>> ledgerMap = {};
  final Map<String, Map<String, dynamic>> studentMap = {};

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final uri = Uri.parse(path);
    final cleanPath = uri.path;

    if (cleanPath.contains('/analytics')) {
      final segments = cleanPath.split('/');
      final studentId = segments[segments.indexOf('analytics') - 1];
      final schoolId = uri.queryParameters['school_id'] ??
          queryParameters?['school_id']?.toString() ??
          '';
      final key = '$schoolId:$studentId';

      if (analyticsMap.containsKey(key)) {
        return ApiResult.success(mapper({'data': analyticsMap[key]!}));
      }

      // Default: zero recorded records
      return ApiResult.success(mapper({
        'data': {
          'student_id': studentId,
          'school_id': schoolId,
          'attendance': {
            'has_data': false,
            'attendance_rate': null,
            'total_days': 0,
            'present_days': 0,
            'absent_days': 0,
            'leave_days': 0,
            'monthly_trend': [],
          },
          'academics': {
            'has_data': false,
            'academic_average': null,
            'exam_trends': [],
            'subject_scores': [],
          },
          'fees': {
            'has_data': false,
            'total_assigned': 0.0,
            'total_paid': 0.0,
            'balance_outstanding': 0.0,
            'paid_percentage': null,
            'status': 'No fee records',
          },
          'ai_analysis': {
            'has_data': false,
            'trend': null,
            'headline': null,
            'insight': null,
            'strong_highlights': [],
            'support_highlights': [],
            'action_recommendation': null,
            'status_message': 'Insufficient data for AI analysis',
          },
          'homework': [],
          'activity_logs': [],
        }
      }));
    }

    if (cleanPath.startsWith('/fees/ledgers/')) {
      final studentId = cleanPath.replaceAll('/fees/ledgers/', '');
      if (ledgerMap.containsKey(studentId)) {
        return ApiResult.success(mapper({'data': ledgerMap[studentId]!}));
      }
      return ApiResult.success(mapper({
        'data': {
          'student_id': studentId,
          'opening_balance': 0.0,
          'assignments': [],
          'scholarships': [],
          'payments': [],
          'closing_balance': 0.0,
        },
      }));
    }

    if (cleanPath.startsWith('/students/')) {
      final studentId = cleanPath.replaceAll('/students/', '');
      if (studentMap.containsKey(studentId)) {
        return ApiResult.success(mapper({'data': studentMap[studentId]!}));
      }
      return ApiResult.success(mapper({
        'data': {
          'id': studentId,
          'tenant_id': 'tenant-1',
          'school_id': 'school-1',
          'academic_year_id': 'ay-1',
          'class_id': 'class-1',
          'section_id': 'section-1',
          'first_name': 'Test',
          'last_name': 'Student',
          'admission_number': 'ADM-$studentId',
          'roll_number': '101',
          'admission_date': '2026-06-01',
          'status': 'ACTIVE',
          'is_active': true,
          'ai_metrics': {},
          'address': {},
          'medical_information': {},
          'settings': {},
          'version': 1,
          'created_at': '2026-06-01T00:00:00Z',
          'updated_at': '2026-06-01T00:00:00Z',
        },
      }));
    }

    if (cleanPath.startsWith('/teachers')) {
      return ApiResult.success(mapper({'data': []}));
    }

    if (cleanPath.startsWith('/guardians')) {
      return ApiResult.success(mapper({'data': []}));
    }

    return ApiResult.success(mapper({'data': {}}));
  }
}

StudentDto createTestStudent({
  String id = 'stud-test-1',
  String schoolId = 'school-1',
  String firstName = 'Anil',
  String lastName = 'Kumar',
  String admissionNumber = 'ADM-2026-001',
  Map<String, dynamic> aiMetrics = const {},
}) {
  return StudentDto(
    id: id,
    tenantId: 'tenant-1',
    schoolId: schoolId,
    academicYearId: 'ay-1',
    classId: 'class-1',
    sectionId: 'section-1',
    firstName: firstName,
    lastName: lastName,
    gender: 'MALE',
    dateOfBirth: '2010-05-15',
    address: const {'city': 'Hyderabad'},
    medicalInformation: const {},
    admissionNumber: admissionNumber,
    rollNumber: '101',
    admissionDate: '2026-06-01',
    status: 'ACTIVE',
    isActive: true,
    settings: const {},
    aiMetrics: aiMetrics,
    version: 1,
    createdAt: '2026-06-01T00:00:00Z',
    updatedAt: '2026-06-01T00:00:00Z',
    className: 'Class 10',
    sectionName: 'Section A',
  );
}

class Student360TestHost extends StatefulWidget {
  final StudentDto student;
  final String schoolId;

  const Student360TestHost({
    super.key,
    required this.student,
    required this.schoolId,
  });

  @override
  State<Student360TestHost> createState() => Student360TestHostState();
}

class Student360TestHostState extends State<Student360TestHost> {
  late StudentDto currentStudent;
  late String currentSchoolId;

  @override
  void initState() {
    super.initState();
    currentStudent = widget.student;
    currentSchoolId = widget.schoolId;
  }

  void update({required StudentDto student, required String schoolId}) {
    setState(() {
      currentStudent = student;
      currentSchoolId = schoolId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Student360Modal(
          student: currentStudent,
          schoolId: currentSchoolId,
        ),
      ),
    );
  }
}

void main() {
  late FakeStudent360ApiClient fakeApi;

  setUp(() {
    fakeApi = FakeStudent360ApiClient();
  });

  Widget buildTestWidget({
    required StudentDto student,
    String schoolId = 'school-1',
  }) {
    fakeApi.studentMap[student.id] = student.toJson();
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApi),
        selectedSchoolIdProvider.overrideWith((ref) => schoolId),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Student360Modal(
            student: student,
            schoolId: schoolId,
          ),
        ),
      ),
    );
  }

  testWidgets('Renders all 8 tabs and student folio identity header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final student = createTestStudent();

    await tester.pumpWidget(buildTestWidget(student: student));
    await tester.pumpAndSettle();

    // Verify Micro-Bar and Identity Banner
    expect(find.text('ADM-2026-001'), findsOneWidget);
    expect(find.text('Anil Kumar'), findsOneWidget);
    expect(find.text('Roll #101'), findsOneWidget);

    // Verify 8 Tabs
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);
    expect(find.text('Fees'), findsOneWidget);
    expect(find.text('Guardian'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);

    // Verify Overview Content cards
    expect(find.text('Attendance Rate'), findsOneWidget);
    expect(find.text('Academic Score'), findsOneWidget);
    expect(find.text('Fees Paid'), findsOneWidget);
  });

  testWidgets('Scenario 1: Zero attendance records displays "No attendance data" and empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final student = createTestStudent(id: 'stud-zero-att', firstName: 'Priya', lastName: 'Rao');

    await tester.pumpWidget(buildTestWidget(student: student));
    await tester.pumpAndSettle();

    // Banner and Overview badge must display "No attendance data"
    expect(find.text('No attendance data'), findsWidgets);

    // Must never fabricate 92% or fallback 0%
    expect(find.textContaining('92%'), findsNothing);
    expect(find.textContaining('92.4%'), findsNothing);
    expect(find.text('0% Attendance'), findsNothing);

    // Navigate to Attendance tab
    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();

    // Verify Attendance Empty State
    expect(find.text('No Attendance Data'), findsOneWidget);
    expect(
      find.text('No daily or session attendance records have been marked for this student yet.'),
      findsOneWidget,
    );
  });

  testWidgets('Scenario 2: Zero marks/exam records displays "No academic data" and empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final student = createTestStudent(id: 'stud-zero-acad', firstName: 'Rohan', lastName: 'Verma');

    await tester.pumpWidget(buildTestWidget(student: student));
    await tester.pumpAndSettle();

    // Overview metric card must show "No academic data"
    expect(find.text('No academic data'), findsOneWidget);

    // Must never fabricate 84% or fallback 0%
    expect(find.textContaining('84%'), findsNothing);
    expect(find.textContaining('84.5%'), findsNothing);

    // Navigate to Academic tab
    await tester.tap(find.text('Academic'));
    await tester.pumpAndSettle();

    // Verify Academic Empty State
    expect(find.text('No Academic Records'), findsOneWidget);
    expect(
      find.text('No examination marks or evaluations have been recorded for this student yet.'),
      findsOneWidget,
    );
  });

  testWidgets('Scenario 3: Zero fee/payment records displays "No fee records" and empty receipts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final student = createTestStudent(id: 'stud-zero-fees', firstName: 'Kavita', lastName: 'Singh');

    await tester.pumpWidget(buildTestWidget(student: student));
    await tester.pumpAndSettle();

    // Banner and Overview card must show "No fee records"
    expect(find.text('No fee records'), findsWidgets);

    // Must never fabricate 100% Cleared
    expect(find.text('100% Cleared'), findsNothing);
    expect(find.text('Cleared'), findsNothing);

    // Navigate to Fees tab
    await tester.tap(find.text('Fees'));
    await tester.pumpAndSettle();

    // Verify real accounting empty state indicators
    expect(find.text('No fee dues assigned'), findsOneWidget);
    expect(find.text('No outstanding dues'), findsOneWidget);
    expect(find.text('No fee receipts recorded yet.'), findsOneWidget);
  });

  testWidgets('Scenario 4: Insufficient analytics data shows "Insufficient data for AI analysis"', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final student = createTestStudent(id: 'stud-no-ai', firstName: 'Meera', lastName: 'Patel');

    await tester.pumpWidget(buildTestWidget(student: student));
    await tester.pumpAndSettle();

    // AI Insight Card displays insufficient data headline and educational prompt
    expect(find.text('Insufficient data for AI analysis'), findsOneWidget);
    expect(
      find.text('Classroom attendance and examination marks are required before AI insights can be generated for this student.'),
      findsOneWidget,
    );
    expect(
      find.text('Record student attendance and examination scores to enable AI analysis.'),
      findsOneWidget,
    );

    // No fabricated subject strengths or fake recommendations
    expect(find.text('Mathematics'), findsNothing);
    expect(find.text('Science'), findsNothing);
  });

  testWidgets('Scenario 5: Switching students cannot show previous student\'s analytics (No Cache Bleed)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final studentA = createTestStudent(id: 'stud-A', firstName: 'Alice', lastName: 'A');
    final studentB = createTestStudent(id: 'stud-B', firstName: 'Bob', lastName: 'B');

    fakeApi.studentMap['stud-A'] = studentA.toJson();
    fakeApi.studentMap['stud-B'] = studentB.toJson();

    // Populate real records for Student A
    fakeApi.analyticsMap['school-1:stud-A'] = {
      'student_id': 'stud-A',
      'school_id': 'school-1',
      'attendance': {
        'has_data': true,
        'attendance_rate': 95.0,
        'total_days': 100,
        'present_days': 95,
        'absent_days': 5,
        'leave_days': 0,
        'monthly_trend': [],
      },
      'academics': {
        'has_data': true,
        'academic_average': 88.0,
        'exam_trends': [],
        'subject_scores': [],
      },
      'fees': {
        'has_data': true,
        'total_assigned': 50000.0,
        'total_paid': 50000.0,
        'balance_outstanding': 0.0,
        'paid_percentage': 100.0,
        'status': 'Cleared',
      },
      'ai_analysis': {
        'has_data': true,
        'trend': 'improving',
        'headline': 'Strong Academic Progression',
        'insight': 'Consistent attendance and top test scores.',
        'strong_highlights': ['High attendance'],
        'support_highlights': [],
        'action_recommendation': 'Maintain current study schedule.',
      },
      'homework': [],
      'activity_logs': [],
    };

    final hostKey = GlobalKey<Student360TestHostState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          selectedSchoolIdProvider.overrideWith((ref) => 'school-1'),
        ],
        child: Student360TestHost(
          key: hostKey,
          student: studentA,
          schoolId: 'school-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Student A's real analytics are visible
    expect(find.text('95% Attendance'), findsOneWidget);
    expect(find.text('Cleared'), findsWidgets);
    expect(find.text('Strong Academic Progression'), findsOneWidget);

    // Switch to Student B in-place via host widget
    hostKey.currentState!.update(student: studentB, schoolId: 'school-1');
    await tester.pumpAndSettle();

    // Verify Student A's analytics are completely evicted and Student B's zero-records state is shown
    expect(find.text('95% Attendance'), findsNothing);
    expect(find.text('Cleared'), findsNothing);
    expect(find.text('Strong Academic Progression'), findsNothing);
    expect(find.text('No attendance data'), findsWidgets);
    expect(find.text('No academic data'), findsOneWidget);
    expect(find.text('No fee records'), findsWidgets);
    expect(find.text('Insufficient data for AI analysis'), findsOneWidget);
  });

  testWidgets('Scenario 6: Switching schools cannot show previous school\'s analytics', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final student = createTestStudent(id: 'stud-multi-school', firstName: 'Sam', lastName: 'Lee');
    fakeApi.studentMap['stud-multi-school'] = student.toJson();

    // Populate data strictly for school-1
    fakeApi.analyticsMap['school-1:stud-multi-school'] = {
      'student_id': 'stud-multi-school',
      'school_id': 'school-1',
      'attendance': {
        'has_data': true,
        'attendance_rate': 91.0,
        'total_days': 50,
        'present_days': 45,
        'absent_days': 5,
        'leave_days': 0,
        'monthly_trend': [],
      },
      'academics': {
        'has_data': false,
        'academic_average': null,
        'exam_trends': [],
        'subject_scores': [],
      },
      'fees': {
        'has_data': false,
        'total_assigned': 0.0,
        'total_paid': 0.0,
        'balance_outstanding': 0.0,
        'paid_percentage': null,
        'status': 'No fee records',
      },
      'ai_analysis': {
        'has_data': false,
        'status_message': 'Insufficient data for AI analysis',
      },
      'homework': [],
      'activity_logs': [],
    };

    final hostKey = GlobalKey<Student360TestHostState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          selectedSchoolIdProvider.overrideWith((ref) => 'school-1'),
        ],
        child: Student360TestHost(
          key: hostKey,
          student: student,
          schoolId: 'school-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('91% Attendance'), findsOneWidget);

    // Switch to school-2 in-place (zero data configured for school-2)
    hostKey.currentState!.update(student: student, schoolId: 'school-2');
    await tester.pumpAndSettle();

    // Verify school-1 data is NOT bled into school-2
    expect(find.text('91% Attendance'), findsNothing);
    expect(find.text('No attendance data'), findsWidgets);
  });
}

