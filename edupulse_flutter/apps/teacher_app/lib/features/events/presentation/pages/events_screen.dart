import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../providers/events_provider.dart';
import '../../data/models/school_event_model.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventsProvider.notifier).fetchEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Events'),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            switch (state) {
              case EventsInitial():
              case EventsLoading():
                return const Center(child: CircularProgressIndicator());
              case EventsError(:final message):
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        SizedBox(height: spacing.md),
                        ElevatedButton(
                          onPressed: () => ref.read(eventsProvider.notifier).fetchEvents(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              case EventsSuccess(:final events):
                if (events.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(eventsProvider.notifier).fetchEvents(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(spacing.lg),
                        child: Text(
                          'No events scheduled.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(eventsProvider.notifier).fetchEvents(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(spacing.md),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isHoliday = event.isHoliday;
                      
                      DateTime? parsedDate;
                      try {
                        parsedDate = DateTime.parse(event.eventDate);
                      } catch (_) {}
                      
                      final dateStr = parsedDate != null
                          ? DateFormat('dd MMM yyyy').format(parsedDate)
                          : event.eventDate;

                      return Card(
                        margin: EdgeInsets.only(bottom: spacing.sm),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.md),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(spacing.md),
                          leading: CircleAvatar(
                            backgroundColor: (isHoliday ? Colors.red : theme.colorScheme.primary).withValues(alpha: 0.15),
                            child: Icon(
                              isHoliday ? Icons.beach_access_rounded : Icons.event_rounded,
                              color: isHoliday ? Colors.red : theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            event.eventName,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: spacing.xs),
                              if (event.description != null && event.description!.isNotEmpty) ...[
                                Text(
                                  event.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                SizedBox(height: spacing.xs),
                              ],
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                  SizedBox(width: spacing.xs),
                                  Text(
                                    dateStr,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  SizedBox(width: spacing.md),
                                  Icon(Icons.location_on_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                  SizedBox(width: spacing.xs),
                                  Expanded(
                                    child: Text(
                                      event.venue ?? 'Test Venue',
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            context.push('/events/${event.id}');
                          },
                        ),
                      );
                    },
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
