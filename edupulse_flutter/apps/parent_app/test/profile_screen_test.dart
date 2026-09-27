import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:parent_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:parent_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:parent_app/features/auth/presentation/providers/auth_provider.dart';

class FakeParentAuthStateNotifier extends AuthStateNotifier {
  final UserEntity _user;
  FakeParentAuthStateNotifier(this._user);

  @override
  AuthState build() {
    return Authenticated(_user);
  }
}

class FakeMultiChildDashboardNotifier extends DashboardNotifier {
  final List<StudentProfile> _students;
  StudentProfile _selectedStudent;

  FakeMultiChildDashboardNotifier(this._students, this._selectedStudent);

  @override
  DashboardState build() {
    return DashboardSuccess(
      ParentDashboardData(
        students: _students,
        selectedStudent: _selectedStudent,
        attendancePercentage: 92.0,
        presentCount: 18,
        absentCount: 2,
        totalFees: 50000,
        paidFees: 35000,
        pendingFees: 15000,
        pendingHomeworkCount: 2,
        upcomingExam: 'Mid-Terms',
        latestResult: 'A',
        latestNotice: 'School reopening on Monday',
      ),
    );
  }

  @override
  void selectStudent(StudentProfile student) {
    _selectedStudent = student;
    state = DashboardSuccess(
      ParentDashboardData(
        students: _students,
        selectedStudent: student,
        attendancePercentage: 95.0,
        presentCount: 19,
        absentCount: 1,
        totalFees: 40000,
        paidFees: 40000,
        pendingFees: 0,
        pendingHomeworkCount: 1,
        upcomingExam: 'Finals',
        latestResult: 'A+',
        latestNotice: 'Sports day next week',
      ),
    );
  }
}

void main() {
  group('Parent App Profile & Multi-Child Switcher Tests', () {
    testWidgets('Renders Profile, Linked Children, and allows one-tap child switching', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockParent = UserEntity(
        id: 'usr-p1',
        firstName: 'Anjali',
        lastName: 'Sharma',
        email: 'anjali.sharma@parent.com',
        tenantId: 'ten-1',
        isSuperuser: false,
        roles: ['PARENT'],
        schools: ['sch-1'],
        schoolNames: {'sch-1': 'Sunrise International School'},
      );

      final student1 = StudentProfile(
        id: 'std-1',
        firstName: 'Rahul',
        lastName: 'Sharma',
        admissionNumber: 'ADM-2024-001',
        classId: 'cls-10',
        sectionId: 'sec-a',
        academicYearId: 'ay-1',
        className: '10',
        sectionName: 'A',
      );

      final student2 = StudentProfile(
        id: 'std-2',
        firstName: 'Priya',
        lastName: 'Sharma',
        admissionNumber: 'ADM-2024-045',
        classId: 'cls-6',
        sectionId: 'sec-b',
        academicYearId: 'ay-1',
        className: '6',
        sectionName: 'B',
      );

      final fakeDashboardNotifier = FakeMultiChildDashboardNotifier([student1, student2], student1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => FakeParentAuthStateNotifier(mockParent)),
            dashboardStateProvider.overrideWith(() => fakeDashboardNotifier),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Profile Header Verification
      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Anjali Sharma'), findsOneWidget);
      expect(find.text('anjali.sharma@parent.com'), findsOneWidget);
      expect(find.text('Parent / Guardian'), findsOneWidget);
      expect(find.text('Sunrise International School'), findsOneWidget);

      // 2. Multi-Child Switcher Verification
      expect(find.text('Linked Children'), findsOneWidget);
      expect(find.text('2 Children'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);

      // Active indicator on Rahul Sharma
      expect(find.text('Active'), findsOneWidget);

      // 3. Switch active child to Priya Sharma
      await tester.tap(find.text('Priya Sharma'));
      await tester.pumpAndSettle();

      expect(find.text('Switched to Priya Sharma'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // 4. Security & Preferences
      expect(find.text('Security & Preferences'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update Profile Photo'), findsOneWidget);

      // 5. Sign Out
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
