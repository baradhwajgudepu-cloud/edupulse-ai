import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class AttendanceRegisterView extends ConsumerStatefulWidget {
  const AttendanceRegisterView({super.key});

  @override
  ConsumerState<AttendanceRegisterView> createState() => _AttendanceRegisterViewState();
}

class _AttendanceRegisterViewState extends ConsumerState<AttendanceRegisterView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceRegisterProvider.notifier).fetchRegister();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(child: Text('Please select a school campus.'));
    }

    final registerState = ref.watch(attendanceRegisterProvider);
    final registerNotifier = ref.read(attendanceRegisterProvider.notifier);

    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final availableSections = sectionsState.sections.where((s) {
      if (registerState.classId != null) {
        return s.classId == registerState.classId;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search Controls Card
          Card(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attendance Register Filters',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Export CSV'),
                            onPressed: registerState.records.isEmpty
                                ? null
                                : () => registerNotifier.exportCsv(),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear Filters'),
                            onPressed: () {
                              _searchController.clear();
                              registerNotifier.setSearch('');
                              registerNotifier.setFilters();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search field
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search student, adm no...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      registerNotifier.setSearch('');
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (val) => registerNotifier.setSearch(val.trim()),
                        ),
                      ),

                      // Class Filter
                      SizedBox(
                        width: 170,
                        child: SafeDropdownButtonFormField<String>(
                          isExpanded: true,
                          value: registerState.classId,
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                            ...classesState.classes.map((c) {
                              return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                            }),
                          ],
                          onChanged: (val) {
                            registerNotifier.setFilters(
                              classId: val,
                              sectionId: null,
                              startDate: registerState.startDate,
                              endDate: registerState.endDate,
                              status: registerState.status,
                            );
                          },
                        ),
                      ),

                      // Section Filter
                      SizedBox(
                        width: 160,
                        child: SafeDropdownButtonFormField<String>(
                          isExpanded: true,
                          value: registerState.sectionId,
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All Sections')),
                            ...availableSections.map((s) {
                              return DropdownMenuItem<String>(value: s.id, child: Text(s.name));
                            }),
                          ],
                          onChanged: (val) {
                            registerNotifier.setFilters(
                              classId: registerState.classId,
                              sectionId: val,
                              startDate: registerState.startDate,
                              endDate: registerState.endDate,
                              status: registerState.status,
                            );
                          },
                        ),
                      ),

                      // Status Filter
                      SizedBox(
                        width: 160,
                        child: SafeDropdownButtonFormField<String>(
                          isExpanded: true,
                          value: registerState.status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem<String>(value: null, child: Text('All Statuses')),
                            DropdownMenuItem<String>(value: 'PRESENT', child: Text('Present')),
                            DropdownMenuItem<String>(value: 'ABSENT', child: Text('Absent')),
                            DropdownMenuItem<String>(value: 'LATE', child: Text('Late')),
                            DropdownMenuItem<String>(value: 'HALF_DAY', child: Text('Half Day')),
                            DropdownMenuItem<String>(value: 'EXCUSED', child: Text('Excused')),
                            DropdownMenuItem<String>(value: 'MEDICAL_LEAVE', child: Text('Medical Leave')),
                          ],
                          onChanged: (val) {
                            registerNotifier.setFilters(
                              classId: registerState.classId,
                              sectionId: registerState.sectionId,
                              startDate: registerState.startDate,
                              endDate: registerState.endDate,
                              status: val,
                            );
                          },
                        ),
                      ),

                      // Date Range
                      SizedBox(
                        width: 210,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          icon: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            registerState.startDate != null && registerState.endDate != null
                                ? '${DateFormat('MM/dd').format(registerState.startDate!)} - ${DateFormat('MM/dd').format(registerState.endDate!)}'
                                : 'Select Date Range',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDateRange: registerState.startDate != null && registerState.endDate != null
                                  ? DateTimeRange(start: registerState.startDate!, end: registerState.endDate!)
                                  : null,
                            );
                            if (range != null) {
                              registerNotifier.setFilters(
                                classId: registerState.classId,
                                sectionId: registerState.sectionId,
                                startDate: range.start,
                                endDate: range.end,
                                status: registerState.status,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Error banner
          if (registerState.error != null) ...[
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
                      registerState.error!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Data Table Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 110, child: Text('Adm No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Class & Sec', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 90, child: Text('Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 110, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Reason & Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                ),

                if (registerState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (registerState.records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No attendance records found matching filters.',
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
                    itemCount: registerState.records.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = registerState.records[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(item.attendanceDate, style: const TextStyle(fontSize: 12)),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                item.admissionNumber ?? '-',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.studentName ?? '-',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.className ?? ""} ${item.sectionName ?? ""}'.trim(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                item.sessionType.replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: _buildStatusBadge(item.attendanceStatus),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                [
                                  if (item.attendanceReason != 'UNKNOWN') item.attendanceReason.replaceAll('_', ' '),
                                  if (item.remarks != null && item.remarks!.isNotEmpty) item.remarks!,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                        'Showing ${registerState.records.isEmpty ? 0 : registerState.skip + 1} to '
                        '${registerState.skip + registerState.records.length} of ${registerState.total} records',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: registerState.skip == 0 || registerState.isLoading
                                ? null
                                : () {
                                    final newSkip = (registerState.skip - registerState.limit).clamp(0, registerState.total);
                                    registerNotifier.fetchRegister(skip: newSkip);
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: registerState.skip + registerState.records.length >= registerState.total || registerState.isLoading
                                ? null
                                : () {
                                    final newSkip = registerState.skip + registerState.limit;
                                    registerNotifier.fetchRegister(skip: newSkip);
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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'PRESENT':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green[800]!;
        break;
      case 'ABSENT':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red[800]!;
        break;
      case 'LATE':
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange[800]!;
        break;
      case 'HALF_DAY':
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.amber[900]!;
        break;
      case 'EXCUSED':
      case 'MEDICAL_LEAVE':
        bg = Colors.purple.withValues(alpha: 0.15);
        fg = Colors.purple[800]!;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.2);
        fg = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
