import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/features/results/data/models/admin_marks_models.dart';
import 'package:admin_portal/features/results/data/models/academic_predictive_models.dart';

void main() {
  group('Marks Import & Predictive Analytics Integrity Suite', () {
    test('1. ExamWideUploadPreviewModel correctly calculates valid/invalid rows and detected scope', () {
      final json = {
        'total_rows': 25,
        'valid_rows_count': 23,
        'invalid_rows_count': 2,
        'classes_detected': ['Grade 10'],
        'sections_detected': ['Section A'],
        'subjects_detected': ['Mathematics', 'Science'],
        'students_count': 23,
        'errors': ['Row 12: Marks obtained (105) exceeds maximum marks (100)'],
        'preview_rows': [
          {
            'row_number': 1,
            'class_name': 'Grade 10',
            'section_name': 'Section A',
            'roll_number': '101',
            'student_name': 'Rohan Verma',
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 85.5,
            'status': 'PRESENT',
            'is_valid': true,
          },
          {
            'row_number': 2,
            'class_name': 'Grade 10',
            'section_name': 'Section A',
            'roll_number': '102',
            'student_name': 'Aarav Sharma',
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 105.0,
            'status': 'PRESENT',
            'is_valid': false,
            'error_message': 'Marks obtained exceeds max marks',
          },
        ],
      };

      final model = ExamWideUploadPreviewModel.fromJson(json);

      expect(model.totalRows, 25);
      expect(model.validRowsCount, 23);
      expect(model.invalidRowsCount, 2);
      expect(model.classesDetected, contains('Grade 10'));
      expect(model.subjectsDetected, containsAll(['Mathematics', 'Science']));
      expect(model.previewRows.length, 2);
      expect(model.previewRows.first.isValid, isTrue);
      expect(model.previewRows.last.isValid, isFalse);
    });

    test('2. ExamWideUploadResultModel tracks idempotent upserts (createdCount vs updatedCount)', () {
      final json = {
        'examination_id': 'exam-uuid-1',
        'examination_name': 'Term 1 Midterm',
        'students_processed': 35,
        'classes_count': 1,
        'sections_count': 1,
        'subjects_count': 3,
        'total_records': 105,
        'saved_count': 105,
        'created_count': 90,
        'updated_count': 15,
        'failed_count': 0,
      };

      final result = ExamWideUploadResultModel.fromJson(json);

      expect(result.examinationName, 'Term 1 Midterm');
      expect(result.totalRecords, 105);
      expect(result.savedCount, 105);
      expect(result.createdCount, 90);
      expect(result.updatedCount, 15);
      expect(result.failedCount, 0);
    });

    test('3. DataSufficiencyModel enforces strict zero-hallucination tier rules', () {
      // 0 Exams -> INSUFFICIENT_DATA
      final insufficientJson = {
        'exam_count': 0,
        'min_required_exams': 2,
        'sufficiency_status': 'INSUFFICIENT_DATA',
        'status_message': 'Insufficient assessment data',
        'is_predictive': false,
      };
      final suff0 = DataSufficiencyModel.fromJson(insufficientJson);
      expect(suff0.isInsufficient, isTrue);
      expect(suff0.isDescriptiveOnly, isFalse);
      expect(suff0.isPredictiveActive, isFalse);
      expect(suff0.isPredictive, isFalse);

      // 1 Exam -> DESCRIPTIVE_ONLY (No trajectory prediction)
      final descriptiveJson = {
        'exam_count': 1,
        'min_required_exams': 2,
        'sufficiency_status': 'DESCRIPTIVE_ONLY',
        'status_message': 'Trajectory prediction requires at least two examination cycles.',
        'is_predictive': false,
      };
      final suff1 = DataSufficiencyModel.fromJson(descriptiveJson);
      expect(suff1.isInsufficient, isFalse);
      expect(suff1.isDescriptiveOnly, isTrue);
      expect(suff1.isPredictiveActive, isFalse);
      expect(suff1.statusMessage, contains('requires at least two examination cycles'));

      // >= 2 Exams -> PREDICTIVE_ACTIVE
      final predictiveJson = {
        'exam_count': 3,
        'min_required_exams': 2,
        'sufficiency_status': 'PREDICTIVE_ACTIVE',
        'status_message': 'Sufficient examination data for trajectory prediction.',
        'is_predictive': true,
      };
      final suff2 = DataSufficiencyModel.fromJson(predictiveJson);
      expect(suff2.isInsufficient, isFalse);
      expect(suff2.isDescriptiveOnly, isFalse);
      expect(suff2.isPredictiveActive, isTrue);
      expect(suff2.isPredictive, isTrue);
    });

    test('4. AcademicPredictiveAnalyticsModel handles unmapped questions fallback safely', () {
      final json = {
        'data_sufficiency': {
          'exam_count': 1,
          'min_required_exams': 2,
          'sufficiency_status': 'DESCRIPTIVE_ONLY',
          'status_message': 'Trajectory prediction requires at least two examination cycles.',
          'is_predictive': false,
        },
        'subject_performance': [
          {
            'subject_id': 'sub-1',
            'subject_name': 'Mathematics',
            'subject_code': 'MATH101',
            'average_percentage': 72.5,
            'min_percentage': 40.0,
            'max_percentage': 96.0,
            'pass_rate_percentage': 88.0,
            'difficulty_rating': 'MEDIUM',
            'historical_trend': [],
            'risk_level': 'LOW',
            'syllabus_coverage_pct': 70.0,
          },
        ],
        'chapter_performance': {
          'is_available': false,
          'message': 'Chapter-level analysis unavailable because examination questions are not mapped',
          'chapters': [],
        },
        'syllabus_correlation': {
          'is_available': false,
          'message': 'Curriculum correlation requires multiple assessment cycles',
        },
      };

      final model = AcademicPredictiveAnalyticsModel.fromJson(json);

      expect(model.dataSufficiency.isDescriptiveOnly, isTrue);
      expect(model.subjectPerformance.length, 1);
      expect(model.subjectPerformance.first.subjectName, 'Mathematics');
      expect(model.chapterPerformance.isAvailable, isFalse);
      expect(
        model.chapterPerformance.message,
        contains('examination questions are not mapped'),
      );
    });

    test('5. StudentPredictiveAnalyticsModel extracts trajectory, score band, and focus subjects', () {
      final json = {
        'data_sufficiency': {
          'exam_count': 2,
          'min_required_exams': 2,
          'sufficiency_status': 'PREDICTIVE_ACTIVE',
          'status_message': 'Active trajectory modeling',
          'is_predictive': true,
        },
        'student_predictive_summary': {
          'trajectory_direction': 'IMPROVING',
          'trajectory_slope': 7.0,
          'predicted_score_band': {
            'min_percentage': 76.0,
            'max_percentage': 88.0,
            'confidence_interval': '95%',
          },
          'weak_subjects': ['Physics'],
          'strong_subjects': ['Mathematics', 'Computer Science'],
        },
        'exam_history': [
          {'exam_name': 'Term 1 Midterm', 'percentage': 70.0},
          {'exam_name': 'Term 1 Final', 'percentage': 84.0},
        ],
      };

      final model = StudentPredictiveAnalyticsModel.fromJson(json);

      expect(model.dataSufficiency.isPredictiveActive, isTrue);
      expect(model.studentPredictiveSummary, isNotNull);
      final summary = model.studentPredictiveSummary!;
      expect(summary.trajectoryDirection, 'IMPROVING');
      expect(summary.predictedScoreBand?.minPercentage, 76.0);
      expect(summary.predictedScoreBand?.maxPercentage, 88.0);
      expect(summary.weakSubjects, contains('Physics'));
      expect(summary.strongSubjects, containsAll(['Mathematics', 'Computer Science']));
    });
  });
}
