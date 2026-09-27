import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/examination_models.dart';
import '../providers/examination_providers.dart';

class QuestionPaperReviewDialog extends ConsumerStatefulWidget {
  final String examId;
  final String paperId;
  final String paperTitle;
  final double maxMarks;
  final List<ExtractedQuestionItemModel> initialQuestions;
  final List<SyllabusTopicOptionModel> syllabusTopics;

  const QuestionPaperReviewDialog({
    super.key,
    required this.examId,
    required this.paperId,
    required this.paperTitle,
    required this.maxMarks,
    required this.initialQuestions,
    required this.syllabusTopics,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String examId,
    required String paperId,
    required String paperTitle,
    required double maxMarks,
    required List<ExtractedQuestionItemModel> initialQuestions,
    required List<SyllabusTopicOptionModel> syllabusTopics,
  }) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenW < 768 ? 12 : 24,
          vertical: screenH < 768 ? 12 : 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: QuestionPaperReviewDialog(
          examId: examId,
          paperId: paperId,
          paperTitle: paperTitle,
          maxMarks: maxMarks,
          initialQuestions: initialQuestions,
          syllabusTopics: syllabusTopics,
        ),
      ),
    );
  }

  @override
  ConsumerState<QuestionPaperReviewDialog> createState() => _QuestionPaperReviewDialogState();
}

