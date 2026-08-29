import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AttendanceFilters extends ConsumerWidget {
  const AttendanceFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const SizedBox.shrink();
    }

    final filters = ref.watch(attendanceFiltersProvider);
    final notifier = ref.read(attendanceFiltersProvider.notifier);

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classesState = ref.watch(classesProvider(schoolId));
    final sectionsState = ref.watch(sectionsProvider(schoolId));

    final filteredSections = sectionsState.sections.where((s) {
      if (filters.classId != null) {
        return s.classId == filters.classId;
      }
      return true;
    }).toList();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Academic Year Filter
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: filters.academicYearId,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Academic Years'),
                  ),
                  ...ayState.years.map((y) {
                    return DropdownMenuItem<String>(
                      value: y.id,
                      child: Text(y.name),
                    );
                  }),
                ],
                onChanged: (val) => notifier.setAcademicYear(val),
              ),
            ),

            // Class Filter
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: filters.classId,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Classes'),
                  ),
                  ...classesState.classes.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.name),
                    );
                  }),
                ],
                onChanged: (val) => notifier.setClass(val),
              ),
            ),

            // Section Filter
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: filters.sectionId,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Sections'),
                  ),
                  ...filteredSections.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.name),
                    );
                  }),
                ],
                onChanged: (val) => notifier.setSection(val),
              ),
            ),

            // Status Filter
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: filters.status,
                decoration: const InputDecoration(
                  labelText: 'Session Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Statuses'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'DRAFT',
                    child: Text('DRAFT'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'SUBMITTED',
                    child: Text('SUBMITTED'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'LOCKED',
                    child: Text('LOCKED'),
                  ),
                ],
                onChanged: (val) => notifier.setStatus(val),
              ),
            ),

            // Date Filter (Datepicker)
            SizedBox(
              width: 180,
              child: OutlinedButton.icon(
                key: const Key('date_filter_btn'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  filters.attendanceDate != null
                      ? DateFormat('yyyy-MM-dd').format(filters.attendanceDate!)
                      : 'Filter Date',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: filters.attendanceDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    notifier.setDate(picked);
                  }
                },
              ),
            ),

            // Clear Button
            if (filters.academicYearId != null ||
                filters.classId != null ||
                filters.sectionId != null ||
                filters.attendanceDate != null ||
                filters.status != null)
              TextButton.icon(
                key: const Key('clear_filters_btn'),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All'),
                onPressed: () => notifier.clearAll(),
              ),
          ],
        ),
      ),
    );
  }
}
