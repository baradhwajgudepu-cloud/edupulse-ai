import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/attendance_models.dart';
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

  void _showJobDetailsDialog(BuildContext context, AttendanceImportJobDto job, String schoolName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    DateTime? createdDt;
    try {
      createdDt = DateTime.parse(job.createdAt);
    } catch (_) {}
    final createdStr = createdDt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdDt) : job.createdAt;

    DateTime? completedDt;
    if (job.completedAt != null) {
      try {
        completedDt = DateTime.parse(job.completedAt!);
      } catch (_) {}
    }
    final completedStr = completedDt != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(completedDt)
        : (job.completedAt ?? 'N/A');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Import Batch Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            _buildStatusBadge(job.status),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('File Name', job.filename),
                _buildDetailRow('Batch Job ID', job.id, isCopyable: true),
                _buildDetailRow('School Campus', schoolName),
                if (job.academicYear != null)
                  _buildDetailRow('Academic Year', job.academicYear!),
                _buildDetailRow(
                  'Uploaded By',
                  job.uploadedByName != null
                      ? '${job.uploadedByName} (${job.uploadedByRole ?? "Staff"})'
                      : (job.uploadedBy ?? 'Automated System'),
                ),
                _buildDetailRow('Upload Date', createdStr),
                _buildDetailRow('Completion Date', completedStr),
                if (job.dateRange != null)
                  _buildDetailRow('Date Range Covered', job.dateRange!),
                const Divider(height: 24),
                Text(
                  'Record Metrics',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildMetricTile('Total Rows', '${job.totalRows}', Colors.blueGrey)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricTile('Successful', '${job.successfulRows}', Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricTile('Failed', '${job.failedRows}', job.failedRows > 0 ? Colors.red : Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricTile('Skipped', '${job.skippedRows}', Colors.orange)),
                  ],
                ),
                if (job.errorSummary != null && job.errorSummary!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.shade900.withValues(alpha: 0.2) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                            SizedBox(width: 6),
                            Text('Error Summary', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(job.errorSummary!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (job.failedRows > 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download Error CSV'),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(attendanceImportsHistoryProvider.notifier).downloadErrorsCsv(job.id);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCopyable) ...[
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14, color: Colors.blueGrey),
                    tooltip: 'Copy',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color.shade800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.shade900, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    final upper = status.toUpperCase();

    if (upper == 'COMPLETED' || upper == 'SUCCESS') {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green.shade800;
    } else if (upper == 'FAILED') {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.red.shade800;
    } else if (upper.contains('PARTIAL') || upper.contains('ERROR')) {
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = Colors.orange.shade900;
    } else if (upper == 'RUNNING' || upper == 'PROCESSING' || upper == 'VALIDATING') {
      bg = Colors.blue.withValues(alpha: 0.15);
      fg = Colors.blue.shade800;
    } else {
      bg = Colors.grey.withValues(alpha: 0.2);
      fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        upper.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Please select a school campus to view attendance import history.'),
        ),
      );
    }

    final schoolsList = ref.watch(schoolsListProvider).schools;
    final currentSchool = schoolsList.where((s) => s.id == schoolId).firstOrNull;
    final schoolName = currentSchool?.name ?? 'Current Campus';

    final historyState = ref.watch(attendanceImportsHistoryProvider);
    final historyNotifier = ref.read(attendanceImportsHistoryProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    // Aggregate statistics
    int totalBatches = historyState.jobs.length;
    int totalRecords = historyState.jobs.fold(0, (sum, j) => sum + j.totalRows);
    int totalSuccess = historyState.jobs.fold(0, (sum, j) => sum + j.successfulRows);
    int totalFailed = historyState.jobs.fold(0, (sum, j) => sum + j.failedRows);

    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth < 600 ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Attendance Import History',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          schoolName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Audit records of batch imports, processing reports, and error log CSV downloads.',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                icon: historyState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                onPressed: historyState.isLoading ? null : () => historyNotifier.fetchHistory(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Aggregate Metrics Bar
          if (historyState.jobs.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return isNarrow
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSummaryCard(theme, 'Total Batches', '$totalBatches', Colors.blueGrey, constraints.maxWidth / 2 - 8),
                          _buildSummaryCard(theme, 'Total Rows', '$totalRecords', Colors.indigo, constraints.maxWidth / 2 - 8),
                          _buildSummaryCard(theme, 'Success', '$totalSuccess', Colors.green, constraints.maxWidth / 2 - 8),
                          _buildSummaryCard(theme, 'Errors/Failed', '$totalFailed', totalFailed > 0 ? Colors.red : Colors.grey, constraints.maxWidth / 2 - 8),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildSummaryCard(theme, 'Batches Imported', '$totalBatches', Colors.blueGrey, null)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSummaryCard(theme, 'Total Records Processed', '$totalRecords', Colors.indigo, null)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSummaryCard(theme, 'Successfully Marked', '$totalSuccess', Colors.green, null)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSummaryCard(theme, 'Failed / Errors', '$totalFailed', totalFailed > 0 ? Colors.red : Colors.grey, null)),
                        ],
                      );
              },
            ),
            const SizedBox(height: 20),
          ],

          // Error Banner
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
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => historyNotifier.fetchHistory(),
                    child: const Text('Retry', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Content Area (Table vs Mobile Card List)
          if (historyState.isLoading && historyState.jobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (historyState.jobs.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_toggle_off, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No Attendance Import History Found',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No bulk attendance files have been imported for $schoolName yet.\nUploaded attendance spreadsheets will appear here with full execution summaries.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check for Updates'),
                        onPressed: () => historyNotifier.fetchHistory(),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (isMobile)
            // Mobile / Tablet Card List View
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyState.jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = historyState.jobs[index];
                return _buildMobileJobCard(context, job, schoolName, isDark, historyNotifier);
              },
            )
          else
            // Desktop Adaptive Table View
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: screenWidth - 48),
                    child: DataTable(
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 64,
                      headingRowColor: WidgetStateProperty.all(isDark ? Colors.grey[850] : Colors.grey[100]),
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('File Name & Job ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Campus / AY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Uploaded By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Upload Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Records (Tot/Succ/Fail)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                      rows: historyState.jobs.map((job) {
                        DateTime? dt;
                        try {
                          dt = DateTime.parse(job.createdAt);
                        } catch (_) {}
                        final dateFormatted = dt != null ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : job.createdAt;

                        return DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => _showJobDetailsDialog(context, job, schoolName),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.description_outlined, size: 16, color: Colors.blueGrey),
                                          const SizedBox(width: 6),
                                          Text(
                                            job.filename,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: ${job.id.length > 12 ? "${job.id.substring(0, 8)}..." : job.id}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(schoolName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  if (job.academicYear != null)
                                    Text(job.academicYear!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(job.uploadedByName ?? 'System User', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  if (job.uploadedByRole != null)
                                    Text(job.uploadedByRole!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            DataCell(Text(dateFormatted, style: const TextStyle(fontSize: 12))),
                            DataCell(_buildStatusBadge(job.status)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text('${job.totalRows}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                    child: Text('${job.successfulRows}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: job.failedRows > 0 ? Colors.red.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${job.failedRows}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: job.failedRows > 0 ? Colors.red.shade800 : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (job.failedRows > 0)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                        side: BorderSide(color: Colors.red.shade300),
                                      ),
                                      icon: const Icon(Icons.file_download_outlined, size: 14, color: Colors.red),
                                      label: const Text('Error CSV', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                      onPressed: () => historyNotifier.downloadErrorsCsv(job.id),
                                    )
                                  else
                                    const Text('-', style: TextStyle(color: Colors.grey)),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, size: 18),
                                    tooltip: 'View Details',
                                    onPressed: () => _showJobDetailsDialog(context, job, schoolName),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String title, String val, MaterialColor color, double? width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade800)),
        ],
      ),
    );
  }

  Widget _buildMobileJobCard(
    BuildContext context,
    AttendanceImportJobDto job,
    String schoolName,
    bool isDark,
    AttendanceImportsHistoryNotifier historyNotifier,
  ) {
    DateTime? dt;
    try {
      dt = DateTime.parse(job.createdAt);
    } catch (_) {}
    final dateFormatted = dt != null ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : job.createdAt;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: File Name and Status Badge
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job.filename,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(job.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Job ID: ${job.id}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            // Metadata Wrap
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(dateFormatted, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                if (job.uploadedByName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${job.uploadedByName} (${job.uploadedByRole ?? "Staff"})', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                if (job.dateRange != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Range: ${job.dateRange}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const Divider(height: 20),

            // Records Counts Row
            Row(
              children: [
                _buildCardPill('Total', '${job.totalRows}', Colors.blueGrey),
                const SizedBox(width: 8),
                _buildCardPill('Success', '${job.successfulRows}', Colors.green),
                const SizedBox(width: 8),
                _buildCardPill('Failed', '${job.failedRows}', job.failedRows > 0 ? Colors.red : Colors.grey),
                const SizedBox(width: 8),
                _buildCardPill('Skipped', '${job.skippedRows}', Colors.orange),
              ],
            ),
            const SizedBox(height: 12),

            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (job.failedRows > 0)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 14, color: Colors.red),
                    label: const Text('Download Error CSV', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                    onPressed: () => historyNotifier.downloadErrorsCsv(job.id),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: const Text('Details', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showJobDetailsDialog(context, job, schoolName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPill(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: color.shade900)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade900)),
        ],
      ),
    );
  }
}
