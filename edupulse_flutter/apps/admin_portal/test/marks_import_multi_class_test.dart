import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/features/results/data/models/admin_marks_models.dart';
import 'package:admin_portal/features/results/data/models/examination_models.dart';

void main() {
  group('Multi-Class Marks Import Suite', () {
    test('1. ExamWideUploadRowModel parses isExisting field correctly', () {
      final jsonExisting = {
        'row_number': 1,
        'class_name': 'Class 5',
        'section_name': 'Section A',
        'roll_number': '501',
        'student_name': 'Aarav Kumar',
        'subject_name': 'Mathematics',
        'max_marks': 50,
        'marks_obtained': 45.0,
        'status': 'PRESENT',
        'is_valid': true,
        'is_existing': true,
      };

      final rowExisting = ExamWideUploadRowModel.fromJson(jsonExisting);
      expect(rowExisting.isExisting, isTrue);
      expect(rowExisting.className, 'Class 5');
      expect(rowExisting.maxMarks, 50);

      final jsonNew = {
        'row_number': 2,
        'class_name': 'Class 10',
        'section_name': 'Section A',
        'roll_number': '1001',
        'student_name': 'Diya Sharma',
        'subject_name': 'Mathematics',
        'max_marks': 100,
        'marks_obtained': 88.0,
        'status': 'PRESENT',
        'is_valid': true,
        'is_existing': false,
      };

      final rowNew = ExamWideUploadRowModel.fromJson(jsonNew);
      expect(rowNew.isExisting, isFalse);
      expect(rowNew.className, 'Class 10');
      expect(rowNew.maxMarks, 100);
    });

    test('2. ExamWideUploadPreviewModel parses existingMarksCount and classesSummary', () {
      final json = {
        'total_rows': 60,
        'valid_rows_count': 58,
        'invalid_rows_count': 2,
        'existing_marks_count': 20,
        'classes_detected': ['Class 5', 'Class 6', 'Class 10'],
        'sections_detected': ['Section A', 'Section B'],
        'subjects_detected': ['Mathematics', 'Science', 'English'],
        'students_count': 58,
        'errors': ['Row 4: Marks exceed maximum'],
        'preview_rows': [],
        'classes_summary': [
          {
            'class_name': 'Class 5',
            'class_id': 'cls-5-id',
            'sections_count': 1,
            'sections': ['Section A'],
            'students_count': 20,
            'valid_rows': 19,
            'invalid_rows': 1,
            'existing_rows': 5,
          },
          {
            'class_name': 'Class 6',
            'class_id': 'cls-6-id',
            'sections_count': 2,
            'sections': ['Section A', 'Section B'],
            'students_count': 38,
            'valid_rows': 39,
            'invalid_rows': 1,
            'existing_rows': 15,
          },
        ],
      };

      final preview = ExamWideUploadPreviewModel.fromJson(json);

      expect(preview.totalRows, 60);
      expect(preview.validRowsCount, 58);
      expect(preview.invalidRowsCount, 2);
      expect(preview.existingMarksCount, 20);
      expect(preview.classesDetected, containsAll(['Class 5', 'Class 6', 'Class 10']));
      expect(preview.classesSummary.length, 2);

      final c5 = preview.classesSummary.first;
      expect(c5.className, 'Class 5');
      expect(c5.sectionsCount, 1);
      expect(c5.studentsCount, 20);
      expect(c5.existingRows, 5);

      final c6 = preview.classesSummary.last;
      expect(c6.className, 'Class 6');
      expect(c6.sectionsCount, 2);
      expect(c6.existingRows, 15);
    });

    test('3. ExamWideUploadResultModel tracks skippedCount alongside created and updated counts', () {
      final json = {
        'examination_id': 'exam-quarterly-2026',
        'examination_name': 'Quarterly Examination 2026',
        'students_processed': 360,
        'classes_count': 6,
        'sections_count': 6,
        'subjects_count': 6,
        'total_records': 2160,
        'saved_count': 2000,
        'failed_count': 0,
        'created_count': 1500,
        'updated_count': 500,
        'skipped_count': 160,
      };

      final result = ExamWideUploadResultModel.fromJson(json);

      expect(result.examinationName, 'Quarterly Examination 2026');
      expect(result.classesCount, 6);
      expect(result.totalRecords, 2160);
      expect(result.savedCount, 2000);
      expect(result.createdCount, 1500);
      expect(result.updatedCount, 500);
      expect(result.skippedCount, 160);
      expect(result.failedCount, 0);
    });

    test('4. Strict cycle filtering identifies only participating classes for cycle', () {
      const exam = ExaminationModel(
        id: 'exam-cycle-1',
        tenantId: 't-1',
        schoolId: 's-1',
        academicYearId: 'ay-1',
        examName: 'Quarterly Examination 2026',
        examType: 'EXAMINATION',
        startDate: '2026-09-01',
        endDate: '2026-09-15',
        status: ExamStatusEnum.scheduled,
        participatingClassIds: ['cls-5', 'cls-6', 'cls-7', 'cls-8', 'cls-9', 'cls-10'],
        participatingClassNames: ['Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'],
      );

      final allSchoolClasses = [
        {'id': 'cls-nursery', 'name': 'Nursery'},
        {'id': 'cls-1', 'name': 'Class 1'},
        {'id': 'cls-5', 'name': 'Class 5'},
        {'id': 'cls-6', 'name': 'Class 6'},
        {'id': 'cls-7', 'name': 'Class 7'},
        {'id': 'cls-8', 'name': 'Class 8'},
        {'id': 'cls-9', 'name': 'Class 9'},
        {'id': 'cls-10', 'name': 'Class 10'},
      ];

      // Step 3 strict filter simulation
      final participating = allSchoolClasses
          .where((c) => exam.effectiveClassIds.contains(c['id']))
          .toList();

      expect(participating.length, 6);
      expect(participating.map((c) => c['name']), containsAll([
        'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'
      ]));
      expect(participating.map((c) => c['name']), isNot(contains('Nursery')));
      expect(participating.map((c) => c['name']), isNot(contains('Class 1')));
    });

    test('5. ExamWideUploadResultModel parses classesBreakdown and failureBreakdown', () {
      final json = {
        'examination_id': 'exam-quarterly-2026',
        'examination_name': 'Quarterly Examination 2026',
        'students_processed': 1080,
        'classes_count': 3,
        'sections_count': 6,
        'subjects_count': 6,
        'total_records': 1080,
        'saved_count': 1080,
        'failed_count': 0,
        'created_count': 720,
        'updated_count': 360,
        'skipped_count': 0,
        'classes_breakdown': [
          {
            'class_name': 'Class 5',
            'sections_count': 2,
            'sections': ['Section A', 'Section B'],
            'students_count': 60,
            'total_records': 360,
            'created_count': 270,
            'updated_count': 90,
            'skipped_count': 0,
            'failed_count': 0,
          },
          {
            'class_name': 'Class 6',
            'sections_count': 2,
            'sections': ['Section A', 'Section B'],
            'students_count': 60,
            'total_records': 360,
            'created_count': 360,
            'updated_count': 0,
            'skipped_count': 0,
            'failed_count': 0,
          },
          {
            'class_name': 'Class 7',
            'sections_count': 2,
            'sections': ['Section A', 'Section B'],
            'students_count': 60,
            'total_records': 360,
            'created_count': 360,
            'updated_count': 0,
            'skipped_count': 0,
            'failed_count': 0,
          },
        ],
        'failure_breakdown': {
          'Schedule missing': 0,
          'Student not found': 0,
        },
      };

      final result = ExamWideUploadResultModel.fromJson(json);

      expect(result.classesBreakdown.length, 3);
      expect(result.classesBreakdown[0].className, 'Class 5');
      expect(result.classesBreakdown[0].totalRecords, 360);
      expect(result.classesBreakdown[0].createdCount, 270);
      expect(result.classesBreakdown[0].updatedCount, 90);
      expect(result.classesBreakdown[1].className, 'Class 6');
      expect(result.classesBreakdown[2].className, 'Class 7');
      expect(result.failureBreakdown['Schedule missing'], 0);
    });

    test('6. ExamWideUploadResultModel parses missing class status, reason and legacy fallback keys', () {
      final json = {
        'examination_id': 'exam-quarterly-2026',
        'examination_name': 'Quarterly Examination 2026',
        'classes_count': 1,
        'total_records': 360,
        'saved_count': 360,
        'created_count': 360,
        'updated_count': 0,
        'skipped_count': 0,
        'failed_count': 0,
        'classes_breakdown': [
          {
            'class_name': 'Class 5',
            'sections_count': 2,
            'sections': ['Section A', 'Section B'],
            'students_count': 60,
            'processed': 360,
            'created': 360,
            'updated': 0,
            'skipped': 0,
            'failed': 0,
            'status': 'SUCCESS',
            'reason': null,
          },
          {
            'class_name': 'Class 10',
            'sections_count': 2,
            'sections': ['Section A', 'Section B'],
            'students_count': 60,
            'total_records': 0,
            'created_count': 0,
            'updated_count': 0,
            'skipped_count': 0,
            'failed_count': 0,
            'status': 'NOT_FOUND',
            'reason': 'No student marks records found in upload data for this class',
          },
        ],
      };

      final result = ExamWideUploadResultModel.fromJson(json);

      expect(result.classesBreakdown.length, 2);
      final c5 = result.classesBreakdown[0];
      expect(c5.className, 'Class 5');
      expect(c5.totalRecords, 360);
      expect(c5.createdCount, 360);
      expect(c5.status, 'SUCCESS');
      expect(c5.reason, isNull);

      final c10 = result.classesBreakdown[1];
      expect(c10.className, 'Class 10');
      expect(c10.totalRecords, 0);
      expect(c10.createdCount, 0);
      expect(c10.status, 'NOT_FOUND');
      expect(c10.reason, 'No student marks records found in upload data for this class');
    });
  });
}

