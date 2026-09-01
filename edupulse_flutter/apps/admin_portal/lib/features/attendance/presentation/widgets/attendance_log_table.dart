import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/attendance_models.dart';
import 'attendance_correction_dialog.dart';

class AttendanceLogTable extends ConsumerWidget {
  final String sessionId;
  final String sessionStatus;
  final List<AttendanceLogDto> logs;

  const AttendanceLogTable({
    super.key,
    required this.sessionId,
    required this.sessionStatus,
    required this.logs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort students numerically by roll number
    final sortedLogs = List<AttendanceLogDto>.from(logs);
    sortedLogs.sort((a, b) {
      final aRollStr = a.studentRollNumber ?? '';
      final bRollStr = b.studentRollNumber ?? '';
      
      final aVal = int.tryParse(aRollStr);
      final bVal = int.tryParse(bRollStr);
      
      if (aVal != null && bVal != null) {
        return aVal.compareTo(bVal);
      }
      return aRollStr.compareTo(bRollStr);
    });

    void showAuditHistory(AttendanceLogDto log) {
      final audits = log.auditLogs;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Audit Trail - ${log.studentName ?? "Student"}'),
            content: audits.isEmpty
                ? const Text('No corrections have been recorded for this student record.')
                : SizedBox(
                    width: 500,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: audits.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final audit = audits[index];
                        String formattedTime = audit.updatedAt;
                        try {
                          final parsed = DateTime.parse(audit.updatedAt);
                          formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed);
                        } catch (_) {}

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${audit.previousStatus} ➔ ${audit.newStatus}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Corrected By: ${audit.updatedBy}', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('Reason: ${audit.reasonForChange}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    void handleCorrect(AttendanceLogDto log) async {
      final success = await showDialog<bool>(
        context: context,
        builder: (context) => AttendanceCorrectionDialog(
          sessionId: sessionId,
          studentId: log.studentId,
          studentName: log.studentName ?? 'N/A',
          currentStatus: log.attendanceStatus,
        ),
      );

      if (success == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance record corrected successfully.')),
        );
      }
    }

    Color getStatusColor(String status) {
      switch (status.toUpperCase()) {
        case 'PRESENT':
        case 'ONLINE':
          return Colors.green;
        case 'ABSENT':
          return Colors.red;
        case 'LATE':
          return Colors.orange;
        case 'MEDICAL_LEAVE':
        case 'EXCUSED':
        case 'HALF_DAY':
          return Colors.purple;
        default:
          return Colors.grey;
      }
    }

    Widget buildLogCard(AttendanceLogDto log) {
      final statusColor = getStatusColor(log.attendanceStatus);
      final totalEdits = log.auditLogs.length;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.studentName ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.attendanceStatus,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Roll No: ${log.studentRollNumber ?? "N/A"} • Adm No: ${log.studentRollNumber ?? "N/A"}'),
              Text('Source: ${log.attendanceSource} • Reason: ${log.attendanceReason}'),
              if (log.remarks != null && log.remarks!.isNotEmpty)
                Text('Remarks: ${log.remarks}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    key: Key('audit_trail_${log.studentId}'),
                    icon: Icon(Icons.history_outlined, size: 16, color: totalEdits > 0 ? theme.colorScheme.primary : Colors.grey),
                    label: Text(
                      totalEdits > 0 ? 'Audit Trail ($totalEdits)' : 'No Edits',
                      style: TextStyle(color: totalEdits > 0 ? theme.colorScheme.primary : Colors.grey),
                    ),
                    onPressed: () => showAuditHistory(log),
                  ),
                  if (sessionStatus != 'LOCKED')
                    TextButton.icon(
                      key: Key('correct_${log.studentId}'),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Correct'),
                      onPressed: () => handleCorrect(log),
                    ),
                ],
              )
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedLogs.length,
            itemBuilder: (context, index) => buildLogCard(sortedLogs[index]),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(isDark ? Colors.grey[850] : Colors.grey[50]),
                columns: const [
                  DataColumn(label: Text('Roll No')),
                  DataColumn(label: Text('Adm No')),
                  DataColumn(label: Text('Student Name')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Remarks')),
                  DataColumn(label: Text('Audits')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: sortedLogs.map((log) {
                  final statusColor = getStatusColor(log.attendanceStatus);
                  final totalEdits = log.auditLogs.length;

                  return DataRow(
                    cells: [
                      DataCell(Text(log.studentRollNumber ?? 'N/A')),
                      DataCell(Text(log.studentId.substring(0, 8))), // Show short UUID as placeholder
                      DataCell(Text(log.studentName ?? 'N/A')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.attendanceStatus,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(Text(log.attendanceSource)),
                      DataCell(Text(log.attendanceReason)),
                      DataCell(Text(log.remarks ?? '-')),
                      DataCell(
                        TextButton.icon(
                          key: Key('audit_trail_${log.studentId}'),
                          icon: Icon(Icons.history_outlined, size: 16, color: totalEdits > 0 ? theme.colorScheme.primary : Colors.grey),
                          label: Text(totalEdits.toString()),
                          onPressed: () => showAuditHistory(log),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            if (sessionStatus != 'LOCKED')
                              IconButton(
                                key: Key('correct_${log.studentId}'),
                                icon: const Icon(Icons.edit_note),
                                tooltip: 'Correct Record',
                                onPressed: () => handleCorrect(log),
                              )
                            else
                              const Text('Locked', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
