import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TeacherMoreScreen extends ConsumerWidget {
  const TeacherMoreScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the Teacher App?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final authState = ref.watch(authStateProvider);

    final user = authState is Authenticated ? authState.user : null;
    final fullName = user?.fullName ?? 'Teacher';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: isDark ? EduPulseTheme.slate950 : EduPulseTheme.slate50,
      appBar: AppBar(
        title: const Text(
          'More & Operations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Teacher Profile Overview Card
            Container(
              padding: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: isDark ? EduPulseTheme.slate900 : Colors.white,
                borderRadius: BorderRadius.circular(radius.md),
                border: Border.all(
                  color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate200,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: EduPulseTheme.primaryTeal.withValues(alpha: 0.12),
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: EduPulseTheme.primaryTeal,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : EduPulseTheme.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: EduPulseTheme.primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EDUCATOR / FACULTY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: EduPulseTheme.primaryTeal,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    tooltip: 'View Profile',
                    onPressed: () => context.push(AppRoutes.profile),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),

            // SECTION 1: TEACHING & STUDENTS
            _buildSectionHeader('TEACHING & STUDENTS', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _TeacherNavItem(
                  title: 'My Classes & Rosters',
                  subtitle: 'Class schedules, enrolled students & subjects',
                  icon: Icons.school_rounded,
                  color: EduPulseTheme.primaryTeal,
                  onTap: () => context.push(AppRoutes.myClasses),
                ),
                _TeacherNavItem(
                  title: 'Student Directory',
                  subtitle: 'Browse student records, parent contacts & profiles',
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => context.push(AppRoutes.studentDirectory),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 2: EVALUATION & GRADING
            _buildSectionHeader('EVALUATION & GRADING', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _TeacherNavItem(
                  title: 'Marks Entry Board',
                  subtitle: 'Bulk grade submission, mark entry & subject papers',
                  icon: Icons.analytics_rounded,
                  color: EduPulseTheme.emeraldSuccess,
                  onTap: () => context.push(AppRoutes.marks),
                ),
                _TeacherNavItem(
                  title: 'Results & Report Cards',
                  subtitle: 'Examine class-wide score sheets & preview report cards',
                  icon: Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push(AppRoutes.results),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 3: STAFF OPERATIONS
            _buildSectionHeader('STAFF OPERATIONS', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _TeacherNavItem(
                  title: 'Geofenced Campus Attendance',
                  subtitle: 'Authoritative GPS attendance check-in & check-out',
                  icon: Icons.pin_drop_rounded,
                  color: EduPulseTheme.roseDanger,
                  onTap: () => context.push(AppRoutes.staffAttendance),
                ),
                _TeacherNavItem(
                  title: 'Leave Requests & Approvals',
                  subtitle: 'Submit leave applications & track principal approval',
                  icon: Icons.event_note_rounded,
                  color: EduPulseTheme.amberWarning,
                  onTap: () => context.push(AppRoutes.teacherLeaveList),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 4: AI STUDIO & TOOLS
            _buildSectionHeader('AI STUDIO & TOOLS', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _TeacherNavItem(
                  title: 'AI Class Performance Diagnostics',
                  subtitle: 'Automated mastery breakdown & weak concept identification',
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => context.push(AppRoutes.classAnalysis),
                ),
                _TeacherNavItem(
                  title: 'AI Homework Generator',
                  subtitle: 'Generate differentiated questions, rubrics & tasks',
                  icon: Icons.psychology_rounded,
                  color: const Color(0xFFEC4899),
                  onTap: () => context.push(AppRoutes.homeworkGenerate),
                ),
                _TeacherNavItem(
                  title: 'School Events Calendar',
                  subtitle: 'Academic schedule, institutional events & holidays',
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => context.push(AppRoutes.events),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 5: COMMUNICATION
            _buildSectionHeader('COMMUNICATION', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _TeacherNavItem(
                  title: 'Parent Inquiries & Connect',
                  subtitle: 'Direct two-way parent queries & academic messaging',
                  icon: Icons.forum_rounded,
                  color: const Color(0xFF14B8A6),
                  onTap: () => context.push(AppRoutes.communication),
                ),
                _TeacherNavItem(
                  title: 'School Notifications',
                  subtitle: 'Broadcast alerts, circulars & official notices',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFF97316),
                  onTap: () => context.push(AppRoutes.notifications),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 6: ACCOUNT
            _buildSectionHeader('ACCOUNT', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _TeacherNavItem(
                  title: 'Teacher Profile & Settings',
                  subtitle: 'Personal details, employee code & password change',
                  icon: Icons.account_circle_rounded,
                  color: EduPulseTheme.primaryTeal,
                  onTap: () => context.push(AppRoutes.profile),
                ),
                _TeacherNavItem(
                  title: 'Sign Out',
                  subtitle: 'End faculty session securely',
                  icon: Icons.logout_rounded,
                  color: theme.colorScheme.error,
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
            SizedBox(height: spacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required bool isDark,
    required AppRadius radius,
    required List<_TeacherNavItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate200,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate100,
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: items[i].color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(items[i].icon, size: 20, color: items[i].color),
              ),
              title: Text(
                items[i].title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : EduPulseTheme.slate900,
                ),
              ),
              subtitle: Text(
                items[i].subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _TeacherNavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TeacherNavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
