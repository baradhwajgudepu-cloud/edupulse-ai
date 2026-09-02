import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/reports/presentation/pages/reports_dashboard_screen.dart';
import 'package:admin_portal/features/reports/presentation/providers/reports_provider.dart';
import 'package:admin_portal/features/settings/presentation/pages/settings_screen.dart';
import 'package:admin_portal/features/settings/presentation/providers/settings_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';

void main() {
  group('Reports Risk KPI & AI Predictive Insights Consistency Tests', () {
    testWidgets('Risk KPI 54 matches AI Predictive Modal count with 54 flagged students', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyHighRisk = List.generate(
        54,
        (i) => {
          'student_id': 'stud-$i',
          'student_name': 'Student High Risk #$i Long Name Demonstration',
          'class_name': 'Grade 10',
          'section_name': 'Section A',
          'current_percentage': 32.5,
          'previous_percentage': 35.0,
          'attendance_percentage': 72.0,
          'trend': 'DECLINING',
          'risk_level': 'HIGH',
          'ai_narrative': 'Student requires immediate academic assistance in core subjects.',
          'recommendation': 'Assign dedicated tutoring and schedule guardian conference.',
          'attendance_trend': 'DECLINING',
          'weak_subjects': ['Mathematics', 'Physics'],
        },
      );

      final overrides = [
        selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
        reportsDashboardProvider.overrideWith((ref) async => {
          'total_students': 250,
          'active_teachers': 18,
          'total_classes': 10,
          'total_sections': 20,
          'average_academic_performance': 68.5,
          'average_attendance': 88.0,
          'fee_collection_percentage': 92.0,
          'students_requiring_attention': 54,
        }),
        reportsAIIntelligenceProvider.overrideWith((ref) async => {
          'high_risk_students': dummyHighRisk,
          'medium_risk_students': [],
          'low_risk_students': [],
          'attendance_academic_risk_count': 54,
          'high_performers_count': 12,
        }),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: ReportsDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Risk Alerts KPI shows 54
      expect(find.text('54'), findsOneWidget);
      expect(find.text('Risk Alerts (School)'), findsOneWidget);

      // Tap on the Risk Alerts Overview card to open modal
      await tester.tap(find.text('Risk Alerts (School)'));
      await tester.pumpAndSettle();

      // Modal title should appear
      expect(find.text('AI Predictive Risk Insights'), findsOneWidget);
      // Student item should appear without overflow
      expect(find.text('Student High Risk #0 Long Name Demonstration'), findsOneWidget);
      expect(find.text('HIGH RISK'), findsWidgets);
    });

    testWidgets('Zero Risk State shows 0 KPI and "No Risk Alerts Flagged" in modal', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final overrides = [
        selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
        reportsDashboardProvider.overrideWith((ref) async => {
          'total_students': 250,
          'active_teachers': 18,
          'total_classes': 10,
          'total_sections': 20,
          'average_academic_performance': 82.5,
          'average_attendance': 95.0,
          'fee_collection_percentage': 98.0,
          'students_requiring_attention': 0,
        }),
        reportsAIIntelligenceProvider.overrideWith((ref) async => {
          'high_risk_students': [],
          'medium_risk_students': [],
          'low_risk_students': [],
          'attendance_academic_risk_count': 0,
          'high_performers_count': 45,
        }),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: ReportsDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
      expect(find.text('Risk Alerts (School)'), findsOneWidget);

      // Tap on the Risk Alerts Overview card
      await tester.tap(find.text('Risk Alerts (School)'));
      await tester.pumpAndSettle();

      expect(find.text('No Risk Alerts Flagged'), findsOneWidget);
    });
  });

  group('School Logo & Identity Settings Widget Tests', () {
    testWidgets('Settings screen renders School Logo section with Replace and Remove actions', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummySchool = SchoolDto(
        id: 'school-123',
        tenantId: 'tenant-123',
        name: 'Delhi Public School Bangalore',
        code: 'DPS_BLR',
        board: 'CBSE',
        schoolType: 'HIGH_SCHOOL',
        email: 'info@dpsblr.edu',
        phone: '+919876543210',
        website: 'https://dpsblr.edu',
        logoUrl: 'tenants/tenant-123/schools/school-123/branding/logo.png',
        isActive: true,
        status: 'ACTIVE',
        version: 1,
      );

      final overrides = [
        selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
        currentSchoolProvider.overrideWith((ref) async => dummySchool),
        tenantPreferencesProvider.overrideWith((ref) async => {
          'whatsapp_enabled': true,
          'whatsapp_provider': 'mock',
        }),
        deliveriesProvider.overrideWith((ref) async => []),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('School Logo & Branding'), findsOneWidget);
      expect(find.text('Current Logo Active'), findsOneWidget);
      expect(find.text('Replace Logo'), findsOneWidget);
      expect(find.text('Remove Logo'), findsOneWidget);
    });

    testWidgets('Settings screen renders cleanly on 320px narrow mobile viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummySchool = SchoolDto(
        id: 'school-123',
        tenantId: 'tenant-123',
        name: 'DPS Compact Mobile Test',
        code: 'DPS_MOB',
        board: 'CBSE',
        schoolType: 'HIGH_SCHOOL',
        email: 'compact@dps.edu',
        isActive: true,
        status: 'ACTIVE',
        version: 1,
      );

      final overrides = [
        selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
        currentSchoolProvider.overrideWith((ref) async => dummySchool),
        tenantPreferencesProvider.overrideWith((ref) async => {}),
        deliveriesProvider.overrideWith((ref) async => []),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('School Logo & Branding'), findsOneWidget);
      expect(find.text('Upload Logo'), findsOneWidget);
    });
  });
}
