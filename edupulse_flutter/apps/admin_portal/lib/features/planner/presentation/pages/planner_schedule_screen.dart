import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/planner_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class PlannerScheduleScreen extends ConsumerStatefulWidget {
  const PlannerScheduleScreen({super.key});

  @override
  ConsumerState<PlannerScheduleScreen> createState() => _PlannerScheduleScreenState();
}

class _PlannerScheduleScreenState extends ConsumerState<PlannerScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(eventsListProvider.notifier).fetchEvents();
        ref.read(examsListProvider.notifier).fetchExams();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please select a school campus from the header to view the academic schedule.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final eventsState = ref.watch(eventsListProvider);
    final examsState = ref.watch(examsListProvider);
    final theme = Theme.of(context);

    final holidays = eventsState.events.where((e) => e.isHoliday).toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              'Academic Schedule & Timeline',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Oversight of academic years, key operational timelines, school terms, and scheduled holidays.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Active Academic Year Card
            if (ayState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (ayState.years.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No academic years registered for this school.')),
                ),
              )
            else ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Academic Years History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Icon(Icons.history, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ayState.years.length,
                        separatorBuilder: (context, idx) => const Divider(),
                        itemBuilder: (context, idx) {
                          final ay = ayState.years[idx];
                          final isCurrent = ay.isCurrent;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.calendar_month,
                              color: isCurrent ? theme.colorScheme.primary : Colors.grey,
                            ),
                            title: Text(
                              '${ay.name} (${ay.code})',
                              style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                            ),
                            subtitle: Text('Duration: ${ay.startDate} to ${ay.endDate}'),
                            trailing: isCurrent
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'ACTIVE CURRENT',
                                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Timeline details (Holidays & Examinations)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Holidays list
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Academic Holidays', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Divider(height: 24),
                          if (eventsState.isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (holidays.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(child: Text('No academic holidays scheduled.')),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: holidays.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final holiday = holidays[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.beach_access, color: Colors.red),
                                  title: Text(holiday.eventName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Date: ${holiday.eventDate} | Venue: ${holiday.venue ?? 'N/A'}'),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Exam Periods list
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scheduled Exam Periods', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Divider(height: 24),
                          if (examsState.isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (examsState.examinations.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(child: Text('No examinations scheduled.')),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: examsState.examinations.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final exam = examsState.examinations[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.school, color: Colors.blue),
                                  title: Text(exam.examName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Term: ${exam.examType} | Duration: ${exam.startDate} to ${exam.endDate}'),
                                );
                              },
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
    );
  }
}
