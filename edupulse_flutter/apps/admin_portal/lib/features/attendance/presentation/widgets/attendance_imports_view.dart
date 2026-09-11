import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AttendanceImportsView extends ConsumerStatefulWidget {
  const AttendanceImportsView({super.key});

  @override
  ConsumerState<AttendanceImportsView> createState() => _AttendanceImportsViewState();
}

class _AttendanceImportsViewState extends ConsumerState<AttendanceImportsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceImportsHistoryProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(child: Text('Please select a school campus.'));
    }

    final historyState = ref.watch(attendanceImportsHistoryProvider);
    final historyNotifier = ref.read(attendanceImportsHistoryProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Import History',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track background batch imports, check statuses, and inspect or download error logs.',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh History',
                onPressed: () => historyNotifier.fetchHistory(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error banner
          if (historyState.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      historyState.error!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Table
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('File Name / Job ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 140, child: Text('Upload Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 110, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 80, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 80, child: Text('Success', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 80, child: Text('Failed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 130, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                ),

                if (historyState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (historyState.jobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No past attendance imports found for this school.',
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: historyState.jobs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final job = historyState.jobs[index];
                      DateTime? dt;
                      try {
                        dt = DateTime.parse(job.createdAt);
                      } catch (_) {}
                      final dateFormatted = dt != null ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : job.createdAt;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.filename,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    'ID: ${job.id}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: Text(dateFormatted, style: const TextStyle(fontSize: 12)),
                            ),
                            SizedBox(
                              width: 110,
                              child: _buildJobStatusBadge(job.status),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text('${job.totalRows}', style: const TextStyle(fontSize: 12)),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${job.successfulRows}',
                                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${job.failedRows}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: job.failedRows > 0 ? Colors.red : Colors.grey,
                                  fontWeight: job.failedRows > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: job.failedRows > 0
                                  ? OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.file_download_outlined, size: 14, color: Colors.red),
                                      label: const Text('Error CSV', style: TextStyle(fontSize: 11, color: Colors.red)),
                                      onPressed: () => historyNotifier.downloadErrorsCsv(job.id),
                                    )
                                  : const Text('-', style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green[800]!;
        break;
      case 'FAILED':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red[800]!;
        break;
      case 'PARTIAL':
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange[800]!;
        break;
      case 'PROCESSING':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue[800]!;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.2);
        fg = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
