import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

import 'package:teacher_app/features/results/domain/entities/result_summary_entity.dart';
import 'package:teacher_app/features/results/domain/entities/report_card_entity.dart';
import 'package:teacher_app/features/results/domain/entities/report_card_preview_entity.dart';
import 'package:teacher_app/features/results/domain/entities/bulk_class_generate_entity.dart';
import 'package:teacher_app/features/results/domain/repositories/results_repository.dart';
import 'package:teacher_app/features/results/presentation/providers/results_providers.dart';
import 'package:teacher_app/features/auth/presentation/providers/auth_provider.dart';

class FakeResultsRepository implements ResultsRepository {
  bool shouldFailSummary = false;
  bool shouldFailPreview = false;
  bool shouldFailBulk = false;

  ResultSummaryEntity summaryData = const ResultSummaryEntity(
    classAverage: 78.5,
    passPercentage: 90.0,
    highestScore: 98.0,
    lowestScore: 40.0,
    missingCount: 1,
    absentCount: 0,
  );

  List<ReportCardEntity> reportCards = [
    ReportCardEntity(
      id: 'card_1',
      verificationUuid: 'uuid-1',
      status: ReportCardStatus.DRAFT,
      pdfUrl: '/static/report_cards/tenant_1/school_1/stud_1_report.pdf',
      pdfHistory: const [],
      settings: const {},
      aiMetrics: const {},
      isActive: true,
      version: 1,
      tenantId: 'tenant_1',
      schoolId: '16730f87-bf8d-44e0-acf9-4b055a778b58',
      academicYearId: 'year_1',
      studentId: 'stud_1',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    ),
  ];

  ReportCardPreviewEntity previewData = const ReportCardPreviewEntity(
    studentId: 'stud_1',
    studentName: 'Alice Green',
    admissionNumber: 'ADM001',
    rollNumber: '2',
    className: 'Grade 8',
    sectionName: 'A1',
    attendanceTotal: 100,
    attendancePresent: 95,
    attendancePercentage: 95.0,
    overallPercentage: 82.5,
    overallGrade: 'A',
    promotionStatus: 'PROMOTED',
    subjectMarks: [
      ReportCardSubjectMarkRowEntity(
        subjectName: 'Mathematics',
        maximumMarks: 100,
        marksObtained: 85.0,
        resultStatus: 'PRESENT',
        grade: 'A',
        remarks: 'Good progress',
      ),
    ],
    teacherRemarks: 'Excellent progress.',
    principalRemarks: 'Approved for promotion.',
    aiNarrative: 'This section will be available after AI analysis.',
    isValid: true,
    missingReasons: [],
  );

  @override
  Future<ApiResult<ResultSummaryEntity>> getResultSummary({
    required String examScheduleId,
    required String schoolId,
  }) async {
    if (shouldFailSummary) {
      return const ApiResult.failure(ApiFailure(statusCode: 500, message: 'Server error', type: ApiFailureType.unknown));
    }
    return ApiResult.success(summaryData);
  }

  @override
  Future<ApiResult<List<ReportCardEntity>>> getReportCards({
    required String schoolId,
    String? classId,
    String? sectionId,
    String? academicYearId,
    ReportCardStatus? status,
  }) async {
    return ApiResult.success(reportCards);
  }

  @override
  Future<ApiResult<ReportCardPreviewEntity>> getReportCardPreview({
    required String studentId,
    required String schoolId,
    String? remarks,
  }) async {
    if (shouldFailPreview) {
      return const ApiResult.failure(ApiFailure(statusCode: 500, message: 'Server error', type: ApiFailureType.unknown));
    }
    return ApiResult.success(previewData);
  }

