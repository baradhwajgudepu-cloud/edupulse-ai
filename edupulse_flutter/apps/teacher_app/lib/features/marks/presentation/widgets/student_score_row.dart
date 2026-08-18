import 'package:flutter/material.dart';
import '../../domain/entities/marks_wizard_entity.dart';
import '../../domain/entities/student_mark_entity.dart';
import '../../domain/repositories/marks_repository.dart';
import 'marks_status_selector.dart';

class StudentScoreRow extends StatefulWidget {
  final StudentShortInfoEntity student;
  final SingleMarkInput currentInput;
  final String? errorMessage;
  final int maxMarks;
  final bool isLocked;
  final ValueChanged<SingleMarkInput> onChanged;
  final List<String> remarksTemplates;

  const StudentScoreRow({
    super.key,
    required this.student,
    required this.currentInput,
    this.errorMessage,
    required this.maxMarks,
    required this.isLocked,
    required this.onChanged,
    required this.remarksTemplates,
  });

  @override
  State<StudentScoreRow> createState() => _StudentScoreRowState();
}

class _StudentScoreRowState extends State<StudentScoreRow> {
  late TextEditingController _scoreController;

  @override
  void initState() {
    super.initState();
    _scoreController = TextEditingController(
      text: widget.currentInput.marksObtained != null
          ? widget.currentInput.marksObtained!.toString()
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant StudentScoreRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentInput.marksObtained != widget.currentInput.marksObtained) {
      final newText = widget.currentInput.marksObtained != null
          ? widget.currentInput.marksObtained!.toString()
          : '';
      if (_scoreController.text != newText) {
        _scoreController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  void _showRemarksDialog() {
    final remarksController = TextEditingController(text: widget.currentInput.remarks ?? '');
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('Remarks for ${widget.student.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: remarksController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter remarks...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.remarksTemplates.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick Templates',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.remarksTemplates.map((template) {
                    return ActionChip(
                      label: Text(template, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        remarksController.text = template;
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onChanged(SingleMarkInput(
                  studentId: widget.student.id,
                  marksObtained: widget.currentInput.marksObtained,
                  resultStatus: widget.currentInput.resultStatus,
                  remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                ));
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditable = !widget.isLocked &&
        (widget.currentInput.resultStatus == ExamResult.PRESENT ||
            widget.currentInput.resultStatus == ExamResult.EXEMPTED);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: widget.errorMessage != null
              ? theme.colorScheme.error
              : theme.colorScheme.outlineVariant,
          width: widget.errorMessage != null ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    widget.student.rollNumber,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.currentInput.remarks != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.comment, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.currentInput.remarks!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MarksStatusSelector(
                  currentStatus: widget.currentInput.resultStatus,
                  isLocked: widget.isLocked,
                  onStatusChanged: (newStatus) {
                    widget.onChanged(SingleMarkInput(
                      studentId: widget.student.id,
                      marksObtained: widget.currentInput.marksObtained,
                      resultStatus: newStatus,
                      remarks: widget.currentInput.remarks,
                    ));
                  },
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  height: 40,
                  child: TextField(
                    controller: _scoreController,
                    enabled: isEditable,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: const OutlineInputBorder(),
                      errorText: widget.errorMessage != null ? '' : null,
                      errorStyle: const TextStyle(height: 0),
                      hintText: widget.currentInput.resultStatus == ExamResult.PRESENT ? '0' : '--',
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      widget.onChanged(SingleMarkInput(
                        studentId: widget.student.id,
                        marksObtained: val.isEmpty ? null : parsed,
                        resultStatus: widget.currentInput.resultStatus,
                        remarks: widget.currentInput.remarks,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    widget.currentInput.remarks != null ? Icons.comment : Icons.comment_outlined,
                    color: widget.currentInput.remarks != null ? theme.colorScheme.primary : Colors.grey,
                  ),
                  onPressed: widget.isLocked ? null : _showRemarksDialog,
                ),
              ],
            ),
            if (widget.errorMessage != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 44.0),
                child: Text(
                  widget.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
