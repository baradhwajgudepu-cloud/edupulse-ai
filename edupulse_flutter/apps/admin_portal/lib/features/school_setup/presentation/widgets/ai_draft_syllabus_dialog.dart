import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/curriculum_models.dart';
import '../../data/models/school_setup_models.dart';
import '../providers/curriculum_providers.dart';

class AIDraftSyllabusDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String subjectId;
  final String subjectName;
  final List<ClassDto> classes;

  const AIDraftSyllabusDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.subjectId,
    required this.subjectName,
    required this.classes,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String schoolId,
    required String academicYearId,
    required String subjectId,
    required String subjectName,
    required List<ClassDto> classes,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AIDraftSyllabusDialog(
        schoolId: schoolId,
        academicYearId: academicYearId,
        subjectId: subjectId,
        subjectName: subjectName,
        classes: classes,
      ),
    );
  }

  @override
  ConsumerState<AIDraftSyllabusDialog> createState() => _AIDraftSyllabusDialogState();
}

class _AIDraftSyllabusDialogState extends ConsumerState<AIDraftSyllabusDialog> {
  String? _selectedClassId;
  int _numUnits = 2;
  int _chaptersPerUnit = 2;
  bool _isGenerating = false;
  bool _isApproving = false;
  String? _errorMessage;

  AIDraftSyllabusResponseDto? _draftResponse;
  late List<AIDraftSyllabusTopicDto> _editableTopics;

  @override
  void initState() {
    super.initState();
    if (widget.classes.isNotEmpty) {
      _selectedClassId = widget.classes.first.id;
    }
    _editableTopics = [];
  }

  Future<void> _generateDraft() async {
    if (_selectedClassId == null) {
      setState(() => _errorMessage = 'Please select a target class first.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final editor = ref.read(syllabusEditorServiceProvider);
      final response = await editor.generateAIDraftSyllabus(
        schoolId: widget.schoolId,
        academicYearId: widget.academicYearId,
        classId: _selectedClassId!,
        subjectId: widget.subjectId,
        numUnits: _numUnits,
        chaptersPerUnit: _chaptersPerUnit,
      );

      if (response != null && mounted) {
        setState(() {
          _draftResponse = response;
          _editableTopics = List.from(response.topics);
          _isGenerating = false;
        });
      } else if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Failed to generate AI syllabus draft. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Error generating draft: $e';
        });
      }
    }
  }

  Future<void> _approveDraft() async {
    if (_draftResponse == null || _editableTopics.isEmpty) return;

    setState(() {
      _isApproving = true;
      _errorMessage = null;
    });

    try {
      final editor = ref.read(syllabusEditorServiceProvider);
      final success = await editor.approveAIDraftSyllabus(
        schoolId: widget.schoolId,
        academicYearId: widget.academicYearId,
        classId: _selectedClassId!,
        subjectId: widget.subjectId,
        topics: _editableTopics,
      );

      if (success && mounted) {
        // Invalidate syllabus providers so UI refreshes
        ref.invalidate(schoolSyllabusListProvider(widget.schoolId));
        ref.invalidate(curriculumStatusProvider(widget.schoolId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI draft syllabus approved and saved for ${widget.subjectName}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() {
          _isApproving = false;
          _errorMessage = 'Failed to approve draft syllabus. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApproving = false;
          _errorMessage = 'Error approving draft: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 700;
    final maxH = (screenH * 0.92).clamp(400.0, 760.0);
    final insetPadding = EdgeInsets.symmetric(
      horizontal: screenW < 600 ? 12 : 24,
      vertical: screenH < 600 ? 12 : 24,
    );

    return Dialog(
      insetPadding: insetPadding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 760 : double.infinity,
          maxHeight: maxH,
        ),
        child: Padding(
          padding: EdgeInsets.all(screenW < 600 ? 14.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF0F766E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'AI Draft Syllabus Proposal',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade600),
                              ),
                              child: Text(
                                'AI DRAFT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Subject: ${widget.subjectName}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Body: Form or Draft Review
              Expanded(
                child: _draftResponse == null
                    ? _buildGeneratorForm(theme)
                    : _buildDraftReview(theme),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: (_isGenerating || _isApproving)
                        ? null
                        : () {
                            if (_draftResponse != null) {
                              setState(() {
                                _draftResponse = null;
                                _editableTopics = [];
                              });
                            } else {
                              Navigator.of(context).pop(false);
                            }
                          },
                    child: Text(_draftResponse != null ? 'Back to Setup' : 'Cancel'),
                  ),
                  if (_draftResponse == null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(_isGenerating ? 'Generating Draft...' : 'Generate Syllabus Draft'),
                      onPressed: _isGenerating ? null : _generateDraft,
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isApproving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isApproving ? 'Saving Syllabus...' : 'Approve & Save Syllabus'),
                      onPressed: _isApproving ? null : _approveDraft,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratorForm(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zero-Hallucination Disclaimer Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Colors.blue.shade800, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zero-Hallucination Safety Protocol',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'School-added subjects are strictly tenant-isolated. Canonical board curricula (CBSE / ICSE / State Board) remain untouched. Generated syllabuses are marked as AI Draft and require admin review before activation.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Target Class Selector
          Text('Target Class', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedClassId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: widget.classes.map((c) {
              return DropdownMenuItem<String>(
                value: c.id,
                child: Text('${c.name} (Grade ${c.level})'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedClassId = val);
            },
          ),
          const SizedBox(height: 20),

          // Units & Chapters count
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Units to Generate: $_numUnits', style: theme.textTheme.labelMedium),
                    Slider(
                      value: _numUnits.toDouble(),
                      min: 1,
                      max: 6,
                      divisions: 5,
                      label: '$_numUnits Units',
                      onChanged: (val) => setState(() => _numUnits = val.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chapters per Unit: $_chaptersPerUnit', style: theme.textTheme.labelMedium),
                    Slider(
                      value: _chaptersPerUnit.toDouble(),
                      min: 1,
                      max: 4,
                      divisions: 3,
                      label: '$_chaptersPerUnit Chapters',
                      onChanged: (val) => setState(() => _chaptersPerUnit = val.round()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Expected total: ${_numUnits * _chaptersPerUnit} chapters (~${_numUnits * _chaptersPerUnit * 4} periods). Topics, descriptions, and period estimates will be populated automatically.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftReview(ThemeData theme) {
    final totalPeriods = _editableTopics.fold<int>(0, (sum, t) => sum + t.estimatedPeriods);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Draft Banner & Disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI GENERATED DRAFT — REVIEW REQUIRED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _draftResponse!.disclaimer,
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Summary Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_editableTopics.length} Topics Proposed',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Total Estimated Periods: $totalPeriods',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Topics List
        Expanded(
          child: ListView.separated(
            itemCount: _editableTopics.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final topic = _editableTopics[index];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${topic.unitName} > ${topic.chapterName}: ${topic.topicName}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${topic.estimatedPeriods} periods',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: topic.description != null && topic.description!.isNotEmpty
                    ? Text(
                        topic.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  tooltip: 'Remove topic',
                  onPressed: () {
                    setState(() {
                      _editableTopics.removeAt(index);
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
