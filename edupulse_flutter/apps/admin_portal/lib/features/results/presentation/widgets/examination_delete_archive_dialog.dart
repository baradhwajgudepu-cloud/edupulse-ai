import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/examination_models.dart';
import '../providers/examination_providers.dart';

class ExaminationDeleteArchiveDialog extends ConsumerStatefulWidget {
  final ExaminationModel exam;

  const ExaminationDeleteArchiveDialog({
    super.key,
    required this.exam,
  });

  static Future<bool?> show(BuildContext context, ExaminationModel exam) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ExaminationDeleteArchiveDialog(exam: exam),
    );
  }

  @override
  ConsumerState<ExaminationDeleteArchiveDialog> createState() => _ExaminationDeleteArchiveDialogState();
}

class _ExaminationDeleteArchiveDialogState extends ConsumerState<ExaminationDeleteArchiveDialog> {
  bool _isLoadingImpact = true;
  bool _isProcessing = false;
  ExamDeletionImpactModel? _impact;
  String? _errorMessage;

  bool _showPermanentConfirmation = false;
  final TextEditingController _nameConfirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchImpact();
  }

  @override
  void dispose() {
    _nameConfirmController.dispose();
    super.dispose();
  }

  Future<void> _fetchImpact() async {
    setState(() {
      _isLoadingImpact = true;
      _errorMessage = null;
    });

    final impact = await ref.read(examinationsProvider.notifier).getDeletionImpact(widget.exam.id);
    if (!mounted) return;

    if (impact != null) {
      setState(() {
        _isLoadingImpact = false;
        _impact = impact;
      });
    } else {
      setState(() {
        _isLoadingImpact = false;
        _errorMessage = 'Could not load impact assessment. Please try again.';
      });
    }
  }

  Future<void> _handleDirectDelete() async {
    setState(() => _isProcessing = true);
    final ok = await ref.read(examinationsProvider.notifier).deleteExamination(widget.exam.id);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleArchive() async {
    setState(() => _isProcessing = true);
    final ok = await ref.read(examinationsProvider.notifier).archiveExamination(widget.exam.id);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handlePermanentDelete() async {
    if (_nameConfirmController.text.trim() != widget.exam.examName.trim()) {
      setState(() {
        _errorMessage = 'Examination name does not match. Please type exactly "${widget.exam.examName}".';
      });
      return;
    }

    setState(() => _isProcessing = true);
    final ok = await ref.read(examinationsProvider.notifier).deleteExaminationPermanent(
      widget.exam.id,
      _nameConfirmController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exam = widget.exam;

    final screenH = MediaQuery.of(context).size.height;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actionsOverflowButtonSpacing: 8,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remove Examination',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  exam.examName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: (screenH * 0.85).clamp(300.0, 680.0),
        ),
        child: _isLoadingImpact
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 36.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Assessing examination impact and records...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Affected Records Metrics Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Affected Records:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildMetricChip(
                                label: 'Scheduled Papers',
                                count: _impact?.papersCount ?? 0,
                                icon: Icons.description_outlined,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                label: 'Question Papers',
                                count: _impact?.questionPapersCount ?? 0,
                                icon: Icons.quiz_outlined,
                                color: Colors.indigo,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                label: 'Marks/Results',
                                count: _impact?.resultsCount ?? 0,
                                icon: Icons.grade_outlined,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: Colors.teal.shade700),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Protected Data: Students, Teachers, Classes, and Syllabus are never deleted.',
                                  style: TextStyle(fontSize: 11, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Scenario 1: DRAFT with NO results -> Direct Delete Allowed
                    if (_impact != null && _impact!.canDeleteDirect) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This examination is in DRAFT status with no student marks or published results. Deleting will cleanly remove empty schedules.',
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Scenario 2: PUBLISHED or CONTAINS RESULTS -> Archive Recommended
                    if (_impact != null && !_impact!.canDeleteDirect) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.archive_outlined, color: Colors.blue.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _impact!.warningMessage.isNotEmpty
                                    ? _impact!.warningMessage
                                    : 'This examination contains recorded results. We strongly recommend Archiving to preserve academic and audit history.',
                                style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Toggle Advanced Permanent Deletion
                      if (!_showPermanentConfirmation)
                        InkWell(
                          onTap: () => setState(() => _showPermanentConfirmation = true),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_drop_down, color: Colors.red.shade700, size: 20),
                                Text(
                                  'Advanced: Permanent Delete (Destructive)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_showPermanentConfirmation) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Permanent Deletion Confirmation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To confirm permanent removal of this exam, its timetable, question papers, and question marks, type the exact examination name below:',
                                style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: Text(
                                  widget.exam.examName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _nameConfirmController,
                                decoration: InputDecoration(
                                  hintText: 'Type examination name here',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.red.shade300),
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (!_isLoadingImpact && _impact != null) ...[
          // Option A: Direct Delete for DRAFT with no marks
          if (_impact!.canDeleteDirect)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing ? null : _handleDirectDelete,
              icon: _isProcessing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Examination'),
            ),

          // Option B: Archive button (Recommended default)
          if (!_impact!.canDeleteDirect && _impact!.canArchive)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing ? null : _handleArchive,
              icon: _isProcessing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Archive Examination (Recommended)'),
            ),

          // Option C: Permanent delete confirmed
          if (_showPermanentConfirmation && !_impact!.canDeleteDirect)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing || _nameConfirmController.text.trim() != widget.exam.examName.trim()
                  ? null
                  : _handlePermanentDelete,
              icon: _isProcessing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever, size: 18),
              label: const Text('Permanently Delete'),
            ),
        ],
      ],
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int count,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color.shade700),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.shade800),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