class _QuestionPaperReviewDialogState extends ConsumerState<QuestionPaperReviewDialog> {
  late List<ExtractedQuestionItemModel> _questions;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Deep clone questions
    _questions = widget.initialQuestions.map((q) {
      return ExtractedQuestionItemModel(
        id: q.id,
        questionNumber: q.questionNumber,
        parentQuestionId: q.parentQuestionId,
        sectionName: q.sectionName,
        sequenceOrder: q.sequenceOrder,
        questionText: q.questionText,
        maxMarks: q.maxMarks,
        questionType: q.questionType,
        difficulty: q.difficulty,
        chapterName: q.chapterName,
        topicName: q.topicName,
        syllabusId: q.syllabusId,
        extractionConfidence: q.extractionConfidence,
        mappingConfidence: q.mappingConfidence,
        mappingSource: q.mappingSource,
        reviewStatus: q.reviewStatus,
        subQuestions: q.subQuestions.map((sub) => ExtractedQuestionItemModel(
          id: sub.id,
          questionNumber: sub.questionNumber,
          parentQuestionId: sub.parentQuestionId,
          sectionName: sub.sectionName,
          sequenceOrder: sub.sequenceOrder,
          questionText: sub.questionText,
          maxMarks: sub.maxMarks,
          questionType: sub.questionType,
          difficulty: sub.difficulty,
          chapterName: sub.chapterName,
          topicName: sub.topicName,
          syllabusId: sub.syllabusId,
          extractionConfidence: sub.extractionConfidence,
          mappingConfidence: sub.mappingConfidence,
          mappingSource: sub.mappingSource,
          reviewStatus: sub.reviewStatus,
        )).toList(),
      );
    }).toList();
  }

  double get _currentSumOfMarks {
    double total = 0.0;
    for (final q in _questions) {
      if (q.subQuestions.isNotEmpty) {
        for (final sub in q.subQuestions) {
          total += sub.maxMarks;
        }
      } else {
        total += q.maxMarks;
      }
    }
    return total;
  }

  void _addNewQuestion() {
    setState(() {
      final nextNum = 'Q${_questions.length + 1}';
      _questions.add(
        ExtractedQuestionItemModel(
          questionNumber: nextNum,
          sectionName: 'Section A',
          sequenceOrder: _questions.length + 1,
          questionText: 'Enter question text here...',
          maxMarks: 5.0,
          questionType: 'SHORT',
          difficulty: 'MEDIUM',
          reviewStatus: 'VERIFIED',
          mappingSource: 'MANUAL',
        ),
      );
    });
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _addSubQuestion(ExtractedQuestionItemModel parent) {
    setState(() {
      final subIndex = parent.subQuestions.length;
      final subSuffix = String.fromCharCode(97 + subIndex); // 'a', 'b', 'c'
      parent.subQuestions.add(
        ExtractedQuestionItemModel(
          questionNumber: '${parent.questionNumber}($subSuffix)',
          parentQuestionId: parent.id,
          sectionName: parent.sectionName,
          sequenceOrder: subIndex + 1,
          questionText: 'Sub-question text...',
          maxMarks: 2.0,
          questionType: 'SHORT',
          difficulty: parent.difficulty,
          chapterName: parent.chapterName,
          topicName: parent.topicName,
          syllabusId: parent.syllabusId,
          reviewStatus: 'VERIFIED',
          mappingSource: 'MANUAL',
        ),
      );
    });
  }

  void _deleteSubQuestion(ExtractedQuestionItemModel parent, int subIndex) {
    setState(() {
      parent.subQuestions.removeAt(subIndex);
    });
  }

  Future<void> _handleSaveAndVerify({required bool markAsVerified}) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = {
      'title': widget.paperTitle,
      'total_marks': widget.maxMarks,
      'mark_as_verified': markAsVerified,
      'questions': _questions.map((q) => q.toJson()).toList(),
    };

    final ok = await ref.read(questionPaperIntelligenceProvider.notifier).verifyQuestionPaper(
      examId: widget.examId,
      paperId: widget.paperId,
      payload: payload,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(questionPaperIntelligenceProvider).errorMessage;
      setState(() {
        _errorMessage = err ?? 'Failed to save question paper verification.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sumMarks = _currentSumOfMarks;
    final marksMatch = (sumMarks - widget.maxMarks).abs() < 0.01;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final dialogWidth = (screenW * 0.95).clamp(320.0, 1000.0);
    final dialogHeight = (screenH * 0.92).clamp(400.0, 750.0);

    return Container(
      width: dialogWidth,
      height: dialogHeight,
      padding: EdgeInsets.all(screenW < 768 ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.rate_review_outlined, color: Colors.indigo.shade700, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Teacher Review & Verification',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_outlined, size: 14, color: Colors.teal.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Zero-Hallucination Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.paperTitle} • Max Marks: ${widget.maxMarks.toStringAsFixed(0)}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Marks sum indicator chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: marksMatch ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: marksMatch ? Colors.green.shade300 : Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Calculated: ${sumMarks.toStringAsFixed(1)} / ${widget.maxMarks.toStringAsFixed(0)} M',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: marksMatch ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    Text(
                      marksMatch ? 'Total Marks Match' : 'Marks mismatch warning',
                      style: TextStyle(
                        fontSize: 10,
                        color: marksMatch ? Colors.green.shade700 : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 16),

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

          // Action bar for questions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questions Hierarchy (${_questions.length} Items):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              FilledButton.icon(
                onPressed: _addNewQuestion,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Question'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Question list
          Expanded(
            child: _questions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No questions configured yet.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload a question paper document or click "Add Question" to start.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      return _buildQuestionCard(q, index);
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // Bottom Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Note: Verified syllabus mappings link directly into student topic analytics.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _handleSaveAndVerify(markAsVerified: false),
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save Draft'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : () => _handleSaveAndVerify(markAsVerified: true),
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Verify & Finalize Paper'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(ExtractedQuestionItemModel q, int index) {
    final isFlagged = q.reviewStatus == 'FLAGGED_FOR_REVIEW';
    final hasLowConfidence = (q.extractionConfidence != null && q.extractionConfidence! < 0.60) ||
        (q.mappingConfidence != null && q.mappingConfidence! < 0.60);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFlagged || hasLowConfidence ? Colors.amber.shade50.withAlpha(80) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFlagged || hasLowConfidence ? Colors.amber.shade400 : Colors.grey.shade300,
          width: isFlagged || hasLowConfidence ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header (Number, Section, Marks, Difficulty, Delete)
          Row(
            children: [
              // Question Number input
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: q.questionNumber,
                  decoration: const InputDecoration(
                    labelText: 'Q. No',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => q.questionNumber = val,
                ),
              ),
              const SizedBox(width: 8),
              // Section Name input
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: q.sectionName,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => q.sectionName = val,
                ),
              ),
              const SizedBox(width: 8),
              // Max Marks
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: q.maxMarks.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Marks',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val);
                    if (d != null) {
                      setState(() => q.maxMarks = d);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Difficulty Dropdown
              DropdownButton<String>(
                value: ['EASY', 'MEDIUM', 'HARD'].contains(q.difficulty.toUpperCase())
                    ? q.difficulty.toUpperCase()
                    : 'MEDIUM',
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('Easy', style: TextStyle(color: Colors.green))),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Medium', style: TextStyle(color: Colors.orange))),
                  DropdownMenuItem(value: 'HARD', child: Text('Hard', style: TextStyle(color: Colors.red))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => q.difficulty = val);
                },
              ),
              const Spacer(),
              if (isFlagged || hasLowConfidence)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        'Review Flagged',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.indigo, size: 20),
                tooltip: 'Add Sub-question (e.g. Q1a)',
                onPressed: () => _addSubQuestion(q),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                tooltip: 'Delete Question',
                onPressed: () => _deleteQuestion(index),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Question Text
          TextFormField(
            initialValue: q.questionText ?? '',
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Question Text',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => q.questionText = val,
          ),
          const SizedBox(height: 10),

          // Row 3: Syllabus Mapping Dropdown (Zero-hallucination)
          _buildSyllabusTopicSelector(q),

          // Sub-questions list
          if (q.subQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sub-questions for ${q.questionNumber}:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ...q.subQuestions.asMap().entries.map((entry) {
                    final subIdx = entry.key;
                    final subQ = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: subQ.questionNumber,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => subQ.questionNumber = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: subQ.questionText ?? '',
                              decoration: const InputDecoration(
                                hintText: 'Sub-question text',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => subQ.questionText = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: TextFormField(
                              initialValue: subQ.maxMarks.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Marks',
                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final d = double.tryParse(v);
                                if (d != null) setState(() => subQ.maxMarks = d);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                            onPressed: () => _deleteSubQuestion(q, subIdx),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyllabusTopicSelector(ExtractedQuestionItemModel q) {
    final topics = widget.syllabusTopics;

    return Row(
      children: [
        Icon(Icons.account_tree_outlined, size: 18, color: Colors.indigo.shade700),
        const SizedBox(width: 6),
        const Text(
          'Configured Syllabus Topic:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            value: q.syllabusId != null && topics.any((t) => t.syllabusId == q.syllabusId)
                ? q.syllabusId
                : null,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
              hintText: 'Select Syllabus Topic (Zero-Hallucination)',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Unmapped / General Assessment', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
              ...topics.map((t) {
                final label = '${t.chapterName} > ${t.topicName}';
                return DropdownMenuItem<String?>(
                  value: t.syllabusId,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                q.syllabusId = val;
                if (val != null) {
                  final matched = topics.firstWhere((t) => t.syllabusId == val);
                  q.chapterName = matched.chapterName;
                  q.topicName = matched.topicName;
                  q.mappingSource = 'TEACHER_REVIEWED';
                  q.reviewStatus = 'VERIFIED';
                } else {
                  q.chapterName = null;
                  q.topicName = null;
                }
              });
            },
          ),
        ),
      ],
    );
  }
}
