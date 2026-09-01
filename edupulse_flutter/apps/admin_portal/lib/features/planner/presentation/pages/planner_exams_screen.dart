import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/planner_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class PlannerExamsScreen extends ConsumerStatefulWidget {
  const PlannerExamsScreen({super.key});

  @override
  ConsumerState<PlannerExamsScreen> createState() => _PlannerExamsScreenState();
}

class _PlannerExamsScreenState extends ConsumerState<PlannerExamsScreen> {
  int _currentStep = 0;
  
  // Wizard States
  final _formKey = GlobalKey<FormState>();
  final _examNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedExamType = 'UNIT_TEST';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  // Schedule Step state
  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  DateTime _paperDate = DateTime.now();
  TimeOfDay _paperStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _paperEndTime = const TimeOfDay(hour: 12, minute: 0);
  String? _roomNumber;
  int _maxMarks = 100;
  int _passMarks = 35;

  List<Map<String, dynamic>> _addedSchedules = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(examsListProvider.notifier).fetchExams();
    });
  }

  void _resetWizard() {
    setState(() {
      _currentStep = 0;
      _examNameController.clear();
      _descriptionController.clear();
      _selectedExamType = 'UNIT_TEST';
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
      _selectedClassId = null;
      _selectedSectionId = null;
      _selectedSubjectId = null;
      _roomNumber = null;
      _maxMarks = 100;
      _passMarks = 35;
      _addedSchedules = [];
    });
  }

  void _showWizardDialog(BuildContext context, String schoolId) {
    _resetWizard();
    // Load prerequisites
    ref.read(classesProvider(schoolId).notifier).fetchClasses();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final classesState = ref.watch(classesProvider(schoolId));
            final sectionsState = _selectedClassId != null ? ref.watch(sectionsProvider(schoolId)) : null;
            final subjectsState = ref.watch(subjectsProvider(schoolId));
            final tsaState = ref.watch(plannerAssignmentsProvider);

            List<Step> steps = [
              // Step 1: Exam Info
              Step(
                title: const Text('Exam Info'),
                isActive: _currentStep >= 0,
                content: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _examNameController,
                        decoration: const InputDecoration(labelText: 'Exam Name *'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedExamType,
                        decoration: const InputDecoration(labelText: 'Exam Type/Term *'),
                        items: const [
                          DropdownMenuItem(value: 'UNIT_TEST', child: Text('Unit Test')),
                          DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                          DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                          DropdownMenuItem(value: 'HALF_YEARLY', child: Text('Half Yearly')),
                          DropdownMenuItem(value: 'PRE_FINAL', child: Text('Pre-Final')),
                          DropdownMenuItem(value: 'ANNUAL', child: Text('Annual')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => _selectedExamType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    _startDate = picked;
                                    if (_endDate.isBefore(picked)) _endDate = picked.add(const Duration(days: 7));
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Start Date *'),
                                child: Text(DateFormat('dd MMM yyyy').format(_startDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate,
                                  firstDate: _startDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() => _endDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'End Date *'),
                                child: Text(DateFormat('dd MMM yyyy').format(_endDate)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Step 2: Add Schedule
              Step(
                title: const Text('Add Schedules'),
                isActive: _currentStep >= 1,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(labelText: 'Class *'),
                      items: classesState.classes.map((c) {
                        return DropdownMenuItem(value: c.id, child: Text(c.name));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          _selectedClassId = val;
                          _selectedSectionId = null;
                        });
                        if (val != null) {
                          ref.read(sectionsProvider(schoolId).notifier).fetchSections(classId: val);
                          ref.read(subjectsProvider(schoolId).notifier).fetchSubjects();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSectionId,
                      decoration: const InputDecoration(labelText: 'Section *'),
                      items: (sectionsState?.sections ?? []).map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => _selectedSectionId = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject *'),
                      items: (subjectsState.subjects).map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.subjectName));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => _selectedSubjectId = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // Paper Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paperDate.isBefore(_startDate) ? _startDate : _paperDate,
                          firstDate: _startDate,
                          lastDate: _endDate,
                        );
                        if (picked != null) setDialogState(() => _paperDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Paper Date *'),
                        child: Text(DateFormat('dd MMM yyyy').format(_paperDate)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Timings
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(context: context, initialTime: _paperStartTime);
                              if (picked != null) setDialogState(() => _paperStartTime = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Start Time *'),
                              child: Text(_paperStartTime.format(context)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(context: context, initialTime: _paperEndTime);
                              if (picked != null) setDialogState(() => _paperEndTime = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'End Time *'),
                              child: Text(_paperEndTime.format(context)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Room Number'),
                      onChanged: (val) => _roomNumber = val.isEmpty ? null : val,
                    ),
                    const SizedBox(height: 16),

                    // Marks
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'Max Marks *'),
                            initialValue: '100',
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _maxMarks = int.tryParse(val) ?? 100,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'Passing Marks *'),
                            initialValue: '35',
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _passMarks = int.tryParse(val) ?? 35,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: () {
                        if (_selectedClassId == null || _selectedSectionId == null || _selectedSubjectId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select class, section, and subject')),
                          );
                          return;
                        }

                        // Lookup TSA
                        tsaState.when(
                          data: (tsas) {
                            final tsa = tsas.firstWhere(
                              (t) => t.classId == _selectedClassId && t.sectionId == _selectedSectionId && t.subjectId == _selectedSubjectId && t.isActive,
                              orElse: () => throw Exception('No active Teacher Subject Assignment found for this mapping.'),
                            );

                            final classObj = classesState.classes.firstWhere((c) => c.id == _selectedClassId);
                            final sectionObj = (sectionsState?.sections ?? []).firstWhere((s) => s.id == _selectedSectionId);
                            final subjectObj = subjectsState.subjects.firstWhere((s) => s.id == _selectedSubjectId);

                            setDialogState(() {
                              _addedSchedules.add({
                                'class_id': _selectedClassId,
                                'section_id': _selectedSectionId,
                                'subject_id': _selectedSubjectId,
                                'teacher_subject_assignment_id': tsa.id,
                                'exam_date': DateFormat('yyyy-MM-dd').format(_paperDate),
                                'start_time': '${_paperStartTime.hour.toString().padLeft(2, '0')}:${_paperStartTime.minute.toString().padLeft(2, '0')}:00',
                                'end_time': '${_paperEndTime.hour.toString().padLeft(2, '0')}:${_paperEndTime.minute.toString().padLeft(2, '0')}:00',
                                'max_marks': _maxMarks,
                                'pass_marks': _passMarks,
                                'room_number': _roomNumber,
                                // UI display helpers
                                '_className': classObj.name,
                                '_sectionName': sectionObj.name,
                                '_subjectName': subjectObj.subjectName,
                              });
                            });
                          },
                          loading: () {},
                          error: (err, _) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error validating TSA: $err')),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Paper Schedule'),
                    ),

                    const SizedBox(height: 16),
                    const Text('Scheduled Papers:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_addedSchedules.isEmpty)
                      const Text('No papers added yet.', style: TextStyle(color: Colors.grey))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _addedSchedules.length,
                        itemBuilder: (context, idx) {
                          final item = _addedSchedules[idx];
                          return Card(
                            color: Colors.grey.shade100,
                            child: ListTile(
                              title: Text('${item['_subjectName']} - ${item['_className']} (${item['_sectionName']})'),
                              subtitle: Text('Date: ${item['exam_date']} | Time: ${item['start_time']} - ${item['end_time']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    _addedSchedules.removeAt(idx);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // Step 3: Review & Submit
              Step(
                title: const Text('Review'),
                isActive: _currentStep >= 2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exam Name: ${_examNameController.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Term Type: $_selectedExamType'),
                    Text('Duration: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}'),
                    if (_descriptionController.text.isNotEmpty) Text('Description: ${_descriptionController.text}'),
                    const SizedBox(height: 16),
                    Text('Schedules count: ${_addedSchedules.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ];

            return AlertDialog(
              title: const Text('Exam Scheduler Wizard'),
              content: SizedBox(
                width: 600,
                child: Stepper(
                  type: StepperType.horizontal,
                  currentStep: _currentStep,
                  steps: steps,
                  onStepContinue: () {
                    if (_currentStep == 0) {
                      if (_formKey.currentState?.validate() ?? false) {
                        setDialogState(() => _currentStep++);
                      }
                    } else if (_currentStep == 1) {
                      if (_addedSchedules.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please add at least one paper schedule.')),
                        );
                        return;
                      }
                      setDialogState(() => _currentStep++);
                    } else if (_currentStep == 2) {
                      // Call wizard API
                      ref.read(examsListProvider.notifier).createExaminationWizard(
                            examName: _examNameController.text,
                            examType: _selectedExamType,
                            startDate: DateFormat('yyyy-MM-dd').format(_startDate),
                            endDate: DateFormat('yyyy-MM-dd').format(_endDate),
                            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
                            schedules: _addedSchedules.map((s) {
                              final map = Map<String, dynamic>.from(s);
                              map.remove('_className');
                              map.remove('_sectionName');
                              map.remove('_subjectName');
                              return map;
                            }).toList(),
                          ).then((success) {
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Examination scheduled successfully.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to save examination schedules.')),
                          );
                        }
                      });
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) {
                      setDialogState(() => _currentStep--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please select a school campus from the header to manage exams.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final state = ref.watch(examsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exam Management Scheduler',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure examination timetables, assign classes/sections, specify max/passing marks, and publish to apps.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showWizardDialog(context, schoolId),
                  icon: const Icon(Icons.school),
                  label: const Text('Schedule New Exam'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Area
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.error != null)
              Center(
                child: Text('Error: ${state.error}', style: TextStyle(color: theme.colorScheme.error)),
              )
            else if (state.examinations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: Text('No examinations found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.examinations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final exam = state.examinations[index];
                  final isPublished = exam.status == 'PUBLISHED';

                  return Card(
                    elevation: 1,
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Text(exam.examName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPublished ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              exam.status,
                              style: TextStyle(
                                color: isPublished ? Colors.green : Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text('Term: ${exam.examType} | Duration: ${exam.startDate} to ${exam.endDate}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPublished) ...[
                            ElevatedButton(
                              onPressed: () async {
                                final res = await ref.read(examsListProvider.notifier).publishExam(exam.id);
                                if (res) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Examination published successfully.')),
                                  );
                                }
                              },
                              child: const Text('Publish'),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Exam'),
                                  content: const Text('Are you sure you want to delete this examination?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                ref.read(examsListProvider.notifier).deleteExam(exam.id);
                              }
                            },
                          ),
                        ],
                      ),
                      children: [
                        if (exam.schedules.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No paper schedules added for this examination.', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: exam.schedules.length,
                            separatorBuilder: (context, idx) => const Divider(),
                            itemBuilder: (context, idx) {
                              final paper = exam.schedules[idx];
                              return ListTile(
                                leading: const Icon(Icons.assignment),
                                title: Text('Paper details: Room: ${paper.roomNumber ?? 'N/A'}'),
                                subtitle: Text('Date: ${paper.examDate} | Time: ${paper.startTime} - ${paper.endTime} | Max Marks: ${paper.maxMarks} | Pass Marks: ${paper.passMarks}'),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
