import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../domain/entities/attendance_record.dart';

class AttendanceCalendar extends StatefulWidget {
  final List<AttendanceRecordEntity> records;
  final Function(DateTime selectedDay) onDaySelected;

  const AttendanceCalendar({
    super.key,
    required this.records,
    required this.onDaySelected,
  });

  @override
  State<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends State<AttendanceCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final attendanceMap = {
      for (var r in widget.records) DateUtils.dateOnly(r.date): r,
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: TableCalendar(
          firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
          lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: theme.colorScheme.primary,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.primary,
            ),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            outsideDaysVisible: false,
          ),
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            widget.onDaySelected(selectedDay);
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              final record = attendanceMap[DateUtils.dateOnly(date)];
              if (record == null) return null;

              final color = switch (record.status) {
                AttendanceStatus.present => Colors.green,
                AttendanceStatus.absent => Colors.red,
                AttendanceStatus.leave => Colors.orange,
                AttendanceStatus.late => Colors.amber,
                AttendanceStatus.halfDay => Colors.deepOrange,
                AttendanceStatus.holiday => Colors.grey,
                AttendanceStatus.online => Colors.blue,
              };

              return Positioned(
                bottom: 6,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
