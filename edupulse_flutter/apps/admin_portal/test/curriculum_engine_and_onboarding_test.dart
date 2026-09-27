import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/features/school_setup/data/models/curriculum_models.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/curriculum_providers.dart';

void main() {
  group('Curriculum Engine & Board-Based Syllabus Verification Suite', () {
    test('1. CurriculumStatusModel parses populated verified status with full audit fields', () {
      final json = {
        'is_populated': true,
        'verified_curriculum_available': true,
        'board': 'CBSE',
        'state': null,
        'academic_year_name': '2025-2026',
        'source': 'NCERT / CBSE Official Curriculum 2025-2026',
        'source_version': '2025-26.v1',
        'verification_status': 'VERIFIED',
        'derived_from': null,
        'total_subjects_with_syllabus': 4,
        'total_chapters': 48,
        'total_topics': 180,
        'status_badge': 'VERIFIED OFFICIAL',
        'message': 'Official syllabus is active and verified.',
      };

      final status = CurriculumStatusModel.fromJson(json);

      expect(status.isPopulated, isTrue);
      expect(status.verifiedCurriculumAvailable, isTrue);
      expect(status.board, equals('CBSE'));
      expect(status.academicYearName, equals('2025-2026'));
      expect(status.source, contains('NCERT / CBSE'));
      expect(status.sourceVersion, equals('2025-26.v1'));
      expect(status.verificationStatus, equals('VERIFIED'));
      expect(status.derivedFrom, isNull);
      expect(status.totalSubjectsWithSyllabus, equals(4));
      expect(status.totalChapters, equals(48));
      expect(status.totalTopics, equals(180));
      expect(status.statusBadge, equals('VERIFIED OFFICIAL'));
    });

    test('2. CurriculumStatusModel handles unpopulated but available state correctly', () {
      final json = {
        'is_populated': false,
        'verified_curriculum_available': true,
        'board': 'ICSE',
        'state': null,
        'academic_year_name': '2025-2026',
        'total_subjects_with_syllabus': 0,
        'total_chapters': 0,
        'total_topics': 0,
        'status_badge': 'READY TO POPULATE',
        'message': 'Official syllabus available. Ready to auto-populate.',
      };

      final status = CurriculumStatusModel.fromJson(json);

      expect(status.isPopulated, isFalse);
      expect(status.verifiedCurriculumAvailable, isTrue);
      expect(status.statusBadge, equals('READY TO POPULATE'));
      expect(status.totalChapters, equals(0));
    });

    test('3. CurriculumStatusModel enforces zero-hallucination guardrail state when unavailable', () {
      final json = {
        'is_populated': false,
        'verified_curriculum_available': false,
        'board': 'IB_DIPLOMA_CUSTOM_UNKNOWN',
        'state': null,
        'total_subjects_with_syllabus': 0,
        'total_chapters': 0,
        'total_topics': 0,
        'status_badge': 'UNAVAILABLE',
        'message': 'Verified curriculum data unavailable for this board/year/class.',
      };

      final status = CurriculumStatusModel.fromJson(json);

      expect(status.isPopulated, isFalse);
      expect(status.verifiedCurriculumAvailable, isFalse);
      expect(status.statusBadge, equals('UNAVAILABLE'));
      expect(status.message, contains('Verified curriculum data unavailable'));
    });

    test('4. CurriculumPopulateResultModel deserializes batch clone results', () {
      final json = {
        'success': true,
        'message': 'Official syllabus successfully populated',
        'board': 'CBSE',
        'state': null,
        'academic_year_name': '2025-2026',
        'total_classes_processed': 1,
        'total_subjects_matched': 4,
        'total_chapters_populated': 48,
        'total_topics_populated': 180,
        'source': 'NCERT / CBSE Official Curriculum 2025-2026',
        'source_version': '2025-26.v1',
        'verification_status': 'VERIFIED',
      };

      final result = CurriculumPopulateResultModel.fromJson(json);

      expect(result.success, isTrue);
      expect(result.board, equals('CBSE'));
      expect(result.academicYearName, equals('2025-2026'));
      expect(result.totalClassesProcessed, equals(1));
      expect(result.totalSubjectsMatched, equals(4));
      expect(result.totalChaptersPopulated, equals(48));
      expect(result.totalTopicsPopulated, equals(180));
      expect(result.source, contains('NCERT / CBSE'));
      expect(result.sourceVersion, equals('2025-26.v1'));
      expect(result.verificationStatus, equals('VERIFIED'));
    });

    test('5. CurriculumChapterItemModel distinguishes between verified official and custom school chapters', () {
      final officialJson = {
        'id': 'syl-ch-1',
        'syllabus_code': 'CBSE-MATH-10-01',
        'chapter_name': 'Real Numbers',
        'unit_name': 'Number Systems',
        'topic_name': 'Fundamental Theorem of Arithmetic',
        'sequence_order': 1,
        'coverage_status': 'COMPLETED',
        'source': 'NCERT / CBSE Official Curriculum 2025-2026',
        'source_version': '2025-26.v1',
        'verification_status': 'VERIFIED',
        'is_custom': false,
      };

      final customJson = {
        'id': 'syl-ch-custom-99',
        'syllabus_code': 'CBSE-MATH-10-CUSTOM',
        'chapter_name': 'Olympiad Problem Solving & Extensions',
        'unit_name': 'Enrichment Units',
        'topic_name': 'Modular Arithmetic & Pigeonhole Principle',
        'sequence_order': 15,
        'coverage_status': 'PLANNED',
        'source': 'Manual Entry (School Campus)',
        'source_version': null,
        'verification_status': 'UNVERIFIED',
        'is_custom': true,
      };

      final officialItem = CurriculumChapterItemModel.fromJson(officialJson);
      final customItem = CurriculumChapterItemModel.fromJson(customJson);

      expect(officialItem.isCustom, isFalse);
      expect(officialItem.verificationStatus, equals('VERIFIED'));
      expect(officialItem.coverageStatus, equals('COMPLETED'));
      expect(officialItem.syllabusCode, equals('CBSE-MATH-10-01'));

      expect(customItem.isCustom, isTrue);
      expect(customItem.verificationStatus, equals('UNVERIFIED'));
      expect(customItem.chapterName, equals('Olympiad Problem Solving & Extensions'));
      expect(customItem.coverageStatus, equals('PLANNED'));
    });

    test('6. CurriculumStatusState immutably tracks loading, error, and status updates', () {
      final initial = CurriculumStatusState(
        status: CurriculumStatusModel.empty(),
        isLoading: false,
      );

      expect(initial.isLoading, isFalse);
      expect(initial.isPopulating, isFalse);
      expect(initial.error, isNull);

      final loading = initial.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);

      final populated = loading.copyWith(
        isLoading: false,
        isPopulating: false,
        status: const CurriculumStatusModel(
          isPopulated: true,
          verifiedCurriculumAvailable: true,
          board: 'Karnataka State Board',
          totalSubjectsWithSyllabus: 3,
          totalChapters: 30,
          totalTopics: 110,
          statusBadge: 'VERIFIED OFFICIAL',
          message: 'Karnataka State syllabus active.',
        ),
      );

      expect(populated.isLoading, isFalse);
      expect(populated.status.board, equals('Karnataka State Board'));
      expect(populated.status.totalChapters, equals(30));
    });
  });
}
