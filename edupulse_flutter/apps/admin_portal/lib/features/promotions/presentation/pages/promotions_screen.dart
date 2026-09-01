import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> {
  String? _selectedSourceAyId;
  String? _selectedSourceClassId;
  String? _selectedTargetAyId;
  Map<String, String> _sectionMappings = {};

  bool _isProcessing = false;
  Map<String, dynamic>? _previewData;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    Future.microtask(() {
      final schoolId = ref.read(selectedSchoolIdProvider);
      if (schoolId != null) {
        ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
        ref.read(classesProvider(schoolId).notifier).fetchClasses();
        ref.read(sectionsProvider(schoolId).notifier).fetchSections();
      }
    });
  }

  Future<void> _runPromotion({required bool preview}) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null || _selectedSourceClassId == null || _selectedTargetAyId == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      if (!preview) {
        _isSuccess = false;
      }
    });

    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'target_academic_year_id': _selectedTargetAyId,
      'section_mappings': _sectionMappings,
    };

    final result = await apiClient.post(
      '/classes/$_selectedSourceClassId/promote?school_id=$schoolId&preview=$preview',
      data: payload,
      mapper: (json) => json as Map<String, dynamic>,
    );

    result.when(
      onSuccess: (data) {
        setState(() {
          _isProcessing = false;
          if (preview) {
            _previewData = data['data'] as Map<String, dynamic>?;
          } else {
            _previewData = null;
            _isSuccess = true;
            _refreshData();
          }
        });
      },
      onFailure: (failure) {
        setState(() {
          _isProcessing = false;
          _errorMessage = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    final theme = Theme.of(context);

    ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        setState(() {
          _selectedSourceAyId = null;
          _selectedSourceClassId = null;
          _selectedTargetAyId = null;
          _sectionMappings = {};
          _previewData = null;
          _errorMessage = null;
          _isSuccess = false;
        });
        ref.read(academicYearsProvider(next).notifier).fetchYears();
        ref.read(classesProvider(next).notifier).fetchClasses();
        ref.read(sectionsProvider(next).notifier).fetchSections();
      }
    });

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Promotions')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Please select a school campus first using the top selector bar to manage student promotions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final classState = ref.watch(classesProvider(schoolId));
    final sectionState = ref.watch(sectionsProvider(schoolId));

    final sourceYears = ayState.years;
    final targetYears = ayState.years.where((y) => y.status == 'ACTIVE' && y.id != _selectedSourceAyId).toList();

    // Source Classes belonging to selected source Academic Year
    final sourceClasses = classState.classes.where((c) {
      if (_selectedSourceAyId != null) return c.academicYearId == _selectedSourceAyId;
      return true;
    }).toList();

    final selectedClass = _selectedSourceClassId == null
        ? null
        : sourceClasses.firstWhere((c) => c.id == _selectedSourceClassId, orElse: () => sourceClasses.first);

    // Source Sections of the selected source class
    final sourceSections = sectionState.sections.where((s) => s.classId == _selectedSourceClassId).toList();

    // Target Class template resolution
    ClassDto? nextClassTemplate;
    if (selectedClass != null && selectedClass.nextClassId != null) {
      try {
        nextClassTemplate = classState.classes.firstWhere((c) => c.id == selectedClass.nextClassId);
      } catch (_) {}
    }

    // Target Class in the target academic year resolved by code
    ClassDto? targetClass;
    List<SectionDto> targetSections = [];
    if (_selectedTargetAyId != null && nextClassTemplate != null) {
      try {
        targetClass = classState.classes.firstWhere(
          (c) => c.code == nextClassTemplate!.code && c.academicYearId == _selectedTargetAyId,
        );
        targetSections = sectionState.sections.where((s) => s.classId == targetClass!.id).toList();
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Promotions & Rollover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshData();
              setState(() {
                _previewData = null;
                _errorMessage = null;
                _isSuccess = false;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isSuccess)
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 12.0),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Promotion Completed Successfully!',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16.0),
                          ),
                          SizedBox(height: 4.0),
                          Text(
                            'All qualified students have been rolled over to their next class and sections.',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Card(
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promotion Setup', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: const Key('promotion_source_ay_dropdown'),
                            value: _selectedSourceAyId,
                            decoration: const InputDecoration(
                              labelText: 'Source Academic Year',
                              border: OutlineInputBorder(),
                            ),
                            items: sourceYears.map((ay) {
                              return DropdownMenuItem<String>(
                                value: ay.id,
                                child: Text(ay.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSourceAyId = val;
                                _selectedSourceClassId = null;
                                _selectedTargetAyId = null;
                                _sectionMappings = {};
                                _previewData = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: const Key('promotion_source_class_dropdown'),
                            value: _selectedSourceClassId,
                            decoration: const InputDecoration(
                              labelText: 'Source Class',
                              border: OutlineInputBorder(),
                            ),
                            items: sourceClasses.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              );
                            }).toList(),
                            onChanged: _selectedSourceAyId == null
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedSourceClassId = val;
                                      _selectedTargetAyId = null;
                                      _sectionMappings = {};
                                      _previewData = null;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    if (selectedClass != null) ...[
                      const SizedBox(height: 16.0),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: theme.colorScheme.primary),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                selectedClass.nextClassId == null
                                    ? 'Promotion Target: Higher Secondary Graduation (Status -> ALUMNI)'
                                    : 'Promotion Target: ${nextClassTemplate?.name ?? "Alumni"} (Code: ${nextClassTemplate?.code ?? ""})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      DropdownButtonFormField<String>(
                        key: const Key('promotion_target_ay_dropdown'),
                        value: _selectedTargetAyId,
                        decoration: const InputDecoration(
                          labelText: 'Target Academic Year',
                          border: OutlineInputBorder(),
                        ),
                        items: targetYears.map((ay) {
                          return DropdownMenuItem<String>(
                            value: ay.id,
                            child: Text('${ay.name} (Active)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedTargetAyId = val;
                            _sectionMappings = {};
                            _previewData = null;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_selectedTargetAyId != null && selectedClass != null) ...[
              const SizedBox(height: 16.0),
              Card(
                elevation: 2.0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Section Mappings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8.0),
                      if (selectedClass.nextClassId == null)
                        const Text(
                          'No section mapping required. Students who clear requirements will be graduated (ALUMNI). Detained students repeat this grade in the target academic year.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        )
                      else if (targetClass == null)
                        Text(
                          'Warning: The target class code "${nextClassTemplate?.code}" is not configured or active in the target academic year.',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        )
                      else ...[
                        Text('Map each section of ${selectedClass.name} to a section of ${targetClass.name}:'),
                        const SizedBox(height: 12.0),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sourceSections.length,
                          itemBuilder: (context, index) {
                            final sourceSec = sourceSections[index];
                            final mappedVal = _sectionMappings[sourceSec.id];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Section ${sourceSec.name}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    flex: 5,
                                    child: DropdownButtonFormField<String>(
                                      key: Key('section_map_${sourceSec.id}'),
                                      value: mappedVal,
                                      decoration: const InputDecoration(
                                        labelText: 'Target Section',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      ),
                                      items: targetSections.map((ts) {
                                        return DropdownMenuItem<String>(
                                          value: ts.id,
                                          child: Text('Section ${ts.name} (Cap: ${ts.capacity})'),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val != null) {
                                            _sectionMappings[sourceSec.id] = val;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isProcessing)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    key: const Key('btn_preview_promotion'),
                    onPressed: (_selectedSourceClassId == null ||
                            _selectedTargetAyId == null ||
                            (selectedClass?.nextClassId != null && targetClass == null) ||
                            (selectedClass?.nextClassId != null &&
                                _sectionMappings.length < sourceSections.length))
                        ? null
                        : () => _runPromotion(preview: true),
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    label: const Text('Preview Promotion'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    ),
                  ),
              ],
            ),
            if (_previewData != null) ...[
              const SizedBox(height: 24.0),
              Card(
                elevation: 2.0,
                color: Colors.blue.shade50.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Promotion Preview Results',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.spaceEvenly,
                        children: [
                          _buildStatCard('Total', _previewData!['total_students'] ?? 0),
                          _buildStatCard('Promoted', _previewData!['eligible'] ?? 0, color: Colors.green),
                          _buildStatCard('Conditional', _previewData!['conditional'] ?? 0, color: Colors.orange),
                          _buildStatCard('Detained', _previewData!['detained'] ?? 0, color: Colors.red),
                          _buildStatCard('Graduated', _previewData!['graduated'] ?? 0, color: Colors.blue),
                          _buildStatCard('Blocked', _previewData!['blocked'] ?? 0, color: Colors.grey),
                        ],
                      ),
                      if ((_previewData!['failures'] as List<dynamic>?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 16.0),
                        Text(
                          'Fatal Errors:',
                          style: theme.textTheme.titleSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: (_previewData!['failures'] as List<dynamic>)
                              .map((f) => Text('- $f', style: const TextStyle(color: Colors.red)))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24.0),
                      Text(
                        'Student Breakdown:',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (_previewData!['promoted_students'] as List<dynamic>?)?.length ?? 0,
                        itemBuilder: (context, idx) {
                          final ps = _previewData!['promoted_students'][idx] as Map<String, dynamic>;
                          final status = ps['status'] as String? ?? '';
                          Color statusColor = Colors.grey;
                          if (status == 'PROMOTED' || status == 'GRADUATED') {
                            statusColor = Colors.green;
                          } else if (status == 'CONDITIONALLY_PROMOTED') {
                            statusColor = Colors.orange;
                          } else if (status == 'DETAINED') {
                            statusColor = Colors.red;
                          }

                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(ps['name'] as String? ?? 'Student'),
                            subtitle: Text('Status: $status'),
                            trailing: Text(
                              status,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            key: const Key('btn_execute_promotion'),
                            onPressed: (_previewData!['failures'] as List<dynamic>?)?.isNotEmpty == true
                                ? null
                                : () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Confirm Promotion Rollover'),
                                          content: const Text(
                                            'Are you sure you want to execute class promotion? This will modify student enrollments and academic year links. This operation cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('Execute'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true) {
                                      _runPromotion(preview: false);
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Confirm & Execute Promotion'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, dynamic count, {Color? color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(label, style: const TextStyle(fontSize: 12.0)),
          ],
        ),
      ),
    );
  }
}
