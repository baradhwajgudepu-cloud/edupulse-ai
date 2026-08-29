import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/planner_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class PlannerEventsScreen extends ConsumerStatefulWidget {
  const PlannerEventsScreen({super.key});

  @override
  ConsumerState<PlannerEventsScreen> createState() => _PlannerEventsScreenState();
}

class _PlannerEventsScreenState extends ConsumerState<PlannerEventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventsListProvider.notifier).fetchEvents();
    });
  }

  void _showCreateEventDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final venueController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);
    String selectedAudience = 'ALL';
    bool isHoliday = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Schedule New Event'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Event Name *'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: venueController,
                        decoration: const InputDecoration(labelText: 'Venue'),
                      ),
                      const SizedBox(height: 16),
                      
                      // Date Selector
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Event Date *'),
                          child: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Start & End Time Selectors
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => startTime = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Start Time *'),
                                child: Text(startTime.format(context)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => endTime = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'End Time *'),
                                child: Text(endTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Target Audience Selector
                      DropdownButtonFormField<String>(
                        value: selectedAudience,
                        decoration: const InputDecoration(labelText: 'Target Audience *'),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All')),
                          DropdownMenuItem(value: 'STUDENTS', child: Text('Students')),
                          DropdownMenuItem(value: 'PARENTS', child: Text('Parents')),
                          DropdownMenuItem(value: 'TEACHERS', child: Text('Teachers')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedAudience = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Holiday checkbox
                      CheckboxListTile(
                        title: const Text('Mark as School Holiday'),
                        value: isHoliday,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => isHoliday = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final double startDouble = startTime.hour + startTime.minute / 60.0;
                      final double endDouble = endTime.hour + endTime.minute / 60.0;
                      if (endDouble <= startDouble) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('End time must be later than start time')),
                        );
                        return;
                      }

                      final success = await ref.read(eventsListProvider.notifier).createEvent(
                            eventName: nameController.text,
                            description: descController.text.isEmpty ? null : descController.text,
                            eventDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                            startTime: '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00',
                            endTime: '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00',
                            venue: venueController.text.isEmpty ? null : venueController.text,
                            targetAudience: selectedAudience,
                            isHoliday: isHoliday,
                          );
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event saved as Draft successfully.')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to save event.')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Draft'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please select a school campus from the header to manage events.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final state = ref.watch(eventsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Events Scheduler',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure, schedule, publish, and delete events or holidays for target campuses.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateEventDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule Event'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Area
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.error != null)
              Center(
                child: Text('Error: ${state.error}', style: TextStyle(color: theme.colorScheme.error)),
              )
            else if (state.events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: Text('No events found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.events.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final event = state.events[index];
                  final isPublished = event.status.name == 'published';

                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left color indicator
                          Container(
                            width: 6,
                            height: 60,
                            decoration: BoxDecoration(
                              color: event.isHoliday ? Colors.red : Colors.green,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Event Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      event.eventName,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 12),
                                    if (event.isHoliday)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'HOLIDAY',
                                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPublished ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        event.status.name.toUpperCase(),
                                        style: TextStyle(
                                          color: isPublished ? Colors.green : Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (event.description != null && event.description!.isNotEmpty) ...[
                                  Text(event.description!, style: theme.textTheme.bodyMedium),
                                  const SizedBox(height: 8),
                                ],
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(event.eventDate, style: theme.textTheme.bodySmall),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('${event.startTime.substring(0, 5)} - ${event.endTime.substring(0, 5)}', style: theme.textTheme.bodySmall),
                                    if (event.venue != null && event.venue!.isNotEmpty) ...[
                                      const SizedBox(width: 16),
                                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(event.venue!, style: theme.textTheme.bodySmall),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Audience: ${event.targetAudience.name.toUpperCase()}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons
                          Row(
                            children: [
                              if (!isPublished) ...[
                                ElevatedButton(
                                  onPressed: () async {
                                    final res = await ref.read(eventsListProvider.notifier).publishEvent(event.id);
                                    if (res) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Event published successfully.')),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to publish event.')),
                                      );
                                    }
                                  },
                                  child: const Text('Publish'),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Event'),
                                      content: const Text('Are you sure you want to delete this event?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final res = await ref.read(eventsListProvider.notifier).deleteEvent(event.id);
                                    if (res) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Event deleted successfully.')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
