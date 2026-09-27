import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/router/routes.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/domain/entities/timetable_entry.dart';
import '../../../dashboard/domain/entities/teacher_profile.dart';
import '../../../dashboard/domain/entities/academic_year.dart';
import '../../../dashboard/domain/entities/dashboard_data.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../../core/providers/school_context_provider.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardStateProvider.notifier).fetchDashboard();
      ref.read(notificationsStateProvider.notifier).fetchNotifications();
    });
  }

  String formatTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final minuteStr = minute.toString().padLeft(2, '0');
      return '$displayHour:$minuteStr $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  bool isClassOngoing(String startTimeStr, String endTimeStr) {
    try {
      final now = DateTime.now();
      final start = _parseTime(startTimeStr);
      final end = _parseTime(endTimeStr);
      return now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return false;
    }
  }

  bool isClassUpcoming(String startTimeStr) {
    try {
      final now = DateTime.now();
      final start = _parseTime(startTimeStr);
      return now.isBefore(start);
    } catch (_) {
      return false;
    }
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
      parts.length > 2 ? int.parse(parts[2]) : 0,
    );
  }

  bool isClassOngoingOrUpcoming(String startTimeStr, String endTimeStr) {
    return isClassOngoing(startTimeStr, endTimeStr) || isClassUpcoming(startTimeStr);
  }

  Color _parseHexColor(String? hexStr, Color defaultColor) {
    if (hexStr == null || hexStr.isEmpty) return defaultColor;
    try {
      final hex = hexStr.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 3) {
        final expanded = hex.split('').map((c) => '$c$c').join();
        return Color(int.parse('FF$expanded', radix: 16));
      }
    } catch (_) {}
    return defaultColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is Unauthenticated) {
        context.go(AppRoutes.login);
      }
    });

    final dashboardState = ref.watch(dashboardStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authStateProvider);
            final schoolName = ref.watch(activeSchoolNameProvider);
            final hasMultipleSchools = authState is Authenticated && authState.user.schools.length > 1;

            if (!hasMultipleSchools) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(local?.translate('app_title') ?? 'EduPulse AI'),
                  if (schoolName.isNotEmpty)
                    Text(
                      schoolName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
            }

            return InkWell(
              onTap: () => _showSchoolSwitcherDialog(context, ref, authState.user),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(local?.translate('app_title') ?? 'EduPulse AI'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            schoolName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer(
              builder: (context, ref, child) {
                final notifState = ref.watch(notificationsStateProvider);
                int unreadCount = 0;
                if (notifState is NotificationsSuccess) {
                  unreadCount = notifState.unreadCount;
                }
                return Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(unreadCount.toString()),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => context.push('/notifications'),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: local?.translate('logout') ?? 'Logout',
            onPressed: () {
              _showLogoutConfirmation(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(dashboardStateProvider.notifier).fetchDashboard();
            await ref.read(notificationsStateProvider.notifier).fetchNotifications(isRefresh: true);
          },
          child: _buildBody(dashboardState, theme, spacing, radius, local),
        ),
      ),
    );
  }

  Widget _buildBody(
    DashboardState state,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    switch (state) {
      case DashboardInitial():
      case DashboardLoading():
        return _buildSkeletonLoader(theme, spacing, radius);

      case DashboardError(:final message):
        return _buildErrorState(message, theme, spacing, radius);

      case DashboardEmpty():
        return _buildEmptyTimetableState(theme, spacing, radius, local);

      case DashboardSuccess(:final data, :final selectedDayOfWeek):
      case DashboardRefreshing(:final data, :final selectedDayOfWeek):
        return _buildDashboardContent(data, selectedDayOfWeek, theme, spacing, radius, local);
    }
  }

  Widget _buildDashboardContent(
    DashboardDataEntity data,
    String selectedDay,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    final teacher = data.teacherProfile;
    final activeYear = data.academicYear;
    
    // Filter and sort schedule
    final dailySchedule = data.schedule
        .where((entry) => entry.dayOfWeek.toUpperCase() == selectedDay.toUpperCase())
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    // Calculate current and next classes if selected day is indeed today
    final isTodaySelected = selectedDay.toUpperCase() ==
        ref.read(dashboardStateProvider.notifier).getBackendDayOfWeek(DateTime.now().weekday).toUpperCase();

    TimetableEntryEntity? ongoingClass;
    TimetableEntryEntity? nextClass;

    if (isTodaySelected && dailySchedule.isNotEmpty) {
      for (final entry in dailySchedule) {
        if (isClassOngoing(entry.startTime, entry.endTime)) {
          ongoingClass = entry;
        } else if (isClassUpcoming(entry.startTime)) {
          if (nextClass == null ||
              _parseTime(entry.startTime).isBefore(_parseTime(nextClass.startTime))) {
            nextClass = entry;
          }
        }
      }
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Teacher Profile Header
          _buildTeacherHeader(teacher, activeYear, theme, spacing, radius),
          SizedBox(height: spacing.md),

          // 2. Quick Actions
          Text(
            local?.translate('quick_actions') ?? 'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: spacing.sm),
          _buildQuickActionsGrid(theme, spacing, radius, local),
          SizedBox(height: spacing.lg),

          // 2.5 Campus Attendance Geofence Status Card (Google AI Studio UX)
          _buildCampusGeofenceCard(theme, spacing, radius),
          SizedBox(height: spacing.lg),

          // 2.6 AI Section
          _buildAiSection(theme, spacing, radius, local),
          SizedBox(height: spacing.lg),

          // 3. Timetable Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Class Timetable',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (ref.watch(dashboardStateProvider) is DashboardRefreshing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          SizedBox(height: spacing.xs),
          _buildDaySelectorBar(selectedDay, theme, spacing, radius),
          SizedBox(height: spacing.md),

          // 4. Schedule list
          if (data.schedule.isEmpty)
            _buildEmptyTimetableState(theme, spacing, radius, local)
          else if (dailySchedule.isEmpty)
            _buildNoClassesForDayCard(theme, spacing, radius)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dailySchedule.length,
              separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
              itemBuilder: (context, index) {
                final entry = dailySchedule[index];
                final isOngoing = ongoingClass?.id == entry.id;
                final isNext = nextClass?.id == entry.id && ongoingClass == null;
                return _buildPeriodCard(entry, isOngoing, isNext, selectedDay, theme, spacing, radius);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCampusGeofenceCard(ThemeData theme, AppSpacing spacing, AppRadius radius) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pin_drop_rounded,
                    size: 18,
                    color: EduPulseTheme.primaryTeal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Campus Attendance Geofence',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : EduPulseTheme.slate900,
                    ),
                  ),
                ],
              ),
              const StatusBadge(
                label: 'Radius 250m Active',
                variant: StatusBadgeVariant.success,
                size: StatusBadgeSize.sm,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'School Campus Center active. Geofence strictly gates attendance submission per Release 2.0 regulations (authoritative GPS accuracy <= 100m).',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherHeader(
    TeacherProfileEntity teacher,
    AcademicYearEntity activeYear,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.lg),
        side: BorderSide(
          color: theme.colorScheme.primaryContainer.withOpacity(0.8),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                '${teacher.firstName.isNotEmpty ? teacher.firstName[0] : ''}${teacher.lastName.isNotEmpty ? teacher.lastName[0] : ''}'
                    .toUpperCase(),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (teacher.designation != null || teacher.department != null) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      [teacher.designation, teacher.department]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' • '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  SizedBox(height: spacing.xs),
                  Text(
                    'Emp Code: ${teacher.employeeCode}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(radius.sm),
              ),
              child: Text(
                activeYear.code,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    final actions = [
      {
        'label': local?.translate('attendance') ?? 'Attendance',
        'desc': 'Mark daily classes',
        'icon': Icons.how_to_reg_rounded,
        'color': theme.colorScheme.primary,
      },
      {
        'label': local?.translate('homework') ?? 'Homework',
        'desc': 'Assign tasks & view',
        'icon': Icons.menu_book_rounded,
        'color': Colors.orange,
      },
      {
        'label': 'Marks Entry',
        'desc': 'Bulk exam grading',
        'icon': Icons.analytics_rounded,
        'color': Colors.green,
      },
      {
        'label': 'My Classes',
        'desc': 'Schedules & subjects',
        'icon': Icons.school_rounded,
        'color': Colors.blue,
      },
      {
        'label': 'Results',
        'desc': 'Report cards preview',
        'icon': Icons.assignment_turned_in_rounded,
        'color': Colors.purple,
      },
      {
        'label': 'Staff Attendance',
        'desc': 'Daily check-in/out',
        'icon': Icons.pin_drop_rounded,
        'color': Colors.red,
      },
      {
        'label': 'Leave Request',
        'desc': 'Submit & view leaves',
        'icon': Icons.event_note_rounded,
        'color': Colors.indigo,
      },
      {
        'label': 'Connect',
        'desc': 'Parent communication queries',
        'icon': Icons.forum_rounded,
        'color': Colors.teal,
      },
      {
        'label': 'Profile',
        'desc': 'Identity & subjects info',
        'icon': Icons.account_circle_rounded,
        'color': Colors.blueGrey,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final act = actions[index];
        final label = act['label'] as String;
        final desc = act['desc'] as String;
        final icon = act['icon'] as IconData;
        final color = act['color'] as Color;

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          child: InkWell(
            onTap: () {
              if (label == 'My Classes') {
                context.push(AppRoutes.myClasses);
              } else if (label == (local?.translate('homework') ?? 'Homework')) {
                context.push(AppRoutes.homework);
              } else if (label == 'Marks Entry') {
                context.push(AppRoutes.marks);
              } else if (label == 'Results') {
                context.push(AppRoutes.results);
              } else if (label == 'Staff Attendance') {
                context.push(AppRoutes.staffAttendance);
              } else if (label == 'Leave Request') {
                context.push(AppRoutes.teacherLeaveList);
              } else if (label == 'Connect') {
                context.push(AppRoutes.communication);
              } else if (label == 'Profile') {
                context.push(AppRoutes.profile);
              } else if (label == (local?.translate('attendance') ?? 'Attendance')) {
                _handleAttendanceTap();
              } else {
                _showComingSoonDialog(label);
              }
            },
            borderRadius: BorderRadius.circular(radius.md),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiSection(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.primary.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2), width: 1.5),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
                    SizedBox(width: spacing.sm),
                    Text(
                      'EduPulse AI Assistant',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/class-analysis'),
                        child: Container(
                          padding: EdgeInsets.all(spacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(radius.sm),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.analytics_outlined, color: Colors.deepPurple, size: 24),
                              SizedBox(height: spacing.xs),
                              const Text(
                                'Class Analysis',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              SizedBox(height: spacing.xs / 2),
                              Text(
                                'Analyze performance trends',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/homework-generate'),
                        child: Container(
                          padding: EdgeInsets.all(spacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(radius.sm),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.auto_awesome_outlined, color: Colors.purple, size: 24),
                              SizedBox(height: spacing.xs),
                              const Text(
                                'AI Homework',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              SizedBox(height: spacing.xs / 2),
                              Text(
                                'Generate questions & tasks',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelectorBar(
    String selectedDay,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    const days = [
      {'label': 'MON', 'value': 'MONDAY'},
      {'label': 'TUE', 'value': 'TUESDAY'},
      {'label': 'WED', 'value': 'WEDNESDAY'},
      {'label': 'THU', 'value': 'THURSDAY'},
      {'label': 'FRI', 'value': 'FRIDAY'},
      {'label': 'SAT', 'value': 'SATURDAY'},
      {'label': 'SUN', 'value': 'SUNDAY'},
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => SizedBox(width: spacing.xs),
        itemBuilder: (context, index) {
          final day = days[index];
          final label = day['label']!;
          final value = day['value']!;
          final isSelected = selectedDay.toUpperCase() == value.toUpperCase();

          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                ref.read(dashboardStateProvider.notifier).selectDay(value);
              }
            },
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            labelStyle: TextStyle(
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.sm),
              side: BorderSide(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildPeriodCard(
    TimetableEntryEntity entry,
    bool isOngoing,
    bool isNext,
    String selectedDay,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final subColor = _parseHexColor(entry.displayColor, theme.colorScheme.primary);

    return Card(
      elevation: isOngoing ? 2 : 0,
      color: isOngoing 
          ? theme.colorScheme.primaryContainer.withOpacity(0.2) 
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(
          color: isOngoing 
              ? theme.colorScheme.primary 
              : theme.colorScheme.outlineVariant,
          width: isOngoing ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          _showTimetableActionBottomSheet(context, entry, selectedDay);
        },
        borderRadius: BorderRadius.circular(radius.md),
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left block - Times
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatTimeString(entry.startTime).replaceAll(' AM', '').replaceAll(' PM', ''),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    formatTimeString(entry.endTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Subject color bar
            Container(
              width: 4,
              color: subColor,
            ),
            // Main block - details
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.subjectName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (entry.isRecovery)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: StatusBadge(
                              label: entry.recoveryLabel ?? 'RECOVERY CLASS',
                              variant: StatusBadgeVariant.warning,
                              size: StatusBadgeSize.sm,
                            ),
                          ),
                        if (isOngoing)
                          const StatusBadge(
                            label: 'ONGOING',
                            variant: StatusBadgeVariant.success,
                            size: StatusBadgeSize.sm,
                          )
                        else if (isNext)
                          const StatusBadge(
                            label: 'NEXT',
                            variant: StatusBadgeVariant.brand,
                            size: StatusBadgeSize.sm,
                          ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.class_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: spacing.xs),
                        Text(
                          '${entry.className} - ${entry.sectionName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (entry.roomId != null) ...[
                          Spacer(),
                          Icon(
                            Icons.place_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(width: spacing.xs),
                          Text(
                            'Room ${entry.roomId!.substring(0, 4).toUpperCase()}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: spacing.xs),
                        Expanded(
                          child: Text(
                            'Planned: ${entry.plannedTopic ?? "${entry.subjectName} Coverage"}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (entry.isRecovery && (entry.primaryTeacherName != null || entry.supportTeacherName != null)) ...[
                      SizedBox(height: spacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.handshake_outlined,
                            size: 13,
                            color: theme.colorScheme.tertiary,
                          ),
                          SizedBox(width: spacing.xs),
                          Expanded(
                            child: Text(
                              entry.primaryTeacherName != null
                                  ? 'Cross-Teacher Recovery (Primary: ${entry.primaryTeacherName})'
                                  : 'Support Teacher: ${entry.supportTeacherName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Period badge on far right
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(radius.md),
                  bottomRight: Radius.circular(radius.md),
                ),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  'P${entry.periodNumber}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  DateTime _getDateForDayOfWeek(String dayOfWeek) {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, ..., 7 = Sunday
    
    final targetWeekday = switch (dayOfWeek.toUpperCase()) {
      'MONDAY' => 1,
      'TUESDAY' => 2,
      'WEDNESDAY' => 3,
      'THURSDAY' => 4,
      'FRIDAY' => 5,
      'SATURDAY' => 6,
      'SUNDAY' => 7,
      _ => 1,
    };
    
    final difference = targetWeekday - currentWeekday;
    return now.add(Duration(days: difference));
  }

  void _showTimetableActionBottomSheet(BuildContext context, TimetableEntryEntity entry, String selectedDay) {
    final date = _getDateForDayOfWeek(selectedDay);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    // Resolve teacher subject assignment ID
    String? tsaId;
    final classesState = ref.read(myClassesStateProvider);
    if (classesState is MyClassesSuccess) {
      for (final cg in classesState.classes) {
        if (cg.classId == entry.classId && cg.sectionId == entry.sectionId) {
          for (final asg in cg.assignments) {
            if (asg.subjectId == entry.subjectId) {
              tsaId = asg.id;
              break;
            }
          }
        }
      }
    } else if (classesState is MyClassesRefreshing) {
      for (final cg in classesState.classes) {
        if (cg.classId == entry.classId && cg.sectionId == entry.sectionId) {
          for (final asg in cg.assignments) {
            if (asg.subjectId == entry.subjectId) {
              tsaId = asg.id;
              break;
            }
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('${entry.subjectName} (${entry.className}-${entry.sectionName})'),
                subtitle: Text('Period ${entry.periodNumber} • ${formatTimeString(entry.startTime)} - ${formatTimeString(entry.endTime)}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.how_to_reg_rounded, color: Colors.blue),
                title: const Text('Mark Attendance'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('${AppRoutes.attendance}?timetableId=${entry.id}&date=$dateStr');
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_rounded, color: Colors.orange),
                title: const Text('Create Homework'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '${AppRoutes.homeworkCreate}?timetableId=${entry.id}'
                    '&tsaId=${tsaId ?? ''}'
                    '&subjectId=${entry.subjectId ?? ''}'
                    '&classId=${entry.classId}'
                    '&sectionId=${entry.sectionId}'
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_check_circle_rounded, color: Colors.teal),
                title: const Text('Update Syllabus Progress'),
                subtitle: const Text('Record actual chapter & topic coverage'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '${AppRoutes.teacherSyllabus}?'
                    'classId=${entry.classId}'
                    '&sectionId=${entry.sectionId}'
                    '&subjectId=${entry.subjectId ?? ""}'
                    '&className=${Uri.encodeComponent(entry.className)}'
                    '&sectionName=${Uri.encodeComponent(entry.sectionName)}'
                    '&subjectName=${Uri.encodeComponent(entry.subjectName)}'
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoClassesForDayCard(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: spacing.md),
            Text(
              'No classes scheduled today',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xs),
            Text(
              'You have no teaching periods assigned for the selected weekday. Take some rest!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTimetableState(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
    EduLocalization? local,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.lg),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: spacing.lg),
                  Text(
                    'No timetable is currently assigned',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    'Please contact your school administrator to configure and assign your class schedule.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.lg),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(dashboardStateProvider.notifier).fetchDashboard();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(local?.translate('retry') ?? 'Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String message,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    String errorTitle = 'Dashboard Loading Failed';
    String errorDesc = message;

    if (message == 'NO_ACTIVE_ACADEMIC_YEAR') {
      errorTitle = 'No active academic year is available';
      errorDesc = 'An active academic year must be configured in the system by a school administrator before timetable scheduling can load.';
    } else if (message == 'NO_TEACHER_PROFILE') {
      errorTitle = 'Teacher profile not found';
      errorDesc = 'Your logged-in email address is not associated with any teacher profile in this school. Please contact support.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.lg),
              side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5), width: 1.5),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  SizedBox(height: spacing.lg),
                  Text(
                    errorTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    errorDesc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.lg),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(dashboardStateProvider.notifier).fetchDashboard();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final shimmerColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.4);

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header skeleton
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(radius.lg),
            ),
          ),
          SizedBox(height: spacing.lg),
          // Actions title
          Container(
            height: 20,
            width: 120,
            color: shimmerColor,
          ),
          SizedBox(height: spacing.sm),
          // Quick actions grid skeleton
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(radius.md),
              ),
            ),
          ),
          SizedBox(height: spacing.lg),
          // Timetable title
          Container(
            height: 20,
            width: 150,
            color: shimmerColor,
          ),
          SizedBox(height: spacing.md),
          // Timetable cards skeletons
          Column(
            children: List.generate(
              3,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(radius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(feature),
          content: Text('The $feature module is coming soon in a future development phase.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out of the Teacher Portal?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authStateProvider.notifier).logout();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleAttendanceTap() {
    final dashboardState = ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard data is loading. Please try again.')),
      );
      return;
    }

    final data = dashboardState is DashboardSuccess
        ? dashboardState.data
        : (dashboardState as DashboardRefreshing).data;

    final selectedDay = dashboardState is DashboardSuccess
        ? dashboardState.selectedDayOfWeek
        : (dashboardState as DashboardRefreshing).selectedDayOfWeek;

    final date = _getDateForDayOfWeek(selectedDay);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final dailySchedule = data.schedule
        .where((entry) => entry.dayOfWeek.toUpperCase() == selectedDay.toUpperCase())
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    if (dailySchedule.isEmpty) {
      // Fallback directly to Daily Class Attendance when no timetable slots exist
      _showDailyClassPicker(context, dateStr, emptyScheduleNotice: 'No scheduled timetable periods for ${selectedDay.toUpperCase()}. Marking daily class attendance.');
      return;
    }

    _showAttendancePeriodSelector(context, dailySchedule, selectedDay);
  }

  void _showAttendancePeriodSelector(
    BuildContext context,
    List<TimetableEntryEntity> dailySchedule,
    String selectedDay,
  ) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final date = _getDateForDayOfWeek(selectedDay);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Text(
                  'Select Period for Attendance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.school_rounded, color: theme.colorScheme.onPrimaryContainer, size: 20),
                ),
                title: const Text('Mark Daily Class Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Homeroom / Full-Day Roster'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _showDailyClassPicker(context, dateStr);
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                child: Text(
                  'TODAY\'S PERIODS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: dailySchedule.length,
                  itemBuilder: (context, index) {
                    final entry = dailySchedule[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        child: Text(
                          'P${entry.periodNumber}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text('${entry.subjectName} (${entry.className}-${entry.sectionName})'),
                      subtitle: Text('${formatTimeString(entry.startTime)} - ${formatTimeString(entry.endTime)}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('${AppRoutes.attendance}?timetableId=${entry.id}&date=$dateStr');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDailyClassPicker(BuildContext context, String dateStr, {String? emptyScheduleNotice}) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final myClassesState = ref.read(myClassesStateProvider);

    if (myClassesState is! MyClassesSuccess) {
      ref.read(myClassesStateProvider.notifier).fetchClasses();
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final classesState = ref.watch(myClassesStateProvider);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Class Attendance',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Select assigned class & section',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                  ),
                  if (emptyScheduleNotice != null)
                    Container(
                      color: Colors.blue.shade50,
                      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.blue.shade800),
                          SizedBox(width: spacing.xs),
                          Expanded(
                            child: Text(
                              emptyScheduleNotice,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  if (classesState is MyClassesLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (classesState is MyClassesError)
                    Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Text(
                        classesState.message,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    )
                  else if (classesState is MyClassesSuccess)
                    if (classesState.classes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('No assigned classes found for this teacher.')),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: classesState.classes.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final group = classesState.classes[idx];
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.class_outlined,
                                  color: theme.colorScheme.onPrimaryContainer,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                '${group.className} — Section ${group.sectionName}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                group.assignments.isNotEmpty
                                    ? group.assignments.map((a) => a.subjectName).join(', ')
                                    : 'Class & Section Assignment',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(bottomSheetContext);
                                context.push(
                                  '${AppRoutes.attendance}?mode=daily'
                                  '&classId=${group.classId}'
                                  '&sectionId=${group.sectionId}'
                                  '&className=${Uri.encodeComponent(group.className)}'
                                  '&sectionName=${Uri.encodeComponent(group.sectionName)}'
                                  '&date=$dateStr',
                                );
                              },
                            );
                          },
                        ),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSchoolSwitcherDialog(BuildContext context, WidgetRef ref, dynamic user) {
    final activeSchoolId = ref.read(activeSchoolIdProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Switch Active School',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...user.schools.map<Widget>((schoolId) {
                final isSelected = schoolId == activeSchoolId;
                final name = user.schoolNames[schoolId] ?? 'School: $schoolId';
                return ListTile(
                  leading: Icon(
                    Icons.account_balance_outlined,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    if (!isSelected) {
                      await ref.read(schoolContextControllerProvider).switchSchool(schoolId);
                      ref.read(dashboardStateProvider.notifier).fetchDashboard();
                      ref.read(myClassesStateProvider.notifier).fetchClasses();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched to $name'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
