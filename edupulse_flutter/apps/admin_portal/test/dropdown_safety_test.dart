import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/core/presentation/utils/dropdown_safety.dart';
import 'package:admin_portal/core/presentation/widgets/safe_dropdown.dart';
import 'package:admin_portal/features/attendance/data/models/attendance_models.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

void main() {
  group('DropdownSafety Utility Tests', () {
    test('Test B: Case normalization and synonym mapping to canonical enums', () {
      // SICK variations
      expect(DropdownSafety.normalizeAttendanceReason('SICK'), equals('SICK'));
      expect(DropdownSafety.normalizeAttendanceReason('sick'), equals('SICK'));
      expect(DropdownSafety.normalizeAttendanceReason('Sick'), equals('SICK'));
      expect(DropdownSafety.normalizeAttendanceReason('  SICKNESS  '), equals('SICK'));
      expect(DropdownSafety.normalizeAttendanceReason('illness'), equals('SICK'));
      expect(DropdownSafety.normalizeAttendanceReason('MEDICAL'), equals('SICK'));
      expect(DropdownSafety.normalizeAttendanceReason('medical_leave'), equals('SICK'));

      // PERSONAL variations
      expect(DropdownSafety.normalizeAttendanceReason('PERSONAL'), equals('PERSONAL'));
      expect(DropdownSafety.normalizeAttendanceReason('family_emergency'), equals('PERSONAL'));
      expect(DropdownSafety.normalizeAttendanceReason('appointment'), equals('PERSONAL'));
      expect(DropdownSafety.normalizeAttendanceReason('transport_delay'), equals('PERSONAL'));

      // SPORTS variations
      expect(DropdownSafety.normalizeAttendanceReason('SPORTS'), equals('SPORTS'));
      expect(DropdownSafety.normalizeAttendanceReason('athletics'), equals('SPORTS'));
      expect(DropdownSafety.normalizeAttendanceReason('tournament'), equals('SPORTS'));

      // OFFICIAL variations
      expect(DropdownSafety.normalizeAttendanceReason('OFFICIAL'), equals('OFFICIAL'));
      expect(DropdownSafety.normalizeAttendanceReason('official_duty'), equals('OFFICIAL'));
      expect(DropdownSafety.normalizeAttendanceReason('competition'), equals('OFFICIAL'));

      // Fallback to UNKNOWN
      expect(DropdownSafety.normalizeAttendanceReason(null), equals('UNKNOWN'));
      expect(DropdownSafety.normalizeAttendanceReason(''), equals('UNKNOWN'));
      expect(DropdownSafety.normalizeAttendanceReason('unexcused'), equals('UNKNOWN'));
      expect(DropdownSafety.normalizeAttendanceReason('other'), equals('UNKNOWN'));
      expect(DropdownSafety.normalizeAttendanceReason('completely_random_string'), equals('UNKNOWN'));
    });

    test('deduplicateBy preserves order and removes duplicates', () {
      final input = ['Apple', 'banana', 'APPLE', 'Cherry', 'banana', 'date'];
      final deduplicated = DropdownSafety.deduplicateBy<String, String>(
        items: input,
        valueExtractor: (item) => item,
        keyNormalizer: (key) => key.toLowerCase(),
      );

      expect(deduplicated, equals(['Apple', 'banana', 'Cherry', 'date']));
    });

    test('safeMenuItems deduplicates DropdownMenuItem by value', () {
      final items = [
        const DropdownMenuItem<String>(value: 'SICK', child: Text('Sick 1')),
        const DropdownMenuItem<String>(value: 'PERSONAL', child: Text('Personal')),
        const DropdownMenuItem<String>(value: 'SICK', child: Text('Sick 2 (duplicate)')),
        const DropdownMenuItem<String>(value: 'OFFICIAL', child: Text('Official')),
      ];

      final sanitized = DropdownSafety.safeMenuItems(items: items);
      expect(sanitized.length, equals(3));
      expect(sanitized.map((e) => e.value).toList(), equals(['SICK', 'PERSONAL', 'OFFICIAL']));
    });

    test('safeValue validates selected value against available options', () {
      final valid = ['SICK', 'PERSONAL', 'UNKNOWN'];

      // Value present -> returns original
      expect(DropdownSafety.safeValue(selectedValue: 'SICK', validValues: valid), equals('SICK'));

      // Value missing -> returns fallback (null default)
      expect(DropdownSafety.safeValue(selectedValue: 'SPORTS', validValues: valid), isNull);

      // Value missing with explicit fallback -> returns explicit fallback
      expect(
        DropdownSafety.safeValue(selectedValue: 'SPORTS', validValues: valid, fallback: 'UNKNOWN'),
        equals('UNKNOWN'),
      );

      // Selected value null -> returns fallback
      expect(DropdownSafety.safeValue(selectedValue: null, validValues: valid), isNull);
    });

    test('Status-specific allowed reasons logic', () {
      expect(DropdownSafety.getReasonsForStatus('PRESENT'), equals(['UNKNOWN']));
      expect(DropdownSafety.getReasonsForStatus('ABSENT'), containsAll(['UNKNOWN', 'SICK', 'PERSONAL']));
      expect(DropdownSafety.getReasonsForStatus('ABSENT'), isNot(contains('SPORTS')));
      expect(DropdownSafety.getReasonsForStatus('LATE'), containsAll(['UNKNOWN', 'PERSONAL', 'OFFICIAL']));
    });
  });

  group('SafeDropdownButton and SafeDropdownButtonFormField Widget Tests', () {
    testWidgets('Test A: Duplicate items deduplicated without triggering assertion', (tester) async {
      final itemsWithDuplicates = [
        const DropdownMenuItem<String>(value: 'SICK', child: Text('Sick Option 1')),
        const DropdownMenuItem<String>(value: 'SICK', child: Text('Sick Option 2 Duplicate')),
        const DropdownMenuItem<String>(value: 'PERSONAL', child: Text('Personal Option')),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButtonFormField<String>(
              value: 'SICK',
              items: itemsWithDuplicates,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Should render without throwing Flutter material Dropdown duplicate item assertion
      expect(tester.takeException(), isNull);
      expect(find.text('Sick Option 1'), findsOneWidget);
    });

    testWidgets('Test C: Stale selected value not in items safely falls back without assertion', (tester) async {
      final items = [
        const DropdownMenuItem<String>(value: 'SICK', child: Text('Sick Option')),
        const DropdownMenuItem<String>(value: 'PERSONAL', child: Text('Personal Option')),
      ];

      // Value 'NON_EXISTENT_STALE_VALUE' is not in items.
      // Standard DropdownButtonFormField throws: "There should be exactly one item with [DropdownButton]'s value..."
      // SafeDropdownButtonFormField handles this gracefully by defaulting to null.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButtonFormField<String>(
              value: 'NON_EXISTENT_STALE_VALUE',
              items: items,
              hint: const Text('Select a reason'),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Select a reason'), findsOneWidget);
    });

    testWidgets('Test C2: SafeDropdownButton (plain) handles stale value safely', (tester) async {
      final items = [
        const DropdownMenuItem<String>(value: 'CLASS_A', child: Text('Class A')),
        const DropdownMenuItem<String>(value: 'CLASS_B', child: Text('Class B')),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButton<String>(
              value: 'OLD_CLASS_C',
              items: items,
              hint: const Text('Select Class'),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Select Class'), findsOneWidget);
    });

    testWidgets('Test E: Dynamic refresh removing selected option resets safely without crash', (tester) async {
      var options = ['Section A', 'Section B', 'Section C'];
      var selected = 'Section C';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SafeDropdownButtonFormField<String>(
                      key: const Key('dynamic_dropdown'),
                      value: selected,
                      items: options
                          .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selected = val ?? 'Section A';
                        });
                      },
                    ),
                    ElevatedButton(
                      key: const Key('refresh_btn'),
                      onPressed: () {
                        setState(() {
                          // Filter changes: new class only has Section A and Section B. Section C is gone!
                          options = ['Section A', 'Section B'];
                        });
                      },
                      child: const Text('Switch Class'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Section C'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Trigger dynamic refresh where Section C is removed
      await tester.tap(find.byKey(const Key('refresh_btn')));
      await tester.pumpAndSettle();

      // No assertion thrown despite previously selected 'Section C' not existing in new items
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test F: Bulk import edit scenario with SICK renders exactly one matching option', (tester) async {
      // Simulates imported record with reason 'SICK'
      const importedReason = 'SICK';
      final allowedReasons = DropdownSafety.getReasonsForStatus('ABSENT');

      final menuItems = allowedReasons.map((code) {
        return DropdownMenuItem<String>(
          value: code,
          child: Text(DropdownSafety.getReasonLabel(code)),
        );
      }).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButtonFormField<String>(
              value: DropdownSafety.normalizeAttendanceReason(importedReason),
              items: menuItems,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Sick / Medical'), findsOneWidget);
    });
  });

  group('Attendance Roster State Transition Tests', () {
    test('Test D: Status transition (ABSENT with SICK -> PRESENT clears reason to UNKNOWN)', () {
      final container = ProviderContainer(
        overrides: [
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyAttendanceMarkProvider.notifier);

      // Setup initial student roster with student_1 ABSENT and reason SICK
      final studentAbsent = StudentRosterItem(
        studentId: 'student_1',
        rollNumber: '1',
        admissionNumber: 'ADM001',
        studentName: 'John Doe',
        status: 'ABSENT',
        reason: 'SICK',
        remarks: 'Doctor note pending',
        isSelected: true,
      );

      notifier.state = DailyAttendanceMarkState(
        roster: [studentAbsent],
      );

      // Student changes status from ABSENT to PRESENT
      notifier.updateStudentStatus('student_1', 'PRESENT');

      final updatedStudent = notifier.state.roster.firstWhere((s) => s.studentId == 'student_1');
      expect(updatedStudent.status, equals('PRESENT'));
      // Reason MUST be cleared to UNKNOWN because PRESENT students have no absence reason
      expect(updatedStudent.reason, equals(DropdownSafety.reasonUnknown));
    });

    test('markAllPresent resets all reasons to UNKNOWN', () {
      final container = ProviderContainer(
        overrides: [
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyAttendanceMarkProvider.notifier);

      final students = [
        StudentRosterItem(
          studentId: 's1',
          rollNumber: '1',
          admissionNumber: 'A1',
          studentName: 'Student 1',
          status: 'ABSENT',
          reason: 'SICK',
        ),
        StudentRosterItem(
          studentId: 's2',
          rollNumber: '2',
          admissionNumber: 'A2',
          studentName: 'Student 2',
          status: 'LATE',
          reason: 'PERSONAL',
        ),
      ];

      notifier.state = DailyAttendanceMarkState(
        roster: students,
      );

      notifier.markAllPresent();

      for (final s in notifier.state.roster) {
        expect(s.status, equals('PRESENT'));
        expect(s.reason, equals(DropdownSafety.reasonUnknown));
      }
    });

    test('markSelectedStatus validates and adjusts incompatible reasons', () {
      final container = ProviderContainer(
        overrides: [
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyAttendanceMarkProvider.notifier);

      final students = [
        StudentRosterItem(
          studentId: 's1',
          rollNumber: '1',
          admissionNumber: 'A1',
          studentName: 'Student 1',
          status: 'ABSENT',
          reason: 'SICK',
          isSelected: true,
        ),
      ];

      notifier.state = DailyAttendanceMarkState(
        roster: students,
      );

      // Mark selected to LATE (LATE does not allow SICK, only UNKNOWN, PERSONAL, OFFICIAL)
      notifier.markSelectedStatus('LATE');

      final updated = notifier.state.roster.first;
      expect(updated.status, equals('LATE'));
      expect(updated.reason, equals(DropdownSafety.reasonUnknown));
    });
  });
}
