import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/results/data/models/admin_marks_models.dart';
import 'package:admin_portal/features/results/presentation/providers/admin_marks_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

void main() {
  group('Admin Marks Management Board - Model & Business Logic Tests', () {
    test('1. Cascading hierarchy selection resets downstream filters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminMarksFiltersProvider.notifier);

      notifier.setAcademicYear('ay-1');
      notifier.setExamination('exam-1');
      notifier.setClass('class-1');
      notifier.setSection('sec-1');
      notifier.setSchedule('sched-1');

      var state = container.read(adminMarksFiltersProvider);
      expect(state.academicYearId, 'ay-1');
      expect(state.examinationId, 'exam-1');
      expect(state.classId, 'class-1');
      expect(state.sectionId, 'sec-1');
      expect(state.scheduleId, 'sched-1');

      // Changing academic year must reset exam, class, section, schedule
      notifier.setAcademicYear('ay-2');
      state = container.read(adminMarksFiltersProvider);
      expect(state.academicYearId, 'ay-2');
      expect(state.examinationId, isNull);
      expect(state.classId, isNull);
      expect(state.sectionId, isNull);
      expect(state.scheduleId, isNull);
    });

    test('2. Changing examination resets class, section, schedule', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminMarksFiltersProvider.notifier);
      notifier.setAcademicYear('ay-1');
      notifier.setExamination('exam-1');
      notifier.setClass('class-1');
      notifier.setSection('sec-1');
      notifier.setSchedule('sched-1');

      notifier.setExamination('exam-2');
      final state = container.read(adminMarksFiltersProvider);
      expect(state.academicYearId, 'ay-1');
      expect(state.examinationId, 'exam-2');
      expect(state.classId, isNull);
      expect(state.sectionId, isNull);
      expect(state.scheduleId, isNull);
    });

    test('3. Negative marks are rejected with validation error', () {
      const schedule = AdminExamScheduleOption(
        id: 'sched-1',
        examId: 'exam-1',
        examName: 'Quarterly',
        classId: 'cls-1',
        className: 'Grade 10',
        subjectId: 'sub-1',
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        maxMarks: 100,
        passMarks: 35,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminMarksBoardProvider.notifier);
      notifier.state = AdminMarksBoardState(
        activeScheduleId: schedule.id,
        activeSchedule: schedule,
        rows: [
          const AdminStudentMarkRow(
            studentId: 'st-1',
            firstName: 'Rahul',
            lastName: 'Kumar',
            rollNumber: '001',
            maxMarks: 100,
          ),
        ],
      );

      notifier.updateStudentMark('st-1', -5);
      final row = container.read(adminMarksBoardProvider).rows.first;
      expect(row.validationError, isNotNull);
      expect(row.validationError, contains('negative'));
    });

    test('4. Marks exceeding maximum marks are rejected', () {
      const schedule = AdminExamScheduleOption(
        id: 'sched-1',
        examId: 'exam-1',
        examName: 'Quarterly',
        classId: 'cls-1',
        className: 'Grade 10',
        subjectId: 'sub-1',
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        maxMarks: 50,
        passMarks: 18,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminMarksBoardProvider.notifier);
      notifier.state = AdminMarksBoardState(
        activeScheduleId: schedule.id,
        activeSchedule: schedule,
        rows: [
          const AdminStudentMarkRow(
            studentId: 'st-1',
            firstName: 'Priya',
            lastName: 'Singh',
            rollNumber: '002',
            maxMarks: 50,
          ),
        ],
      );

      notifier.updateStudentMark('st-1', 75);
      final row = container.read(adminMarksBoardProvider).rows.first;
      expect(row.validationError, isNotNull);
      expect(row.validationError, contains('exceed'));
    });

    test('5. Setting Absent status clears obtained marks', () {
      const schedule = AdminExamScheduleOption(
        id: 'sched-1',
        examId: 'exam-1',
        examName: 'Quarterly',
        classId: 'cls-1',
        className: 'Grade 10',
        subjectId: 'sub-1',
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        maxMarks: 100,
        passMarks: 35,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminMarksBoardProvider.notifier);
      notifier.state = AdminMarksBoardState(
        activeScheduleId: schedule.id,
        activeSchedule: schedule,
        rows: [
          const AdminStudentMarkRow(
            studentId: 'st-1',
            firstName: 'Arjun',
            lastName: 'Reddy',
            rollNumber: '003',
            maxMarks: 100,
            marksObtained: 85,
            resultStatus: AdminMarkResultStatus.present,
          ),
        ],
      );

      notifier.updateStudentStatus('st-1', AdminMarkResultStatus.absent);
      final row = container.read(adminMarksBoardProvider).rows.first;
      expect(row.resultStatus, AdminMarkResultStatus.absent);
      expect(row.marksObtained, isNull);
    });

    test('6. Malpractice requires mandatory remarks', () {
      const schedule = AdminExamScheduleOption(
        id: 'sched-1',
        examId: 'exam-1',
        examName: 'Quarterly',
        classId: 'cls-1',
        className: 'Grade 10',
        subjectId: 'sub-1',
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        maxMarks: 100,
        passMarks: 35,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminMarksBoardProvider.notifier);
      notifier.state = AdminMarksBoardState(
        activeScheduleId: schedule.id,
        activeSchedule: schedule,
        rows: [
          const AdminStudentMarkRow(
            studentId: 'st-1',
            firstName: 'Suresh',
            lastName: 'Rao',
            rollNumber: '004',
            maxMarks: 100,
            marksObtained: 40,
            remarks: '',
          ),
        ],
      );

      notifier.updateStudentStatus('st-1', AdminMarkResultStatus.malpractice);
      var row = container.read(adminMarksBoardProvider).rows.first;
      expect(row.validationError, isNotNull);
      expect(row.validationError, contains('Remarks required'));

      notifier.updateStudentRemarks('st-1', 'Found carrying unauthorized paper');
      row = container.read(adminMarksBoardProvider).rows.first;
      expect(row.validationError, isNull);
    });

    test('7. Administrative override captures mandatory reason', () {
      const schedule = AdminExamScheduleOption(
        id: 'sched-1',
        examId: 'exam-1',
        examName: 'Quarterly',
        classId: 'cls-1',
        className: 'Grade 10',
        subjectId: 'sub-1',
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        maxMarks: 100,
        passMarks: 35,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminMarksBoardProvider.notifier);
      notifier.state = AdminMarksBoardState(
        activeScheduleId: schedule.id,
        activeSchedule: schedule,
        rows: [
          const AdminStudentMarkRow(
            studentId: 'st-1',
            firstName: 'Deepa',
            lastName: 'Sharma',
            rollNumber: '005',
            maxMarks: 100,
            marksObtained: 72,
          ),
        ],
      );

      notifier.applyAdministrativeOverride('st-1', 78, 'Correction after answer script verification');
      final row = container.read(adminMarksBoardProvider).rows.first;
      expect(row.marksObtained, 78);
      expect(row.overrideReason, 'Correction after answer script verification');
      expect(row.isModified, isTrue);
      expect(row.validationError, isNull);
    });

    test('8. Board KPIs dynamically compute statistics', () {
      final state = AdminMarksBoardState(
        rows: [
          const AdminStudentMarkRow(
            studentId: 'st-1',
            firstName: 'A',
            lastName: '1',
            rollNumber: '001',
            maxMarks: 100,
            marksObtained: 90,
          ),
          const AdminStudentMarkRow(
            studentId: 'st-2',
            firstName: 'B',
            lastName: '2',
            rollNumber: '002',
            maxMarks: 100,
            marksObtained: 60,
          ),
          const AdminStudentMarkRow(
            studentId: 'st-3',
            firstName: 'C',
            lastName: '3',
            rollNumber: '003',
            maxMarks: 100,
            marksObtained: null,
            resultStatus: AdminMarkResultStatus.present,
          ),
          const AdminStudentMarkRow(
            studentId: 'st-4',
            firstName: 'D',
            lastName: '4',
            rollNumber: '004',
            maxMarks: 100,
            marksObtained: null,
            resultStatus: AdminMarkResultStatus.absent,
          ),
        ],
      );

      expect(state.totalStudents, 4);
      expect(state.enteredCount, 3); // 2 scores + 1 absent
      expect(state.missingCount, 1);
      expect(state.classAverage, 75.0); // (90 + 60) / 2
      expect(state.highestMarks, 90.0);
      expect(state.lowestMarks, 60.0);
    });

    test('9. School context switching resets marks and filter providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize selected school
      container.read(selectedSchoolIdProvider.notifier).state = 'school-1';
      container.read(adminMarksFiltersProvider.notifier).setAcademicYear('ay-1');
      container.read(adminMarksFiltersProvider.notifier).setExamination('exam-1');

      expect(container.read(adminMarksFiltersProvider).academicYearId, 'ay-1');

      // Switch school
      container.read(selectedSchoolIdProvider.notifier).state = 'school-2';

      expect(container.read(adminMarksFiltersProvider).academicYearId, isNull);
      expect(container.read(adminMarksBoardProvider).rows, isEmpty);
    });
  });
}
