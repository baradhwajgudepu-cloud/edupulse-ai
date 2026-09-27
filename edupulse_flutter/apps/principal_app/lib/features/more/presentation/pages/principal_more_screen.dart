import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../../../core/router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PrincipalMoreScreen extends ConsumerWidget {
  const PrincipalMoreScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the Principal App?'),
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
    final fullName = user?.fullName ?? 'Principal';
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
            // Profile & Campus Overview Card
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
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
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
                            'PRINCIPAL / CAMPUS LEADER',
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
                    tooltip: 'View Profile & School Context',
                    onPressed: () => context.push(AppRoutes.profile),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),

            // SECTION 1: STAFF & OPERATIONS
            _buildSectionHeader('STAFF & OPERATIONS', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _NavItem(
                  title: 'Teacher Directory',
                  subtitle: 'Browse teacher profiles, subjects & departments',
                  icon: Icons.badge_rounded,
                  color: EduPulseTheme.primaryTeal,
                  onTap: () => context.push(AppRoutes.teachers),
                ),
                _NavItem(
                  title: 'Staff Attendance',
                  subtitle: 'Review teacher daily check-ins & logs',
                  icon: Icons.how_to_reg_rounded,
                  color: EduPulseTheme.emeraldSuccess,
                  onTap: () => context.push(AppRoutes.teacherAttendance),
                ),
                _NavItem(
                  title: 'Staff Leave Requests',
                  subtitle: 'Review and approve/reject teacher leave applications',
                  icon: Icons.event_note_rounded,
                  color: EduPulseTheme.amberWarning,
                  onTap: () => context.push(AppRoutes.teacherLeaves),
                ),
                _NavItem(
                  title: 'Campus Geofence Configuration',
                  subtitle: 'Configure authoritative GPS boundary coordinates & radius',
                  icon: Icons.pin_drop_rounded,
                  color: EduPulseTheme.roseDanger,
                  onTap: () => context.push(AppRoutes.geofence),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 2: ACADEMICS & EXAMINATION
            _buildSectionHeader('ACADEMICS & EXAMINATION', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _NavItem(
                  title: 'Academic & Performance Analytics',
                  subtitle: 'Exam scores, student attendance rates & homework trajectories',
                  icon: Icons.insights_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => context.push(AppRoutes.analytics),
                ),
                _NavItem(
                  title: 'Manage Examinations',
                  subtitle: 'Setup assessment terms, exam schedules & grading schemas',
                  icon: Icons.assignment_turned_in_rounded,
                  color: EduPulseTheme.primaryTeal,
                  onTap: () => context.push(AppRoutes.manageExams),
                ),
                _NavItem(
                  title: 'Syllabus Progress & Recovery Intelligence',
                  subtitle: 'Institutional heatmap, pacing status & editable recovery plans',
                  icon: Icons.auto_stories_rounded,
                  color: const Color(0xFF0D9488),
                  onTap: () => context.push(AppRoutes.syllabusProgress),
                ),
                _NavItem(
                  title: 'Report Cards Management',
                  subtitle: 'Generate, lock reviews & publish academic report cards',
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push(AppRoutes.reportCards),
                ),
                _NavItem(
                  title: 'School Planner & Calendar',
                  subtitle: 'Manage events, announcements & institutional schedules',
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFFEC4899),
                  onTap: () => context.push(AppRoutes.planner),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 3: FINANCE & DUES
            _buildSectionHeader('FINANCE & DUES', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _NavItem(
                  title: 'Fees Collection & AI Analytics',
                  subtitle: 'Campus fee ledger, realization progress & forecasts',
                  icon: Icons.account_balance_wallet_rounded,
                  color: EduPulseTheme.emeraldSuccess,
                  onTap: () => context.push(AppRoutes.fees),
                ),
                _NavItem(
                  title: 'Class Outstanding Dues',
                  subtitle: 'Breakdown of pending tuition fees and defaulters by class',
                  icon: Icons.pending_actions_rounded,
                  color: EduPulseTheme.amberWarning,
                  onTap: () => context.push(AppRoutes.outstandingDetails),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 4: COMMUNICATION & ALERTS
            _buildSectionHeader('COMMUNICATION & ALERTS', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _NavItem(
                  title: 'Parent Inquiries Inbox',
                  subtitle: 'Direct two-way messaging and academic query tickets',
                  icon: Icons.forum_rounded,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => context.push(AppRoutes.communication),
                ),
                _NavItem(
                  title: 'School Notifications',
                  subtitle: 'System notices, parent broadcasts & alert logs',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFF97316),
                  onTap: () => context.push(AppRoutes.notifications),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),

            // SECTION 5: ACCOUNT & SYSTEM
            _buildSectionHeader('ACCOUNT & SYSTEM', isDark),
            SizedBox(height: spacing.xs),
            _buildNavCard(
              isDark: isDark,
              radius: radius,
              items: [
                _NavItem(
                  title: 'Principal Profile & Campus Context',
                  subtitle: 'Account metadata, security roles & campus switcher',
                  icon: Icons.account_circle_rounded,
                  color: EduPulseTheme.primaryTeal,
                  onTap: () => context.push(AppRoutes.profile),
                ),
                _NavItem(
                  title: 'Sign Out',
                  subtitle: 'End administrative session securely',
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
    required List<_NavItem> items,
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

class _NavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
