import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_models.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_validators.dart';

void main() {
  group('School Onboarding Scale & Preview Independence Tests', () {
    test('360 students dataset validates all 360 rows with zero errors', () {
      final List<List<String>> csvRows = [];
      csvRows.add([
        'admission_number',
        'first_name',
        'last_name',
        'gender',
        'date_of_birth',
        'admission_date',
        'roll_number',
        'academic_year_code',
        'class_code',
        'section_code',
        'status'
      ]);

      for (int i = 1; i <= 360; i++) {
        csvRows.add([
          'ADM2025${i.toString().padLeft(3, '0')}',
          'Student$i',
          'Rao',
          i % 2 == 1 ? 'MALE' : 'FEMALE',
          '2014-06-15',
          '2025-06-01',
          '${(i % 30) + 1}',
          'AY2025-2026',
          'C5',
          'A',
          'ACTIVE'
        ]);
      }

      final sheetData = SchoolOnboardingValidators.validateSheet(
        OnboardingStep.students,
        'students.csv',
        csvRows,
      );

      expect(sheetData.rows.length, equals(360));
      expect(sheetData.rows.every((r) => r.status == OnboardingRowStatus.valid), isTrue);
      expect(sheetData.rows.every((r) => r.errors.isEmpty), isTrue);
    });

    test('Validation error on row 101 is accurately detected beyond the 50-row preview limit', () {
      final List<List<String>> csvRows = [];
      csvRows.add([
        'guardian_code',
        'first_name',
        'last_name',
        'gender',
        'date_of_birth',
        'mobile',
        'email',
        'guardian_type',
        'status'
      ]);

      for (int i = 1; i <= 360; i++) {
        final email = (i == 101) ? 'INVALID_EMAIL_FORMAT' : 'guardian$i@test.com';
        csvRows.add([
          'GRD${i.toString().padLeft(3, '0')}',
          'Guardian$i',
          'Sharma',
          'MALE',
          '1985-05-10',
          '9849${i.toString().padLeft(6, '0')}',
          email,
          'FATHER',
          'ACTIVE'
        ]);
      }

      final sheetData = SchoolOnboardingValidators.validateSheet(
        OnboardingStep.guardians,
        'guardians.csv',
        csvRows,
      );

      expect(sheetData.rows.length, equals(360));
      
      final row101 = sheetData.rows[100]; // 0-indexed index 100 is row 101
      expect(row101.rowIndex, equals(102)); // 1-indexed CSV line 102
      expect(row101.status, equals(OnboardingRowStatus.error));
      expect(row101.errors.any((e) => e.contains('email')), isTrue);
    });
  });
}
