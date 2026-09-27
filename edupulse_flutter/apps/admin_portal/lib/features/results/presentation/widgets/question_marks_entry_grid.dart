import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/examination_models.dart';
import '../providers/examination_providers.dart';

class QuestionMarksEntryGrid extends ConsumerStatefulWidget {
  final String examId;
  final String paperId;
  final QuestionWiseMarksMatrixModel matrix;
  final VoidCallback onSaved;

  const QuestionMarksEntryGrid({
    super.key,
    required this.examId,
    required this.paperId,
    required this.matrix,
    required this.onSaved,
  });

  @override
  ConsumerState<QuestionMarksEntryGrid> createState() => _QuestionMarksEntryGridState();
}

class _QuestionMarksEntryGridState extends ConsumerState<QuestionMarksEntryGrid> {
  late String _entryMode; // 'QUESTION_WISE' or 'TOTAL_ONLY'
  late List<QuestionWiseStudentRowModel> _rows;
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _entryMode = widget.matrix.mode.toUpperCase() == 'TOTAL_ONLY' ? 'TOTAL_ONLY' : 'QUESTION_WISE';
    _cloneRows();
  }

  @override
  void didUpdateWidget(covariant QuestionMarksEntryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matrix != widget.matrix) {
      _cloneRows();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _cloneRows() {
    _rows = widget.matrix.rows.map((r) {
      return QuestionWiseStudentRowModel(
        studentId: r.studentId,
        studentName: r.studentName,
        admissionNumber: r.admissionNumber,
        rollNumber: r.rollNumber,
        questionMarks: Map<String, double>.from(r.questionMarks),
        totalObtained: r.totalObtained,
        maxMarks: r.maxMarks,
        isComplete: r.isComplete,
        resultStatus: r.resultStatus,
        remarks: r.remarks,
      );
    }).toList();

    // Initialize controllers
    _controllers.clear();
    for (final row in _rows) {
      // Total controller
      _controllers['total_${row.studentId}'] = TextEditingController(
        text: row.totalObtained > 0 ? row.totalObtained.toString() : '',
      );
      // Question controllers
      for (final q in widget.matrix.questions) {
        final val = row.questionMarks[q.questionNumber];
        _controllers['${row.studentId}_${q.questionNumber}'] = TextEditingController(
          text: val != null ? val.toString() : '',
        );
      }
    }
  }

  void _recalculateRowTotal(QuestionWiseStudentRowModel row) {
    double sum = 0.0;
    for (final entry in row.questionMarks.entries) {
      sum += entry.value;
    }
    row.totalObtained = double.parse(sum.toStringAsFixed(2));
    _controllers['total_${row.studentId}']?.text = row.totalObtained > 0 ? row.totalObtained.toString() : '';
  }

  Future<void> _handleSave({required bool isDraft}) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payloadRows = _rows.map((r) => r.toJson()).toList();

    final ok = await ref.read(questionWiseMarksProvider.notifier).saveMarks(
      examId: widget.examId,
      paperId: widget.paperId,
      rows: payloadRows,
      isDraft: isDraft,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDraft ? 'Marks draft saved successfully.' : 'Marks finalized and synchronized!'),
          backgroundColor: isDraft ? Colors.blue.shade800 : Colors.green.shade800,
        ),
      );
      widget.onSaved();
    } else {
      final err = ref.read(questionWiseMarksProvider).errorMessage;
      setState(() {
        _errorMessage = err ?? 'Failed to save marks.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final matrix = widget.matrix;
    final questions = matrix.questions;
    final isQMode = _entryMode == 'QUESTION_WISE' && questions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selector and header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${matrix.className} - ${matrix.sectionName} • ${matrix.subjectName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Max Marks: ${matrix.totalMaxMarks.toStringAsFixed(0)} • Students: ${_rows.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const Spacer(),
              // Mode Segmented Button
              SegmentedButton<String>(
                segments: [
                  const ButtonSegment(
                    value: 'TOTAL_ONLY',
                    label: Text('Mode A: Total Only'),
                    icon: Icon(Icons.pin, size: 16),
                  ),
                  ButtonSegment(
                    value: 'QUESTION_WISE',
                    label: Text(
                      questions.isNotEmpty
                          ? 'Mode B: Question-Wise (${questions.length} Qs)'
                          : 'Mode B: Question-Wise (No Paper)',
                    ),
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    enabled: questions.isNotEmpty,
                  ),
                ],
                selected: {_entryMode},
                onSelectionChanged: (newSelection) {
                  setState(() => _entryMode = newSelection.first);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                ),
              ],
            ),
          ),

        // Spreadsheet Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 16,
                    horizontalMargin: 16,
                    columns: [
                      const DataColumn(label: Text('Roll', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      if (isQMode)
                        ...questions.map((q) => DataColumn(
                              label: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.questionNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    '${q.maxMarks.toStringAsFixed(0)}M',
                                    style: TextStyle(fontSize: 10, color: Colors.indigo.shade700),
                                  ),
                                ],
                              ),
                            )),
                      DataColumn(
                        label: Text(
                          'Total (${matrix.totalMaxMarks.toStringAsFixed(0)}M)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                      ),
                      const DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _rows.map((row) {
                      final isAbsent = row.resultStatus == 'ABSENT';
                      return DataRow(
                        cells: [
                          DataCell(Text(row.rollNumber ?? '-')),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(row.admissionNumber, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          // Attendance Status Dropdown
                          DataCell(
                            DropdownButton<String>(
                              value: row.resultStatus,
                              isDense: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'PRESENT', child: Text('Present', style: TextStyle(color: Colors.green))),
                                DropdownMenuItem(value: 'ABSENT', child: Text('Absent', style: TextStyle(color: Colors.red))),
                                DropdownMenuItem(value: 'EXEMPTED', child: Text('Exempt', style: TextStyle(color: Colors.orange))),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    row.resultStatus = val;
                                    if (val == 'ABSENT') {
                                      row.totalObtained = 0.0;
                                      row.questionMarks.clear();
                                      _recalculateRowTotal(row);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          // Question wise cells
                          if (isQMode)
                            ...questions.map((q) {
                              final ctrl = _controllers['${row.studentId}_${q.questionNumber}'];
                              return DataCell(
                                SizedBox(
                                  width: 65,
                                  child: TextFormField(
                                    controller: ctrl,
                                    enabled: !isAbsent,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                      fillColor: isAbsent ? Colors.grey.shade100 : Colors.white,
                                      filled: true,
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        if (parsed < 0 || parsed > q.maxMarks) {
                                          // Reject out-of-bounds marks
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Invalid mark: Must be between 0 and ${q.maxMarks}'),
                                              backgroundColor: Colors.red.shade700,
                                              duration: const Duration(seconds: 1),
                                            ),
                                          );
                                          return;
                                        }
                                        row.questionMarks[q.questionNumber] = parsed;
                                      } else {
                                        row.questionMarks.remove(q.questionNumber);
                                      }
                                      setState(() {
                                        _recalculateRowTotal(row);
                                      });
                                    },
                                  ),
                                ),
                              );
                            }),
                          // Total Marks Cell
                          DataCell(
                            SizedBox(
                              width: 75,
                              child: TextFormField(
                                controller: _controllers['total_${row.studentId}'],
                                enabled: !isAbsent && !isQMode, // In Q-mode, it auto-calculates!
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                  fillColor: isQMode ? Colors.teal.shade50 : (isAbsent ? Colors.grey.shade100 : Colors.white),
                                  filled: true,
                                ),
                                onChanged: (val) {
                                  if (!isQMode) {
                                    final d = double.tryParse(val);
                                    if (d != null) {
                                      if (d < 0 || d > matrix.totalMaxMarks) {
                                        return;
                                      }
                                      row.totalObtained = d;
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                          // Remarks Cell
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: TextFormField(
                                initialValue: row.remarks ?? '',
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Optional remark',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) => row.remarks = v,
                              ),
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
        ),
        const SizedBox(height: 12),

        // Action Buttons Row
        Row(
          children: [
            if (isQMode)
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.teal.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Live Auto-Sum Enabled • Question marks automatically sync to total score.',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            else
              Text(
                'Mode A: Entering total paper marks directly without question breakdown.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _handleSave(isDraft: true),
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Draft'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : () => _handleSave(isDraft: false),
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Submit & Finalize Marks'),
            ),
          ],
        ),
      ],
    );
  }
}
