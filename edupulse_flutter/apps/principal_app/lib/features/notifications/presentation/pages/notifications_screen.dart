import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsStateProvider.notifier).fetchNotifications();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(notificationsStateProvider.notifier).fetchNotifications(isRefresh: true);
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'ATTENDANCE':
        return Icons.co_present_rounded;
      case 'EXAMINATION':
      case 'MARKS':
        return Icons.grade_rounded;
      case 'REPORT_CARD':
        return Icons.assignment_rounded;
      case 'FEE':
        return Icons.payment_rounded;
      case 'HOMEWORK':
        return Icons.menu_book_rounded;
      case 'ANNOUNCEMENT':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getCategoryColor(String category, ThemeData theme) {
    switch (category.toUpperCase()) {
      case 'ATTENDANCE':
        return Colors.blue;
      case 'EXAMINATION':
      case 'MARKS':
        return Colors.purple;
      case 'REPORT_CARD':
        return Colors.green;
      case 'FEE':
        return Colors.orange;
      case 'HOMEWORK':
        return Colors.indigo;
      case 'ANNOUNCEMENT':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }

  void _handleDeepLink(NotificationDto notification) {
    switch (notification.type.toUpperCase()) {
      case 'ATTENDANCE':
        context.push('/analytics'); // Principal monitors attendance metrics here
        break;
      case 'REPORT_CARD':
        context.push('/report-cards');
        break;
      case 'FEE':
        context.push('/fees');
        break;
      default:
        context.push('/dashboard');
        break;
    }
  }

  void _showPreferencesSheet(BuildContext context, NotificationPreferencesDto prefs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool enableHomework = prefs.enableHomework;
            bool enableAttendance = prefs.enableAttendance;
            bool enableMarks = prefs.enableMarks;
            bool enableReportCard = prefs.enableReportCard;
            bool enableAnnouncements = prefs.enableAnnouncements;
            bool enableEvents = prefs.enableEvents;
            bool enableFee = prefs.enableFee;
            bool enablePush = prefs.enablePush;
            bool enableEmail = prefs.enableEmail;
            bool enableSms = prefs.enableSms;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notification Preferences',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Categories', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
                    SwitchListTile(
                      title: const Text('Attendance'),
                      subtitle: const Text('Absence alerts and low attendance concerns'),
                      value: enableAttendance,
                      onChanged: (val) {
                        setModalState(() => enableAttendance = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Exams & Marks'),
                      subtitle: const Text('Exams scheduled and test grades published'),
                      value: enableMarks,
                      onChanged: (val) {
                        setModalState(() => enableMarks = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Report Cards'),
                      subtitle: const Text('Academic term summaries and promotions'),
                      value: enableReportCard,
                      onChanged: (val) {
                        setModalState(() => enableReportCard = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Fee Reminders'),
                      subtitle: const Text('Fee structures and receipts available'),
                      value: enableFee,
                      onChanged: (val) {
                        setModalState(() => enableFee = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Homework & Classes'),
                      subtitle: const Text('New assignments and timetable updates'),
                      value: enableHomework,
                      onChanged: (val) {
                        setModalState(() => enableHomework = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('School Announcements'),
                      subtitle: const Text('School circulars and event alerts'),
                      value: enableAnnouncements,
                      onChanged: (val) {
                        setModalState(() => enableAnnouncements = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Non-Mandatory Channels', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
                    SwitchListTile(
                      title: const Text('Mobile Push Notifications'),
                      value: enablePush,
                      onChanged: (val) {
                        setModalState(() => enablePush = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Email Alerts'),
                      value: enableEmail,
                      onChanged: (val) {
                        setModalState(() => enableEmail = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('SMS / Text Notifications'),
                      value: enableSms,
                      onChanged: (val) {
                        setModalState(() => enableSms = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ref.read(notificationsStateProvider.notifier).updatePreferences(
                          NotificationPreferencesDto(
                            enableHomework: enableHomework,
                            enableAttendance: enableAttendance,
                            enableMarks: enableMarks,
                            enableReportCard: enableReportCard,
                            enableAnnouncements: enableAnnouncements,
                            enableEvents: enableEvents,
                            enableFee: enableFee,
                            enablePush: enablePush,
                            enableEmail: enableEmail,
                            enableSms: enableSms,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(notificationsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [
          if (state is NotificationsSuccess) ...[
            if (state.list.any((n) => !n.isRead))
              IconButton(
                icon: const Icon(Icons.mark_chat_read_rounded),
                tooltip: 'Mark all as read',
                onPressed: () {
                  ref.read(notificationsStateProvider.notifier).markAllAsRead();
                },
              ),
            if (state.preferences != null)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Preferences',
                onPressed: () => _showPreferencesSheet(context, state.preferences!),
              ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: switch (state) {
          NotificationsInitial() => const Center(child: CircularProgressIndicator()),
          NotificationsLoading() => const Center(child: CircularProgressIndicator()),
          NotificationsError(:final message) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: EdgeInsets.all(spacing.lg),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    SizedBox(height: spacing.sm),
                    Text(
                      'Failed to load notifications',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.md),
                    ElevatedButton.icon(
                      onPressed: _onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          NotificationsSuccess(:final list) => list.isEmpty
              ? ListView(
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey),
                          SizedBox(height: spacing.sm),
                          Text(
                            'All caught up!',
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            'No new notifications for your account.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  ],
                )
              : ListView.separated(
                  padding: EdgeInsets.all(spacing.md),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
                  itemBuilder: (context, index) {
                    final notification = list[index];
                    final isUnread = !notification.isRead;
                    final isHighPriority = notification.priority == 'HIGH' || notification.priority == 'URGENT';
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(notification.createdAt.toLocal());

                    return Card(
                      elevation: isUnread ? 2 : 0,
                      color: isUnread
                          ? (isHighPriority
                              ? Colors.red.shade50.withValues(alpha: 0.4)
                              : theme.colorScheme.surface)
                          : theme.colorScheme.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius.md),
                        side: BorderSide(
                          color: isUnread
                              ? (isHighPriority ? Colors.red.shade200 : theme.colorScheme.primary.withValues(alpha: 0.3))
                              : theme.colorScheme.outlineVariant,
                          width: isUnread ? 1.5 : 1.0,
                        ),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(notification.type, theme).withValues(alpha: 0.15),
                          child: Icon(
                            _getCategoryIcon(notification.type),
                            color: _getCategoryColor(notification.type, theme),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                  color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: EdgeInsets.only(left: spacing.xs),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: spacing.xs),
                          child: Text(
                            dateStr,
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                          ),
                        ),
                        onExpansionChanged: (expanded) {
                          if (expanded && isUnread) {
                            ref.read(notificationsStateProvider.notifier).markAsRead(notification.id);
                          }
                        },
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Divider(),
                                SizedBox(height: spacing.xs),
                                Text(
                                  notification.message,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                SizedBox(height: spacing.sm),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _handleDeepLink(notification),
                                      icon: const Icon(Icons.open_in_new, size: 16),
                                      label: const Text('View Action', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                    Chip(
                                      backgroundColor: isHighPriority ? Colors.red.shade100 : null,
                                      label: Text(
                                        notification.priority,
                                        style: TextStyle(
                                          color: isHighPriority ? Colors.red.shade900 : null,
                                          fontSize: 10,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
        },
      ),
    );
  }
}
