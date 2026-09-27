import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edupulse_ui/edupulse_ui.dart';

void main() {
  group('EduPulse Design System Widgets', () {
    testWidgets('KPICard renders correctly with trend and value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KPICard(
              title: 'Total Students',
              value: '1,420',
              subtitle: 'Active enrollments',
              trendValue: '+4.2%',
              trendPositive: true,
              badgeText: 'Term 1',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('TOTAL STUDENTS'), findsOneWidget);
      expect(find.text('1,420'), findsOneWidget);
      expect(find.text('Active enrollments'), findsOneWidget);
      expect(find.text('+4.2%'), findsOneWidget);
      expect(find.text('Term 1'), findsOneWidget);
    });

    testWidgets('StatusBadge renders correct variants', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(label: 'Active', variant: StatusBadgeVariant.success),
                StatusBadge(label: 'Pending', variant: StatusBadgeVariant.warning),
                StatusBadge(label: 'Overdue', variant: StatusBadgeVariant.error),
                StatusBadge(label: 'Informational', variant: StatusBadgeVariant.info),
                StatusBadge(label: 'Draft', variant: StatusBadgeVariant.neutral),
                StatusBadge(label: 'Platform', variant: StatusBadgeVariant.brand),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Informational'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
    });

    testWidgets('DonutChart renders slices and center label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonutChart(
              title: 'Student Attendance',
              timeframe: 'Today',
              centerLabel: '94%',
              centerSublabel: 'Present',
              data: [
                DonutSegment(id: 'p', label: 'Present', value: 94, color: Colors.teal),
                DonutSegment(id: 'a', label: 'Absent', value: 6, color: Colors.red),
              ],
            ),
          ),
        ),
      );

      expect(find.text('STUDENT ATTENDANCE'), findsOneWidget);
      expect(find.text('94%'), findsWidgets);
      expect(find.text('Present'), findsWidgets);
    });

    testWidgets('LineTrendChart renders points and threshold line', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LineTrendChart(
              title: 'Attendance Trend',
              threshold: 75,
              thresholdLabel: '75% Min Target',
              data: [
                TrendDataPoint(label: 'Jul', value: 88),
                TrendDataPoint(label: 'Aug', value: 92),
                TrendDataPoint(label: 'Sep', value: 94),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ATTENDANCE TREND'), findsOneWidget);
      expect(find.byType(LineTrendChart), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ProgressRing renders percentage value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressRing(
              value: 86,
              label: 'Term Average',
            ),
          ),
        ),
      );

      expect(find.text('86%'), findsOneWidget);
      expect(find.text('Term Average'), findsOneWidget);
    });

    testWidgets('SubjectBarChart renders ranked subject bars', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectBarChart(
              title: 'Subject Breakdown',
              benchmark: 75,
              data: [
                SubjectScore(subject: 'Mathematics', score: 92, strong: true),
                SubjectScore(subject: 'Science', score: 85),
                SubjectScore(subject: 'English', score: 58, needsSupport: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('SUBJECT BREAKDOWN'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
    });

    testWidgets('AIInsightCard renders analysis and recommendation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AIInsightCard(
              trend: TrendDirection.improving,
              headline: 'Attendance is up 4% this month',
              insight: 'Consistent morning attendance across standard 8 and 9.',
              strongHighlights: ['Mathematics', 'Physics'],
              supportHighlights: ['English grammar'],
              actionRecommendation: 'Schedule 20-minute daily vocabulary drill.',
            ),
          ),
        ),
      );

      expect(find.text('AI DATA ANALYSIS'), findsOneWidget);
      expect(find.text('Attendance is up 4% this month'), findsOneWidget);
      expect(find.text('Schedule 20-minute daily vocabulary drill.'), findsOneWidget);
    });

    testWidgets('State feedback widgets render correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  EmptyStateWidget(
                    title: 'No Records',
                    description: 'Start by creating your first entry.',
                    actionText: 'Create Entry',
                    onAction: () {},
                  ),
                  const ErrorStateWidget(
                    title: 'Connection Lost',
                    description: 'Could not fetch records.',
                  ),
                  const InsufficientDataState(
                    title: 'Gathering Data',
                    message: 'Needs 3 terms of history.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Records'), findsOneWidget);
      expect(find.text('Create Entry'), findsOneWidget);
      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('GATHERING DATA'), findsOneWidget);
    });
  });
}
