import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/planner_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class PlannerCalendarScreen extends ConsumerStatefulWidget {
  const PlannerCalendarScreen({super.key});

  @override
  ConsumerState<PlannerCalendarScreen> createState() => _PlannerCalendarScreenState();
}

class _PlannerCalendarScreenState extends ConsumerState<PlannerCalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedCalendarDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFeedForMonth();
    });
  }

  void _fetchFeedForMonth() {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    ref.read(calendarFeedProvider.notifier).fetchFeed(
          startDate: DateFormat('yyyy-MM-dd').format(start),
          endDate: DateFormat('yyyy-MM-dd').format(end),
        );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please select a school campus from the header to view the calendar.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final state = ref.watch(calendarFeedProvider);
    final theme = Theme.of(context);

    // List of days in the month
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstDayOffset = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1; // Mon=0, Sun=6

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
                      'Calendar Feed',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aggregated timeline of school events, academic holidays, and scheduled examinations.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchFeedForMonth,
                  tooltip: 'Refresh Calendar',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Layout (Grid Calendar + Agenda side-by-side or stacked depending on width)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                
                final calendarWidget = Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Month selector header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                setState(() {
                                  _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                                });
                                _fetchFeedForMonth();
                              },
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                setState(() {
                                  _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                                });
                                _fetchFeedForMonth();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Week days headers
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            Expanded(child: Center(child: Text('Mon', style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text('Tue', style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text('Wed', style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text('Thu', style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text('Fri', style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text('Sat', style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text('Sun', style: TextStyle(fontWeight: FontWeight.bold)))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Grid of Month Days
                        if (state.isLoading)
                          const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          SizedBox(
                            height: 240,
                            child: Center(child: Text('Error: ${state.error}')),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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

                              // Matches in consolidated feed
                              final matches = state.feedItems.where((item) => item['date'] == dateStr).toList();
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
                                  margin: const EdgeInsets.all(4),
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
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                            ),
                                          if (hasExam)
                                            Container(
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                            ),
                                          if (hasEvent)
                                            Container(
                                              width: 5,
                                              height: 5,
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
                          ),
                      ],
                    ),
                  ),
                );

                final agendaWidget = Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agenda: ${DateFormat('dd MMMM yyyy').format(_selectedCalendarDay)}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 24),
                        Builder(
                          builder: (context) {
                            if (state.isLoading) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final dayStr = DateFormat('yyyy-MM-dd').format(_selectedCalendarDay);
                            final dayEvents = state.feedItems.where((item) => item['date'] == dayStr).toList();

                            if (dayEvents.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.0),
                                child: Center(
                                  child: Text('No calendar events found', style: TextStyle(color: Colors.grey)),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: dayEvents.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final item = dayEvents[index];
                                final isHoliday = item['type'] == 'HOLIDAY';
                                final isExam = item['type'] == 'EXAMINATION';

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isHoliday
                                          ? Colors.red.withValues(alpha: 0.15)
                                          : (isExam ? Colors.blue.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15)),
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
                                  trailing: item['start_time'] != null && item['end_time'] != null
                                      ? Text(
                                          '${item['start_time'].toString().substring(0, 5)} - ${item['end_time'].toString().substring(0, 5)}',
                                          style: theme.textTheme.bodySmall,
                                        )
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: calendarWidget),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: agendaWidget),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      calendarWidget,
                      const SizedBox(height: 24),
                      agendaWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
