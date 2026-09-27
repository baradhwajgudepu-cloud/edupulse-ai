import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/school_setup_center_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';

class FakeSchoolsListNotifier extends StateNotifier<SchoolsListState> implements SchoolsListNotifier {
  FakeSchoolsListNotifier(super.state);

  @override
  Future<void> fetchSchools() async {}
}

void main() {
  group('SchoolSetupCenterScreen Widget Tests', () {
    testWidgets('Renders School Setup Center with 8 progressive setup stages and progress header', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockSchool = SchoolDto(
        id: 'school-1',
        name: 'Sri Vidya Junior College',
        code: 'TS-HYD-500072-JC',
        board: 'Telangana State Board (TSBIE)',
        schoolType: 'JUNIOR_COLLEGE',
        email: 'admin@srividya.edu',
        isActive: true,
        status: 'ACTIVE',
        tenantId: 'tenant-1',
        version: 1,
        principalName: 'Dr. K. V. Raman, Ph.D.',
        latitude: 17.4485,
        longitude: 78.3742,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-1'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SchoolSetupCenterScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header should display
      expect(find.text('School Setup Center'), findsOneWidget);
      expect(find.text('Foundational school database setup. Setup does not block daily admissions or fees.'), findsOneWidget);
      expect(find.textContaining('of 8 completed'), findsOneWidget);

      // Verify all 8 setup stage names are rendered
      expect(find.text('School Identity & Affiliation'), findsOneWidget);
      expect(find.text('Academic Year & Term Periods'), findsOneWidget);
      expect(find.text('Academic Classes & Streams'), findsOneWidget);
      expect(find.text('Sections & Faculty Allocation'), findsOneWidget);
      expect(find.text('Lecture Rooms & Campus Laboratories'), findsOneWidget);
      expect(find.text('Faculty & Administrative Staff Roster'), findsOneWidget);
      expect(find.text('Students Enrollment & Admissions'), findsOneWidget);
      expect(find.text('Guardians & Parent Portal Mapping'), findsOneWidget);

      // Verify active school data rendered in stage details
      expect(find.text('Sri Vidya Junior College'), findsOneWidget);
      expect(find.text('TS-HYD-500072-JC'), findsOneWidget);
      expect(find.text('Telangana State Board (TSBIE)'), findsOneWidget);
      expect(find.text('Dr. K. V. Raman, Ph.D.'), findsOneWidget);
    });
  });
}
