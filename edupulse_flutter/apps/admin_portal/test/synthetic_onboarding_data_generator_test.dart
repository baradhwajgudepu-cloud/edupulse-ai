import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_models.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_validators.dart';
import 'package:admin_portal/features/bulk_import/data/models/synthetic_onboarding_data_generator.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/school_onboarding_providers.dart';

void main() {
  group('Synthetic Onboarding Data Generator Tests', () {
    test('Generates all 13 onboarding CSV datasets with exact required cardinalities', () {
      final csvs = SyntheticOnboardingDataGenerator.generateAllCsvs(
        schoolCode: 'TMSJC',
        schoolName: 'Telangana Model School & Junior College',
        schoolEmail: 'principal.ts001@telanganaschool.edu',
        board: 'CBSE',
      );

      expect(csvs.length, equals(13));

      final expectedCounts = {
        OnboardingStep.school: 1,
        OnboardingStep.academicYears: 1,
        OnboardingStep.classes: 6,
        OnboardingStep.sections: 12,
        OnboardingStep.subjects: 6,
        OnboardingStep.teachers: 18,
        OnboardingStep.guardians: 360,
        OnboardingStep.students: 360,
        OnboardingStep.relationships: 360,
        OnboardingStep.teacherAssignments: 72,
        OnboardingStep.timetable: 360,
        OnboardingStep.syllabus: 114,
        OnboardingStep.exams: 36,
      };

      for (final entry in expectedCounts.entries) {
        final step = entry.key;
        final expected = entry.value;
        final csv = csvs[step]!;

        // Must not contain escaped literal backslash-n
        expect(csv.contains(r'\\n'), isFalse, reason: 'CSV for ${step.label} should not contain literal \\\\n');

        final parsed = SchoolOnboardingValidators.parseCsv(csv);
        final dataRows = parsed.length - 1; // Exclude header
        expect(dataRows, equals(expected), reason: 'Expected $expected rows for ${step.label}, got $dataRows');
      }
    });

    test('Guardians CSV generates 360 genuine distinct records with unique mobile/email', () {
      final csvs = SyntheticOnboardingDataGenerator.generateAllCsvs();
      final guardiansCsv = csvs[OnboardingStep.guardians]!;

      final parsed = SchoolOnboardingValidators.parseCsv(guardiansCsv);
      expect(parsed.length - 1, equals(360));

      final mobileSet = <String>{};
      final emailSet = <String>{};
      final codeSet = <String>{};

      for (int i = 1; i < parsed.length; i++) {
        final row = parsed[i];
        final code = row[0];
        final mob = row[5];
        final email = row[6];

        expect(codeSet.add(code), isTrue, reason: 'Duplicate guardian_code: $code');
        expect(mobileSet.add(mob), isTrue, reason: 'Duplicate mobile: $mob');
        expect(emailSet.add(email), isTrue, reason: 'Duplicate email: $email');
      }
    });

    test('Students CSV generates 360 records with unique admission numbers and roll numbers per section', () {
      final csvs = SyntheticOnboardingDataGenerator.generateAllCsvs();
      final studentsCsv = csvs[OnboardingStep.students]!;

      final parsed = SchoolOnboardingValidators.parseCsv(studentsCsv);
      expect(parsed.length - 1, equals(360));

      final admSet = <String>{};
      for (int i = 1; i < parsed.length; i++) {
        final adm = parsed[i][0];
        expect(admSet.add(adm), isTrue, reason: 'Duplicate admission_number: $adm');
      }
    });

    test('Teachers CSV generates 18 distinct faculty members', () {
      final csvs = SyntheticOnboardingDataGenerator.generateAllCsvs();
      final teachersCsv = csvs[OnboardingStep.teachers]!;

      final parsed = SchoolOnboardingValidators.parseCsv(teachersCsv);
      expect(parsed.length - 1, equals(18));

      final empSet = <String>{};
      for (int i = 1; i < parsed.length; i++) {
        final emp = parsed[i][7];
        expect(empSet.add(emp), isTrue, reason: 'Duplicate employee_code: $emp');
      }
    });

    test('CSV Parser correctly handles CRLF, quoted fields, and UTF-8 round-trip', () {
      const sampleCsv = "col1,col2,col3\r\n\"Val 1\",\"Val, with comma\",Val3\r\nVal4,Val5,\"Val6\"\r\n";
      final parsed = SchoolOnboardingValidators.parseCsv(sampleCsv);

      expect(parsed.length, equals(3));
      expect(parsed[0], equals(['col1', 'col2', 'col3']));
      expect(parsed[1], equals(['Val 1', 'Val, with comma', 'Val3']));
      expect(parsed[2], equals(['Val4', 'Val5', 'Val6']));

      // UTF-8 bytes round-trip
      final bytes = utf8.encode(sampleCsv);
      final decoded = utf8.decode(bytes);
      final parsedFromBytes = SchoolOnboardingValidators.parseCsv(decoded);
      expect(parsedFromBytes.length, equals(3));
      expect(parsedFromBytes[1][1], equals('Val, with comma'));
    });

    test('schoolOnboardingProvider loadSyntheticFixture populates state with 360 guardians and 360 students', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();

      final state = container.read(schoolOnboardingProvider);

      expect(state.sheets.containsKey(OnboardingStep.guardians), isTrue);
      expect(state.sheets[OnboardingStep.guardians]!.rows.length, equals(360));

      expect(state.sheets.containsKey(OnboardingStep.students), isTrue);
      expect(state.sheets[OnboardingStep.students]!.rows.length, equals(360));

      expect(state.sheets.containsKey(OnboardingStep.teachers), isTrue);
      expect(state.sheets[OnboardingStep.teachers]!.rows.length, equals(18));

      expect(state.sheets.containsKey(OnboardingStep.relationships), isTrue);
      expect(state.sheets[OnboardingStep.relationships]!.rows.length, equals(360));

      expect(state.sheets.containsKey(OnboardingStep.teacherAssignments), isTrue);
      expect(state.sheets[OnboardingStep.teacherAssignments]!.rows.length, equals(72));

      expect(state.sheets.containsKey(OnboardingStep.timetable), isTrue);
      expect(state.sheets[OnboardingStep.timetable]!.rows.length, equals(360));

      expect(state.sheets.containsKey(OnboardingStep.syllabus), isTrue);
      expect(state.sheets[OnboardingStep.syllabus]!.rows.length, equals(114));

      expect(state.sheets.containsKey(OnboardingStep.exams), isTrue);
      expect(state.sheets[OnboardingStep.exams]!.rows.length, equals(36));
    });
  });
}
