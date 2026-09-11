import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendance_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class AttendanceUploadWizard extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToRegister;

  const AttendanceUploadWizard({
    super.key,
    this.onNavigateToHistory,
    this.onNavigateToRegister,
  });

  @override
  ConsumerState<AttendanceUploadWizard> createState() => _AttendanceUploadWizardState();
}

class _AttendanceUploadWizardState extends ConsumerState<AttendanceUploadWizard> {
  String? _selectedAcademicYearId;

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Center(child: Text('Please select a school campus.'));
    }

    final uploadState = ref.watch(bulkAttendanceUploadProvider);
    final uploadNotifier = ref.read(bulkAttendanceUploadProvider.notifier);
    final ayState = ref.watch(academicYearsProvider(schoolId));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Auto-select academic year if not yet set
    if (_selectedAcademicYearId == null && ayState.years.isNotEmpty) {
      _selectedAcademicYearId = ayState.years.first.id;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Bulk Attendance Upload Wizard',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload past or bulk attendance via Excel (.xlsx, .xls) or CSV files with automated validation and conflict resolution.',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Error banner
          if (uploadState.errorMessage != null) ...[
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
                      uploadState.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Step Progress Indicator
          _buildStepBar(context, uploadState.currentStep),
          const SizedBox(height: 24),

          // Step Content
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildStepContent(context, uploadState, uploadNotifier, ayState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBar(BuildContext context, int currentStep) {
    final steps = [
      '1. Select File',
      '2. Validate',
      '3. Preview & Strategy',
      '4. Complete',
    ];

    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = (currentStep == 0 && i == 0) ||
            (currentStep == 1 && i == 1) ||
            ((currentStep == 2 || currentStep == 3) && i == 2) ||
            (currentStep == 4 && i == 3);
        final isPassed = (currentStep > 0 && i == 0) ||
            (currentStep > 1 && i == 1) ||
            (currentStep >= 4 && i == 2);

        final theme = Theme.of(context);

        Color circleColor = Colors.grey[400]!;
        if (isActive) circleColor = theme.colorScheme.primary;
        if (isPassed) circleColor = Colors.green;

        return Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: circleColor,
                child: isPassed
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  steps[i],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Container(
                    width: 20,
                    height: 1,
                    color: isPassed ? Colors.green : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    BulkAttendanceUploadState uploadState,
    BulkAttendanceUploadNotifier uploadNotifier,
    dynamic ayState,
  ) {
    switch (uploadState.currentStep) {
      case 0:
        return _buildStep0FileSelection(context, uploadNotifier);
      case 1:
        return _buildStep1Validation(context, uploadState, uploadNotifier, ayState);
      case 2:
      case 3:
        return _buildStep2PreviewAndStrategy(context, uploadState, uploadNotifier);
      case 4:
        return _buildStep4Complete(context, uploadState, uploadNotifier);
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 0: Download Template & Pick File
  Widget _buildStep0FileSelection(BuildContext context, BulkAttendanceUploadNotifier uploadNotifier) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step 1: Download Template & Choose Attendance File',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Download CSV Template'),
              onPressed: () => uploadNotifier.downloadTemplate(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Make sure your file columns match the standard template:\n'
          'Admission Number, Student Name, Class, Section, Attendance Date (YYYY-MM-DD), Session (FULL_DAY/MORNING/AFTERNOON), Status (PRESENT/ABSENT/LATE/HALF_DAY/EXCUSED), Remarks',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Center(
          child: InkWell(
            onTap: () => uploadNotifier.pickFile(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.primary.withValues(alpha: 0.03),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Click to select file (.xlsx, .xls, .csv)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('Maximum file size: 15MB', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Step 1: Validate
  Widget _buildStep1Validation(
    BuildContext context,
    BulkAttendanceUploadState uploadState,
    BulkAttendanceUploadNotifier uploadNotifier,
    dynamic ayState,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Configure Academic Scope & Validate Data',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.attach_file, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Selected File: ${uploadState.selectedFileName ?? "Unknown"}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => uploadNotifier.reset(),
                child: const Text('Change File'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 300,
          child: SafeDropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedAcademicYearId,
            decoration: const InputDecoration(
              labelText: 'Target Academic Year',
              border: OutlineInputBorder(),
            ),
            items: (ayState.years as List).map<DropdownMenuItem<String>>((y) {
              return DropdownMenuItem<String>(
                value: y.id,
                child: Text(y.name),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedAcademicYearId = val;
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          icon: uploadState.isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(uploadState.isValidating ? 'Validating Data...' : 'Validate File Data'),
          onPressed: uploadState.isValidating || _selectedAcademicYearId == null
              ? null
              : () => uploadNotifier.validateFile(_selectedAcademicYearId!),
        ),
      ],
    );
  }

  // Step 2 & 3: Preview & Strategy
  Widget _buildStep2PreviewAndStrategy(
    BuildContext context,
    BulkAttendanceUploadState uploadState,
    BulkAttendanceUploadNotifier uploadNotifier,
  ) {
    final theme = Theme.of(context);
    final valResult = uploadState.validateResult;
    if (valResult == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Validation Summary & Conflict Strategy',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Validation Metric Cards
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _metricPill('Total Rows', '${valResult.totalRows}', Colors.blue),
            _metricPill('Valid Rows', '${valResult.validRows}', Colors.green),
            _metricPill('Invalid Rows', '${valResult.invalidRows}', Colors.red),
            _metricPill('Conflict Rows', '${valResult.conflictRows}', Colors.orange),
          ],
        ),
        const SizedBox(height: 24),

        // Conflict Resolution Strategy Option
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conflict Resolution Strategy for Existing Records:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: const Text('Skip Existing Records (Default)'),
                subtitle: const Text('If student attendance already exists for that session and date, do not modify it.'),
                value: 'SKIP_EXISTING',
                groupValue: uploadState.conflictStrategy,
                onChanged: (val) => uploadNotifier.setConflictStrategy(val!),
              ),
              RadioListTile<String>(
                title: const Text('Replace Existing Records'),
                subtitle: const Text('Overwrite existing attendance records with the values in this import file and log an audit trail.'),
                value: 'REPLACE_EXISTING',
                groupValue: uploadState.conflictStrategy,
                onChanged: (val) => uploadNotifier.setConflictStrategy(val!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Row Previews
        Text(
          'Data Preview (First ${valResult.previewRows.length} rows):',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.grey.withValues(alpha: 0.1),
                child: const Row(
                  children: [
                    SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(width: 90, child: Text('Adm No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Class & Sec', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(width: 85, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(width: 70, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(width: 80, child: Text('Validation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Expanded(flex: 2, child: Text('Details / Conflict', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                ),
              ),
              ...valResult.previewRows.map((row) {
                Color valColor = Colors.green;
                if (row.validationStatus == 'INVALID') valColor = Colors.red;
                if (row.validationStatus == 'CONFLICT') valColor = Colors.orange;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text('${row.rowNumber}', style: const TextStyle(fontSize: 11))),
                      SizedBox(width: 90, child: Text(row.admissionNumber ?? '-', style: const TextStyle(fontSize: 11))),
                      Expanded(flex: 2, child: Text(row.studentName ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('${row.className ?? ""} ${row.sectionName ?? ""}'.trim(), style: const TextStyle(fontSize: 11))),
                      SizedBox(width: 85, child: Text(row.attendanceDate ?? '-', style: const TextStyle(fontSize: 11))),
                      SizedBox(width: 70, child: Text(row.status ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(
                        width: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: valColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            row.validationStatus,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: valColor),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.errorMessage ?? (row.conflictExistingStatus != null ? 'Existing: ${row.conflictExistingStatus}' : '-'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: row.errorMessage != null ? Colors.red : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Execution buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => uploadNotifier.reset(),
              child: const Text('Cancel & Start Over'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              icon: uploadState.isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(uploadState.isImporting ? 'Importing Records...' : 'Execute Attendance Import'),
              onPressed: uploadState.isImporting ? null : () => uploadNotifier.executeImport(),
            ),
          ],
        ),
      ],
    );
  }

  // Step 4: Complete
  Widget _buildStep4Complete(
    BuildContext context,
    BulkAttendanceUploadState uploadState,
    BulkAttendanceUploadNotifier uploadNotifier,
  ) {
    final imp = uploadState.importResult;
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Attendance Import Complete!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Import Job: ${imp?.jobId ?? ""}',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (imp != null) ...[
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _metricPill('Total Rows', '${imp.totalRows}', Colors.blue),
              _metricPill('Imported / Updated', '${imp.importedRows}', Colors.green),
              _metricPill('Skipped', '${imp.skippedRows}', Colors.orange),
              _metricPill('Failed', '${imp.failedRows}', Colors.red),
            ],
          ),
        ],
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Upload Another File'),
              onPressed: () => uploadNotifier.reset(),
            ),
            const SizedBox(width: 16),
            if (widget.onNavigateToHistory != null) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('View Import History'),
                onPressed: widget.onNavigateToHistory,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _metricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
