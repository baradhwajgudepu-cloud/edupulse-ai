import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/teachers/presentation/providers/teachers_providers.dart';
import 'package:admin_portal/features/students/presentation/providers/student_providers.dart';
import 'package:admin_portal/features/guardians/presentation/providers/guardian_providers.dart';
import 'rooms_screen.dart';
import '../providers/curriculum_providers.dart';
import '../../data/models/curriculum_models.dart';
import '../widgets/review_edit_syllabus_dialog.dart';

class SchoolSetupCenterScreen extends ConsumerStatefulWidget {
  const SchoolSetupCenterScreen({super.key});

  @override
  ConsumerState<SchoolSetupCenterScreen> createState() => _SchoolSetupCenterScreenState();
}

class _SchoolSetupCenterScreenState extends ConsumerState<SchoolSetupCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final schoolsState = ref.watch(schoolsListProvider);
    final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
    final selectedSchool = schoolsState.schools.where((s) => s.id == selectedSchoolId).firstOrNull;

    final hasProfile = selectedSchool != null && selectedSchool.name.isNotEmpty && selectedSchool.code.isNotEmpty;
    final hasBoard = selectedSchool != null && selectedSchool.board.isNotEmpty;
    final hasGeofence = selectedSchool?.isGeofenceConfigured ?? false;

    // Academic Years, Classes, Sections
    final ayList = selectedSchoolId != null ? ref.watch(academicYearsProvider(selectedSchoolId)).years : [];
    final classList = selectedSchoolId != null ? ref.watch(classesProvider(selectedSchoolId)).classes : [];
    final sectionList = selectedSchoolId != null ? ref.watch(sectionsProvider(selectedSchoolId)).sections : [];
    final roomsState = ref.watch(roomsListProvider);
    final roomsList = roomsState.valueOrNull ?? [];
    final teachersList = ref.watch(teachersListProvider).teachers;
    final studentsList = ref.watch(studentListProvider).students;
    final guardiansList = ref.watch(guardianListProvider).guardians;

    final curriculumState = selectedSchoolId != null
        ? ref.watch(curriculumStatusProvider(selectedSchoolId))
        : null;
    final curriculumStatus = curriculumState?.status ?? CurriculumStatusModel.empty();

    final stages = [
      _SetupStageData(
        stepNumber: 1,
        name: 'School Identity & Affiliation',
        shortLabel: 'School',
        isCompleted: hasProfile && hasBoard,
        targetRoute: AppRoutes.settings,
        summary: 'Institution branding, state board code, principal designation, and campus address',
        details: [
          _StageField('School Name', (selectedSchool?.name.isNotEmpty == true) ? selectedSchool!.name : 'Not configured'),
          _StageField('Affiliation Board', (selectedSchool?.board.isNotEmpty == true) ? selectedSchool!.board : 'Not configured'),
          _StageField('Institution Code', (selectedSchool?.code.isNotEmpty == true) ? selectedSchool!.code : 'Not configured'),
          _StageField('Principal / Head', (selectedSchool?.principalName != null && selectedSchool!.principalName!.isNotEmpty) ? selectedSchool.principalName! : 'Not configured'),
        ],
      ),
      _SetupStageData(
        stepNumber: 2,
        name: 'Academic Year & Term Periods',
        shortLabel: 'Academic Year',
        isCompleted: ayList.isNotEmpty,
        targetRoute: selectedSchoolId != null ? '/schools/$selectedSchoolId/academic-years' : AppRoutes.dashboard,
        summary: 'Current operating session calendar, working days schedule, and examination cycles',
        details: [
          _StageField('Active Academic Year', ayList.isNotEmpty ? ayList.first.name : 'Not configured'),
          _StageField('Term 1 Duration', ayList.isNotEmpty ? 'Term 1 Active' : 'Not configured'),
          _StageField('Term 2 Duration', ayList.isNotEmpty ? 'Term 2 Active' : 'Not configured'),
          _StageField('Working Days / Year', ayList.isNotEmpty ? '${ayList.length} Sessions Configured' : 'Not configured'),
        ],
      ),
      _SetupStageData(
        stepNumber: 3,
        name: 'Academic Classes & Streams',
        shortLabel: 'Classes',
        isCompleted: classList.isNotEmpty,
        targetRoute: AppRoutes.classes,
        summary: 'Grade levels and stream offerings (Intermediate 1st Year, 2nd Year, High School)',
        details: [
          _StageField('Configured Classes', classList.isNotEmpty ? '${classList.length} Configured Classes' : 'Not configured'),
          _StageField('Streams Offered', classList.isNotEmpty ? classList.map((c) => c.name).take(3).join(', ') : 'Not configured'),
          _StageField('Medium of Instruction', classList.isNotEmpty ? 'Active Curriculum' : 'Not configured'),
        ],
      ),
      _SetupStageData(
        stepNumber: 4,
        name: 'Curriculum & Board-Based Syllabus',
        shortLabel: 'Curriculum',
        isCompleted: curriculumStatus.isPopulated,
        targetRoute: '',
        onCustomAction: selectedSchoolId != null
            ? () {
                ReviewEditSyllabusDialog.show(
                  context,
                  schoolId: selectedSchoolId,
                  schoolName: selectedSchool?.name ?? 'School',
                  board: selectedSchool?.board ?? 'CBSE',
                  state: selectedSchool?.state,
                );
              }
            : null,
        actionLabel: curriculumStatus.isPopulated ? 'Review & Edit' : 'Auto-Populate Syllabus',
        summary: 'Official board-aligned syllabus, units, and chapters automatically resolved & cloned per school',
        details: [
          _StageField('Affiliation Board', (selectedSchool?.board.isNotEmpty == true) ? selectedSchool!.board : 'Not configured'),
          _StageField('Populated Chapters', curriculumStatus.isPopulated ? '${curriculumStatus.totalChapters} Chapters (${curriculumStatus.totalTopics} Topics)' : 'Not populated'),
          _StageField('Syllabus Source', curriculumStatus.source != null ? '${curriculumStatus.source} (${curriculumStatus.sourceVersion ?? 'Official'})' : 'Official Board Catalog'),
          _StageField('Verification Status', curriculumStatus.verificationStatus ?? (curriculumStatus.isPopulated ? 'VERIFIED' : 'Pending Auto-Populate')),
        ],
      ),
      _SetupStageData(
        stepNumber: 5,
        name: 'Sections & Faculty Allocation',
        shortLabel: 'Sections',
        isCompleted: sectionList.isNotEmpty,
        targetRoute: AppRoutes.sections,
        summary: 'Sub-cohorts assigned to designated class teachers and lecture schedules',
        details: [
          _StageField('Total Sections', sectionList.isNotEmpty ? '${sectionList.length} Academic Sections' : 'Not configured'),
          _StageField('Class Teachers', sectionList.isNotEmpty ? 'Sections Active' : 'Not configured'),
          _StageField('Target Batch Size', sectionList.isNotEmpty ? 'Batch Allocations Active' : 'Not configured'),
        ],
      ),
      _SetupStageData(
        stepNumber: 6,
        name: 'Lecture Rooms & Campus Laboratories',
        shortLabel: 'Rooms',
        isCompleted: roomsList.isNotEmpty,
        targetRoute: AppRoutes.rooms,
        summary: 'Physical room numbers, science laboratories, computer labs, and seating capacities',
        details: [
          _StageField('Lecture Theatres', roomsList.isNotEmpty ? '${roomsList.length} Rooms Configured' : 'Not configured'),
          _StageField('Science Laboratories', roomsList.any((r) => r.roomType.toUpperCase().contains('LAB')) ? 'Laboratories Configured' : (roomsList.isNotEmpty ? 'Classrooms' : 'Not configured')),
          _StageField('Campus Capacity', roomsList.isNotEmpty ? '${roomsList.fold<int>(0, (sum, r) => sum + r.capacity)} Total Student Seating' : 'Not configured'),
        ],
      ),
      _SetupStageData(
        stepNumber: 7,
        name: 'Faculty & Administrative Staff Roster',
        shortLabel: 'Staff',
        isCompleted: teachersList.isNotEmpty,
        targetRoute: AppRoutes.teachers,
        summary: 'Senior lecturers, lab assistants, accounts administrators, and attendance permissions',
        details: [
          _StageField('Teaching Faculty', teachersList.isNotEmpty ? '${teachersList.length} Faculty Members' : 'Not configured'),
          _StageField('Administrative Staff', teachersList.isNotEmpty ? 'Staff Roster Configured' : 'Not configured'),
          _StageField('Attendance Geofence', hasGeofence ? 'Campus Perimeter Enforced' : 'Not configured'),
        ],
      ),
      _SetupStageData(
        stepNumber: 8,
        name: 'Students Enrollment & Admissions',
        shortLabel: 'Students',
        isCompleted: studentsList.isNotEmpty,
        targetRoute: AppRoutes.students,
        summary: 'Admissions register, roll numbers, biometrics/photos, and academic records',
        details: [
          _StageField('Active Enrolled', studentsList.isNotEmpty ? '${studentsList.length} Enrolled Students' : 'Not configured'),
          _StageField('Admissions Open', studentsList.isNotEmpty ? 'Admissions Active' : 'Not configured'),
          _StageField('Documentation', studentsList.isNotEmpty ? 'Documentation Active' : 'Not configured'),
        ],
      ),
      _SetupStageData(
        stepNumber: 9,
        name: 'Guardians & Parent Portal Mapping',
        shortLabel: 'Guardians',
        isCompleted: guardiansList.isNotEmpty,
        targetRoute: AppRoutes.guardians,
        summary: 'Primary contact phone numbers, SMS notification channels, and emergency contacts',
        details: [
          _StageField('Registered Guardians', guardiansList.isNotEmpty ? '${guardiansList.length} Registered Guardians' : 'Not configured'),
          _StageField('SMS Alerts', guardiansList.isNotEmpty ? 'Notification Channel Active' : 'Not configured'),
          _StageField('Parent Portal Status', guardiansList.isNotEmpty ? 'Active' : 'Not configured'),
        ],
      ),
    ];

    final completedCount = stages.where((s) => s.isCompleted).length;
    final progressPct = (completedCount / stages.length * 100).round();

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFBF1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.check_circle, color: Color(0xFF0F766E), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'School Setup Center',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Foundational school database setup. Setup does not block daily admissions or fees.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => context.go(AppRoutes.plannerSchedule),
                            icon: const Icon(Icons.calendar_month_outlined, size: 16),
                            label: const Text('Open School Planner'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Text(
                              '$completedCount of ${stages.length} completed',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: completedCount / stages.length,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Overall setup completion: $progressPct%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (selectedSchoolId != null) ...[
              _buildCurriculumBanner(
                context,
                selectedSchoolId,
                selectedSchool?.name ?? 'School',
                selectedSchool?.board ?? 'CBSE',
                selectedSchool?.state,
                curriculumStatus,
                curriculumState?.isPopulating ?? false,
              ),
              const SizedBox(height: 20),
            ],

            // 2. Stages List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final stage = stages[index];
                return _buildStageCard(context, stage);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageCard(BuildContext context, _SetupStageData stage) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stage.isCompleted ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: stage.isCompleted ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: stage.isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${stage.stepNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            stage.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: stage.isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: stage.isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Text(
                              stage.isCompleted ? 'Completed' : 'Not Configured',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: stage.isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stage.summary,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: stage.onCustomAction ?? (stage.targetRoute.isNotEmpty ? () => context.go(stage.targetRoute) : null),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: Text(stage.actionLabel ?? (stage.isCompleted ? 'View' : 'Configure')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 10,
                children: stage.details.map((d) {
                  return SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.field,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.value,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurriculumBanner(
    BuildContext context,
    String schoolId,
    String schoolName,
    String board,
    String? state,
    CurriculumStatusModel status,
    bool isPopulating,
  ) {
    final isPopulated = status.isPopulated;
    final boardDisplay = (board.toUpperCase() == 'STATE' && state != null && state.isNotEmpty)
        ? '$state State Board'
        : board;

    final badgeBg = isPopulated
        ? const Color(0xFFDCFCE7)
        : (status.verifiedCurriculumAvailable ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2));
    final badgeBorder = isPopulated
        ? const Color(0xFF86EFAC)
        : (status.verifiedCurriculumAvailable ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5));
    final badgeText = isPopulated
        ? const Color(0xFF15803D)
        : (status.verifiedCurriculumAvailable ? const Color(0xFFB45309) : const Color(0xFFB91C1C));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPopulated ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopulated ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPopulated
                      ? const Color(0xFFDCFCE7)
                      : (status.verifiedCurriculumAvailable ? const Color(0xFFE0E7FF) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPopulated
                      ? Icons.verified
                      : (status.verifiedCurriculumAvailable ? Icons.auto_stories : Icons.warning_amber_rounded),
                  color: isPopulated
                      ? const Color(0xFF15803D)
                      : (status.verifiedCurriculumAvailable ? const Color(0xFF4338CA) : const Color(0xFFDC2626)),
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
                        const Text(
                          'Automatic Board-Based Syllabus Engine',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeBorder),
                          ),
                          child: Text(
                            status.statusBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPopulated
                          ? 'Official $boardDisplay syllabus resolved and verified. Isolated per campus with exam question mapping.'
                          : (status.verifiedCurriculumAvailable
                              ? 'EduPulse automatically populates official curriculum for $boardDisplay without manual entry.'
                              : 'Verified curriculum unavailable for $boardDisplay. You can import or create a custom syllabus.'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPopulated)
                    ElevatedButton.icon(
                      onPressed: isPopulating || !status.verifiedCurriculumAvailable
                          ? null
                          : () async {
                              final success = await ref
                                  .read(curriculumStatusProvider(schoolId).notifier)
                                  .autoPopulateCurriculum();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Official syllabus auto-populated successfully!'
                                          : 'Failed to auto-populate syllabus. Please check board settings.',
                                    ),
                                    backgroundColor: success ? const Color(0xFF0F766E) : Colors.red,
                                  ),
                                );
                              }
                              if (success) {
                                ref.invalidate(schoolSyllabusListProvider(schoolId));
                              }
                            },
                      icon: isPopulating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(
                        isPopulating
                            ? 'Populating...'
                            : (!status.verifiedCurriculumAvailable ? 'Curriculum Unavailable' : 'Auto-Populate Syllabus'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        elevation: 0,
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ReviewEditSyllabusDialog.show(
                        context,
                        schoolId: schoolId,
                        schoolName: schoolName,
                        board: board,
                        state: state,
                      );
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: Text(isPopulated ? 'Review & Edit Syllabus' : 'Preview Syllabus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildCurriculumChip('Affiliation Board', boardDisplay),
              if (state != null) _buildCurriculumChip('State', state),
              _buildCurriculumChip('Total Chapters', '${status.totalChapters} Chapters'),
              _buildCurriculumChip('Total Topics', '${status.totalTopics} Topics'),
              if (status.source != null)
                _buildCurriculumChip('Source', '${status.source} (${status.sourceVersion ?? "Official"})'),
              if (status.derivedFrom != null)
                _buildCurriculumChip('Derivation', status.derivedFrom!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStageData {
  final int stepNumber;
  final String name;
  final String shortLabel;
  final bool isCompleted;
  final String targetRoute;
  final String summary;
  final List<_StageField> details;
  final VoidCallback? onCustomAction;
  final String? actionLabel;

  const _SetupStageData({
    required this.stepNumber,
    required this.name,
    required this.shortLabel,
    required this.isCompleted,
    required this.targetRoute,
    required this.summary,
    required this.details,
    this.onCustomAction,
    this.actionLabel,
  });
}

class _StageField {
  final String field;
  final String value;
  const _StageField(this.field, this.value);
}
