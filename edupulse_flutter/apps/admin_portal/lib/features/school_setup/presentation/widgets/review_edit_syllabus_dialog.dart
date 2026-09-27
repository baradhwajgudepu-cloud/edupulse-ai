import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../data/models/curriculum_models.dart';
import '../../data/models/school_setup_models.dart';
import '../providers/curriculum_providers.dart';
import '../providers/school_setup_providers.dart';

class ReviewEditSyllabusDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String schoolName;
  final String board;
  final String? state;
  final String? academicYearId;

  const ReviewEditSyllabusDialog({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.board,
    this.state,
    this.academicYearId,
  });

  static Future<void> show(
    BuildContext context, {
    required String schoolId,
    required String schoolName,
    required String board,
    String? state,
    String? academicYearId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReviewEditSyllabusDialog(
        schoolId: schoolId,
        schoolName: schoolName,
        board: board,
        state: state,
        academicYearId: academicYearId,
      ),
    );
  }

  @override
  ConsumerState<ReviewEditSyllabusDialog> createState() => _ReviewEditSyllabusDialogState();
}

class _ReviewEditSyllabusDialogState extends ConsumerState<ReviewEditSyllabusDialog> {
  String? _selectedClassId;
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedUnits = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(classesProvider(widget.schoolId).notifier).fetchClasses(academicYearId: widget.academicYearId);
      ref.read(subjectsProvider(widget.schoolId).notifier).fetchSubjects(academicYearId: widget.academicYearId);
      ref.read(curriculumStatusProvider(widget.schoolId).notifier).fetchStatus(academicYearId: widget.academicYearId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusState = ref.watch(curriculumStatusProvider(widget.schoolId));
    final classesState = ref.watch(classesProvider(widget.schoolId));
    final subjectsState = ref.watch(subjectsProvider(widget.schoolId));

    final schoolClasses = List<ClassDto>.from(classesState.classes)
      ..sort((a, b) => a.level.compareTo(b.level));

    if (_selectedClassId == null && schoolClasses.isNotEmpty) {
      _selectedClassId = schoolClasses.first.id;
    }

    final selectedClass = schoolClasses.firstWhere(
      (c) => c.id == _selectedClassId,
      orElse: () => schoolClasses.isNotEmpty ? schoolClasses.first : const ClassDto(
        id: '',
        tenantId: '',
        schoolId: '',
        academicYearId: '',
        name: 'Selected Class',
        code: '',
        level: 8,
        category: 'MIDDLE',
        capacity: 30,
        status: 'ACTIVE',
        isActive: true,
        version: 1,
      ),
    );

    final subjectNameMap = {for (final s in subjectsState.subjects) s.id: s.subjectName};

    final classSyllabusQuery = _selectedClassId != null
        ? ClassSyllabusQuery(
            schoolId: widget.schoolId,
            classId: _selectedClassId!,
            academicYearId: widget.academicYearId,
          )
        : null;

    final syllabusAsync = classSyllabusQuery != null
        ? ref.watch(classSyllabusListProvider(classSyllabusQuery))
        : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = (screenWidth * 0.95).clamp(320.0, 1150.0);
    final dialogHeight = (screenHeight * 0.92).clamp(400.0, 850.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 768 ? 12 : 24,
        vertical: screenHeight < 768 ? 12 : 24,
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: EdgeInsets.all(screenWidth < 768 ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sticky Header with Session & Master Protection notice
            _buildHeader(statusState.status),
            const SizedBox(height: 12),

            // Master Curriculum Immutability Notice
            _buildImmutabilityBanner(),
            const SizedBox(height: 14),

            // 2. Class-Wise Bifurcation Pills
            _buildClassSelectorBar(schoolClasses),
            const SizedBox(height: 14),

            // 3. Dynamic Class KPIs & Search/Filter
            if (syllabusAsync != null)
              syllabusAsync.when(
                data: (rawItems) {
                  final filteredItems = _applyFilters(rawItems);
                  final hierarchy = SyllabusHierarchySubject.buildHierarchy(
                    items: filteredItems,
                    subjectNameMap: subjectNameMap,
                  );
                  return Column(
                    children: [
                      _buildClassKpiBar(selectedClass, rawItems, hierarchy),
                      const SizedBox(height: 12),
                      _buildSearchAndFilterBar(),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (_, __) => const SizedBox.shrink(),
              ),

            const SizedBox(height: 12),

            // 4. 5-Level Hierarchical Tree
            Expanded(
              child: syllabusAsync == null
                  ? const Center(child: Text('Please configure and select a class.'))
                  : syllabusAsync.when(
                      data: (rawItems) {
                        if (rawItems.isEmpty) {
                          return _buildEmptyClassState(selectedClass);
                        }
                        final filteredItems = _applyFilters(rawItems);
                        if (filteredItems.isEmpty) {
                          return const Center(
                            child: Text(
                              'No topics match the search and status filter.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        final hierarchy = SyllabusHierarchySubject.buildHierarchy(
                          items: filteredItems,
                          subjectNameMap: subjectNameMap,
                        );
                        return _buildHierarchyTree(hierarchy, selectedClass);
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(
                        child: Text(
                          'Failed to load class syllabus: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),

            // 5. Footer Actions
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  List<CurriculumChapterItemModel> _applyFilters(List<CurriculumChapterItemModel> items) {
    return items.where((item) {
      if (_statusFilter != 'ALL' && item.coverageStatus != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesChapter = item.chapterName.toLowerCase().contains(q);
        final matchesTopic = item.topicName.toLowerCase().contains(q);
        final matchesUnit = item.unitName.toLowerCase().contains(q);
        if (!matchesChapter && !matchesTopic && !matchesUnit) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildHeader(CurriculumStatusModel status) {
    final boardDisplay = (widget.board.toUpperCase() == 'STATE' && widget.state != null)
        ? '${widget.state} State Board'
        : widget.board;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Review & Edit School Syllabus',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: EduPulseTheme.slate900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 14, color: Color(0xFF15803D)),
                        const SizedBox(width: 6),
                        Text(
                          boardDisplay,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.schoolName} • Academic Year 2026-2027',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildImmutabilityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: Color(0xFF475569)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Master Curriculum Protection: Official board master remains immutable. All modifications, sequence reordering, and estimated periods adapt exclusively to this campus and sync with Timetable AI.',
              style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelectorBar(List<ClassDto> classes) {
    if (classes.isEmpty) {
      return const Text('No classes configured for this school.', style: TextStyle(color: Colors.grey));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text(
            'CLASSES:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          ...classes.map((cls) {
            final isSelected = cls.id == _selectedClassId;
            final label = cls.displayName?.isNotEmpty == true
                ? cls.displayName!
                : (cls.name.toLowerCase().contains('class') || cls.name.toLowerCase().contains('grade')
                    ? cls.name
                    : 'Class ${cls.level}');

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedClassId = cls.id;
                      _expandedUnits.clear();
                    });
                  }
                },
                selectedColor: const Color(0xFF0F766E),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildClassKpiBar(
    ClassDto selectedClass,
    List<CurriculumChapterItemModel> rawItems,
    List<SyllabusHierarchySubject> hierarchy,
  ) {
    final totalUnits = hierarchy.fold<int>(0, (sum, s) => sum + s.totalUnits);
    final totalChapters = hierarchy.fold<int>(0, (sum, s) => sum + s.totalChapters);
    final totalTopics = hierarchy.fold<int>(0, (sum, s) => sum + s.totalTopics);
    final totalPeriods = hierarchy.fold<int>(0, (sum, s) => sum + s.totalEstimatedPeriods);
    final completedTopics = rawItems.where((t) => t.coverageStatus == 'COMPLETED').length;
    final completionPct = rawItems.isEmpty ? 0.0 : (completedTopics / rawItems.length) * 100.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'CLASS ${selectedClass.level}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          _buildKpiPill('Subjects', '${hierarchy.length}'),
          _buildKpiPill('Units', '$totalUnits'),
          _buildKpiPill('Chapters', '$totalChapters'),
          _buildKpiPill('Topics', '$totalTopics'),
          _buildKpiPill('Est. Periods', '$totalPeriods'),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Completion: ${completionPct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completionPct / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiPill(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chapters or topics...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 36,
          child: DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButton<String>(
                value: _statusFilter,
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  DropdownMenuItem(value: 'ONGOING', child: Text('Ongoing')),
                  DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _statusFilter = val);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHierarchyTree(List<SyllabusHierarchySubject> subjects, ClassDto selectedClass) {
    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, sIdx) {
        final subject = subjects[sIdx];
        return _buildSubjectCard(subject, selectedClass);
      },
    );
  }

  Widget _buildSubjectCard(SyllabusHierarchySubject subject, ClassDto selectedClass) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.book, size: 18, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Text(
                  subject.subjectName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subject.totalUnits} Units • ${subject.totalChapters} Chapters • ${subject.totalTopics} Topics • ${subject.totalEstimatedPeriods} Periods',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3730A3)),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddUnitDialog(subject.subjectId, selectedClass),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Unit', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F766E)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                  tooltip: 'Delete Subject Syllabus for Class',
                  onPressed: () => _confirmDeleteSubject(subject, selectedClass),
                ),
              ],
            ),
          ),

          // Units List
          ...subject.units.map((unit) => _buildUnitAccordion(unit, subject, selectedClass)),
        ],
      ),
    );
  }

  Widget _buildUnitAccordion(
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    final unitKey = '${subject.subjectId}_${unit.unitName}';
    final isExpanded = _expandedUnits.contains(unitKey);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        children: [
          // Unit Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedUnits.remove(unitKey);
                } else {
                  _expandedUnits.add(unitKey);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 20,
                    color: const Color(0xFF475569),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unit.unitName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Text(
                    '${unit.chapters.length} Chapters • ${unit.totalTopics} Topics • ${unit.totalEstimatedPeriods} Periods',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF475569)),
                    tooltip: 'Rename Unit',
                    onPressed: () => _showRenameUnitDialog(unit, subject, selectedClass),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF0F766E)),
                    tooltip: 'Add Chapter to Unit',
                    onPressed: () => _showAddChapterDialog(unit, subject, selectedClass),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                    tooltip: 'Delete Unit',
                    onPressed: () => _confirmDeleteUnit(unit, subject, selectedClass),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Chapters Content
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(left: 28, right: 16, bottom: 8),
              child: Column(
                children: unit.chapters.map((chap) => _buildChapterRow(chap, unit, subject, selectedClass)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterRow(
    SyllabusHierarchyChapter chapter,
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${chapter.sequenceOrder}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chapter.chapterName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${chapter.totalEstimatedPeriods} Periods',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit, size: 14, color: Color(0xFF475569)),
                tooltip: 'Edit Chapter',
                onPressed: () => _showEditChapterDialog(chapter, unit, subject, selectedClass),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF0F766E)),
                tooltip: 'Add Topic to Chapter',
                onPressed: () => _showAddTopicDialog(chapter, unit, subject, selectedClass),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                tooltip: 'Delete Chapter',
                onPressed: () => _confirmDeleteChapter(chapter, unit, subject, selectedClass),
              ),
            ],
          ),

          // Topics Rows
          const SizedBox(height: 6),
          ...chapter.topics.map((t) => _buildTopicItem(t, chapter, unit, subject, selectedClass)),
        ],
      ),
    );
  }

  Widget _buildTopicItem(
    SyllabusHierarchyTopic topic,
    SyllabusHierarchyChapter chapter,
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    final isCompleted = topic.coverageStatus == 'COMPLETED';
    final isOngoing = topic.coverageStatus == 'ONGOING';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      topic.topicName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    if (topic.isCustom) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: const Text('CUSTOM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8))),
                      ),
                    ],
                  ],
                ),
                if (topic.description?.isNotEmpty == true)
                  Text(
                    topic.description!,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${topic.estimatedPeriods} p',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFDCFCE7)
                  : (isOngoing ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              topic.coverageStatus,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isCompleted
                    ? const Color(0xFF15803D)
                    : (isOngoing ? const Color(0xFF1D4ED8) : const Color(0xFF475569)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 12, color: Color(0xFF64748B)),
            tooltip: 'Edit Topic',
            onPressed: () => _showEditTopicDialog(topic, selectedClass),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 12, color: Color(0xFFDC2626)),
            tooltip: 'Delete Topic',
            onPressed: () => _confirmDeleteTopic(topic, selectedClass),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyClassState(ClassDto selectedClass) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No syllabus items configured for Class ${selectedClass.level}.',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          const Text(
            'You can auto-populate the official board curriculum or manually add subjects and chapters.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final ok = await ref.read(curriculumStatusProvider(widget.schoolId).notifier).autoPopulateCurriculum();
              if (ok && mounted) {
                _refreshCurrentClass();
              }
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Auto-Populate Class Syllabus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        const Text(
          'Authoritative Master remains immutable. Changes isolate strictly to this campus copy.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  // =========================================================================
  // MODALS & DIALOGS FOR 5-LEVEL EDITING
  // =========================================================================

  void _refreshCurrentClass() {
    if (_selectedClassId != null) {
      ref.invalidate(classSyllabusListProvider(ClassSyllabusQuery(
        schoolId: widget.schoolId,
        classId: _selectedClassId!,
        academicYearId: widget.academicYearId,
      )));
      ref.invalidate(curriculumStatusProvider(widget.schoolId));
    }
  }

  void _showAddTopicDialog(
    SyllabusHierarchyChapter chapter,
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    final topicCtrl = TextEditingController();
    final periodsCtrl = TextEditingController(text: '4');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Topic to ${chapter.chapterName}', style: const TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: topicCtrl,
                decoration: const InputDecoration(labelText: 'Topic Name', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'Topic name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: periodsCtrl,
                decoration: const InputDecoration(labelText: 'Estimated Periods', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Valid number required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final service = ref.read(syllabusEditorServiceProvider);
                final ok = await service.addTopic(
                  schoolId: widget.schoolId,
                  academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                  classId: selectedClass.id,
                  subjectId: subject.subjectId,
                  unitName: unit.unitName,
                  chapterName: chapter.chapterName,
                  topicName: topicCtrl.text.trim(),
                  estimatedPeriods: int.parse(periodsCtrl.text.trim()),
                  description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  sequenceOrder: chapter.topics.length + 1,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ok) {
                  _refreshCurrentClass();
                  _showSnack('Topic added successfully.');
                } else {
                  _showSnack('Failed to add topic.', isError: true);
                }
              }
            },
            child: const Text('Add Topic'),
          ),
        ],
      ),
    );
  }

  void _showEditTopicDialog(SyllabusHierarchyTopic topic, ClassDto selectedClass) {
    final topicCtrl = TextEditingController(text: topic.topicName);
    final periodsCtrl = TextEditingController(text: '${topic.estimatedPeriods}');
    final descCtrl = TextEditingController(text: topic.description ?? '');
    String covStatus = topic.coverageStatus;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Edit Topic', style: TextStyle(fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(labelText: 'Topic Name', border: OutlineInputBorder()),
                  validator: (v) => v?.trim().isEmpty == true ? 'Topic name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: periodsCtrl,
                  decoration: const InputDecoration(labelText: 'Estimated Periods', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v ?? '') == null ? 'Valid number required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: covStatus,
                  decoration: const InputDecoration(labelText: 'Coverage Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                    DropdownMenuItem(value: 'ONGOING', child: Text('ONGOING')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => covStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  final service = ref.read(syllabusEditorServiceProvider);
                  final ok = await service.updateTopic(
                    schoolId: widget.schoolId,
                    syllabusId: topic.id,
                    topicName: topicCtrl.text.trim(),
                    estimatedPeriods: int.parse(periodsCtrl.text.trim()),
                    coverageStatus: covStatus,
                    description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (ok) {
                    _refreshCurrentClass();
                    _showSnack('Topic updated successfully.');
                  } else {
                    _showSnack('Failed to update topic.', isError: true);
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditChapterDialog(
    SyllabusHierarchyChapter chapter,
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    final nameCtrl = TextEditingController(text: chapter.chapterName);
    final periodsCtrl = TextEditingController(text: '${chapter.estimatedPeriods}');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Chapter', style: TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Chapter Name', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'Chapter name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: periodsCtrl,
                decoration: const InputDecoration(labelText: 'Estimated Periods', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Valid number required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final service = ref.read(syllabusEditorServiceProvider);
                final ok = await service.updateChapter(
                  schoolId: widget.schoolId,
                  academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                  classId: selectedClass.id,
                  subjectId: subject.subjectId,
                  oldChapterName: chapter.chapterName,
                  newChapterName: nameCtrl.text.trim(),
                  unitName: unit.unitName,
                  estimatedPeriods: int.parse(periodsCtrl.text.trim()),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ok) {
                  _refreshCurrentClass();
                  _showSnack('Chapter updated successfully.');
                } else {
                  _showSnack('Failed to update chapter.', isError: true);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddChapterDialog(
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    final chapCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final periodsCtrl = TextEditingController(text: '4');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Chapter to ${unit.unitName}', style: const TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: chapCtrl,
                decoration: const InputDecoration(labelText: 'Chapter Name', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'Chapter name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: topicCtrl,
                decoration: const InputDecoration(labelText: 'First Topic Name', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'First topic name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: periodsCtrl,
                decoration: const InputDecoration(labelText: 'Estimated Periods', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Valid number required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final service = ref.read(syllabusEditorServiceProvider);
                final ok = await service.addTopic(
                  schoolId: widget.schoolId,
                  academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                  classId: selectedClass.id,
                  subjectId: subject.subjectId,
                  unitName: unit.unitName,
                  chapterName: chapCtrl.text.trim(),
                  topicName: topicCtrl.text.trim(),
                  estimatedPeriods: int.parse(periodsCtrl.text.trim()),
                  sequenceOrder: unit.chapters.length + 1,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ok) {
                  _refreshCurrentClass();
                  _showSnack('Chapter added successfully.');
                } else {
                  _showSnack('Failed to add chapter.', isError: true);
                }
              }
            },
            child: const Text('Add Chapter'),
          ),
        ],
      ),
    );
  }

  void _showRenameUnitDialog(
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    final nameCtrl = TextEditingController(text: unit.unitName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Unit', style: TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Unit Name', border: OutlineInputBorder()),
            validator: (v) => v?.trim().isEmpty == true ? 'Unit name required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final service = ref.read(syllabusEditorServiceProvider);
                final ok = await service.renameUnit(
                  schoolId: widget.schoolId,
                  academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                  classId: selectedClass.id,
                  subjectId: subject.subjectId,
                  oldUnitName: unit.unitName,
                  newUnitName: nameCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ok) {
                  _refreshCurrentClass();
                  _showSnack('Unit renamed successfully.');
                } else {
                  _showSnack('Failed to rename unit.', isError: true);
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showAddUnitDialog(String subjectId, ClassDto selectedClass) {
    final unitCtrl = TextEditingController();
    final chapCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Unit', style: TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Unit Name', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'Unit name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: chapCtrl,
                decoration: const InputDecoration(labelText: 'First Chapter Name', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'Chapter name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: topicCtrl,
                decoration: const InputDecoration(labelText: 'First Topic Name', border: OutlineInputBorder()),
                validator: (v) => v?.trim().isEmpty == true ? 'Topic name required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final service = ref.read(syllabusEditorServiceProvider);
                final ok = await service.addTopic(
                  schoolId: widget.schoolId,
                  academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                  classId: selectedClass.id,
                  subjectId: subjectId,
                  unitName: unitCtrl.text.trim(),
                  chapterName: chapCtrl.text.trim(),
                  topicName: topicCtrl.text.trim(),
                  estimatedPeriods: 4,
                  sequenceOrder: 1,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ok) {
                  _refreshCurrentClass();
                  _showSnack('Unit and chapter created.');
                } else {
                  _showSnack('Failed to create unit.', isError: true);
                }
              }
            },
            child: const Text('Create Unit'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTopic(SyllabusHierarchyTopic topic, ClassDto selectedClass) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Topic?'),
        content: Text('Are you sure you want to delete "${topic.topicName}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              final service = ref.read(syllabusEditorServiceProvider);
              final ok = await service.deleteTopic(
                schoolId: widget.schoolId,
                syllabusId: topic.id,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (ok) {
                _refreshCurrentClass();
                _showSnack('Topic deleted.');
              } else {
                _showSnack('Failed to delete topic.', isError: true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChapter(
    SyllabusHierarchyChapter chapter,
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chapter?'),
        content: Text('Are you sure you want to delete chapter "${chapter.chapterName}" and all its ${chapter.topics.length} topics?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              final service = ref.read(syllabusEditorServiceProvider);
              final ok = await service.deleteChapter(
                schoolId: widget.schoolId,
                academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                classId: selectedClass.id,
                subjectId: subject.subjectId,
                chapterName: chapter.chapterName,
                unitName: unit.unitName,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (ok) {
                _refreshCurrentClass();
                _showSnack('Chapter deleted.');
              } else {
                _showSnack('Failed to delete chapter.', isError: true);
              }
            },
            child: const Text('Delete Chapter'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUnit(
    SyllabusHierarchyUnit unit,
    SyllabusHierarchySubject subject,
    ClassDto selectedClass,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit?'),
        content: Text('Are you sure you want to delete unit "${unit.unitName}" and all its chapters/topics?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              final service = ref.read(syllabusEditorServiceProvider);
              final ok = await service.deleteUnit(
                schoolId: widget.schoolId,
                academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                classId: selectedClass.id,
                subjectId: subject.subjectId,
                unitName: unit.unitName,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (ok) {
                _refreshCurrentClass();
                _showSnack('Unit deleted.');
              } else {
                _showSnack('Failed to delete unit.', isError: true);
              }
            },
            child: const Text('Delete Unit'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubject(SyllabusHierarchySubject subject, ClassDto selectedClass) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject Syllabus?'),
        content: Text('Are you sure you want to delete the complete syllabus for "${subject.subjectName}" in Class ${selectedClass.level}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              final service = ref.read(syllabusEditorServiceProvider);
              final ok = await service.deleteClassSubject(
                schoolId: widget.schoolId,
                academicYearId: widget.academicYearId ?? selectedClass.academicYearId,
                classId: selectedClass.id,
                subjectId: subject.subjectId,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (ok) {
                _refreshCurrentClass();
                _showSnack('Subject syllabus deleted.');
              } else {
                _showSnack('Failed to delete subject syllabus.', isError: true);
              }
            },
            child: const Text('Delete Subject'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F766E),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
