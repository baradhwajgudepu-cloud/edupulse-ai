import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/models/school_event_model.dart';
import '../../data/models/announcement_model.dart';
import '../providers/planner_provider.dart';

class SchoolPlannerScreen extends ConsumerStatefulWidget {
  const SchoolPlannerScreen({super.key});

  @override
  ConsumerState<SchoolPlannerScreen> createState() => _SchoolPlannerScreenState();
}

class _SchoolPlannerScreenState extends ConsumerState<SchoolPlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedCalendarDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initial fetch of data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(actionItemsProvider.notifier).fetchActionItems();
      _fetchCalendarForSelectedMonth();
      ref.read(eventsListProvider.notifier).fetchEvents();
      ref.read(announcementsListProvider.notifier).fetchAnnouncements();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _fetchCalendarForSelectedMonth() {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    ref.read(calendarFeedProvider.notifier).fetchFeed(
          startDate: DateFormat('yyyy-MM-dd').format(start),
          endDate: DateFormat('yyyy-MM-dd').format(end),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('School Planner'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Action Center'),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendar Feed'),
            Tab(icon: Icon(Icons.event_note_outlined), text: 'Events'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Announcements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActionCenterTab(context, theme, spacing),
          _buildCalendarFeedTab(context, theme, spacing),
          _buildEventsTab(context, theme, spacing),
          _buildAnnouncementsTab(context, theme, spacing),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ACTION CENTER
  // ==========================================
  Widget _buildActionCenterTab(BuildContext context, ThemeData theme, AppSpacing spacing) {
    final state = ref.watch(actionItemsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(actionItemsProvider.notifier).fetchActionItems();
      },
      child: () {
        if (state is ActionItemsLoading || state is ActionItemsInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ActionItemsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${state.message}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.read(actionItemsProvider.notifier).fetchActionItems(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is ActionItemsSuccess) {
          final counts = state.counts;
          final leaves = counts['pending_leaves_count'] ?? 0;
          final exams = counts['draft_examinations_count'] ?? 0;
          final announcements = counts['draft_announcements_count'] ?? 0;
          final events = counts['draft_events_count'] ?? 0;
          final total = counts['total_actions_count'] ?? 0;

          return ListView(
            padding: EdgeInsets.all(spacing.md),
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.notification_important_rounded,
                          size: 40, color: theme.colorScheme.onPrimaryContainer),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Tasks Center',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'You have $total items requiring review or publication.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: spacing.md,
                mainAxisSpacing: spacing.md,
                childAspectRatio: 1.1,
                children: [
                  _buildActionCard(
                    theme: theme,
                    spacing: spacing,
                    title: 'Teacher Leaves',
                    count: leaves,
                    icon: Icons.time_to_leave_rounded,
                    color: Colors.amber,
                    actionText: 'Review Requests',
                    onTap: () => context.go(AppRoutes.teacherLeaves),
                  ),
                  _buildActionCard(
                    theme: theme,
                    spacing: spacing,
                    title: 'Draft Exams',
                    count: exams,
                    icon: Icons.menu_book_rounded,
                    color: Colors.blue,
                    actionText: 'Manage Exams',
                    onTap: () => context.push(AppRoutes.manageExams),
                  ),
                  _buildActionCard(
                    theme: theme,
                    spacing: spacing,
                    title: 'Draft Circulars',
                    count: announcements,
                    icon: Icons.campaign_rounded,
                    color: Colors.indigo,
                    actionText: 'Compose & Publish',
                    onTap: () => _tabController.animateTo(3),
                  ),
                  _buildActionCard(
                    theme: theme,
                    spacing: spacing,
                    title: 'Draft Events',
                    count: events,
                    icon: Icons.event_rounded,
                    color: Colors.pink,
                    actionText: 'Schedule Event',
                    onTap: () => _tabController.animateTo(2),
                  ),
                ],
              ),
            ],
          );
        }
        return const SizedBox();
      }(),
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required AppSpacing spacing,
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (count > 0)
                    Badge(
                      label: Text('$count'),
                      backgroundColor: theme.colorScheme.error,
                      largeSize: 20,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                actionText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: CALENDAR Consolidated FEED
  // ==========================================
  Widget _buildCalendarFeedTab(BuildContext context, ThemeData theme, AppSpacing spacing) {
    final state = ref.watch(calendarFeedProvider);

    return Column(
      children: [
        // Month Selector Header
        Padding(
          padding: EdgeInsets.all(spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                  });
                  _fetchCalendarForSelectedMonth();
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                  });
                  _fetchCalendarForSelectedMonth();
                },
              ),
            ],
          ),
        ),
        
        // Month Days Grid View
        Expanded(
          flex: 4,
          child: () {
            if (state is CalendarFeedLoading || state is CalendarFeedInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CalendarFeedError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            if (state is CalendarFeedSuccess) {
              final feedItems = state.feedItems;
              return _buildCalendarGrid(feedItems, theme, spacing);
            }
            return const SizedBox();
          }(),
        ),

        const Divider(height: 1),

        // Selected Day Agenda Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          alignment: Alignment.centerLeft,
          child: Text(
            'Agenda: ${DateFormat('dd MMMM yyyy').format(_selectedCalendarDay)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // Agenda Items
        Expanded(
          flex: 3,
          child: () {
            if (state is CalendarFeedSuccess) {
              final feedItems = state.feedItems;
              final dayStr = DateFormat('yyyy-MM-dd').format(_selectedCalendarDay);
              final dayEvents = feedItems.where((item) => item['date'] == dayStr).toList();

              if (dayEvents.isEmpty) {
                return const Center(
                  child: Text('No events scheduled for this day.'),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.all(spacing.sm),
                itemCount: dayEvents.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = dayEvents[index];
                  final isHoliday = item['type'] == 'HOLIDAY';
                  final isExam = item['type'] == 'EXAMINATION';

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isHoliday
                            ? Colors.red.withOpacity(0.15)
                            : (isExam ? Colors.blue.withOpacity(0.15) : Colors.green.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item['type'] ?? 'EVENT',
                        style: TextStyle(
                          color: isHoliday ? Colors.red : (isExam ? Colors.blue : Colors.green),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['description'] ?? ''),
                    trailing: Text(
                      '${item['start_time'].toString().substring(0, 5)} - ${item['end_time'].toString().substring(0, 5)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              );
            }
            return const SizedBox();
          }(),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(List<Map<String, dynamic>> feedItems, ThemeData theme, AppSpacing spacing) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstDayOffset = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1; // Mon=0, Sun=6

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: daysInMonth + firstDayOffset,
      itemBuilder: (context, index) {
        if (index < firstDayOffset) {
          return const SizedBox();
        }

        final day = index - firstDayOffset + 1;
        final dateObj = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);

        // Find matches in consolidated feed
        final matches = feedItems.where((item) => item['date'] == dateStr).toList();
        final hasHoliday = matches.any((m) => m['type'] == 'HOLIDAY');
        final hasExam = matches.any((m) => m['type'] == 'EXAMINATION');
        final hasEvent = matches.any((m) => m['type'] == 'EVENT');

        final isSelected = DateUtils.isSameDay(dateObj, _selectedCalendarDay);
        final isToday = DateUtils.isSameDay(dateObj, DateTime.now());

        return InkWell(
          onTap: () {
            setState(() {
              _selectedCalendarDay = dateObj;
            });
          },
          borderRadius: BorderRadius.circular(100),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isToday ? theme.colorScheme.primaryContainer : null),
              border: isToday && !isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : (isToday ? theme.colorScheme.onPrimaryContainer : null),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasHoliday)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    if (hasExam)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      ),
                    if (hasEvent)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: EVENTS LISTING & MANAGEMENT
  // ==========================================
  Widget _buildEventsTab(BuildContext context, ThemeData theme, AppSpacing spacing) {
    final state = ref.watch(eventsListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context, theme, spacing),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(eventsListProvider.notifier).fetchEvents();
        },
        child: () {
          if (state is EventsListLoading || state is EventsListInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is EventsListError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is EventsListSuccess) {
            final events = state.events;
            if (events.isEmpty) {
              return const Center(child: Text('No events scheduled.'));
            }

            return ListView.builder(
              padding: EdgeInsets.all(spacing.sm),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final isDraft = event.status == EventStatus.draft;

                return Card(
                  margin: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: spacing.xs),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.eventName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildStatusBadge(event.status, theme),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(event.description ?? 'No description provided.'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(event.eventDate, style: theme.textTheme.bodySmall),
                            const SizedBox(width: 12),
                            const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${event.startTime.substring(0, 5)} - ${event.endTime.substring(0, 5)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (event.venue != null && event.venue!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(event.venue!, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: () {
                      if (isDraft) {
                        return PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'publish') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Publish'),
                                  content: const Text('Are you sure you want to publish this event? This will notify the target audience immediately.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Publish'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              final success = await ref
                                  .read(eventsListProvider.notifier)
                                  .publishEvent(event.id);
                              if (success) {
                                ref.read(actionItemsProvider.notifier).fetchActionItems();
                                _fetchCalendarForSelectedMonth();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Event published successfully!')),
                                );
                              }
                            } else if (val == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: const Text('Are you sure you want to delete this draft event?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              final success = await ref
                                  .read(eventsListProvider.notifier)
                                  .deleteEvent(event.id);
                              if (success) {
                                ref.read(actionItemsProvider.notifier).fetchActionItems();
                                _fetchCalendarForSelectedMonth();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Event deleted successfully.')),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'publish',
                              child: Row(
                                children: [
                                  Icon(Icons.publish_rounded, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Publish'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_rounded, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else if (event.status == EventStatus.published) {
                        return PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'cancel') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Cancel'),
                                  content: const Text('Are you sure you want to cancel this event?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('No'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Yes, Cancel Event'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              final success = await ref
                                  .read(eventsListProvider.notifier)
                                  .cancelEvent(event);
                              if (success) {
                                ref.read(actionItemsProvider.notifier).fetchActionItems();
                                _fetchCalendarForSelectedMonth();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Event cancelled successfully.')),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_outlined, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Text('Cancel Event'),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return null;
                    }(),
                  ),
                );
              },
            );
          }
          return const SizedBox();
        }(),
      ),
    );
  }

  Widget _buildStatusBadge(dynamic status, ThemeData theme) {
    String label = 'DRAFT';
    Color color = Colors.grey;

    if (status == EventStatus.published || status == AnnouncementStatus.published) {
      label = 'PUBLISHED';
      color = Colors.green;
    } else if (status == EventStatus.cancelled || status == AnnouncementStatus.cancelled) {
      label = 'CANCELLED';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ==========================================
  // TAB 4: ANNOUNCEMENTS LISTING & MANAGEMENT
  // ==========================================
  Widget _buildAnnouncementsTab(BuildContext context, ThemeData theme, AppSpacing spacing) {
    final state = ref.watch(announcementsListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAnnouncementDialog(context, theme, spacing),
        child: const Icon(Icons.campaign_outlined),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(announcementsListProvider.notifier).fetchAnnouncements();
        },
        child: () {
          if (state is AnnouncementsListLoading || state is AnnouncementsListInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AnnouncementsListError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is AnnouncementsListSuccess) {
            final announcements = state.announcements;
            if (announcements.isEmpty) {
              return const Center(child: Text('No announcements posted.'));
            }

            return ListView.builder(
              padding: EdgeInsets.all(spacing.sm),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                final circular = announcements[index];
                final isDraft = circular.status == AnnouncementStatus.draft;

                return Card(
                  margin: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: spacing.xs),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            circular.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildStatusBadge(circular.status, theme),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(circular.message),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Audience: ${circular.audienceType.toJson()}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (circular.targetRole != null) ...[
                              Text(' (${circular.targetRole})', style: theme.textTheme.bodySmall),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                circular.priority,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: isDraft
                        ? PopupMenuButton<String>(
                            onSelected: (val) async {
                              if (val == 'publish') {
                                final success = await ref
                                    .read(announcementsListProvider.notifier)
                                    .publishAnnouncement(circular.id);
                                if (success) {
                                  ref.read(actionItemsProvider.notifier).fetchActionItems();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Circular published successfully!')),
                                  );
                                }
                              } else if (val == 'delete') {
                                final success = await ref
                                    .read(announcementsListProvider.notifier)
                                    .deleteAnnouncement(circular.id);
                                if (success) {
                                  ref.read(actionItemsProvider.notifier).fetchActionItems();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Circular deleted.')),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'publish',
                                child: Row(
                                  children: [
                                    Icon(Icons.publish_rounded, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Publish'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_rounded, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            );
          }
          return const SizedBox();
        }(),
      ),
    );
  }

  // ==========================================
  // COMPOSER: ADD EVENT DIALOG FORM
  // ==========================================
  void _showAddEventDialog(BuildContext context, ThemeData theme, AppSpacing spacing) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final venueController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    EventAudience targetAudience = EventAudience.all;
    bool isHoliday = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: spacing.md,
            left: spacing.md,
            right: spacing.md,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule New Event',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Event Name*', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: venueController,
                    decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  
                  // Date Picker Trigger
                  ListTile(
                    title: const Text('Event Date'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),
                  
                  // Time Slots Trigger
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(startTime.format(context)),
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: startTime);
                            if (picked != null) {
                              setModalState(() => startTime = picked);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time'),
                          subtitle: Text(endTime.format(context)),
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: endTime);
                            if (picked != null) {
                              setModalState(() => endTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  // Target Audience Dropdown
                  DropdownButtonFormField<EventAudience>(
                    value: targetAudience,
                    decoration: const InputDecoration(labelText: 'Target Audience', border: OutlineInputBorder()),
                    items: EventAudience.values
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.name.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => targetAudience = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Is Holiday Checkbox
                  CheckboxListTile(
                    title: const Text('Mark as School Holiday'),
                    value: isHoliday,
                    onChanged: (val) {
                      if (val != null) setModalState(() => isHoliday = val);
                    },
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                            final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                            final success = await ref.read(eventsListProvider.notifier).createEvent(
                                  eventName: nameController.text,
                                  description: descController.text,
                                  eventDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                                  startTime: startStr,
                                  endTime: endStr,
                                  venue: venueController.text,
                                  targetAudience: targetAudience,
                                  isHoliday: isHoliday,
                                );

                            if (success) {
                              ref.read(actionItemsProvider.notifier).fetchActionItems();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Event saved as draft.')),
                              );
                            }
                          }
                        },
                        child: const Text('Save Draft'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Publish'),
                                content: const Text('Are you sure you want to publish this event? This will notify the target audience immediately.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Publish'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                              final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                              final success = await ref.read(eventsListProvider.notifier).createAndPublishEvent(
                                    eventName: nameController.text,
                                    description: descController.text,
                                    eventDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                                    startTime: startStr,
                                    endTime: endStr,
                                    venue: venueController.text,
                                    targetAudience: targetAudience,
                                    isHoliday: isHoliday,
                                  );

                              if (success) {
                                ref.read(actionItemsProvider.notifier).fetchActionItems();
                                _fetchCalendarForSelectedMonth();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Event published successfully!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to publish event. Please try again.')),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('Publish'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // COMPOSER: ADD ANNOUNCEMENT DIALOG FORM
  // ==========================================
  void _showAddAnnouncementDialog(BuildContext context, ThemeData theme, AppSpacing spacing) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    AnnouncementAudienceType audienceType = AnnouncementAudienceType.role;
    String selectedRole = 'TEACHER';
    
    List<Map<String, dynamic>> classesList = [];
    List<Map<String, dynamic>> sectionsList = [];
    String? selectedClassId;
    String? selectedSectionId;
    String priority = 'NORMAL';
    bool isLoadingScopes = true;

    // Load classes & sections scope lists asynchronously
    Future<void> loadScopes(StateSetter setModalState) async {
      final repo = ref.read(plannerRepositoryProvider);
      final session = ref.read(sessionManagerProvider);
      final schoolId = await session.getSchoolId();
      if (schoolId != null) {
        final cRes = await repo.getClasses(schoolId: schoolId);
        final sRes = await repo.getSections(schoolId: schoolId);
        cRes.when(onSuccess: (list) => classesList = list, onFailure: (_) {});
        sRes.when(onSuccess: (list) => sectionsList = list, onFailure: (_) {});
      }
      setModalState(() {
        isLoadingScopes = false;
        if (classesList.isNotEmpty) selectedClassId = classesList.first['id'];
        if (sectionsList.isNotEmpty) selectedSectionId = sectionsList.first['id'];
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isLoadingScopes) {
            loadScopes(setModalState);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: spacing.md,
              left: spacing.md,
              right: spacing.md,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose Announcement/Circular',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title*', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: messageController,
                      decoration: const InputDecoration(labelText: 'Message*', border: OutlineInputBorder()),
                      maxLines: 4,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Priority
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'LOW', child: Text('LOW')),
                        DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                        DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
                        DropdownMenuItem(value: 'URGENT', child: Text('URGENT')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => priority = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Audience Type
                    DropdownButtonFormField<AnnouncementAudienceType>(
                      value: audienceType,
                      decoration: const InputDecoration(labelText: 'Audience Scope', border: OutlineInputBorder()),
                      items: AnnouncementAudienceType.values
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e == AnnouncementAudienceType.className ? 'CLASS' : e.name.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => audienceType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Conditional target controls
                    if (audienceType == AnnouncementAudienceType.role)
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Target Role', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'TEACHER', child: Text('TEACHERS')),
                          DropdownMenuItem(value: 'PARENT', child: Text('PARENTS')),
                          DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                          DropdownMenuItem(value: 'ADMIN', child: Text('ADMINS')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedRole = val);
                        },
                      ),

                    if (audienceType == AnnouncementAudienceType.className && !isLoadingScopes)
                      DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: const InputDecoration(labelText: 'Target Class', border: OutlineInputBorder()),
                        items: classesList
                            .map((c) => DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text(c['name'] ?? 'Class'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedClassId = val);
                        },
                      ),

                    if (audienceType == AnnouncementAudienceType.section && !isLoadingScopes)
                      DropdownButtonFormField<String>(
                        value: selectedSectionId,
                        decoration: const InputDecoration(labelText: 'Target Section', border: OutlineInputBorder()),
                        items: sectionsList
                            .map((s) => DropdownMenuItem(
                                  value: s['id'] as String,
                                  child: Text('${s['class_name'] ?? ''} - ${s['name'] ?? ''}'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedSectionId = val);
                        },
                      ),

                    if (isLoadingScopes && audienceType != AnnouncementAudienceType.role)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              final success = await ref
                                  .read(announcementsListProvider.notifier)
                                  .createAnnouncement(
                                    title: titleController.text,
                                    message: messageController.text,
                                    audienceType: audienceType,
                                    targetRole: audienceType == AnnouncementAudienceType.role ? selectedRole : null,
                                    targetClassId: audienceType == AnnouncementAudienceType.className ? selectedClassId : null,
                                    targetSectionId: audienceType == AnnouncementAudienceType.section ? selectedSectionId : null,
                                    priority: priority,
                                  );

                              if (success) {
                                ref.read(actionItemsProvider.notifier).fetchActionItems();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Announcement saved as draft.')),
                                );
                              }
                            }
                          },
                          child: const Text('Save Draft'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
