import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:admin_portal/features/migrations/presentation/providers/migration_providers.dart';
import 'package:admin_portal/features/migrations/data/models/migration_models.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/web_download_helper.dart';

class StudentMigrationWizardScreen extends ConsumerStatefulWidget {
  final String? jobId;

  const StudentMigrationWizardScreen({super.key, this.jobId});

  @override
  ConsumerState<StudentMigrationWizardScreen> createState() => _StudentMigrationWizardScreenState();
}

class _StudentMigrationWizardScreenState extends ConsumerState<StudentMigrationWizardScreen> {
  int _rowPage = 0;
  final int _rowLimit = 10;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.jobId != null) {
        ref.read(studentMigrationWizardProvider.notifier).preloadJob(widget.jobId!);
      } else {
        final wizardState = ref.read(studentMigrationWizardProvider);
        if (wizardState.currentStep == 0 && wizardState.selectedSchoolId == null) {
          final schoolId = ref.read(selectedSchoolIdProvider);
          final ayId = ref.read(selectedAcademicYearIdProvider);
          if (schoolId != null && ayId != null) {
            ref.read(studentMigrationWizardProvider.notifier).updateContext(schoolId, ayId);
          }
        }
      }
    });
  }

  void _downloadTemplate() {
    const templateHeaders =
        'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,middle_name,blood_group,aadhaar_number,emis_number,mobile,email,photo_url,class_code,section_code';
    const templateRow =
        '\nJohn,Doe,MALE,2010-05-15,ADM1001,10,2024-04-01,Edward,O+,123456789012,EMIS9999,9876543210,john.doe@school.com,,CLASS-10,SEC-A';
    downloadCsvFile('student_migration_template.csv', '$templateHeaders$templateRow');
  }

  void _downloadErrorReport(List<ImportJobRowDto> errors) {
    final csvRows = [
      'Row Number,Source Identifier,Status,Error Code,Error Message',
    ];
    for (final err in errors) {
      csvRows.add(
        '${err.rowNumber},"${err.sourceIdentifier ?? ''}",${err.status},"${err.errorCode ?? ''}","${err.errorMessage ?? ''}"',
      );
    }
    downloadCsvFile(
      'migration_errors_${widget.jobId ?? "job"}.csv',
      csvRows.join('\n'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentMigrationWizardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jobId == null ? 'New Student Migration' : 'Migration Job Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (state.currentStep > 0 && widget.jobId == null) {
              ref.read(studentMigrationWizardProvider.notifier).prevStep();
            } else {
              context.go('/migrations');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStepProgress(state.currentStep, theme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: _buildStepContent(state, theme),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (state.isActionInProgress)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          state.currentStep == 4 ? 'Migration in progress...' : 'Processing, please wait...',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (state.currentStep == 4) ...[
                          const SizedBox(height: 8),
                          const Text('Do not navigate away or close this page.', style: TextStyle(color: Colors.grey)),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepProgress(int currentStep, ThemeData theme) {
    final steps = ['Context', 'CSV Upload', 'Validation', 'Review', 'Execution', 'Complete'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(steps.length, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? theme.colorScheme.primary
                            : theme.disabledColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent || isCompleted ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? theme.colorScheme.primary : theme.disabledColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (index < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(StudentMigrationWizardState state, ThemeData theme) {
    if (state.errorMessage != null) {
      return Card(
        color: theme.colorScheme.errorContainer,
        margin: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (state.currentStep) {
      case 0:
        return _buildContextStep(state, theme);
      case 1:
        return _buildCsvUploadStep(state, theme);
      case 2:
        return _buildValidationStep(state, theme);
      case 3:
        return _buildErrorReviewStep(state, theme);
      case 4:
        return _buildExecutionStep(state, theme);
      case 5:
        return _buildCompleteStep(state, theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContextStep(StudentMigrationWizardState state, ThemeData theme) {
    final schoolsState = ref.watch(schoolsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select School & Academic Year Context', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Choose the destination campus and academic calendar scope for the imported student registry.'),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Target School / Campus', border: OutlineInputBorder()),
          value: state.selectedSchoolId,
          items: schoolsState.schools.map((school) {
            return DropdownMenuItem(value: school.id, child: Text(school.name));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(studentMigrationWizardProvider.notifier).updateContext(val, '');
            }
          },
        ),
        const SizedBox(height: 24),
        if (state.selectedSchoolId != null) ...[
          Builder(
            builder: (context) {
              final yearsState = ref.watch(academicYearsProvider(state.selectedSchoolId!));
              if (yearsState.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (yearsState.error != null) {
                return Text('Error loading academic years: ${yearsState.error}', style: TextStyle(color: theme.colorScheme.error));
              }
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Academic Year Scope', border: OutlineInputBorder()),
                value: state.selectedAcademicYearId?.isEmpty ?? true ? null : state.selectedAcademicYearId,
                items: yearsState.years.map((y) {
                  return DropdownMenuItem(value: y.id, child: Text('${y.name}${y.isCurrent ? " (Current)" : ""}'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(studentMigrationWizardProvider.notifier).updateContext(state.selectedSchoolId!, val);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: state.selectedSchoolId != null &&
                    state.selectedAcademicYearId != null &&
                    state.selectedAcademicYearId!.isNotEmpty
                ? () => ref.read(studentMigrationWizardProvider.notifier).nextStep()
                : null,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _buildCsvUploadStep(StudentMigrationWizardState state, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Student File', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Supported formats: CSV, XLS, XLSX, XLSM, XLSB, ODS'),
        const SizedBox(height: 24),
        InkWell(
          onTap: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['csv', 'xlsx', 'xls', 'xlsm', 'xlsb', 'ods'],
              withData: true,
            );
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              if (file.bytes != null) {
                ref.read(studentMigrationWizardProvider.notifier).updateSelectedFile(file.name, file.bytes!);
              }
            }
          },
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: state.fileName != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.insert_drive_file, size: 48, color: Colors.blue),
                        const SizedBox(height: 8),
                        Text(state.fileName!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Click to replace file', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Click to select student CSV file'),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CSV Format Guidelines:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('• Mandatory Headers: first_name, last_name, gender, date_of_birth, admission_number, roll_number, admission_date'),
                const SizedBox(height: 4),
                const Text('• Optional Headers: middle_name, blood_group, aadhaar_number, emis_number, mobile, email, photo_url, class_code, section_code'),
                const SizedBox(height: 4),
                const Text('• Gender options: MALE, FEMALE, or OTHER (case insensitive)'),
                const SizedBox(height: 4),
                const Text('• Dates: Must follow YYYY-MM-DD format'),
                const SizedBox(height: 4),
                const Text('• Constraints checked: Unique admission numbers, roll numbers inside section context, and global Aadhaar uniqueness'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download),
                  label: const Text('Download Official Template'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => ref.read(studentMigrationWizardProvider.notifier).prevStep(),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: state.fileName != null
                  ? () async {
                      final jobCreated =
                          await ref.read(studentMigrationWizardProvider.notifier).createImportJob();
                      if (jobCreated) {
                        final validated =
                            await ref.read(studentMigrationWizardProvider.notifier).validateCsvFile();
                        if (validated) {
                          ref.read(studentMigrationWizardProvider.notifier).nextStep();
                        }
                      }
                    }
                  : null,
              child: const Text('Validate File'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValidationStep(StudentMigrationWizardState state, ThemeData theme) {
    final job = state.activeJob;
    if (job == null) return const Text('No active job found.');

    final failedRowsCount = job.failedRows;
    final totalRowsCount = job.totalRows;
    final validRowsCount = totalRowsCount - failedRowsCount;
    final sheets = job.jobMetadata['sheets'] as List<dynamic>?;
    final selectedSheet = job.jobMetadata['selected_sheet'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sheets != null && sheets.length > 1) ...[
          Text('Select Worksheet:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: selectedSheet,
            items: sheets.map((s) {
              final name = s.toString();
              return DropdownMenuItem<String>(
                value: name,
                child: Text(name),
              );
            }).toList(),
            onChanged: (newSheet) {
              if (newSheet != null && newSheet != selectedSheet) {
                ref.read(studentMigrationWizardProvider.notifier).updateSelectedSheet(newSheet);
              }
            },
          ),
          const SizedBox(height: 24),
        ],
        Text('Validation Results Summary', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: failedRowsCount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                failedRowsCount > 0 ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                color: failedRowsCount > 0 ? Colors.orange : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  failedRowsCount > 0
                      ? 'Validation Complete. Some rows have validation errors. Rows with validation errors will not be executed.'
                      : 'Validation Complete. All rows are valid and ready to execute!',
                  style: TextStyle(
                    color: failedRowsCount > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Table(
          border: TableBorder.symmetric(inside: BorderSide(color: theme.dividerColor)),
          children: [
            _buildTableRow('Total Uploaded Rows', '$totalRowsCount', theme),
            _buildTableRow('Valid / Ready Rows', '$validRowsCount', theme),
            _buildTableRow('Failed / Invalid Rows', '$failedRowsCount', theme),
            _buildTableRow('Skipped Rows', '${job.skippedRows}', theme),
            _buildTableRow('Status', job.status, theme),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => ref.read(studentMigrationWizardProvider.notifier).prevStep(),
              child: const Text('Upload New File'),
            ),
            Row(
              children: [
                if (failedRowsCount > 0) ...[
                  OutlinedButton(
                    onPressed: () => ref.read(studentMigrationWizardProvider.notifier).nextStep(),
                    child: const Text('Review Errors'),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton(
                  onPressed: validRowsCount > 0
                      ? () {
                          // Jump to step 4 (index 4 is execution confirmation)
                          if (failedRowsCount > 0) {
                            ref.read(studentMigrationWizardProvider.notifier).nextStep(); // to review
                          } else {
                            ref.read(studentMigrationWizardProvider.notifier).nextStep(); // review
                            ref.read(studentMigrationWizardProvider.notifier).nextStep(); // to execution
                          }
                        }
                      : null,
                  child: const Text('Proceed to Execute'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value, ThemeData theme) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildErrorReviewStep(StudentMigrationWizardState state, ThemeData theme) {
    final errors = state.validationErrors;

    final startIndex = _rowPage * _rowLimit;
    final endIndex = (startIndex + _rowLimit) < errors.length ? (startIndex + _rowLimit) : errors.length;
    final List<ImportJobRowDto> pagedErrors = errors.isNotEmpty ? errors.sublist(startIndex, endIndex) : <ImportJobRowDto>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Review Row Errors', style: theme.textTheme.headlineSmall),
            OutlinedButton.icon(
              onPressed: () => _downloadErrorReport(errors),
              icon: const Icon(Icons.download),
              label: const Text('Download Error CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Row')),
                DataColumn(label: Text('Source ID / Admission Number')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Error Code')),
                DataColumn(label: Text('Error Message')),
              ],
              rows: pagedErrors.map<DataRow>((ImportJobRowDto err) {
                return DataRow(
                  cells: [
                    DataCell(Text(err.rowNumber.toString())),
                    DataCell(Text(err.sourceIdentifier ?? 'N/A')),
                    DataCell(Text(err.status, style: const TextStyle(color: Colors.red))),
                    DataCell(Text(err.errorCode ?? 'N/A')),
                    DataCell(Text(err.errorMessage ?? 'N/A')),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        if (errors.length > _rowLimit) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _rowPage > 0 ? () => setState(() => _rowPage--) : null,
              ),
              Text('Page ${_rowPage + 1} of ${(errors.length / _rowLimit).ceil()}'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: endIndex < errors.length ? () => setState(() => _rowPage++) : null,
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () {
                // Return to validation summary
                ref.read(studentMigrationWizardProvider.notifier).prevStep();
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(studentMigrationWizardProvider.notifier).nextStep(); // to execution confirmation
              },
              child: const Text('Proceed to Execute'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExecutionStep(StudentMigrationWizardState state, ThemeData theme) {
    final job = state.activeJob;
    if (job == null) return const Text('No active job metadata.');

    final failedCount = job.failedRows;
    final totalCount = job.totalRows;
    final validCount = totalCount - failedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Execution Confirmation', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text(
          'Please verify the details below before starting the final student migration database execution. This operation will commit new student profiles to the repository.',
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirm Migration Configuration:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('• Destination School Context ID: ${job.schoolId}'),
                const SizedBox(height: 8),
                Text('• Destination Academic Year ID: ${job.jobMetadata['academic_year_id'] ?? "Default"}'),
                const SizedBox(height: 8),
                Text('• Valid student profiles to create: $validCount'),
                const SizedBox(height: 8),
                Text('• Invalid/corrupted rows to be skipped: $failedCount'),
                const SizedBox(height: 16),
                const Text(
                  'Warning: Rows with errors will be skipped entirely. Ensure you have backed up any necessary sheets.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => ref.read(studentMigrationWizardProvider.notifier).prevStep(),
              child: const Text('Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: () async {
                final result = await ref.read(studentMigrationWizardProvider.notifier).executeMigration();
                if (result) {
                  ref.read(studentMigrationWizardProvider.notifier).nextStep();
                }
              },
              child: const Text('Confirm & Execute'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompleteStep(StudentMigrationWizardState state, ThemeData theme) {
    final job = state.activeJob;
    if (job == null) return const Text('No job outcome summary found.');

    IconData icon;
    Color color;
    String statusTitle;
    String statusDesc;

    if (job.status == 'COMPLETED') {
      icon = Icons.check_circle_outline;
      color = Colors.green;
      statusTitle = 'Migration Completed';
      statusDesc = 'All valid student records have been created and committed successfully.';
    } else if (job.status == 'COMPLETED_WITH_ERRORS') {
      icon = Icons.warning_amber_outlined;
      color = Colors.orange;
      statusTitle = 'Migration Completed with Errors';
      statusDesc = 'Some valid student records were committed, but some rows failed during execution.';
    } else {
      icon = Icons.error_outline;
      color = Colors.red;
      statusTitle = 'Migration Failed';
      statusDesc = job.errorSummary ?? 'The execution was aborted or encountered fatal connection errors.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 72),
        const SizedBox(height: 16),
        Text(statusTitle, style: theme.textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(statusDesc, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 32),
        Table(
          border: TableBorder.symmetric(inside: BorderSide(color: theme.dividerColor)),
          children: [
            _buildTableRow('Total Processed Rows', '${job.processedRows}', theme),
            _buildTableRow('Successful Student Creations', '${job.successfulRows}', theme),
            _buildTableRow('Failed Rows During Execution', '${job.failedRows}', theme),
            _buildTableRow('Skipped Rows', '${job.skippedRows}', theme),
            _buildTableRow('Status', job.status, theme),
          ],
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            if (state.validationErrors.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _downloadErrorReport(state.validationErrors),
                icon: const Icon(Icons.download),
                label: const Text('Download Error CSV'),
              ),
            OutlinedButton(
              onPressed: () {
                context.go('/migrations');
              },
              child: const Text('View History'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/students');
              },
              child: const Text('View Students'),
            ),
          ],
        ),
      ],
    );
  }
}
