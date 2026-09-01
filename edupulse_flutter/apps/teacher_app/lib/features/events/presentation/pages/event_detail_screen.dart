import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:intl/intl.dart';

import '../providers/events_provider.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventDetailProvider(widget.eventId).notifier).fetchDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(eventDetailProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            switch (state) {
              case EventDetailInitial():
              case EventDetailLoading():
                return const Center(child: CircularProgressIndicator());
              case EventDetailError(:final message):
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
                          onPressed: () => ref.read(eventDetailProvider(widget.eventId).notifier).fetchDetail(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              case EventDetailSuccess(:final event):
                final isHoliday = event.isHoliday;
                DateTime? parsedDate;
                try {
                  parsedDate = DateTime.parse(event.eventDate);
                } catch (_) {}
                
                final dateStr = parsedDate != null
                    ? DateFormat('EEEE, dd MMMM yyyy').format(parsedDate)
                    : event.eventDate;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.lg),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: (isHoliday ? Colors.red : theme.colorScheme.primary).withValues(alpha: 0.15),
                                    child: Icon(
                                      isHoliday ? Icons.beach_access_rounded : Icons.event_rounded,
                                      color: isHoliday ? Colors.red : theme.colorScheme.primary,
                                    ),
                                  ),
                                  SizedBox(width: spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.eventName,
                                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        if (isHoliday) ...[
                                          SizedBox(height: spacing.xs),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(radius.sm),
                                            ),
                                            child: const Text(
                                              'Official School Holiday',
                                              style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              Text(
                                'Description',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: spacing.xs),
                              Text(
                                event.description ?? 'No description provided.',
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                              ),
                              const Divider(height: 32),
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                                  SizedBox(width: spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Date',
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                        Text(
                                          dateStr,
                                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacing.md),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, color: theme.colorScheme.primary),
                                  SizedBox(width: spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Time',
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                        Text(
                                          '${event.startTime} - ${event.endTime}',
                                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacing.md),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded, color: theme.colorScheme.primary),
                                  SizedBox(width: spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Venue',
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                        Text(
                                          event.venue ?? 'Test Venue',
                                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
