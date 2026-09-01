import 'dart:convert';
import 'dart:async';
import '../providers/web_diagnostic_stub.dart'
    if (dart.library.js_util) '../providers/web_diagnostic_web.dart'
    if (dart.library.html) '../providers/web_diagnostic_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../providers/bulk_import_providers.dart';
import '../providers/web_download_helper.dart';
import '../../data/models/bulk_import_models.dart';
import '../../data/models/csv_helper.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  int _previewPage = 0;
  static const int _pageSize = 10;
  int _executionPage = 0;
  String _executionFilter = 'ALL';
  String _previewFilter = 'ALL';
  String _searchQuery = '';
  final Set<int> _selectedRowIndices = {};

  late final TextEditingController _searchController;
  late final ScrollController _specsHorizontalController;
  late final ScrollController _previewHorizontalController;
  late final ScrollController _previewVerticalController;
  late final ScrollController _executionHorizontalController;
  late final ScrollController _executionVerticalController;
  late final ScrollController _capacityScrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _specsHorizontalController = ScrollController();
    _previewHorizontalController = ScrollController();
    _previewVerticalController = ScrollController();
    _executionHorizontalController = ScrollController();
    _executionVerticalController = ScrollController();
    _capacityScrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _specsHorizontalController.dispose();
    _previewHorizontalController.dispose();
    _previewVerticalController.dispose();
    _executionHorizontalController.dispose();
    _executionVerticalController.dispose();
    _capacityScrollController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscardEdits(BuildContext context, BulkImportState state) async {
    if (state.isCompleted) return true;
    final hasUnsavedEdits = state.rows.any((row) => row.editedFields.isNotEmpty);
    if (!hasUnsavedEdits) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Unsaved Edits?'),
        content: const Text(
          'You have edited values in the preview grid. Uploading a new file or changing settings will discard all edited values. Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard & Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleFileSelection(BuildContext context) async {
    final state = ref.read(bulkImportProvider);
    final proceed = await _confirmDiscardEdits(context, state);
    if (!proceed) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls', 'xlsm', 'xlsb', 'ods'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null) {
        setState(() {
          _previewPage = 0;
          _executionPage = 0;
          _executionFilter = 'ALL';
          _previewFilter = 'ALL';
          _searchQuery = '';
          _searchController.clear();
          _selectedRowIndices.clear();
        });
        if (file.name.toLowerCase().endsWith('.csv')) {
          try {
            final content = utf8.decode(bytes);
            ref.read(bulkImportProvider.notifier).selectFile(file.name, content);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to read file encoding: ${e.toString()}')),
              );
            }
          }
        } else {
          ref.read(bulkImportProvider.notifier).selectSpreadsheetFile(file.name, bytes);
        }
      }
    }
  }

  void _showSuggestRollNumbersDialog(BuildContext context, BulkImportState state) {
    final notifier = ref.read(bulkImportProvider.notifier);
    final suggestions = notifier.suggestRollNumbers();

    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No duplicate roll number errors detected or no unused suggestions found.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Roll Number Suggestions'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The following student rows have duplicate roll numbers in their section. We suggest these unused roll numbers:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(color: Colors.grey[300]!),
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer),
                        children: const [
                          Padding(padding: EdgeInsets.all(6.0), child: Text('Row', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(6.0), child: Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(6.0), child: Text('Current', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(6.0), child: Text('Suggested', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      ...suggestions.entries.map((entry) {
                        final rowIndex = entry.key;
                        final suggestion = entry.value;
                        final row = state.rows.firstWhere((r) => r.rowIndex == rowIndex);
                        final studentName = '${row.data['first_name'] ?? ''} ${row.data['last_name'] ?? ''}';
                        final currentRoll = row.data['roll_number'] ?? '';

                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(rowIndex.toString(), style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(studentName, style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(currentRoll, style: const TextStyle(fontSize: 12))),
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(
                                suggestion,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Note: These suggestions will not be saved automatically. Click Apply to copy them to the validation grid.',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                for (final entry in suggestions.entries) {
                  notifier.updateCell(entry.key, 'roll_number', entry.value);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Applied ${suggestions.length} roll number suggestions.')),
                );
              },
              child: const Text('Apply Suggestions'),
            ),
          ],
        );
      },
    );
  }

  void _showImportConfirmation(BuildContext context, String schoolId, String schoolName, BulkImportState state) {
    final theme = Theme.of(context);
    final totalStudents = state.rows.length;
    final academicYearsCount = state.rows.map((r) => r.data['academic_year_id'] ?? '').where((id) => id.isNotEmpty).toSet().length;

    final resolvedClassUUIDs = state.resolvedClassIds.values.where((id) => id.isNotEmpty).toSet().length;
    final resolvedSectionUUIDs = state.resolvedSectionIds.values.where((id) => id.isNotEmpty).toSet().length;

    final valid = state.rows.where((r) => r.status == ImportRowStatus.valid || r.status == ImportRowStatus.success).length;
    final warnings = state.rows.where((r) => r.status == ImportRowStatus.warning).length;
    final duplicates = state.rows.where((r) => r.status == ImportRowStatus.duplicate).length;
    final capacityErrors = state.rows.where((r) => r.status == ImportRowStatus.capacityError).length;
    final dependencyErrors = state.rows.where((r) => r.status == ImportRowStatus.dependencyError).length;
    final blockingErrors = state.rows.where((r) => r.status == ImportRowStatus.error).length;

    final hasAnyBlockingErrors = blockingErrors > 0 || dependencyErrors > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ready to Import'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSummaryRow('Students', totalStudents.toString()),
              _buildSummaryRow('Academic Years', academicYearsCount.toString()),
              if (state.selectedType == ImportType.students) ...[
                _buildSummaryRow('Classes', '$resolvedClassUUIDs resolved'),
                _buildSummaryRow('Sections', '$resolvedSectionUUIDs resolved'),
              ],
              const Divider(),
              _buildSummaryRow('Valid', valid.toString(), color: Colors.green),
              _buildSummaryRow('Warnings', warnings.toString(), color: Colors.orange),
              _buildSummaryRow('Duplicates', duplicates.toString(), color: Colors.purple),
              _buildSummaryRow('Capacity Errors', capacityErrors.toString(), color: Colors.deepOrange),
              _buildSummaryRow('Dependency Errors', dependencyErrors.toString(), color: Colors.brown),
              _buildSummaryRow('Blocking Errors', blockingErrors.toString(), color: Colors.red),
              const SizedBox(height: 16),
              if (hasAnyBlockingErrors) ...[
                const Text(
                  'Resolve all blocking errors and dependency errors before importing.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ] else ...[
                const Text(
                  'This operation cannot be undone. Valid student profiles will be imported.',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: hasAnyBlockingErrors
                ? null
                : () {
                    Navigator.pop(dialogCtx);
                    final apiClient = ref.read(apiClientProvider);
                    ref.read(bulkImportProvider.notifier).importRecords(schoolId, apiClient);
                  },
            child: const Text('Import Valid Rows'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          _previewPage = 0;
          _executionPage = 0;
          _executionFilter = 'ALL';
          _previewFilter = 'ALL';
          _searchQuery = '';
          _searchController.clear();
          _selectedRowIndices.clear();
        });
      }
    });
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final schoolsState = ref.watch(schoolsListProvider);
    final importState = ref.watch(bulkImportProvider);

    if (schoolId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Please select a school context first',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    final schoolName = schoolsState.schools.firstWhere(
      (s) => s.id == schoolId,
      orElse: () => const SchoolDto(
        id: '',
        tenantId: '',
        name: 'Selected Campus',
        code: '',
        board: '',
        schoolType: '',
        email: '',
        isActive: true,
        status: 'ACTIVE',
        version: 1,
      ),
    ).name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Data Onboarding'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.business, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active School: $schoolName',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (importState.isUploading)
              _buildProgressCard(context, importState)
            else if (importState.isRetrying)
              _buildRetryProgressCard(context, importState)
            else if (importState.isCompleted)
              _buildCompletionCard(context, schoolName, importState)
            else
              _buildSetupCard(context, schoolName, importState),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCORSIsolationDialog(context, schoolId),
        backgroundColor: Colors.red,
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
    );
  }

  void _showCORSIsolationDialog(BuildContext context, String? schoolId) {
    if (schoolId == null) return;
    
    final logController = StreamController<String>.broadcast();
    final logBuffer = StringBuffer();
    
    void log(String message) {
      logBuffer.write(message);
      logController.add(logBuffer.toString());
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.red),
              SizedBox(width: 8),
              Text('CORS / XHR Isolation Diagnostics'),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: StreamBuilder<String>(
                      stream: logController.stream,
                      initialData: 'Click a button below to run native browser-layer diagnostics...',
                      builder: (context, snapshot) {
                        return SingleChildScrollView(
                          reverse: true,
                          child: Text(
                            snapshot.data ?? '',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        logBuffer.clear();
                        _runNativeFetch(schoolId, log);
                      },
                      child: const Text('Test Native Fetch'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        logBuffer.clear();
                        _runProgressiveTest(schoolId, log);
                      },
                      child: const Text('Progressive Headers'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                logController.close();
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runNativeFetch(String schoolId, void Function(String) log) async {
    final tokenProvider = ref.read(authTokenProvider);
    final token = await tokenProvider?.getAccessToken() ?? '';
    await runNativeFetchImpl(schoolId, token, log);
  }

  Future<void> _runProgressiveTest(String schoolId, void Function(String) log) async {
    final tokenProvider = ref.read(authTokenProvider);
    final token = await tokenProvider?.getAccessToken() ?? '';
    await runProgressiveTestImpl(schoolId, token, log);
  }

  Widget _buildSetupCard(BuildContext context, String schoolName, BulkImportState state) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final schoolId = ref.watch(selectedSchoolIdProvider);

    int capacityErrorsCount = 0;
    final Map<String, int> incomingCounts = {};
    List<SectionDto> studentSections = [];
    final List<Widget> capacityBanners = [];
    if (state.rows.isNotEmpty && state.selectedType == ImportType.students && schoolId != null) {
      studentSections = state.cachedSections;

      final referencedSectionIds = state.rows
          .map((r) => r.data['section_id'] ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final List<SectionDto> sectionsToDisplay = studentSections
          .where((sec) => referencedSectionIds.contains(sec.id))
          .toList();

      sectionsToDisplay.sort((a, b) {
        final aClass = state.cachedClasses.firstWhere(
          (c) => c.id == a.classId,
          orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: '', code: '', level: 1, category: '', capacity: 40, status: '', isActive: true, version: 1),
        );
        final bClass = state.cachedClasses.firstWhere(
          (c) => c.id == b.classId,
          orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: '', code: '', level: 1, category: '', capacity: 40, status: '', isActive: true, version: 1),
        );
        final classCompare = aClass.name.compareTo(bClass.name);
        if (classCompare != 0) return classCompare;
        return a.name.compareTo(b.name);
      });

      // 1. Compute incoming counts
      for (final row in state.rows) {
        if (row.status != ImportRowStatus.success) {
          final secId = row.data['section_id'];
          if (secId != null && secId.isNotEmpty) {
            incomingCounts[secId] = (incomingCounts[secId] ?? 0) + 1;
          }
        }
      }

      // 2. Count capacity errors
      for (final row in state.rows) {
        final secId = row.data['section_id'];
        if (secId != null && secId.isNotEmpty) {
          SectionDto? matchedSec;
          for (final s in studentSections) {
            if (s.id == secId) {
              matchedSec = s;
              break;
            }
          }
          if (matchedSec != null) {
            final existing = state.existingSectionCounts[secId] ?? 0;
            final incoming = incomingCounts[secId] ?? 0;
            if (existing + incoming > matchedSec.capacity) {
              capacityErrorsCount++;
            }
          }
        }
      }

      // 3. Warning banners
      for (final sec in sectionsToDisplay) {
        final existing = state.existingSectionCounts[sec.id] ?? 0;
        final incoming = incomingCounts[sec.id] ?? 0;
        final capacity = sec.capacity;
        final projected = existing + incoming;
        if (projected > capacity) {
          final available = capacity - existing > 0 ? capacity - existing : 0;
          final parentClass = state.cachedClasses.firstWhere(
            (c) => c.id == sec.classId,
            orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: 'Unknown Class', code: '', level: 1, category: '', capacity: 40, status: '', isActive: true, version: 1),
          );
          final displayName = parentClass.id.isNotEmpty
              ? '${parentClass.name} / ${sec.name}'
              : sec.name;
          capacityBanners.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Section $displayName has only $available available seats, but $incoming incoming students are assigned to it.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
      studentSections = sectionsToDisplay;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 1: Select Import Entity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ImportType.values.map((type) {
                final isSelected = state.selectedType == type;
                return ChoiceChip(
                  label: Text(type.label),
                  selected: isSelected,
                  onSelected: (_) async {
                    final proceed = await _confirmDiscardEdits(context, state);
                    if (!proceed) return;
                    setState(() {
                      _previewPage = 0;
                      _executionPage = 0;
                      _executionFilter = 'ALL';
                      _previewFilter = 'ALL';
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedRowIndices.clear();
                    });
                    ref.read(bulkImportProvider.notifier).setImportType(type);
                  },
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 32),
            Text('Step 2: Column Template Specifications', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Your CSV file must match the following columns (Optional fields can be left blank):',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            _buildTemplateSpecsTable(context, state.selectedType),
            const Divider(height: 32),
            Text('Step 3: Upload CSV File', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: primaryColor.withValues(alpha: 0.05),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.blue),
                    const SizedBox(height: 12),
                    Text(
                      state.fileName ?? 'No file selected yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: state.fileName != null ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _handleFileSelection(context),
                      icon: const Icon(Icons.file_open),
                      label: const Text('Select File'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Supported formats: CSV, XLS, XLSX, XLSM, XLSB, ODS', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    if (state.sheets.length > 1) ...[
                      const SizedBox(height: 16),
                      const Text('Select Worksheet:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: state.selectedSheet,
                        items: state.sheets.map((sheet) {
                          return DropdownMenuItem<String>(
                            value: sheet,
                            child: Text(sheet),
                          );
                        }).toList(),
                        onChanged: (newSheet) {
                          if (newSheet != null && newSheet != state.selectedSheet) {
                            ref.read(bulkImportProvider.notifier).selectSpreadsheetFile(
                              state.fileName!,
                              state.rawBytes!,
                              sheetName: newSheet,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (state.globalErrorMessage != null && state.rows.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.globalErrorMessage!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (state.rows.isNotEmpty) ...[
              const Divider(height: 32),
              Text('Step 4: Preview and Validate Rows', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildValidationSummary(context, state),
              if (state.selectedType == ImportType.students)
                _buildDependencyPreviewPanel(context, state),
              if (state.selectedType == ImportType.students && studentSections.isNotEmpty) ...[
                _buildSectionCapacityPanel(context, state, studentSections, incomingCounts),
                ...capacityBanners,
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search students (first_name, last_name, admission_number, roll_number, email)...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _previewPage = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.selectedType == ImportType.students) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            foregroundColor: theme.colorScheme.onSecondaryContainer,
                          ),
                          onPressed: () {
                            _showSuggestRollNumbersDialog(context, state);
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Suggest Roll Numbers'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                        ),
                        onPressed: () {
                          final firstRow = state.rows.first;
                          final headers = firstRow.data.keys.toList();
                          final List<String> csvLines = [];
                          csvLines.add(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));
                          for (final row in state.rows) {
                            final line = headers.map((h) {
                              final val = row.data[h] ?? '';
                              return '"${val.replaceAll('"', '""')}"';
                            }).join(',');
                            csvLines.add(line);
                          }
                          final csvContent = csvLines.join('\n');
                          downloadCsvFile('corrected_${state.fileName ?? "import.csv"}', csvContent);
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download Corrected CSV'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('All (${state.rows.length})'),
                        selected: _previewFilter == 'ALL',
                        onSelected: (_) => setState(() {
                          _previewFilter = 'ALL';
                          _previewPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: Text('Errors (${state.rows.where((r) => r.status == ImportRowStatus.error).length})'),
                        selected: _previewFilter == 'ERRORS',
                        onSelected: (_) => setState(() {
                          _previewFilter = 'ERRORS';
                          _previewPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: Text('Warnings (${state.rows.where((r) => r.status == ImportRowStatus.warning).length})'),
                        selected: _previewFilter == 'WARNINGS',
                        onSelected: (_) => setState(() {
                          _previewFilter = 'WARNINGS';
                          _previewPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: Text('Valid (${state.rows.where((r) => r.status == ImportRowStatus.valid).length})'),
                        selected: _previewFilter == 'VALID',
                        onSelected: (_) => setState(() {
                          _previewFilter = 'VALID';
                          _previewPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: Text('Edited (${state.rows.where((r) => r.editedFields.isNotEmpty).length})'),
                        selected: _previewFilter == 'EDITED',
                        onSelected: (_) => setState(() {
                          _previewFilter = 'EDITED';
                          _previewPage = 0;
                        }),
                      ),
                      if (state.selectedType == ImportType.students)
                        ChoiceChip(
                          label: Text('Capacity Errors ($capacityErrorsCount)'),
                          selected: _previewFilter == 'CAPACITY_ERRORS',
                          onSelected: (_) => setState(() {
                            _previewFilter = 'CAPACITY_ERRORS';
                            _previewPage = 0;
                          }),
                        ),
                    ],
                  ),
                  if (_selectedRowIndices.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                      ),
                      onPressed: () {
                        final schoolId = ref.read(selectedSchoolIdProvider);
                        final academicYearsState = schoolId != null ? ref.read(academicYearsProvider(schoolId)) : null;
                        final classesState = schoolId != null ? ref.read(classesProvider(schoolId)) : null;
                        final sectionsState = schoolId != null ? ref.read(sectionsProvider(schoolId)) : null;

                        final List<String> ayOptions = [];
                        final Map<String, String> ayMap = {};
                        if (academicYearsState != null && !academicYearsState.isLoading) {
                          for (final y in academicYearsState.years) {
                            ayOptions.add(y.id);
                            ayMap[y.id] = y.name;
                          }
                        }

                        final List<String> classOptions = [];
                        final Map<String, String> classMap = {};
                        if (classesState != null && !classesState.isLoading) {
                          for (final c in classesState.classes) {
                            classOptions.add(c.id);
                            classMap[c.id] = c.displayName ?? c.name;
                          }
                        }

                        final List<String> sectionOptions = [];
                        final Map<String, String> sectionMap = {};
                        if (sectionsState != null && !sectionsState.isLoading) {
                          for (final s in sectionsState.sections) {
                            sectionOptions.add(s.id);
                            sectionMap[s.id] = s.name;
                          }
                        }

                        _showBulkEditDialog(
                          context,
                          state,
                          ayOptions,
                          ayMap,
                          classOptions,
                          classMap,
                          sectionOptions,
                          sectionMap,
                        );
                      },
                      icon: const Icon(Icons.edit_note),
                      label: Text('Edit Selected (${_selectedRowIndices.length})'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPreviewTable(context, state),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 16,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final proceed = await _confirmDiscardEdits(context, state);
                      if (!proceed) return;
                      setState(() {
                        _previewPage = 0;
                        _executionPage = 0;
                        _executionFilter = 'ALL';
                        _previewFilter = 'ALL';
                        _searchQuery = '';
                        _searchController.clear();
                        _selectedRowIndices.clear();
                      });
                      ref.read(bulkImportProvider.notifier).reset();
                    },
                    child: const Text('Reset'),
                  ),
                  Builder(
                    builder: (btnCtx) {
                      final validCount = state.rows.where((r) => r.status == ImportRowStatus.valid || r.status == ImportRowStatus.warning).length;
                      final errorsCount = state.rows.where((r) =>
                          r.status == ImportRowStatus.error ||
                          r.status == ImportRowStatus.duplicate ||
                          r.status == ImportRowStatus.capacityError ||
                          r.status == ImportRowStatus.dependencyError).length;
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        onPressed: (validCount == 0 || (state.selectedType == ImportType.students && (!state.dependenciesReady || state.dependenciesDirty)))
                            ? null
                            : () {
                                 final schoolId = ref.read(selectedSchoolIdProvider)!;
                                 _showImportConfirmation(btnCtx, schoolId, schoolName, state);
                               },
                        child: (state.selectedType == ImportType.students && (!state.dependenciesReady || state.dependenciesDirty))
                            ? const Text('Resolve class and section dependencies first')
                            : (errorsCount > 0
                                ? Text('Import Valid Rows ($validCount)')
                                : const Text('Import Valid Records')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSpecsTable(BuildContext context, ImportType type) {
    final theme = Theme.of(context);
    final columns = _getTemplateFields(type);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        controller: _specsHorizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notif) => notif.depth == 0,
        child: SingleChildScrollView(
          controller: _specsHorizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 800),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(3),
              },
              border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey[300]!)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer),
                  children: const [
                    Padding(padding: EdgeInsets.all(8.0), child: Text('Column Header', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8.0), child: Text('Requirement', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8.0), child: Text('Format / Details', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                ...columns.map((col) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(col.name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          col.isRequired ? 'REQUIRED' : 'OPTIONAL',
                          style: TextStyle(
                            color: col.isRequired ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(col.format, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidationSummary(BuildContext context, BulkImportState state) {
    final theme = Theme.of(context);
    final total = state.rows.length;
    final valid = state.rows.where((r) => r.status == ImportRowStatus.valid || r.status == ImportRowStatus.success).length;
    final warnings = state.rows.where((r) => r.status == ImportRowStatus.warning).length;
    final duplicates = state.rows.where((r) => r.status == ImportRowStatus.duplicate).length;
    final capacityErrors = state.rows.where((r) => r.status == ImportRowStatus.capacityError).length;
    final dependencyErrors = state.rows.where((r) => r.status == ImportRowStatus.dependencyError).length;
    final errors = state.rows.where((r) => r.status == ImportRowStatus.error).length;
    final skipped = state.rows.where((r) => r.status == ImportRowStatus.skipped).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildSummaryChip(context, 'Total Rows', total.toString(), Colors.blue),
              _buildSummaryChip(context, 'Valid', valid.toString(), Colors.green),
              _buildSummaryChip(context, 'Warnings', warnings.toString(), Colors.orange),
              _buildSummaryChip(context, 'Duplicates', duplicates.toString(), Colors.purple),
              _buildSummaryChip(context, 'Capacity Errors', capacityErrors.toString(), Colors.deepOrange),
              _buildSummaryChip(context, 'Dependency Errors', dependencyErrors.toString(), Colors.brown),
              _buildSummaryChip(context, 'Blocking Errors', errors.toString(), Colors.red),
              if (skipped > 0)
                _buildSummaryChip(context, 'Skipped', skipped.toString(), Colors.grey),
            ],
          ),
          if (duplicates > 0) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                ref.read(bulkImportProvider.notifier).skipConflictingRows();
              },
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip Conflicting Rows'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryChip(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable(BuildContext context, BulkImportState state) {
    final theme = Theme.of(context);
    final headers = CsvHelper.getRequiredColumns(state.selectedType);
    final schoolId = ref.read(selectedSchoolIdProvider);

    final academicYearsState = schoolId != null ? ref.watch(academicYearsProvider(schoolId)) : null;
    final classesState = schoolId != null ? ref.watch(classesProvider(schoolId)) : null;
    final sectionsState = schoolId != null ? ref.watch(sectionsProvider(schoolId)) : null;

    final List<String> ayOptions = [];
    final Map<String, String> ayMap = {};
    if (academicYearsState != null && !academicYearsState.isLoading) {
      for (final y in academicYearsState.years) {
        ayOptions.add(y.id);
        ayMap[y.id] = y.name;
      }
    }

    final List<String> classOptions = [];
    final Map<String, String> classMap = {};
    if (classesState != null && !classesState.isLoading) {
      for (final c in classesState.classes) {
        classOptions.add(c.id);
        classMap[c.id] = c.displayName ?? c.name;
      }
    }

    final List<String> sectionOptions = [];
    final Map<String, String> sectionMap = {};
    if (sectionsState != null && !sectionsState.isLoading) {
      for (final s in sectionsState.sections) {
        sectionOptions.add(s.id);
        sectionMap[s.id] = s.name;
      }
    }

    final Map<String, int> incomingCounts = {};
    if (state.selectedType == ImportType.students) {
      for (final r in state.rows) {
        if (r.status != ImportRowStatus.success) {
          final sId = r.data['section_id'];
          if (sId != null && sId.isNotEmpty) {
            incomingCounts[sId] = (incomingCounts[sId] ?? 0) + 1;
          }
        }
      }
    }

    final filteredRows = state.rows.where((row) {
      if (_previewFilter == 'ERRORS' && row.status != ImportRowStatus.error) return false;
      if (_previewFilter == 'WARNINGS' && row.status != ImportRowStatus.warning) return false;
      if (_previewFilter == 'VALID' && row.status != ImportRowStatus.valid) return false;
      if (_previewFilter == 'EDITED' && row.editedFields.isEmpty) return false;

      if (_previewFilter == 'CAPACITY_ERRORS' && schoolId != null && sectionsState != null && !sectionsState.isLoading) {
        final secId = row.data['section_id'];
        if (secId == null || secId.isEmpty) return false;
        
        SectionDto? matchedSec;
        for (final s in sectionsState.sections) {
          if (s.id == secId) {
            matchedSec = s;
            break;
          }
        }
        if (matchedSec == null) return false;
        
        final existing = state.existingSectionCounts[secId] ?? 0;
        final incoming = incomingCounts[secId] ?? 0;
        if (existing + incoming <= matchedSec.capacity) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final firstName = (row.data['first_name'] ?? '').toLowerCase();
        final lastName = (row.data['last_name'] ?? '').toLowerCase();
        final admNo = (row.data['admission_number'] ?? '').toLowerCase();
        final rollNo = (row.data['roll_number'] ?? '').toLowerCase();
        final email = (row.data['email'] ?? '').toLowerCase();

        final match = firstName.contains(query) ||
            lastName.contains(query) ||
            admNo.contains(query) ||
            rollNo.contains(query) ||
            email.contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    final totalRows = filteredRows.length;
    final totalPages = (totalRows / _pageSize).ceil();

    if (_previewPage >= totalPages && totalPages > 0) {
      _previewPage = totalPages - 1;
    }
    if (_previewPage < 0) {
      _previewPage = 0;
    }

    final start = _previewPage * _pageSize;
    final end = (start + _pageSize) < totalRows ? (start + _pageSize) : totalRows;
    final pageRows = filteredRows.sublist(start, end);

    final List<DataColumn> dataColumns = [
      DataColumn(
        label: SizedBox(
          width: 50,
          child: Checkbox(
            value: pageRows.isNotEmpty && pageRows.every((r) => _selectedRowIndices.contains(r.rowIndex)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedRowIndices.addAll(pageRows.map((r) => r.rowIndex));
                } else {
                  _selectedRowIndices.removeAll(pageRows.map((r) => r.rowIndex));
                }
              });
            },
          ),
        ),
      ),
      const DataColumn(label: SizedBox(width: 60, child: Text('Row'))),
      const DataColumn(label: SizedBox(width: 110, child: Text('Status'))),
      const DataColumn(label: SizedBox(width: 250, child: Text('Issues'))),
      ...headers.map((h) => DataColumn(label: SizedBox(width: 160, child: Text(h)))),
    ];

    final headerTable = DataTable(
      headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainer),
      headingRowHeight: 48,
      dataRowHeight: 0.1,
      columnSpacing: 0,
      columns: dataColumns,
      rows: const [],
    );

    final bodyTable = DataTable(
      headingRowHeight: 0.1,
      headingRowColor: WidgetStateProperty.all(Colors.transparent),
      columnSpacing: 0,
      columns: dataColumns,
      rows: pageRows.map((row) {
        Color rowColor = Colors.transparent;
        Widget statusWidget = const Text('');

        if (row.status == ImportRowStatus.error) {
          rowColor = Colors.red.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('ERROR', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.red,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.duplicate) {
          rowColor = Colors.red.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('DUPLICATE', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.capacityError) {
          rowColor = Colors.red.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('CAPACITY ERR', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.deepOrange,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.dependencyError) {
          rowColor = Colors.red.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('DEP ERROR', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.brown,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.skipped) {
          rowColor = Colors.grey.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('SKIPPED', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.grey,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.warning) {
          rowColor = Colors.orange.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('WARNING', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.orange,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.success) {
          rowColor = Colors.green.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('SUCCESS', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.green,
            visualDensity: VisualDensity.compact,
          );
        } else {
          rowColor = Colors.green.withValues(alpha: 0.02);
          statusWidget = const Chip(
            label: Text('VALID', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.green,
            visualDensity: VisualDensity.compact,
          );
        }

        final allIssues = [...row.errors, ...row.warnings];

        return DataRow(
          color: WidgetStateProperty.all(rowColor),
          cells: [
            DataCell(
              SizedBox(
                width: 50,
                child: Checkbox(
                  value: _selectedRowIndices.contains(row.rowIndex),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedRowIndices.add(row.rowIndex);
                      } else {
                        _selectedRowIndices.remove(row.rowIndex);
                      }
                    });
                  },
                ),
              ),
            ),
            DataCell(SizedBox(width: 60, child: Text(row.rowIndex.toString()))),
            DataCell(SizedBox(width: 110, child: statusWidget)),
            DataCell(
              SizedBox(
                width: 250,
                child: allIssues.isEmpty
                    ? const Text('None', style: TextStyle(color: Colors.green, fontSize: 11))
                    : Tooltip(
                        message: allIssues.join('; '),
                        child: Text(
                          allIssues.join('; '),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: TextStyle(
                            color: row.errors.isNotEmpty ? Colors.red : Colors.orange,
                            fontSize: 11,
                          ),
                        ),
                      ),
              ),
            ),
            ...headers.map((h) {
              final columnName = h.toLowerCase();
              final currentValue = row.data[columnName] ?? '';
              final isEdited = row.editedFields.contains(columnName);
              final isCellError = row.errors.any((err) => err.toLowerCase().contains(columnName));
              final originalValue = row.originalData[columnName] ?? '';

              List<String> options = [];
              Map<String, String> nameMap = {};
              if (columnName == 'academic_year_id') {
                options = ayOptions;
                nameMap = ayMap;
              } else if (columnName == 'class_id') {
                options = classOptions;
                nameMap = classMap;
              } else if (columnName == 'section_id') {
                final rowClassId = row.data['class_id'] ?? '';
                final List<String> filteredSecOptions = [];
                if (sectionsState != null && !sectionsState.isLoading) {
                  for (final s in sectionsState.sections) {
                    if (s.classId == rowClassId) {
                      filteredSecOptions.add(s.id);
                    }
                  }
                }
                options = filteredSecOptions;
                nameMap = sectionMap;
              } else if (columnName == 'gender') {
                options = const ['MALE', 'FEMALE', 'OTHER'];
              } else if (columnName == 'blood_group') {
                options = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
              }

              return DataCell(
                SizedBox(
                  width: 160,
                  child: EditableCell(
                    rowIndex: row.rowIndex,
                    columnName: columnName,
                    currentValue: currentValue,
                    isEdited: isEdited,
                    isError: isCellError,
                    originalValue: originalValue,
                    autocompleteOptions: options,
                    idToNameMap: nameMap,
                    onSubmitted: (newVal) {
                      ref.read(bulkImportProvider.notifier).updateCell(row.rowIndex, columnName, newVal);
                    },
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );

    final double calculatedMinWidth = 470.0 + (headers.length * 160.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            controller: _previewHorizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (notif) => notif.depth == 0,
            child: SingleChildScrollView(
              controller: _previewHorizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: calculatedMinWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerTable,
                    Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: Scrollbar(
                        controller: _previewVerticalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        notificationPredicate: (notif) => notif.depth == 0,
                        child: SingleChildScrollView(
                          controller: _previewVerticalController,
                          scrollDirection: Axis.vertical,
                          child: bodyTable,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${totalRows == 0 ? 0 : start + 1} to $end of $totalRows rows',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: _previewPage > 0 ? () => setState(() => _previewPage = 0) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previewPage > 0 ? () => setState(() => _previewPage--) : null,
                  ),
                  Text(
                    'Page ${_previewPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _previewPage < totalPages - 1 ? () => setState(() => _previewPage++) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: _previewPage < totalPages - 1 ? () => setState(() => _previewPage = totalPages - 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, BulkImportState state) {
    final theme = Theme.of(context);
    final percent = state.totalProgress > 0 ? (state.currentProgress / state.totalProgress * 100).toInt() : 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Importing ${state.selectedType.label}...',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: state.totalProgress > 0 ? (state.currentProgress / state.totalProgress) : 0.0,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress: $percent%', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${state.currentProgress} / ${state.totalProgress} records processed'),
              ],
            ),
            const Divider(height: 32),
            if (state.currentItemName != null) ...[
              Text(
                'Current Row: ${state.currentProgress}',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                state.currentItemName!,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressCounter('Successful', state.successCount, Colors.green),
                _buildProgressCounter('Failed', state.failedCount, Colors.red),
                _buildProgressCounter('Skipped', state.skippedCount, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRetryProgressCard(BuildContext context, BulkImportState state) {
    final theme = Theme.of(context);
    final percent = state.retryTotal > 0 ? (state.retryProgress / state.retryTotal * 100).toInt() : 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Retrying Failed Students...',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: state.retryTotal > 0 ? (state.retryProgress / state.retryTotal) : 0.0,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress: $percent%', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${state.retryProgress} / ${state.retryTotal} retried'),
              ],
            ),
            const Divider(height: 32),
            if (state.retryCurrentItemName != null) ...[
              Text(
                'Current Student:',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                state.retryCurrentItemName!,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressCounter('Successful', state.retrySuccessCount, Colors.green),
                _buildProgressCounter('Already Exists', state.retryAlreadyExistsCount, Colors.purple),
                _buildProgressCounter('Still Failed', state.retryStillFailedCount, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionCard(BuildContext context, String schoolName, BulkImportState state) {
    final theme = Theme.of(context);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(
                    state.failedCount == 0 ? Icons.check_circle_outline : Icons.error_outline,
                    size: 64,
                    color: state.failedCount == 0 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Import Completed',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (state.retryTotal > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Retry Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                    const SizedBox(height: 4),
                    Text(
                      'Retried: ${state.retryTotal} | Successfully Created: ${state.retrySuccessCount} | Already Exists: ${state.retryAlreadyExistsCount} | Still Failed: ${state.retryStillFailedCount}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 32),
            _buildCompletionRow('Total CSV Rows', state.rows.length.toString()),
            _buildCompletionRow('Successfully Imported', state.totalSuccessCount.toString(), color: Colors.green),
            _buildCompletionRow('Validation Skipped', state.validationErrorCount.toString(), color: Colors.orange),
            _buildCompletionRow('Already Exists', state.alreadyExistsCount.toString(), color: Colors.purple),
            _buildCompletionRow('Network Failures', state.networkErrorCount.toString(), color: Colors.blue),
            _buildCompletionRow('API Failures', state.apiErrorCount.toString(), color: Colors.red),
            if (state.globalErrorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stopped early: ${state.globalErrorMessage!}',
                        style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 32),
            Text('Execution Logs & Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDetailedExecutionLogsPanel(context, state),
            _buildExecutionDetailsTable(context, state),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (state.networkErrorCount > 0) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (schoolId != null) {
                        ref.read(bulkImportProvider.notifier).retryNetworkFailures(schoolId);
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text('Retry Network Failures (${state.networkErrorCount})'),
                  ),
                  const SizedBox(width: 12),
                ],
                if (state.skippedCount > 0) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      final skippedRows = state.rows.where((r) => r.status == ImportRowStatus.skipped || r.status == ImportRowStatus.error).toList();
                      final errorHeaders = [
                        'row_number',
                        'first_name',
                        'last_name',
                        'admission_number',
                        'roll_number',
                        'academic_year_id',
                        'class_id',
                        'section_id',
                        'status',
                        'error_message',
                      ];
                      final List<String> csvLines = [];
                      csvLines.add(errorHeaders.map((h) => '"$h"').join(','));
                      for (final row in skippedRows) {
                        final errMsg = [...row.errors, ...row.warnings].join('; ');
                        final line = [
                          row.rowIndex.toString(),
                          row.data['first_name'] ?? '',
                          row.data['last_name'] ?? '',
                          row.data['admission_number'] ?? '',
                          row.data['roll_number'] ?? '',
                          row.data['academic_year_id'] ?? '',
                          row.data['class_id'] ?? '',
                          row.data['section_id'] ?? '',
                          'SKIPPED',
                          errMsg,
                        ].map((val) => '"${val.replaceAll('"', '""')}"').join(',');
                        csvLines.add(line);
                      }
                      final csvContent = csvLines.join('\n');
                      downloadCsvFile('error_report_${state.fileName ?? "import.csv"}', csvContent);
                    },
                    icon: const Icon(Icons.download_for_offline),
                    label: const Text('Download Error Report'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ref.read(bulkImportProvider.notifier).resumeEditing();
                    },
                    child: Text('Resolve ${state.skippedCount} Errors'),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: () => ref.read(bulkImportProvider.notifier).reset(),
                  child: const Text('Start Another Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: color != null ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionDetailsTable(BuildContext context, BulkImportState state) {
    final theme = Theme.of(context);
    final allRows = state.rows;
    final successes = allRows.where((r) => r.status == ImportRowStatus.success).toList();
    final networkErrors = allRows.where((r) => r.status == ImportRowStatus.networkError).toList();
    final alreadyExists = allRows.where((r) => r.status == ImportRowStatus.alreadyExists).toList();
    final apiErrors = allRows.where((r) => r.status == ImportRowStatus.apiError || r.status == ImportRowStatus.failed).toList();
    final skips = allRows.where((r) => r.status == ImportRowStatus.skipped || r.status == ImportRowStatus.validationError || r.status == ImportRowStatus.error).toList();

    final List<ParsedRow> filteredRows;
    if (_executionFilter == 'SUCCESS') {
      filteredRows = successes;
    } else if (_executionFilter == 'NETWORK') {
      filteredRows = networkErrors;
    } else if (_executionFilter == 'ALREADY_EXISTS') {
      filteredRows = alreadyExists;
    } else if (_executionFilter == 'API_ERROR' || _executionFilter == 'FAILED') {
      filteredRows = apiErrors;
    } else if (_executionFilter == 'SKIPPED') {
      filteredRows = skips;
    } else {
      filteredRows = allRows;
    }

    final totalRows = filteredRows.length;
    final totalPages = (totalRows / _pageSize).ceil();
    if (_executionPage >= totalPages && totalPages > 0) {
      _executionPage = totalPages - 1;
    }
    if (_executionPage < 0) {
      _executionPage = 0;
    }

    final start = _executionPage * _pageSize;
    final end = (start + _pageSize) < totalRows ? (start + _pageSize) : totalRows;
    final pageRows = filteredRows.sublist(start, end);

    final List<DataColumn> resultColumns = [
      const DataColumn(label: SizedBox(width: 60, child: Text('Row'))),
      const DataColumn(label: SizedBox(width: 120, child: Text('Status'))),
      const DataColumn(label: SizedBox(width: 200, child: Text('Entity / Name'))),
      const DataColumn(label: SizedBox(width: 430, child: Text('API Error / Message'))),
    ];

    final headerTable = DataTable(
      headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainer),
      headingRowHeight: 48,
      dataRowHeight: 0.1,
      columnSpacing: 0,
      columns: resultColumns,
      rows: const [],
    );

    final bodyTable = DataTable(
      headingRowHeight: 0.1,
      headingRowColor: WidgetStateProperty.all(Colors.transparent),
      columnSpacing: 0,
      columns: resultColumns,
      rows: pageRows.map((row) {
        Color rowColor = Colors.transparent;
        Widget statusWidget = const Text('');

        if (row.status == ImportRowStatus.success) {
          rowColor = Colors.green.withValues(alpha: 0.02);
          statusWidget = const Chip(
            label: Text('SUCCESS', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.green,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.networkError) {
          rowColor = Colors.blue.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('NETWORK ERROR', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.blue,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.alreadyExists) {
          rowColor = Colors.purple.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('ALREADY EXISTS', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.purple,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.apiError || row.status == ImportRowStatus.failed) {
          rowColor = Colors.red.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('API ERROR', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.red,
            visualDensity: VisualDensity.compact,
          );
        } else if (row.status == ImportRowStatus.skipped || row.status == ImportRowStatus.validationError) {
          rowColor = Colors.grey.withValues(alpha: 0.05);
          statusWidget = const Chip(
            label: Text('SKIPPED', style: TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.grey,
            visualDensity: VisualDensity.compact,
          );
        }

        final errorMsg = row.apiErrorMessage ?? '—';

        return DataRow(
          color: WidgetStateProperty.all(rowColor),
          cells: [
            DataCell(SizedBox(width: 60, child: Text(row.rowIndex.toString()))),
            DataCell(SizedBox(width: 120, child: statusWidget)),
            DataCell(SizedBox(width: 200, child: Text(_resolveRowName(row, state.selectedType), overflow: TextOverflow.ellipsis))),
            DataCell(
              SizedBox(
                width: 430,
                child: Tooltip(
                  message: errorMsg,
                  child: Text(
                    errorMsg,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      color: (row.status == ImportRowStatus.failed || row.status == ImportRowStatus.apiError)
                          ? Colors.red
                          : (row.status == ImportRowStatus.networkError ? Colors.blue[800] : Colors.grey[700]),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('All (${allRows.length})'),
                selected: _executionFilter == 'ALL',
                onSelected: (_) => setState(() {
                  _executionFilter = 'ALL';
                  _executionPage = 0;
                }),
              ),
              ChoiceChip(
                label: Text('Success (${successes.length})'),
                selected: _executionFilter == 'SUCCESS',
                onSelected: (_) => setState(() {
                  _executionFilter = 'SUCCESS';
                  _executionPage = 0;
                }),
              ),
              if (networkErrors.isNotEmpty)
                ChoiceChip(
                  label: Text('Network Failures (${networkErrors.length})'),
                  selected: _executionFilter == 'NETWORK',
                  onSelected: (_) => setState(() {
                    _executionFilter = 'NETWORK';
                    _executionPage = 0;
                  }),
                ),
              if (alreadyExists.isNotEmpty)
                ChoiceChip(
                  label: Text('Already Exists (${alreadyExists.length})'),
                  selected: _executionFilter == 'ALREADY_EXISTS',
                  onSelected: (_) => setState(() {
                    _executionFilter = 'ALREADY_EXISTS';
                    _executionPage = 0;
                  }),
                ),
              ChoiceChip(
                label: Text('API Errors (${apiErrors.length})'),
                selected: _executionFilter == 'API_ERROR' || _executionFilter == 'FAILED',
                onSelected: (_) => setState(() {
                  _executionFilter = 'API_ERROR';
                  _executionPage = 0;
                }),
              ),
              ChoiceChip(
                label: Text('Skipped (${skips.length})'),
                selected: _executionFilter == 'SKIPPED',
                onSelected: (_) => setState(() {
                  _executionFilter = 'SKIPPED';
                  _executionPage = 0;
                }),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            controller: _executionHorizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (notif) => notif.depth == 0,
            child: SingleChildScrollView(
              controller: _executionHorizontalController,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headerTable,
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: Scrollbar(
                      controller: _executionVerticalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 0,
                      child: SingleChildScrollView(
                        controller: _executionVerticalController,
                        scrollDirection: Axis.vertical,
                        child: bodyTable,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${totalRows == 0 ? 0 : start + 1} to $end of $totalRows rows',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: _executionPage > 0 ? () => setState(() => _executionPage = 0) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _executionPage > 0 ? () => setState(() => _executionPage--) : null,
                  ),
                  Text(
                    'Page ${_executionPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _executionPage < totalPages - 1 ? () => setState(() => _executionPage++) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: _executionPage < totalPages - 1 ? () => setState(() => _executionPage = totalPages - 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _resolveRowName(ParsedRow row, ImportType type) {
    if (type == ImportType.students || type == ImportType.guardians) {
      final first = row.data['first_name'] ?? '';
      final last = row.data['last_name'] ?? '';
      return '$first $last'.trim();
    } else if (type == ImportType.classes || type == ImportType.sections) {
      return row.data['name'] ?? 'Row ${row.rowIndex}';
    } else {
      return row.data['subject_name'] ?? 'Row ${row.rowIndex}';
    }
  }

  List<_TemplateField> _getTemplateFields(ImportType type) {
    switch (type) {
      case ImportType.students:
        return const [
          _TemplateField('academic_year_id', true, 'Active Academic Year UUID'),
          _TemplateField('first_name', true, 'Text (e.g. Rahul)'),
          _TemplateField('last_name', true, 'Text (e.g. Sharma)'),
          _TemplateField('gender', true, 'MALE, FEMALE, or OTHER'),
          _TemplateField('date_of_birth', true, 'YYYY-MM-DD (e.g. 2014-05-12)'),
          _TemplateField('admission_number', true, 'Unique key (e.g. ADM101)'),
          _TemplateField('admission_date', true, 'YYYY-MM-DD'),
          _TemplateField('roll_number', true, 'Student roll ID'),
          _TemplateField('email', false, 'Email address'),
          _TemplateField('phone', false, 'Phone/Mobile contact'),
          _TemplateField('father_name', false, 'Father\'s Name'),
          _TemplateField('mother_name', false, 'Mother\'s Name'),
          _TemplateField('address', false, 'Residential Address'),
          _TemplateField('class_name', false, 'Class Name (e.g. Class 8) - Optional if class_id supplied'),
          _TemplateField('class_code', false, 'Class Code (e.g. CLASS_8) - Optional if class_id supplied'),
          _TemplateField('section_name', false, 'Section Name (e.g. Section A) - Optional if section_id supplied'),
          _TemplateField('section_code', false, 'Section Code (e.g. SEC_A) - Optional if section_id supplied'),
          _TemplateField('status', false, 'ACTIVE, INACTIVE, etc.'),
        ];
      case ImportType.guardians:
        return const [
          _TemplateField('guardian_type', true, 'FATHER, MOTHER, LEGAL_GUARDIAN, GRANDPARENT, UNCLE, AUNT, or OTHER'),
          _TemplateField('first_name', true, 'Text'),
          _TemplateField('middle_name', false, 'Text'),
          _TemplateField('last_name', true, 'Text'),
          _TemplateField('gender', true, 'MALE, FEMALE, or OTHER'),
          _TemplateField('date_of_birth', true, 'YYYY-MM-DD'),
          _TemplateField('aadhaar_number', false, '12-digit number'),
          _TemplateField('pan_number', false, '10-digit PAN format (e.g. ABCDE1234F)'),
          _TemplateField('occupation', false, 'Text description'),
          _TemplateField('qualification', false, 'Text description'),
          _TemplateField('organization', false, 'Text'),
          _TemplateField('annual_income', false, 'Decimal value (e.g. 450000.0)'),
          _TemplateField('mobile', true, 'Contact number'),
          _TemplateField('alternate_mobile', false, 'Contact number'),
          _TemplateField('email', false, 'Email address'),
        ];
      case ImportType.classes:
        return const [
          _TemplateField('name', true, 'Text (e.g. Class 8, Grade 1)'),
          _TemplateField('display_name', false, 'Optional alternative title'),
          _TemplateField('code', true, 'Upper alphanumeric/underscores (e.g. CLASS_8)'),
          _TemplateField('level', true, 'Integer level index (e.g. 8)'),
          _TemplateField('category', false, 'PRE_PRIMARY, PRIMARY, MIDDLE, HIGH (Default: PRIMARY)'),
          _TemplateField('stream', false, 'Science, Commerce, Arts'),
          _TemplateField('description', false, 'Paragraph text'),
          _TemplateField('capacity', true, 'Positive integer capacity limit (e.g. 40)'),
          _TemplateField('promotion_order', false, 'Optional level integer'),
          _TemplateField('next_class_id', false, 'Direct next Class UUID'),
          _TemplateField('academic_year_id', true, 'Academic Year UUID'),
        ];
      case ImportType.sections:
        return const [
          _TemplateField('name', true, 'Text (e.g. Section A, Lotus)'),
          _TemplateField('code', true, 'Upper alphanumeric/underscores (e.g. SEC_A)'),
          _TemplateField('capacity', true, 'Positive integer capacity limit (e.g. 40)'),
          _TemplateField('room_number', false, 'Room string identifier'),
          _TemplateField('sort_order', false, 'Positive integer weight index'),
          _TemplateField('description', false, 'Paragraph text'),
          _TemplateField('class_id', true, 'Target Class UUID'),
          _TemplateField('academic_year_id', true, 'Academic Year UUID'),
        ];
      case ImportType.subjects:
        return const [
          _TemplateField('subject_code', true, 'Upper alphanumeric (e.g. SUB_MATH)'),
          _TemplateField('subject_name', true, 'Text (e.g. Mathematics)'),
          _TemplateField('short_name', false, 'Text abbreviation'),
          _TemplateField('category', true, 'CORE, ELECTIVE, LANGUAGE, OPTIONAL, LAB, SPORTS, ARTS, or CO_CURRICULAR'),
          _TemplateField('subject_type', true, 'THEORY, PRACTICAL, or THEORY_PRACTICAL'),
          _TemplateField('description', false, 'Text description'),
          _TemplateField('credit_hours', false, 'Non-negative integer'),
          _TemplateField('weekly_periods', false, 'Non-negative integer'),
          _TemplateField('theory_marks', false, 'Non-negative integer (Default: 0)'),
          _TemplateField('practical_marks', false, 'Non-negative integer (Default: 0)'),
          _TemplateField('pass_marks', false, 'Non-negative integer (Default: 0)'),
          _TemplateField('display_color', false, 'Hex code (e.g. #FF5733)'),
          _TemplateField('display_order', false, 'Integer index'),
          _TemplateField('academic_year_id', true, 'Academic Year UUID'),
        ];
    }
  }

  void _showBulkEditDialog(
    BuildContext context,
    BulkImportState state,
    List<String> ayOpts,
    Map<String, String> ayMap,
    List<String> classOpts,
    Map<String, String> classMap,
    List<String> sectionOpts,
    Map<String, String> sectionMap,
  ) {
    String? selectedAy;
    String? selectedClass;
    String? selectedSection;

    bool applyAy = false;
    bool applyClass = false;
    bool applySection = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Text('Bulk Edit Selected Rows (${_selectedRowIndices.length} rows)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select the fields you want to update for all selected rows:'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Update Academic Year'),
                  value: applyAy,
                  onChanged: (val) => setDlgState(() => applyAy = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (applyAy)
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0, bottom: 12.0),
                    child: DropdownButtonFormField<String>(
                      value: selectedAy,
                      items: ayOpts.map((opt) => DropdownMenuItem(value: opt, child: Text(ayMap[opt] ?? opt))).toList(),
                      onChanged: (val) => setDlgState(() => selectedAy = val),
                      decoration: const InputDecoration(labelText: 'Academic Year', isDense: true),
                    ),
                  ),
                CheckboxListTile(
                  title: const Text('Update Class'),
                  value: applyClass,
                  onChanged: (val) => setDlgState(() => applyClass = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (applyClass)
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0, bottom: 12.0),
                    child: DropdownButtonFormField<String>(
                      value: selectedClass,
                      items: classOpts.map((opt) => DropdownMenuItem(value: opt, child: Text(classMap[opt] ?? opt))).toList(),
                      onChanged: (val) => setDlgState(() => selectedClass = val),
                      decoration: const InputDecoration(labelText: 'Class', isDense: true),
                    ),
                  ),
                CheckboxListTile(
                  title: const Text('Update Section'),
                  value: applySection,
                  onChanged: (val) => setDlgState(() => applySection = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (applySection)
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0, bottom: 12.0),
                    child: DropdownButtonFormField<String>(
                      value: selectedSection,
                      items: sectionOpts.map((opt) => DropdownMenuItem(value: opt, child: Text(sectionMap[opt] ?? opt))).toList(),
                      onChanged: (val) => setDlgState(() => selectedSection = val),
                      decoration: const InputDecoration(labelText: 'Section', isDense: true),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (!applyAy && !applyClass && !applySection)
                    ? null
                    : () {
                        Navigator.pop(dialogCtx);
                        final notifier = ref.read(bulkImportProvider.notifier);
                        final rowsToEdit = _selectedRowIndices.toList();
                        setState(() {
                          _selectedRowIndices.clear();
                        });

                        if (applyAy && selectedAy != null) {
                          notifier.updateSelectedRows(rowsToEdit, 'academic_year_id', selectedAy!);
                        }
                        if (applyClass && selectedClass != null) {
                          notifier.updateSelectedRows(rowsToEdit, 'class_id', selectedClass!);
                        }
                        if (applySection && selectedSection != null) {
                          notifier.updateSelectedRows(rowsToEdit, 'section_id', selectedSection!);
                        }
                      },
                child: const Text('Apply Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionCapacityPanel(
    BuildContext context,
    BulkImportState state,
    List<SectionDto> sections,
    Map<String, int> incomingCounts,
  ) {
    final theme = Theme.of(context);
    if (sections.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(top: 16, bottom: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Section Capacity Status',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Capacity could not be verified from the available section data.',
                style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Section Capacity Status',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Scrollbar(
                controller: _capacityScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _capacityScrollController,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.5), // Section
                      1: FlexColumnWidth(1.2), // Existing Students
                      2: FlexColumnWidth(1.2), // Configured Capacity
                      3: FlexColumnWidth(1.2), // Available Seats
                      4: FlexColumnWidth(1.2), // Incoming CSV Students
                      5: FlexColumnWidth(1.2), // Projected Total
                      6: FlexColumnWidth(1.2), // Overflow
                      7: FlexColumnWidth(1.2), // Status
                    },
                    border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey[200]!)),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey[100]),
                        children: const [
                          Padding(padding: EdgeInsets.all(8), child: Text('Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Existing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Incoming', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Projected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Overflow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      ...sections.map((sec) {
                        final existing = state.existingSectionCounts[sec.id] ?? 0;
                        final incoming = incomingCounts[sec.id] ?? 0;
                        final capacity = sec.capacity;
                        final projected = existing + incoming;
                        final available = capacity - existing > 0 ? capacity - existing : 0;
                        final overflow = projected > capacity ? projected - capacity : 0;
                        final isExceeded = projected > capacity;

                        final parentClass = state.cachedClasses.firstWhere(
                          (c) => c.id == sec.classId,
                          orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: '', code: '', level: 1, category: '', capacity: 40, status: '', isActive: true, version: 1),
                        );
                        final displayName = parentClass.id.isNotEmpty
                            ? '${parentClass.name} / ${sec.name}'
                            : sec.name;

                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(existing.toString(), style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(capacity.toString(), style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(available.toString(), style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(incoming.toString(), style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(projected.toString(), style: TextStyle(fontSize: 12, color: isExceeded ? Colors.red : Colors.black))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(overflow.toString(), style: TextStyle(fontSize: 12, color: overflow > 0 ? Colors.red : Colors.black, fontWeight: overflow > 0 ? FontWeight.bold : FontWeight.normal))),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Icon(
                                    isExceeded ? Icons.error : Icons.check_circle,
                                    color: isExceeded ? Colors.red : Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isExceeded ? 'ERROR' : 'VALID',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isExceeded ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDependencyPreviewPanel(BuildContext context, BulkImportState state) {
    final theme = Theme.of(context);
    if (state.selectedType != ImportType.students || state.rows.isEmpty) return const SizedBox.shrink();

    final schoolId = ref.read(selectedSchoolIdProvider);
    final academicYearsState = schoolId != null
        ? ref.watch(academicYearsProvider(schoolId))
        : null;

    final String ayIdFromCsv = state.rows.firstWhere(
      (r) => r.data['academic_year_id'] != null && r.data['academic_year_id']!.trim().isNotEmpty,
      orElse: () => ParsedRow(rowIndex: 0, data: {}, errors: [], warnings: [], status: ImportRowStatus.valid),
    ).data['academic_year_id'] ?? '';

    String academicYearDisplay = 'N/A';
    if (ayIdFromCsv.isNotEmpty) {
      if (academicYearsState == null || academicYearsState.isLoading) {
        academicYearDisplay = 'Loading ($ayIdFromCsv)...';
      } else {
        final match = academicYearsState.years.firstWhere(
          (y) => y.id == ayIdFromCsv,
          orElse: () => const AcademicYearDto(id: '', tenantId: '', schoolId: '', name: '', code: '', startDate: '', endDate: '', status: '', isCurrent: false, version: 1),
        );
        if (match.id.isNotEmpty) {
          academicYearDisplay = match.name;
        } else {
          academicYearDisplay = 'Academic Year dependency error: Academic year UUID "$ayIdFromCsv" not found in school years.';
        }
      }
    }

    final bool hasDependencyHeaders = state.headers.any((k) =>
        k == 'class_id' ||
        k == 'class_name' ||
        k == 'class_code' ||
        k == 'section_id' ||
        k == 'section_name' ||
        k == 'section_code');

    String dependencyStateText = 'Analyzing Dependencies...';
    Color dependencyStateColor = Colors.orange;
    if (state.dependenciesPreparing) {
      dependencyStateText = 'Analyzing Dependencies...';
      dependencyStateColor = Colors.orange;
    } else if (state.dependencyError != null) {
      dependencyStateText = 'Dependency Error';
      dependencyStateColor = Colors.red;
    } else if (!hasDependencyHeaders) {
      dependencyStateText = 'No Dependencies Detected';
      dependencyStateColor = Colors.grey;
    } else if (!state.dependenciesReady || state.dependenciesDirty) {
      dependencyStateText = 'Dependencies Need Preparation';
      dependencyStateColor = Colors.amber[800]!;
    } else {
      dependencyStateText = 'Dependencies Ready';
      dependencyStateColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Dependencies',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Academic Year: $academicYearDisplay', style: TextStyle(fontWeight: FontWeight.w600, color: academicYearDisplay.contains('dependency error') ? Colors.red : null)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDependencySummaryCard(
                    title: 'Classes',
                    total: state.dependencyTotalClasses,
                    existing: state.dependencyExistingClasses,
                    newCount: state.dependencyNewClasses,
                    items: _buildClassDependencyItems(state),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDependencySummaryCard(
                    title: 'Sections',
                    total: state.dependencyTotalSections,
                    existing: state.dependencyExistingSections,
                    newCount: state.dependencyNewSections,
                    items: _buildSectionDependencyItems(state),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Students to Import: ${state.rows.length}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    if (!state.dependenciesReady || state.dependenciesDirty) ...[
                      Text(dependencyStateText, style: TextStyle(color: dependencyStateColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: state.dependenciesPreparing ? null : () => _showPrepareDependenciesConfirmation(context, state),
                        icon: state.dependenciesPreparing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.build),
                        label: Text(state.dependenciesPreparing ? 'Preparing Dependencies...' : 'Prepare Dependencies'),
                      ),
                    ] else ...[
                      Icon(Icons.check_circle, color: dependencyStateColor),
                      const SizedBox(width: 6),
                      Text(dependencyStateText, style: TextStyle(color: dependencyStateColor, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
            if (state.dependencyError != null) ...[
              const SizedBox(height: 8),
              Text(state.dependencyError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDependencySummaryCard({
    required String title,
    required int total,
    required int existing,
    required int newCount,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title ($total total, $existing existing, $newCount new)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: items,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildClassDependencyItems(BulkImportState state) {
    final schoolId = ref.read(selectedSchoolIdProvider);
    final csvClasses = <String, Map<String, String>>{};
    for (final r in state.rows) {
      final ayId = r.data['academic_year_id'] ?? '';
      final className = r.data['class_name'] ?? '';
      final classCode = r.data['class_code'] ?? '';
      final classId = r.data['class_id'] ?? '';
      if (classId.isEmpty && (classCode.isNotEmpty || className.isNotEmpty)) {
        final codeOrName = classCode.isNotEmpty ? classCode : className;
        csvClasses['$ayId|$codeOrName'] = {
          'name': className.isNotEmpty ? className : classCode,
          'code': classCode.isNotEmpty ? classCode : className,
          'ayId': ayId,
        };
      }
    }

    return csvClasses.entries.map((entry) {
      final val = entry.value;
      final ayId = val['ayId']!;
      final code = val['code']!;
      final name = val['name']!;
      final lookupKey = '$schoolId|$ayId|${code.isNotEmpty ? code : name}';

      final resolvedId = state.resolvedClassIds[lookupKey];
      
      IconData icon = Icons.add;
      Color color = Colors.blue;
      String label = 'Will be created';
      if (resolvedId != null && resolvedId.isNotEmpty) {
        icon = Icons.check_circle_outline;
        color = Colors.green;
        label = 'Existing/Resolved';
      } else if (state.dependencyError != null) {
        icon = Icons.error_outline;
        color = Colors.red;
        label = 'Failed';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text('$name ($code)', style: const TextStyle(fontSize: 12))),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildSectionDependencyItems(BulkImportState state) {
    final schoolId = ref.read(selectedSchoolIdProvider);
    final csvSections = <String, Map<String, String>>{};
    for (final r in state.rows) {
      final ayId = r.data['academic_year_id'] ?? '';
      final classId = r.data['class_id'] ?? '';
      final className = r.data['class_name'] ?? '';
      final classCode = r.data['class_code'] ?? '';
      final sectionName = r.data['section_name'] ?? '';
      final sectionCode = r.data['section_code'] ?? '';
      final sectionId = r.data['section_id'] ?? '';

      if (sectionId.isEmpty && (sectionCode.isNotEmpty || sectionName.isNotEmpty)) {
        final classRef = classId.isNotEmpty ? classId : (classCode.isNotEmpty ? classCode : className);
        final codeOrName = sectionCode.isNotEmpty ? sectionCode : sectionName;
        csvSections['$ayId|$classRef|$codeOrName'] = {
          'class_ref': classRef,
          'name': sectionName.isNotEmpty ? sectionName : sectionCode,
          'code': sectionCode.isNotEmpty ? sectionCode : sectionName,
          'ayId': ayId,
        };
      }
    }

    final RegExp uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

    return csvSections.entries.map((entry) {
      final val = entry.value;
      final ayId = val['ayId']!;
      final classRef = val['class_ref']!;
      final code = val['code']!;
      final name = val['name']!;

      // Try resolving classId
      String parentClassId = classRef;
      if (!uuidRegex.hasMatch(classRef)) {
        parentClassId = state.resolvedClassIds['$schoolId|$ayId|$classRef'] ?? '';
      }

      final lookupKey = '$schoolId|$ayId|$parentClassId|${code.isNotEmpty ? code : name}';
      final resolvedId = state.resolvedSectionIds[lookupKey];

      IconData icon = Icons.add;
      Color color = Colors.blue;
      String label = 'Will be created';
      if (resolvedId != null && resolvedId.isNotEmpty) {
        icon = Icons.check_circle_outline;
        color = Colors.green;
        label = 'Existing/Resolved';
      } else if (state.dependencyError != null) {
        icon = Icons.error_outline;
        color = Colors.red;
        label = 'Failed';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text('$classRef / $name', style: const TextStyle(fontSize: 12))),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _showPrepareDependenciesConfirmation(BuildContext context, BulkImportState state) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final schoolsState = ref.read(schoolsListProvider);
    final schoolName = schoolsState.schools.firstWhere(
      (s) => s.id == schoolId,
      orElse: () => const SchoolDto(
        id: '',
        tenantId: '',
        name: 'Selected Campus',
        code: '',
        board: '',
        schoolType: '',
        email: '',
        isActive: true,
        status: 'ACTIVE',
        version: 1,
      ),
    ).name;

    final classCapController = TextEditingController(text: '40');
    final classLvlController = TextEditingController(text: '1');
    final secCapController = TextEditingController(text: '40');

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prepare Dependencies?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.dependencyNewClasses} new classes and ${state.dependencyNewSections} new sections will be created for $schoolName.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: classCapController,
                decoration: const InputDecoration(
                  labelText: 'Default New Class Capacity',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  final parsed = int.tryParse(val ?? '');
                  if (parsed == null || parsed < 1) return 'Must be a positive integer';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: classLvlController,
                decoration: const InputDecoration(
                  labelText: 'Default New Class Level',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  final parsed = int.tryParse(val ?? '');
                  if (parsed == null || parsed < 0) return 'Must be a non-negative integer';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: secCapController,
                decoration: const InputDecoration(
                  labelText: 'Default New Section Capacity',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  final parsed = int.tryParse(val ?? '');
                  if (parsed == null || parsed < 1) return 'Must be a positive integer';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final classCap = int.parse(classCapController.text);
                final classLvl = int.parse(classLvlController.text);
                final secCap = int.parse(secCapController.text);

                Navigator.pop(context);
                
                await ref.read(bulkImportProvider.notifier).prepareDependencies(classCap, classLvl, secCap);
              }
            },
            child: const Text('Prepare Dependencies'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedExecutionLogsPanel(BuildContext context, BulkImportState state) {
    final List<Widget> logItems = [];

    final schoolId = ref.read(selectedSchoolIdProvider);

    // 1. Classes logs
    final csvClasses = <String, Map<String, String>>{};
    for (final r in state.rows) {
      final ayId = r.data['academic_year_id'] ?? '';
      final className = r.data['class_name'] ?? '';
      final classCode = r.data['class_code'] ?? '';
      final classId = r.data['class_id'] ?? '';
      if (classId.isEmpty && (classCode.isNotEmpty || className.isNotEmpty)) {
        final codeOrName = classCode.isNotEmpty ? classCode : className;
        csvClasses['$ayId|$codeOrName'] = {
          'name': className.isNotEmpty ? className : classCode,
          'code': classCode.isNotEmpty ? classCode : className,
          'ayId': ayId,
        };
      }
    }

    for (final entry in csvClasses.entries) {
      final val = entry.value;
      final ayId = val['ayId']!;
      final code = val['code']!;
      final name = val['name']!;
      final lookupKey = '$schoolId|$ayId|${code.isNotEmpty ? code : name}';
      final resolvedId = state.resolvedClassIds[lookupKey];

      if (resolvedId != null && resolvedId.isNotEmpty) {
        final isCreated = state.createdClassIds.contains(resolvedId);
        if (isCreated) {
          logItems.add(
            _buildTerminalLogLine('CLASS CREATED', '$name\nCode: $code', Colors.blue),
          );
        } else {
          logItems.add(
            _buildTerminalLogLine('CLASS RESOLVED', '$name\nExisting record reused', Colors.green),
          );
        }
      }
    }

    // 2. Sections logs
    final csvSections = <String, Map<String, String>>{};
    for (final r in state.rows) {
      final ayId = r.data['academic_year_id'] ?? '';
      final classId = r.data['class_id'] ?? '';
      final className = r.data['class_name'] ?? '';
      final classCode = r.data['class_code'] ?? '';
      final sectionName = r.data['section_name'] ?? '';
      final sectionCode = r.data['section_code'] ?? '';
      final sectionId = r.data['section_id'] ?? '';

      if (sectionId.isEmpty && (sectionCode.isNotEmpty || sectionName.isNotEmpty)) {
        final classRef = classId.isNotEmpty ? classId : (classCode.isNotEmpty ? classCode : className);
        final codeOrName = sectionCode.isNotEmpty ? sectionCode : sectionName;
        csvSections['$ayId|$classRef|$codeOrName'] = {
          'class_ref': classRef,
          'name': sectionName.isNotEmpty ? sectionName : sectionCode,
          'code': sectionCode.isNotEmpty ? sectionCode : sectionName,
          'ayId': ayId,
        };
      }
    }

    for (final entry in csvSections.entries) {
      final val = entry.value;
      final ayId = val['ayId']!;
      final classRef = val['class_ref']!;
      final code = val['code']!;
      final name = val['name']!;

      String parentClassId = classRef;
      final RegExp uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (!uuidRegex.hasMatch(classRef)) {
        parentClassId = state.resolvedClassIds['$schoolId|$ayId|$classRef'] ?? '';
      }

      final lookupKey = '$schoolId|$ayId|$parentClassId|${code.isNotEmpty ? code : name}';
      final resolvedId = state.resolvedSectionIds[lookupKey];

      if (resolvedId != null && resolvedId.isNotEmpty) {
        final isCreated = state.createdSectionIds.contains(resolvedId);
        if (isCreated) {
          logItems.add(
            _buildTerminalLogLine('SECTION CREATED', '$classRef / $name\nCode: $code', Colors.blue),
          );
        } else {
          logItems.add(
            _buildTerminalLogLine('SECTION RESOLVED', '$classRef / $name\nExisting record reused', Colors.green),
          );
        }
      }
    }

    // 3. Students logs
    for (final row in state.rows) {
      final firstName = row.data['first_name'] ?? '';
      final lastName = row.data['last_name'] ?? '';
      final name = '$firstName $lastName'.trim();
      final className = row.data['class_name'] ?? row.data['class_id'] ?? '';
      final sectionName = row.data['section_name'] ?? row.data['section_id'] ?? '';

      if (row.status == ImportRowStatus.success) {
        logItems.add(
          _buildTerminalLogLine('STUDENT CREATED', '$name\nClass $className / Section $sectionName', Colors.cyan),
        );
      } else if (row.status == ImportRowStatus.skipped) {
        final reason = [...row.errors, ...row.warnings].join('; ');
        logItems.add(
          _buildTerminalLogLine('STUDENT SKIPPED', '$name\nReason: ${reason.isNotEmpty ? reason : "Duplicate roll number"}', Colors.orange),
        );
      } else if (row.status == ImportRowStatus.failed) {
        logItems.add(
          _buildTerminalLogLine('STUDENT FAILED', '$name\n${row.apiErrorMessage ?? "HTTP 400\nActual backend error"}', Colors.red),
        );
      }
    }

    if (state.selectedType == ImportType.students && state.rows.isNotEmpty && (state.isUploading || state.isCompleted || state.successCount > 0 || state.failedCount > 0)) {
      final totalRows = state.rows.length;
      final uniqueAy = state.rows.map((r) => r.data['academic_year_id'] ?? '').where((id) => id.isNotEmpty).toSet().length;

      final csvClassesDebug = <String, Map<String, String>>{};
      final csvSectionsDebug = <String, Map<String, String>>{};
      final RegExp uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

      for (final r in state.rows) {
        final ayId = r.data['academic_year_id'] ?? '';
        if (ayId.isEmpty) continue;

        final classId = (r.data['class_id'] ?? '').trim();
        final className = (r.data['class_name'] ?? '').trim();
        final classCode = (r.data['class_code'] ?? '').trim();

        final sectionId = (r.data['section_id'] ?? '').trim();
        final sectionName = (r.data['section_name'] ?? '').trim();
        final sectionCode = (r.data['section_code'] ?? '').trim();

        String classRef = '';
        if (classId.isNotEmpty) {
          classRef = classId.toLowerCase();
        } else if (classCode.isNotEmpty || className.isNotEmpty) {
          classRef = (classCode.isNotEmpty ? classCode : className).trim().toLowerCase();
        }

        if (classRef.isNotEmpty) {
          final classKey = '$ayId|$classRef';
          if (!csvClassesDebug.containsKey(classKey)) {
            csvClassesDebug[classKey] = {};
          }

          String secRef = '';
          if (sectionId.isNotEmpty) {
            secRef = sectionId.toLowerCase();
          } else if (sectionCode.isNotEmpty || sectionName.isNotEmpty) {
            secRef = (sectionCode.isNotEmpty ? sectionCode : sectionName).trim().toLowerCase();
          }

          if (secRef.isNotEmpty) {
            final sectionKey = '$ayId|$classRef|$secRef';
            if (!csvSectionsDebug.containsKey(sectionKey)) {
              csvSectionsDebug[sectionKey] = {};
            }
          }
        }
      }

      final resolvedClassUUIDs = state.resolvedClassIds.values.where((id) => id.isNotEmpty).toSet().length;
      final resolvedSectionUUIDs = state.resolvedSectionIds.values.where((id) => id.isNotEmpty).toSet().length;

      final rowsWithClassIdUUID = state.rows.map((r) => r.data['class_id'] ?? '').where((id) => uuidRegex.hasMatch(id)).length;
      final rowsWithSectionIdUUID = state.rows.map((r) => r.data['section_id'] ?? '').where((id) => uuidRegex.hasMatch(id)).length;

      logItems.insert(0, Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DEBUG SUMMARY (STUDENT DEPENDENCIES)', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(height: 6),
            Text(
              'CSV rows: $totalRows\n'
              'Academic years detected: $uniqueAy\n'
              'Unique classes detected: ${csvClassesDebug.length}\n'
              'Unique sections detected: ${csvSectionsDebug.length}\n'
              'Existing classes resolved: ${state.dependencyExistingClasses}\n'
              'New classes: ${state.dependencyNewClasses}\n'
              'Existing sections resolved: ${state.dependencyExistingSections}\n'
              'New sections: ${state.dependencyNewSections}\n'
              'Resolved class UUIDs: $resolvedClassUUIDs\n'
              'Resolved section UUIDs: $resolvedSectionUUIDs\n'
              'Rows with class_id UUID: $rowsWithClassIdUUID\n'
              'Rows with section_id UUID: $rowsWithSectionIdUUID',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace', height: 1.4),
            ),
          ],
        ),
      ));
    }

    if (logItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      height: 250,
      child: ListView.builder(
        itemCount: logItems.length,
        itemBuilder: (context, index) => logItems[index],
      ),
    );
  }

  Widget _buildTerminalLogLine(String action, String details, Color actionColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[$action]',
            style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          Text(
            details,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
        ],
      ),
    );
  }
}

class _TemplateField {
  final String name;
  final bool isRequired;
  final String format;

  const _TemplateField(this.name, this.isRequired, this.format);
}

class EditableCell extends StatefulWidget {
  final int rowIndex;
  final String columnName;
  final String currentValue;
  final bool isEdited;
  final bool isError;
  final String originalValue;
  final List<String> autocompleteOptions;
  final Map<String, String> idToNameMap;
  final ValueChanged<String> onSubmitted;

  const EditableCell({
    required this.rowIndex,
    required this.columnName,
    required this.currentValue,
    required this.isEdited,
    required this.isError,
    required this.originalValue,
    required this.autocompleteOptions,
    required this.idToNameMap,
    required this.onSubmitted,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  bool _isEditing = false;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue != widget.currentValue && !_isEditing) {
      _controller.text = widget.currentValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus && _isEditing) {
          _commitEdit();
        }
      });
    }
  }

  void _commitEdit() {
    setState(() {
      _isEditing = false;
    });
    if (_controller.text != widget.currentValue) {
      widget.onSubmitted(_controller.text);
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.currentValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      if (widget.autocompleteOptions.isNotEmpty) {
        return Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _cancelEdit();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.autocompleteOptions.contains(widget.currentValue) ? widget.currentValue : null,
              isExpanded: true,
              hint: const Text('Select...', style: TextStyle(fontSize: 12)),
              items: widget.autocompleteOptions.map((opt) {
                final displayName = widget.idToNameMap[opt] ?? opt;
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(displayName, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  widget.onSubmitted(val);
                }
                setState(() {
                  _isEditing = false;
                });
              },
            ),
          ),
        );
      }

      return KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _cancelEdit();
          }
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          onSubmitted: (_) => _commitEdit(),
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: OutlineInputBorder(),
          ),
        ),
      );
    }

    final isReferenceColumn = widget.columnName.endsWith('_id');
    final displayText = isReferenceColumn
        ? (widget.idToNameMap[widget.currentValue] ?? widget.currentValue)
        : widget.currentValue;

    Widget cellWidget = InkWell(
      onDoubleTap: () => setState(() => _isEditing = true),
      onTap: () => setState(() => _isEditing = true),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              displayText.isEmpty ? '—' : displayText,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: displayText.isEmpty ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          if (widget.isEdited)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.isError) {
      cellWidget = Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: cellWidget,
      );
    } else if (widget.isEdited) {
      cellWidget = Container(
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.08),
          border: Border.all(color: Colors.amber, width: 1),
        ),
        child: cellWidget,
      );
    }

    if (widget.isEdited || widget.isError) {
      final tooltipMessage = [
        if (widget.isError) 'Cell contains validation errors.',
        if (widget.isEdited) 'Original value: "${widget.originalValue}"',
      ].join('\n');

      cellWidget = Tooltip(
        message: tooltipMessage,
        child: cellWidget,
      );
    }

    return cellWidget;
  }
}