  @override
  Future<ApiResult<ReportCardEntity>> generateReportCard({
    required String studentId,
    required String schoolId,
    String? remarks,
  }) async {
    final updatedCard = ReportCardEntity(
      id: 'card_1',
      verificationUuid: 'uuid-1',
      status: ReportCardStatus.DRAFT,
      pdfUrl: '/static/report_cards/tenant_1/school_1/stud_1_report.pdf',
      pdfHistory: const [],
      settings: const {},
      aiMetrics: const {},
      isActive: true,
      version: 2,
      tenantId: 'tenant_1',
      schoolId: schoolId,
      academicYearId: 'year_1',
      studentId: studentId,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    return ApiResult.success(updatedCard);
  }

  @override
  Future<ApiResult<ReportCardEntity>> submitForReview({
    required String id,
    required String schoolId,
  }) async {
    final updatedCard = ReportCardEntity(
      id: id,
      verificationUuid: 'uuid-1',
      status: ReportCardStatus.UNDER_REVIEW,
      pdfUrl: '/static/report_cards/tenant_1/school_1/stud_1_report.pdf',
      pdfHistory: const [],
      settings: const {},
      aiMetrics: const {},
      isActive: true,
      version: 2,
      tenantId: 'tenant_1',
      schoolId: schoolId,
      academicYearId: 'year_1',
      studentId: 'stud_1',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    return ApiResult.success(updatedCard);
  }

  @override
  Future<ApiResult<BulkClassGenerateEntity>> bulkGenerateClass({
    required String classId,
    required String sectionId,
    required String schoolId,
  }) async {
    if (shouldFailBulk) {
      return const ApiResult.failure(ApiFailure(statusCode: 500, message: 'Server error', type: ApiFailureType.unknown));
    }
    return const ApiResult.success(BulkClassGenerateEntity(
      totalStudents: 10,
      generatedCount: 9,
      failedCount: 1,
      failures: [
        StudentFailureDetailEntity(studentId: 'stud_5', studentName: 'Bob White', reasons: ['Math marks missing']),
      ],
    ));
  }
}

class FakeAuthStateNotifier extends AuthStateNotifier {
  final AuthState initialVal;
  FakeAuthStateNotifier(this.initialVal);

  @override
  AuthState build() {
    return initialVal;
  }
}

void main() {
  group('Results Feature Tests', () {
    late FakeResultsRepository fakeRepository;
    late ProviderContainer container;

    setUp(() {
      fakeRepository = FakeResultsRepository();
      container = ProviderContainer(
        overrides: [
          resultsRepositoryProvider.overrideWithValue(fakeRepository),
          authStateProvider.overrideWith(() => FakeAuthStateNotifier(
            Authenticated(
              UserEntity(
                id: 'teacher_123',
                email: 'teacher@edupulse.ai',
                firstName: 'Sarah',
                lastName: 'Connor',
                tenantId: 'tenant_1',
                isSuperuser: false,
                roles: const ['TEACHER'],
                schools: const ['16730f87-bf8d-44e0-acf9-4b055a778b58'],
              ),
            ),
          )),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Results summary statistical metrics loads successfully', () async {
      final summaryFuture = container.read(resultsSummaryProvider('schedule_1').future);
      final data = await summaryFuture;
      expect(data.classAverage, 78.5);
      expect(data.passPercentage, 90.0);
      expect(data.highestScore, 98.0);
      expect(data.lowestScore, 40.0);
    });

    test('2. Report card list loads successfully for class and section', () async {
      final cardsFuture = container.read(reportCardsProvider((classId: 'class_1', sectionId: 'section_1')).future);
      final data = await cardsFuture;
      expect(data, isNotEmpty);
      expect(data.first.status, ReportCardStatus.DRAFT);
    });

    test('3. Student result preview loads and matches details', () async {
      final notifier = container.read(studentResultPreviewProvider('stud_1').notifier);
      await notifier.fetchPreviewAndReportCard(
        studentId: 'stud_1',
        schoolId: 'school_1',
        classId: 'class_1',
        sectionId: 'section_1',
      );

      final state = container.read(studentResultPreviewProvider('stud_1'));
      expect(state.isLoading, false);
      expect(state.preview, isNotNull);
      expect(state.preview?.studentName, 'Alice Green');
      expect(state.preview?.overallGrade, 'A');
      expect(state.preview?.subjectMarks.first.subjectName, 'Mathematics');
    });

    test('4. Generate report card draft registers version increments', () async {
      final notifier = container.read(studentResultPreviewProvider('stud_1').notifier);
      await notifier.fetchPreviewAndReportCard(
        studentId: 'stud_1',
        schoolId: 'school_1',
        classId: 'class_1',
        sectionId: 'section_1',
      );

      notifier.updateRemarks('Great improvement.');
      final success = await notifier.generateDraft(
        studentId: 'stud_1',
        schoolId: 'school_1',
        classId: 'class_1',
        sectionId: 'section_1',
      );

      expect(success, true);
      final state = container.read(studentResultPreviewProvider('stud_1'));
      expect(state.reportCard?.version, 2);
    });

    test('5. Submit for review transitions report card status', () async {
      final notifier = container.read(studentResultPreviewProvider('stud_1').notifier);
      await notifier.fetchPreviewAndReportCard(
        studentId: 'stud_1',
        schoolId: 'school_1',
        classId: 'class_1',
        sectionId: 'section_1',
      );

      final success = await notifier.submitReview(
        schoolId: 'school_1',
        classId: 'class_1',
        sectionId: 'section_1',
      );

      expect(success, true);
      final state = container.read(studentResultPreviewProvider('stud_1'));
      expect(state.reportCard?.status, ReportCardStatus.UNDER_REVIEW);
    });

    test('6. Bulk generate class triggers sequential runs and maps failures', () async {
      final bulkNotifier = container.read(bulkClassGenerateProvider.notifier);
      await bulkNotifier.runBulkGenerate(
        classId: 'class_1',
        sectionId: 'section_1',
        schoolId: 'school_1',
      );

      final state = container.read(bulkClassGenerateProvider);
      expect(state.value?.totalStudents, 10);
      expect(state.value?.generatedCount, 9);
      expect(state.value?.failedCount, 1);
      expect(state.value?.failures.first.studentName, 'Bob White');
    });
  });
}
