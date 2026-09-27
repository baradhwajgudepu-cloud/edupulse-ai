import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import '../../../../core/router/routes.dart';
import '../providers/dashboard_provider.dart';

class DashboardCards extends StatelessWidget {
  final ParentDashboardData data;

  const DashboardCards({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final selected = data.selectedStudent;
    final totalFees = data.totalFees;
    final hasPendingFees = data.pendingFees > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Student Profile Card with Biometric Check-In
        if (selected != null)
          Card(
            elevation: 1,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: EduPulseTheme.primaryTeal,
                        child: Text(
                          selected.firstName.isNotEmpty ? selected.firstName.substring(0, 1).toUpperCase() : 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : EduPulseTheme.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Class Info: ${selected.className} - ${selected.sectionName.replaceAll('Section ', '')}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Admission No: ${selected.admissionNumber}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(radius.sm),
                      border: Border.all(
                        color: isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: EduPulseTheme.emeraldSuccess),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Campus Check-In Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF064E3B),
                                  ),
                                ),
                                Text(
                                  'Biometric gate entry at 08:42 AM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const StatusBadge(
                          label: 'Present',
                          variant: StatusBadgeVariant.success,
                          size: StatusBadgeSize.sm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: spacing.md),

        // 2. Core ProgressRing Metric Tiles
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.md, horizontal: spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                InkWell(
                  onTap: () => context.push(AppRoutes.attendance),
                  borderRadius: BorderRadius.circular(radius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ProgressRing(
                      value: data.attendancePercentage,
                      size: 78,
                      strokeWidth: 7,
                      color: EduPulseTheme.emeraldSuccess,
                      sublabel: 'Compliant',
                      label: 'Presence Rate',
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.push(AppRoutes.homework),
                  borderRadius: BorderRadius.circular(radius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ProgressRing(
                      value: data.pendingHomeworkCount == 0
                          ? 100.0
                          : (100.0 - (data.pendingHomeworkCount * 15)).clamp(20.0, 95.0),
                      size: 78,
                      strokeWidth: 7,
                      color: EduPulseTheme.primaryTeal,
                      sublabel: '${data.pendingHomeworkCount} Due',
                      label: 'Tasks Done',
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.push(AppRoutes.exams),
                  borderRadius: BorderRadius.circular(radius.sm),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: ProgressRing(
                      value: 88.0,
                      size: 78,
                      strokeWidth: 7,
                      color: Color(0xFF2563EB),
                      sublabel: 'Grade A2',
                      label: 'Term Average',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.md),

        // 3. Visual Analytics Section
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LineTrendChart(
                  title: 'Academic Performance Trajectory',
                  timeframe: 'Unit Test 1 → Pre-Board 2026',
                  data: [
                    TrendDataPoint(label: 'UT 1', value: 82),
                    TrendDataPoint(label: 'Mid-Term', value: 85),
                    TrendDataPoint(label: 'UT 2', value: 83),
                    TrendDataPoint(label: 'Pre-Board', value: 88),
                  ],
                  threshold: 75,
                  thresholdLabel: 'Class Avg (75%)',
                  unit: '%',
                  trend: TrendDirection.improving,
                  trendNote: 'Consistent upward trajectory in STEM subjects',
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 12),
                SubjectBarChart(
                  title: 'Subject-Wise Mastery Breakdown',
                  timeframe: 'Latest Term Assessment',
                  data: [
                    SubjectScore(subject: 'Mathematics', score: 88, grade: 'A1'),
                    SubjectScore(subject: 'Science', score: 85, grade: 'A2'),
                    SubjectScore(subject: 'English', score: 78, grade: 'B1'),
                    SubjectScore(subject: 'Social Studies', score: 82, grade: 'A2'),
                  ],
                  benchmark: 75,
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 12),
                AIInsightCard(
                  trend: TrendDirection.improving,
                  headline: 'Academic Progress & Strengths Analysis',
                  insight:
                      'Student demonstrates exceptional mastery in Mathematics (88%) and Science (85%). Consistent classroom participation and high concept retention observed.',
                  timeframe: 'Academic Year 2025-2026',
                  strongHighlights: ['Mathematics (88%)', 'Science (85%)'],
                  supportHighlights: ['English Composition'],
                  actionRecommendation:
                      'Maintain momentum in Calculus problem sets and review weekly essay rubrics.',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.md),

        // 4. Fees Card (Dark Slate hero card matching Google AI Studio prototype)
        Card(
          elevation: 2,
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TERM 1 FEE STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: EduPulseTheme.primaryTeal.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasPendingFees
                              ? '${currencyFormatter.format(data.pendingFees)} Outstanding'
                              : 'All Dues Cleared',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(
                      label: hasPendingFees ? 'Pending' : 'Paid in Full',
                      variant: hasPendingFees ? StatusBadgeVariant.warning : StatusBadgeVariant.success,
                      size: StatusBadgeSize.sm,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasPendingFees
                      ? 'Tuition and laboratory materials fee due for September 2026 term.'
                      : 'No outstanding school fees for the active academic session.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(radius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDarkFeeDetail('Total Fees', currencyFormatter.format(totalFees)),
                      _buildDarkFeeDetail('Paid', currencyFormatter.format(data.paidFees), textColor: EduPulseTheme.emeraldSuccess),
                      _buildDarkFeeDetail('Pending', currencyFormatter.format(data.pendingFees), textColor: const Color(0xFFF87171)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.payFees),
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('Pay Fees'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EduPulseTheme.emeraldSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius.sm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.md),

        // 5. 2x2 Grid for Other Cards
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: spacing.md,
          mainAxisSpacing: spacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            // Attendance Card
            _buildParentCard(
              context: context,
              title: 'Attendance Summary',
              icon: Icons.fact_check_rounded,
              color: Colors.teal,
              onTap: () => context.push(AppRoutes.attendance),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.attendancePercentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    'Present: ${data.presentCount} | Absent: ${data.absentCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Homework Card
            _buildParentCard(
              context: context,
              title: 'Homework Overview',
              icon: Icons.menu_book_rounded,
              color: Colors.orange,
              onTap: () => context.push(AppRoutes.homework),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.pendingHomeworkCount} Pending',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    'Due assignments',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Exam Card
            _buildParentCard(
              context: context,
              title: 'Exams & Results',
              icon: Icons.assessment_rounded,
              color: Colors.blue,
              onTap: () => context.push(AppRoutes.exams),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.upcomingExam,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    data.latestResult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Announcements Card
            _buildParentCard(
              context: context,
              title: 'Announcements',
              icon: Icons.notifications_active_rounded,
              color: Colors.purple,
              onTap: () => context.push(AppRoutes.announcements),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.latestNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDarkFeeDetail(String label, String value, {Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildParentCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  SizedBox(width: spacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

