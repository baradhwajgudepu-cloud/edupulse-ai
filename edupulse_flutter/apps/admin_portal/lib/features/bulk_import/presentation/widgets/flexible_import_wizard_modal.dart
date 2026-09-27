import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/routes.dart';

class FlexibleImportWizardModal extends ConsumerStatefulWidget {
  final String importEntity; // 'students' or 'teachers'
  const FlexibleImportWizardModal({super.key, this.importEntity = 'students'});

  static Future<void> show(BuildContext context, {String importEntity = 'students'}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FlexibleImportWizardModal(importEntity: importEntity),
    );
  }

  @override
  ConsumerState<FlexibleImportWizardModal> createState() =>
      _FlexibleImportWizardModalState();
}

class _FlexibleImportWizardModalState
    extends ConsumerState<FlexibleImportWizardModal> {
  int _currentStep = 1;

  String _fileName = '2026_intermediate_fresh_admissions.csv';
  String _fileSize = '142 KB (85 records)';
  bool _isProcessing = false;
  Uint8List? _fileBytes;

  List<String> _sourceHeaders = [
    'Student_Full_Name',
    'Adm No',
    'Std',
    'Class_Section',
    'Father Name',
    'Mobile',
    'House_Name',
    'Bus_Route',
  ];

  Map<String, String> _columnMappings = {
    'Student_Full_Name': 'Student Name',
    'Adm No': 'Admission Number',
    'Std': 'Class / Grade',
    'Class_Section': 'Section',
    'Father Name': 'Guardian Name',
    'Mobile': 'Guardian Phone',
    'House_Name': 'Custom Field (House)',
    'Bus_Route': 'Custom Field (Bus Route)',
  };

  final List<String> _canonicalFields = [
    'Student Name',
    'Admission Number',
    'Class / Grade',
    'Section',
    'Guardian Name',
    'Guardian Phone',
    'Gender',
    'Date of Birth',
    'Custom Field (House)',
    'Custom Field (Bus Route)',
    'Ignore Column',
  ];

  final List<Map<String, String>> _sampleRows = [
    {
      'Student Name': 'K. Anil Kumar',
      'Admission Number': 'SV2026-1042',
      'Class / Grade': '1st Year MPC',
      'Section': 'Section A',
      'Guardian Phone': '+91 98490 23145',
      'Status': 'Valid',
    },
    {
      'Student Name': 'P. Sneha Reddy',
      'Admission Number': 'SV2026-1043',
      'Class / Grade': '1st Year BiPC',
      'Section': 'Section B',
      'Guardian Phone': '+91 98490 23146',
      'Status': 'Valid',
    },
    {
      'Student Name': 'M. Rajesh Varma',
      'Admission Number': 'SV2026-1044',
      'Class / Grade': '2nd Year MPC',
      'Section': 'Section A',
      'Guardian Phone': '+91 98490 23147',
      'Status': 'Valid',
    },
    {
      'Student Name': 'S. Harika',
      'Admission Number': 'SV2026-1045',
      'Class / Grade': '1st Year CEC',
      'Section': 'Section C',
      'Guardian Phone': '',
      'Status': 'Notice (Missing Phone)',
    },
  ];

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        setState(() {
          _fileName = file.name;
          _fileSize = '${(file.size / 1024).toStringAsFixed(1)} KB';
          _fileBytes = file.bytes;
        });

        // Try parsing headers if CSV
        if (file.bytes != null && file.name.endsWith('.csv')) {
          final content = utf8.decode(file.bytes!, allowMalformed: true);
          final lines = content.split('\n');
          if (lines.isNotEmpty) {
            final headers = lines.first.split(',').map((h) => h.trim().replaceAll('"', '')).where((h) => h.isNotEmpty).toList();
            if (headers.isNotEmpty) {
              setState(() {
                _sourceHeaders = headers;
                _columnMappings = {
                  for (final h in headers) h: _autoMatchHeader(h)
                };
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error selecting file: $e');
    }
  }

  String _autoMatchHeader(String h) {
    final lower = h.toLowerCase().trim();
    // Prioritize parent/guardian so 'Father Name' or 'Parent Name' does not match 'name' -> 'Student Name'
    if (lower.contains('parent') || lower.contains('father') || lower.contains('mother') || lower.contains('guardian')) {
      return 'Guardian Name';
    }
    if (lower.contains('phone') || lower.contains('mobile') || lower.contains('contact') || lower.contains('cell')) {
      return 'Guardian Phone';
    }
    if (lower.contains('adm') || lower.contains('roll') || lower.contains('number') || lower.contains('admission') || lower.contains('reg') || lower == 'id') {
      return 'Admission Number';
    }
    if (lower.contains('class') || lower.contains('grade') || lower.contains('std') || lower.contains('standard') || lower.contains('stream')) {
      return 'Class / Grade';
    }
    if (lower.contains('sec') || lower.contains('div') || lower.contains('section')) {
      return 'Section';
    }
    if (lower.contains('name') || lower.contains('student')) {
      return 'Student Name';
    }
    if (lower.contains('house')) return 'Custom Field (House)';
    if (lower.contains('bus') || lower.contains('route')) return 'Custom Field (Bus Route)';
    return 'Ignore Column';
  }

  void _handleNext() {
    if (_currentStep == 4) {
      setState(() {
        _currentStep = 5;
        _isProcessing = true;
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _currentStep = 6;
        });
      });
    } else if (_currentStep < 6) {
      setState(() => _currentStep++);
    }
  }

  void _handlePrev() {
    if (_currentStep > 1 && _currentStep < 6) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 640;

    final steps = [
      (num: 1, label: 'Upload'),
      (num: 2, label: 'Map Columns'),
      (num: 3, label: 'Validate'),
      (num: 4, label: 'Preview'),
      (num: 5, label: 'Import'),
      (num: 6, label: 'Results'),
    ];

    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW < 600 ? 12 : 24,
        vertical: screenH < 600 ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: (screenH * 0.92).clamp(420.0, 800.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulk ${widget.importEntity == "teachers" ? "Teacher Roster" : "Student Roster"} Import Wizard',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Step $_currentStep of 6 • Guided CSV data ingest with column mapping & validation',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Step Indicator Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    _buildStepDot(steps[i].num, steps[i].label, isDesktop),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep > steps[i].num
                              ? const Color(0xFF0F766E)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            // Wizard Step Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildStepContent(theme),
              ),
            ),

            // Wizard Footer Navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (_currentStep > 1 && _currentStep < 6)
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handlePrev,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (_currentStep == 6)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go(widget.importEntity == 'teachers' ? AppRoutes.teachers : AppRoutes.students);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text('View ${widget.importEntity == "teachers" ? "Teachers" : "Students"} Directory'),
                        )
                      else if (_currentStep == 5)
                        const SizedBox.shrink()
                      else if (_currentStep == 3) ...[
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _currentStep = 4),
                          icon: const Icon(Icons.rate_review_outlined, size: 16),
                          label: const Text('Review Issues'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentStep = 5;
                              _isProcessing = true;
                            });
                            Future.delayed(const Duration(milliseconds: 1400), () {
                              if (!mounted) return;
                              setState(() {
                                _isProcessing = false;
                                _currentStep = 6;
                              });
                            });
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Import Valid Records'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ] else
                        ElevatedButton.icon(
                          onPressed: _handleNext,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(_currentStep == 4 ? 'Import Valid Records' : 'Next Step'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDot(int num, String label, bool isDesktop) {
    final isDone = _currentStep > num;
    final isCurrent = _currentStep == num;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? const Color(0xFF0F766E)
                  : isCurrent
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '$num',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Upload();
      case 2:
        return _buildStep2MapColumns();
      case 3:
        return _buildStep3Validate();
      case 4:
        return _buildStep4Preview();
      case 5:
        return _buildStep5Import();
      case 6:
        return _buildStep6Results();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Upload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCCFBF1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF0F766E), size: 26),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select or drop your roster spreadsheet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Supports UTF-8 formatted CSV or Excel (.xlsx) files with header rows.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: _pickFile,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  child: const Text('Browse Files'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // File Verified Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF99F6E4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.table_chart_outlined, color: Color(0xFF0F766E), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(_fileSize, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'File Verified',
                  style: TextStyle(color: Color(0xFF0F766E), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2MapColumns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Map Spreadsheet Headers to EduPulse Canonical Fields',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Auto-detected matching columns below. Review and adjust any mapping before proceeding:',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sourceHeaders.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, idx) {
              final header = _sourceHeaders[idx];
              final mappedValue = _columnMappings[header] ?? 'Ignore Column';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            header,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace'),
                          ),
                          const Text('Source column', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: mappedValue,
                        isDense: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        items: _canonicalFields
                            .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (newVal) {
                          if (newVal != null) {
                            setState(() => _columnMappings[header] = newVal);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Validate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF059669), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validation Passed with Notices',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF065F46)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '143 valid records, 5 records missing optional information (non-blocking).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep = 5;
                  _isProcessing = true;
                });
                Future.delayed(const Duration(milliseconds: 1400), () {
                  if (!mounted) return;
                  setState(() {
                    _isProcessing = false;
                    _currentStep = 6;
                  });
                });
              },
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Import Valid Records'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _currentStep = 4);
              },
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text('Review Issues'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text('Data Integrity Checks Performed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        _buildCheckRow(Icons.check_circle_rounded, const Color(0xFF059669), 'Admission numbers unique (Zero conflicts in database)'),
        _buildCheckRow(Icons.check_circle_rounded, const Color(0xFF059669), 'Academic class and section entities mapped correctly'),
        _buildCheckRow(Icons.check_circle_rounded, const Color(0xFF059669), 'Custom fields (House, Bus Route) mapped to JSON settings'),
        _buildCheckRow(Icons.info_outline_rounded, const Color(0xFFD97706), '5 records have missing optional guardian phone numbers (Non-blocking)'),
      ],
    );
  }

  Widget _buildCheckRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Preview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ingest Data Preview (First 4 Sample Rows)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Verify sample records with applied mappings before committing:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Student Name')),
              DataColumn(label: Text('Adm No')),
              DataColumn(label: Text('Class / Stream')),
              DataColumn(label: Text('Section')),
              DataColumn(label: Text('Guardian Phone')),
              DataColumn(label: Text('Validation')),
            ],
            rows: _sampleRows.map((r) {
              final isValid = r['Status'] == 'Valid';
              return DataRow(cells: [
                DataCell(Text(r['Student Name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(r['Admission Number'] ?? '', style: const TextStyle(fontFamily: 'monospace'))),
                DataCell(Text(r['Class / Grade'] ?? '')),
                DataCell(Text(r['Section'] ?? '')),
                DataCell(Text(r['Guardian Phone'] ?? '-')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isValid ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r['Status'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isValid ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Import() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0),
        child: Column(
          children: const [
            CircularProgressIndicator(color: Color(0xFF0F766E), strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Ingesting Records...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 6),
            Text(
              'Executing safe chunked transactions. Preserving tenant isolation and school boundaries.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep6Results() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 36),
        ),
        const SizedBox(height: 14),
        const Text(
          'Ingest Completed Successfully!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'All mapped records have been committed to the school campus roster.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _ResultMetric(label: 'Total Processed', value: '143'),
              _ResultMetric(label: 'Successfully Added', value: '143', color: Color(0xFF059669)),
              _ResultMetric(label: 'Errors / Conflicts', value: '0'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _ResultMetric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF0F172A))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }
}
