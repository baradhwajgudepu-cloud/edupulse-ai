import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/features/school_setup/data/models/curriculum_models.dart';

void main() {
  group('Syllabus Class Bifurcation & 5-Level Hierarchy Suite', () {
    final sampleItemsClass8 = [
      const CurriculumChapterItemModel(
        id: 'top-1',
        syllabusCode: 'CBSE-MATH-8-01',
        chapterName: 'Rational Numbers',
        unitName: 'Number Systems',
        topicName: 'Properties of Rational Numbers',
        classId: 'class-8-uuid',
        subjectId: 'sub-math-uuid',
        sequenceOrder: 1,
        estimatedPeriods: 3,
        coverageStatus: 'COMPLETED',
        lifecycleStatus: 'COMPLETED',
        isCustom: false,
      ),
      const CurriculumChapterItemModel(
        id: 'top-2',
        syllabusCode: 'CBSE-MATH-8-01',
        chapterName: 'Rational Numbers',
        unitName: 'Number Systems',
        topicName: 'Representation on Number Line',
        classId: 'class-8-uuid',
        subjectId: 'sub-math-uuid',
        sequenceOrder: 2,
        estimatedPeriods: 2,
        coverageStatus: 'COMPLETED',
        lifecycleStatus: 'COMPLETED',
        isCustom: false,
      ),
      const CurriculumChapterItemModel(
        id: 'top-3',
        syllabusCode: 'CBSE-MATH-8-02',
        chapterName: 'Linear Equations in One Variable',
        unitName: 'Algebra',
        topicName: 'Solving Linear Equations',
        classId: 'class-8-uuid',
        subjectId: 'sub-math-uuid',
        sequenceOrder: 1,
        estimatedPeriods: 4,
        coverageStatus: 'PENDING',
        lifecycleStatus: 'PLANNED',
        isCustom: false,
      ),
      const CurriculumChapterItemModel(
        id: 'top-4',
        syllabusCode: 'CBSE-SCI-8-01',
        chapterName: 'Crop Production and Management',
        unitName: 'Food & Agriculture',
        topicName: 'Agricultural Practices & Sowing',
        classId: 'class-8-uuid',
        subjectId: 'sub-sci-uuid',
        sequenceOrder: 1,
        estimatedPeriods: 5,
        coverageStatus: 'PENDING',
        lifecycleStatus: 'PLANNED',
        isCustom: false,
      ),
    ];

    final sampleItemsClass9 = [
      const CurriculumChapterItemModel(
        id: 'top-9-1',
        syllabusCode: 'CBSE-MATH-9-01',
        chapterName: 'Number Systems',
        unitName: 'Number Systems',
        topicName: 'Irrational Numbers',
        classId: 'class-9-uuid',
        subjectId: 'sub-math-uuid',
        sequenceOrder: 1,
        estimatedPeriods: 4,
        coverageStatus: 'PENDING',
        lifecycleStatus: 'PLANNED',
        isCustom: false,
      ),
    ];

    test('1. Class-wise bifurcation isolates items strictly by classId', () {
      final combinedItems = [...sampleItemsClass8, ...sampleItemsClass9];

      final filteredClass8 = combinedItems.where((i) => i.classId == 'class-8-uuid').toList();
      final filteredClass9 = combinedItems.where((i) => i.classId == 'class-9-uuid').toList();

      expect(filteredClass8.length, equals(4));
      expect(filteredClass9.length, equals(1));
      expect(filteredClass8.every((i) => i.classId == 'class-8-uuid'), isTrue);
      expect(filteredClass9.every((i) => i.classId == 'class-9-uuid'), isTrue);
    });

    test('2. buildHierarchy organizes items into 5-level structure (Subject -> Unit -> Chapter -> Topic)', () {
      final subjectNames = {
        'sub-math-uuid': 'Mathematics',
        'sub-sci-uuid': 'Science',
      };

      final hierarchy = SyllabusHierarchySubject.buildHierarchy(
        items: sampleItemsClass8,
        subjectNameMap: subjectNames,
      );

      expect(hierarchy.length, equals(2)); // Mathematics and Science
      final math = hierarchy.firstWhere((s) => s.subjectName == 'Mathematics');
      final sci = hierarchy.firstWhere((s) => s.subjectName == 'Science');

      expect(math.units.length, equals(2)); // Number Systems, Algebra
      expect(sci.units.length, equals(1)); // Food & Agriculture

      final numSystemsUnit = math.units.firstWhere((u) => u.unitName == 'Number Systems');
      expect(numSystemsUnit.chapters.length, equals(1)); // Rational Numbers
      expect(numSystemsUnit.chapters.first.topics.length, equals(2)); // 2 topics
    });

    test('3. Dynamic period totals roll up accurately from topics to subjects', () {
      final subjectNames = {
        'sub-math-uuid': 'Mathematics',
        'sub-sci-uuid': 'Science',
      };

      final hierarchy = SyllabusHierarchySubject.buildHierarchy(
        items: sampleItemsClass8,
        subjectNameMap: subjectNames,
      );

      final math = hierarchy.firstWhere((s) => s.subjectName == 'Mathematics');
      final numSystemsUnit = math.units.firstWhere((u) => u.unitName == 'Number Systems');
      final rationalNumbersChapter = numSystemsUnit.chapters.first;

      // Chapter Rational Numbers has 3 + 2 = 5 periods
      expect(rationalNumbersChapter.totalEstimatedPeriods, equals(5));

      // Mathematics total = 3 + 2 + 4 = 9 periods
      expect(math.totalEstimatedPeriods, equals(9));
      expect(math.totalChapters, equals(2));
      expect(math.totalTopics, equals(3));
    });

    test('4. Completion percentages compute accurately based on COMPLETED status', () {
      final subjectNames = {
        'sub-math-uuid': 'Mathematics',
        'sub-sci-uuid': 'Science',
      };

      final hierarchy = SyllabusHierarchySubject.buildHierarchy(
        items: sampleItemsClass8,
        subjectNameMap: subjectNames,
      );

      final math = hierarchy.firstWhere((s) => s.subjectName == 'Mathematics');
      final numSystemsUnit = math.units.firstWhere((u) => u.unitName == 'Number Systems');
      final rationalNumbersChapter = numSystemsUnit.chapters.first;

      // Rational numbers chapter: 2 out of 2 completed = 100%
      expect(rationalNumbersChapter.completionPercentage, equals(100.0));

      // Math overall: 2 out of 3 completed = 66.666%
      expect(math.completionPercentage, closeTo(66.67, 0.1));
    });
  });
}
