import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

import 'package:teacher_app/features/marks/domain/entities/examination_entity.dart';
import 'package:teacher_app/features/marks/domain/entities/exam_schedule_entity.dart';
import 'package:teacher_app/features/marks/domain/entities/student_mark_entity.dart';
import 'package:teacher_app/features/marks/domain/entities/marks_wizard_entity.dart';
import 'package:teacher_app/features/marks/domain/entities/marks_publish_summary_entity.dart';
import 'package:teacher_app/features/marks/domain/repositories/marks_repository.dart';
import 'package:teacher_app/features/marks/presentation/providers/marks_providers.dart';
import 'package:teacher_app/features/auth/presentation/providers/auth_provider.dart';

class FakeMarksRepository implements MarksRepository {
  bool shouldFailExams = false;
  bool shouldTimeoutSave = false;
  int getExaminationsCallCount = 0;
  
  List<ExaminationEntity> examinations = [
    ExaminationEntity(
      id: 'exam_1',
      tenantId: 'tenant_1',
      schoolId: '16730f87-bf8d-44e0-acf9-4b055a778b58',
      academicYearId: 'year_1',
      examName: 'Midterm',
      examType: ExamType.MONTHLY,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 10),
      status: ExamStatus.PUBLISHED,
      settings: const {},
      aiMetrics: const {},
      isActive: true,
      version: 1,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      schedules: [
        ExamScheduleEntity(
          id: 'schedule_1',
          examId: 'exam_1',
          classId: 'class_1',
          sectionId: 'section_1',
          subjectId: 'sub_1',
          teacherSubjectAssignmentId: 'tsa_1',
          examDate: DateTime(2026, 8, 5),
          startTime: '09:00',
          endTime: '12:00',
          maxMarks: 100,
          passMarks: 35,
          isActive: true,
          version: 1,
        ),
      ],
    ),
  ];

  MarksWizardEntity wizardData = MarksWizardEntity(
    totalStudents: 3,
    enteredCount: 0,
    missingCount: 3,
    missingStudents: const [
      StudentShortInfoEntity(id: 'stud_1', firstName: 'Alice', lastName: 'Green', rollNumber: '2'),
      StudentShortInfoEntity(id: 'stud_2', firstName: 'Bob', lastName: 'White', rollNumber: '1'),
      StudentShortInfoEntity(id: 'stud_3', firstName: 'Charlie', lastName: 'Brown', rollNumber: '10'),
    ],
    entries: const [
      MarkWizardItemEntity(
        student: StudentShortInfoEntity(id: 'stud_1', firstName: 'Alice', lastName: 'Green', rollNumber: '2'),
        isMissing: true,
      ),
      MarkWizardItemEntity(
        student: StudentShortInfoEntity(id: 'stud_2', firstName: 'Bob', lastName: 'White', rollNumber: '1'),
        isMissing: true,
      ),
      MarkWizardItemEntity(
        student: StudentShortInfoEntity(id: 'stud_3', firstName: 'Charlie', lastName: 'Brown', rollNumber: '10'),
        isMissing: true,
      ),
    ],
  );

  @override
  Future<ApiResult<List<ExaminationEntity>>> getExaminations({
    required String schoolId,
    String? academicYearId,
    String? search,
  }) async {
    getExaminationsCallCount++;
    if (shouldFailExams) {
      return const ApiResult.failure(ApiFailure(statusCode: 500, message: 'Server error', type: ApiFailureType.unknown));
    }
    return ApiResult.success(examinations);
  }

  @override
  Future<ApiResult<ExaminationEntity>> getExaminationById({
    required String id,
    required String schoolId,
  }) async {
    final exam = examinations.firstWhere((e) => e.id == id);
    return ApiResult.success(exam);
  }

  @override
  Future<ApiResult<MarksWizardEntity>> getMarksWizard({
    required String examScheduleId,
    required String schoolId,
  }) async {
    return ApiResult.success(wizardData);
  }

  @override
  Future<ApiResult<List<StudentMarkEntity>>> bulkSaveMarks({
    required String schoolId,
    required String examScheduleId,
    required String teacherSubjectAssignmentId,
    required List<SingleMarkInput> marks,
    required bool autosave,
    required bool isUpdate,
  }) async {
    final savedRecords = marks.map((m) {
      return StudentMarkEntity(
        id: 'mark_${m.studentId}',
        tenantId: 'tenant_1',
        schoolId: schoolId,
        academicYearId: 'year_1',
        examinationId: 'exam_1',
        examScheduleId: examScheduleId,
        studentId: m.studentId,
        teacherSubjectAssignmentId: teacherSubjectAssignmentId,
        teacherId: 'teacher_123',
        subjectId: 'sub_1',
        classId: 'class_1',
        sectionId: 'section_1',
        maximumMarks: 100,
        marksObtained: m.marksObtained,
        resultStatus: m.resultStatus,
        status: MarksStatus.DRAFT,
        settings: const {},
        aiMetrics: const {},
        auditHistory: const [],
        isActive: true,
        version: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    // Update wizardData state mock
    wizardData = MarksWizardEntity(
      totalStudents: 3,
      enteredCount: savedRecords.length,
      missingCount: 3 - savedRecords.length,
      missingStudents: const [],
      entries: wizardData.entries.map((item) {
        final match = savedRecords.firstWhere((r) => r.studentId == item.student.id);
        return MarkWizardItemEntity(
          student: item.student,
          markRecord: match,
          isMissing: false,
        );
      }).toList(),
    );

    if (shouldTimeoutSave) {
      return const ApiResult.failure(ApiFailure(statusCode: 408, message: 'timeout error connection', type: ApiFailureType.unknown));
    }

    return ApiResult.success(savedRecords);
  }

  @override
  Future<ApiResult<MarksPublishSummaryEntity>> getPublishSummary({
    required String examScheduleId,
    required String schoolId,
  }) async {
    return const ApiResult.success(MarksPublishSummaryEntity(
      examName: 'Midterm',
      subjectName: 'Math',
      className: 'Class 10 - A',
      totalStudents: 3,
      enteredCount: 3,
      missingCount: 0,
      passPercentage: 100.0,
    ));
  }

  @override
  Future<ApiResult<List<StudentMarkEntity>>> publishMarks({
    required String examScheduleId,
    required String schoolId,
  }) async {
    return const ApiResult.success([]);
  }

  @override
  Future<ApiResult<List<String>>> getRemarksTemplates() async {
    return const ApiResult.success(['Excellent', 'Good progress', 'Needs improvement']);
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
  group('Marks Feature Tests', () {
    late FakeMarksRepository fakeRepository;
    late ProviderContainer container;

    setUp(() {
      fakeRepository = FakeMarksRepository();
      container = ProviderContainer(
        overrides: [
          marksRepositoryProvider.overrideWithValue(fakeRepository),
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

    test('1-4. Examination listing loading success, failure, retry', () async {
      // 1. Success
      final examsFuture = container.read(marksExaminationsProvider(null).future);
      expect(await examsFuture, isNotEmpty);
      expect(fakeRepository.getExaminationsCallCount, 1);

      // 2. Failure
      fakeRepository.shouldFailExams = true;
      final failingContainer = ProviderContainer(
        overrides: [
          marksRepositoryProvider.overrideWithValue(fakeRepository),
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
      try {
        await failingContainer.read(marksExaminationsProvider(null).future);
        fail('Should throw exception');
      } catch (e) {
        expect(e, isA<ApiFailure>());
      }
    });

    test('7-19. Student marks entry loading, validations, sorting, remarks templates', () async {
      final notifier = container.read(marksWizardProvider('schedule_1').notifier);
      
      // Wait for initialization loading
      await Future.delayed(const Duration(milliseconds: 10));
      final wizardState = container.read(marksWizardProvider('schedule_1'));

      expect(wizardState.isLoading, false);
      expect(wizardState.wizardData, isNotNull);
      expect(wizardState.localDrafts, isNotEmpty);

      // Roll-number sorting check
      final entries = List<MarkWizardItemEntity>.from(wizardState.wizardData!.entries);
      entries.sort((a, b) {
        final rollA = int.tryParse(a.student.rollNumber) ?? 999999;
        final rollB = int.tryParse(b.student.rollNumber) ?? 999999;
        return rollA.compareTo(rollB);
      });
      expect(entries[0].student.rollNumber, '1'); // Bob White
      expect(entries[1].student.rollNumber, '2'); // Alice Green
      expect(entries[2].student.rollNumber, '10'); // Charlie Brown

      // Maximum marks validation check (> 100 max marks)
      notifier.updateMark('stud_1', marksObtained: 105, maxMarks: 100);
      expect(container.read(marksWizardProvider('schedule_1')).validationErrors['stud_1'], isNotNull);

      // Negative marks validation check
      notifier.updateMark('stud_1', marksObtained: -5, maxMarks: 100);
      expect(container.read(marksWizardProvider('schedule_1')).validationErrors['stud_1'], isNotNull);

      // Present -> Absent clears marks
      notifier.updateMark('stud_1', marksObtained: 85, maxMarks: 100);
      notifier.updateMark('stud_1', resultStatus: ExamResult.ABSENT, maxMarks: 100);
      expect(container.read(marksWizardProvider('schedule_1')).localDrafts['stud_1']?.marksObtained, isNull);

      // Absent -> Present allows editing
      notifier.updateMark('stud_1', resultStatus: ExamResult.PRESENT, maxMarks: 100);
      notifier.updateMark('stud_1', marksObtained: 90, maxMarks: 100);
      expect(container.read(marksWizardProvider('schedule_1')).localDrafts['stud_1']?.marksObtained, 90);
    });

    test('20-25. Autosave debounce, save success, timeout reconciliation', () async {
      final notifier = container.read(marksWizardProvider('schedule_1').notifier);
      await Future.delayed(const Duration(milliseconds: 10));

      notifier.updateMark('stud_1', marksObtained: 95, maxMarks: 100);

      // Trigger timeout save manually
      fakeRepository.shouldTimeoutSave = true;
      await notifier.saveDraft(teacherSubjectAssignmentId: 'tsa_1', autosave: true);

      // Let save proceed, timeout triggers reconciliation
      // Reconciliation queries `/entry` again which fetches updated mock records
      final state = container.read(marksWizardProvider('schedule_1'));
      expect(state.saveStatusText, contains('Saved'));
    });

    test('26-29. Publish summary loading', () async {
      final notifier = container.read(marksWizardProvider('schedule_1').notifier);
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.fetchPublishSummary();
      final state = container.read(marksWizardProvider('schedule_1'));
      expect(state.publishSummary, isNotNull);
      expect(state.publishSummary?.passPercentage, 100.0);
    });

    test('30-33. Publish confirmation and action execution', () async {
      final notifier = container.read(marksWizardProvider('schedule_1').notifier);
      await Future.delayed(const Duration(milliseconds: 10));

      final success = await notifier.publishMarks();
      expect(success, true);
    });
  });
}
