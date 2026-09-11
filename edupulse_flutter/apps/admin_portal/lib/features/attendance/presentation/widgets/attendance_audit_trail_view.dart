import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class AttendanceAuditTrailView extends ConsumerStatefulWidget {
  const AttendanceAuditTrailView({super.key});

  @override
  ConsumerState<AttendanceAuditTrailView> createState() => _AttendanceAuditTrailViewState();
}

class _AttendanceAuditTrailViewState extends ConsumerState<AttendanceAuditTrailView> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceAuditLogsProvider.notifier).fetchAuditLogs();
    });
  }

  void _fetchWithFilters({int skip = 0}) {
    ref.read(attendanceAuditLogsProvider.notifier).fetchAuditLogs(
          startDate: _startDate,
          endDate: _endDate,
          action: _selectedAction,
          skip: skip,
        );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(child: Text('Please select a school campus.'));
    }

    final auditState = ref.watch(attendanceAuditLogsProvider);
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
                      'Attendance Audit Trail',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Immutable audit log tracking every attendance record create, update, correction, import, and migration.',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Logs',
                onPressed: () => _fetchWithFilters(skip: auditState.skip),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Action Filter
                  SizedBox(
                    width: 170,
                    child: SafeDropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedAction,
                      decoration: const InputDecoration(
                        labelText: 'Audit Action',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Actions')),
                        DropdownMenuItem(value: 'CREATE', child: Text('Create')),
                        DropdownMenuItem(value: 'UPDATE', child: Text('Update / Correct')),
                        DropdownMenuItem(value: 'DELETE', child: Text('Delete')),
                        DropdownMenuItem(value: 'IMPORT', child: Text('Import')),
                        DropdownMenuItem(value: 'MIGRATION', child: Text('Migration')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedAction = val;
                        });
                        _fetchWithFilters(skip: 0);
                      },
                    ),
                  ),

                  // Date Range
                  SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'
                            : 'Select Date Range',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _startDate != null && _endDate != null
                              ? DateTimeRange(start: _startDate!, end: _endDate!)
                              : null,
                        );
                        if (range != null) {
                          setState(() {
                            _startDate = range.start;
                            _endDate = range.end;
                          });
                          _fetchWithFilters(skip: 0);
                        }
                      },
                    ),
                  ),

                  // Clear Filters
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Reset Filters'),
                    onPressed: () {
                      setState(() {
                        _selectedAction = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _fetchWithFilters(skip: 0);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Informative banner when detailed audit trail is not active in production version
          if (auditState.isUnsupportedVersion) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2415) : const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auditState.unsupportedMessage ?? 'Detailed audit history is not available in this production API version.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Granular status transition deltas and actor mutation logs require backend audit-log service activation. Attendance records can be verified in the Attendance Register tab.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFD6D3D1) : const Color(0xFF78716C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Error banner
          if (auditState.error != null) ...[
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
                      auditState.error!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Table Card
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
                      SizedBox(width: 140, child: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 100, child: Text('Att. Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 90, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Status Transition', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Actor & Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 90, child: Text('Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Reason / Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                ),

                if (auditState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (auditState.isUnsupportedVersion)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history_toggle_off, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'Detailed Audit Trail Not Active',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Detailed audit history is not available in this production API version.\nStudent attendance records can be verified in the Attendance Register.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (auditState.logs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.policy_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No audit logs match current filters.',
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
                    itemCount: auditState.logs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = auditState.logs[index];
                      DateTime? dt;
                      try {
                        dt = DateTime.parse(log.timestamp);
                      } catch (_) {}
                      final dateFormatted = dt != null ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : log.timestamp;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(dateFormatted, style: const TextStyle(fontSize: 11)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.studentName ?? 'Student',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  Text(
                                    '${log.admissionNumber ?? ""} • ${log.className ?? ""} ${log.sectionName ?? ""}'.trim(),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(log.attendanceDate, style: const TextStyle(fontSize: 12)),
                            ),
                            SizedBox(
                              width: 90,
                              child: _buildActionBadge(log.action),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  if (log.oldStatus != null) ...[
                                    _statusPill(log.oldStatus!),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                    ),
                                  ],
                                  _statusPill(log.newStatus),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.changedByName ?? log.changedBy ?? 'System',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  if (log.changedByRole != null)
                                    Text(
                                      log.changedByRole!,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                log.source.replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                log.reason ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Pagination Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${auditState.logs.isEmpty ? 0 : auditState.skip + 1} to '
                        '${auditState.skip + auditState.logs.length} of ${auditState.total} logs',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: auditState.skip == 0 || auditState.isLoading
                                ? null
                                : () {
                                    final newSkip = (auditState.skip - auditState.limit).clamp(0, auditState.total);
                                    _fetchWithFilters(skip: newSkip);
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: auditState.skip + auditState.logs.length >= auditState.total || auditState.isLoading
                                ? null
                                : () {
                                    final newSkip = auditState.skip + auditState.limit;
                                    _fetchWithFilters(skip: newSkip);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bg;
    Color fg;

    switch (action.toUpperCase()) {
      case 'CREATE':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green[800]!;
        break;
      case 'UPDATE':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue[800]!;
        break;
      case 'DELETE':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red[800]!;
        break;
      case 'IMPORT':
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange[800]!;
        break;
      case 'MIGRATION':
        bg = Colors.purple.withValues(alpha: 0.15);
        fg = Colors.purple[800]!;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.2);
        fg = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        action.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PRESENT':
        color = Colors.green;
        break;
      case 'ABSENT':
        color = Colors.red;
        break;
      case 'LATE':
        color = Colors.orange;
        break;
      default:
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
