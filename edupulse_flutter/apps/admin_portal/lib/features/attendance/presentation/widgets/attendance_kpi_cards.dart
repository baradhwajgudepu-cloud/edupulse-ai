import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendance_providers.dart';

class AttendanceKpiCards extends ConsumerWidget {
  const AttendanceKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpi = ref.watch(attendanceKpiProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBgColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[200];

    Widget buildCard(String label, String value, IconData icon, Color color) {
      return Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor ?? Colors.grey),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          buildCard(
            'Total Sessions',
            kpi.totalSessions.toString(),
            Icons.class_outlined,
            theme.colorScheme.primary,
          ),
          buildCard(
            'Present',
            kpi.present.toString(),
            Icons.check_circle_outline,
            Colors.green,
          ),
          buildCard(
            'Absent',
            kpi.absent.toString(),
            Icons.cancel_outlined,
            Colors.red,
          ),
          buildCard(
            'Late',
            kpi.late.toString(),
            Icons.access_time,
            Colors.orange,
          ),
          buildCard(
            'Leave / Excused',
            kpi.leave.toString(),
            Icons.event_busy,
            Colors.purple,
          ),
          buildCard(
            'Rate',
            '${kpi.attendancePercentage.toStringAsFixed(1)}%',
            Icons.percent,
            theme.colorScheme.secondary,
          ),
        ];

        if (constraints.maxWidth > 800) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards,
          );
        } else {
          return SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: cards.map((c) => Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: c,
              )).toList(),
            ),
          );
        }
      },
    );
  }
}
