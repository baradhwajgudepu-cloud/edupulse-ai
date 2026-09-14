import 'package:flutter_test/flutter_test.dart';
import 'package:edupulse_core/edupulse_core.dart';

void main() {
  group('displaySubjectName Helper Tests', () {
    test('Returns subjectName when present and non-empty', () {
      final result = displaySubjectName(
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        subjectId: '123e4567-e89b-12d3-a456-426614174000',
      );
      expect(result, 'Mathematics');
    });

    test('Trims whitespace from subjectName', () {
      final result = displaySubjectName(
        subjectName: '   English Language   ',
        subjectCode: 'ENG101',
      );
      expect(result, 'English Language');
    });

    test('Falls back to subjectCode when subjectName is null', () {
      final result = displaySubjectName(
        subjectName: null,
        subjectCode: 'SCI101',
        subjectId: '123e4567-e89b-12d3-a456-426614174000',
      );
      expect(result, 'SCI101');
    });

    test('Falls back to subjectCode when subjectName is empty or whitespace only', () {
      final result = displaySubjectName(
        subjectName: '   ',
        subjectCode: 'SOC101',
      );
      expect(result, 'SOC101');
    });

    test('Trims whitespace from subjectCode', () {
      final result = displaySubjectName(
        subjectName: '',
        subjectCode: '   HIN101   ',
      );
      expect(result, 'HIN101');
    });

    test('Falls back to default "Subject" when both subjectName and subjectCode are null', () {
      final result = displaySubjectName(
        subjectName: null,
        subjectCode: null,
        subjectId: '123e4567-e89b-12d3-a456-426614174000',
      );
      expect(result, 'Subject');
    });

    test('Falls back to default "Subject" when both subjectName and subjectCode are empty', () {
      final result = displaySubjectName(
        subjectName: '  ',
        subjectCode: '',
      );
      expect(result, 'Subject');
    });

    test('Never exposes or returns internal UUID subjectId', () {
      const fakeUuid = 'b5f2c4a1-0d3a-4467-8e62-9e8a5b28d09f';
      final result = displaySubjectName(
        subjectName: null,
        subjectCode: null,
        subjectId: fakeUuid,
      );
      expect(result, isNot(contains(fakeUuid)));
      expect(result, 'Subject');
    });
  });
}
