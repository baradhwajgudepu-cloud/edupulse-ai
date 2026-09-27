import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import '../../../../core/routing/routes.dart';
import '../../data/models/planner_models.dart';
import '../../data/models/academic_planning_models.dart';
import '../../data/models/timetable_models.dart';
import '../providers/planner_providers.dart';
import '../providers/academic_planning_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class PlannerScheduleScreen extends ConsumerStatefulWidget {
  const PlannerScheduleScreen({super.key});

  @override
  ConsumerState<PlannerScheduleScreen> createState() => _PlannerScheduleScreenState();
}

class _PlannerScheduleScreenState extends ConsumerState<PlannerScheduleScreen> {
  final _scrollController = ScrollController();
  final _leavesKey = GlobalKey();
  final _examsKey = GlobalKey();
  final _circularsKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  final _eventsKey = GlobalKey();
  final _timelineKey = GlobalKey();
  final _recoveryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshAllData() {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId != null) {
      ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
      ref.read(eventsListProvider.notifier).fetchEvents();
      ref.read(examsListProvider.notifier).fetchExams();
      ref.read(announcementsListProvider.notifier).fetchAnnouncements();
      ref.read(teacherLeavesProvider.notifier).fetchLeaves();
      ref.read(plannerNotificationsProvider.notifier).fetchNotifications();
    }
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return Scaffold(
        backgroundColor: EduPulseTheme.slate50,
        body: const Center(
          child: Text(
            'Please select a school campus from the header to view School Operations & Planning.',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final ayState = ref.watch(academicYearsProvider(schoolId));
    final eventsState = ref.watch(eventsListProvider);
    final examsState = ref.watch(examsListProvider);
    final announcementsState = ref.watch(announcementsListProvider);
    final leavesState = ref.watch(teacherLeavesProvider);
    final notificationsState = ref.watch(plannerNotificationsProvider);
    final timelineItems = ref.watch(operationalTimelineProvider);
    final schoolName = ref.watch(selectedSchoolNameProvider);

    final activeAy = ayState.years.where((y) => y.isCurrent).firstOrNull ??
        (ayState.years.isNotEmpty ? ayState.years.first : null);
    final activeAyLabel = activeAy != null ? activeAy.name : '2026-2027';

    // Current date format
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateString = '${now.day} ${months[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: EduPulseTheme.slate50,
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner with Context Chips & Actions
            _buildHeaderBanner(
              schoolName: schoolName.isNotEmpty ? schoolName : 'Active School',
              ayLabel: activeAyLabel,
              dateString: dateString,
              onRefresh: _refreshAllData,
            ),
            const SizedBox(height: 16),

            // 2. Quick Actions Row
            _buildQuickActionsSection(context),
            const SizedBox(height: 20),

            // 2.5 Academic Planning Intelligence Banner
            if (activeAy != null) ...[
              _buildAcademicPlanningIntelligenceBanner(context, schoolId, activeAy.id),
              const SizedBox(height: 20),
              Container(key: _recoveryKey, child: _buildAITimetableRecoverySection(context, schoolId, activeAy.id)),
              const SizedBox(height: 20),
            ],

            // 3. Teacher Leave Approvals
            Container(key: _leavesKey, child: _buildTeacherLeavesSection(context, leavesState)),
            const SizedBox(height: 20),

            // 4. Exams & Assessments
            Container(key: _examsKey, child: _buildExamsSection(context, examsState)),
            const SizedBox(height: 20),

            // 5. Circulars & Announcements
            Container(key: _circularsKey, child: _buildCircularsSection(context, announcementsState)),
            const SizedBox(height: 20),

            // 6. Notifications
            Container(key: _notificationsKey, child: _buildNotificationsSection(context, notificationsState)),
            const SizedBox(height: 20),

            // 7. School Events
            Container(key: _eventsKey, child: _buildEventsSection(context, eventsState)),
            const SizedBox(height: 20),

            // 8. Unified School Operations Timeline
            Container(key: _timelineKey, child: _buildOperationsTimelineSection(timelineItems)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER BANNER & CONTEXT CHIPS
  // ==========================================
  Widget _buildHeaderBanner({
    required String schoolName,
    required String ayLabel,
    required String dateString,
    required VoidCallback onRefresh,
  }) {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hub_outlined, color: Color(0xFF0F766E), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'School Operations & Planning',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Plan, approve, publish and coordinate school operations.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Context Chips Row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildContextChip(
                icon: Icons.school_outlined,
                label: 'Campus: $schoolName',
                bg: const Color(0xFFF0FDFA),
                border: const Color(0xFF99F6E4),
                text: const Color(0xFF0F766E),
              ),
              _buildContextChip(
                icon: Icons.calendar_today_outlined,
                label: 'Session: $ayLabel',
                bg: const Color(0xFFF0FDF4),
                border: const Color(0xFFBBF7D0),
                text: const Color(0xFF15803D),
              ),
              _buildContextChip(
                icon: Icons.access_time_outlined,
                label: 'Current Term: Term 1',
                bg: const Color(0xFFEFF6FF),
                border: const Color(0xFFBFDBFE),
                text: const Color(0xFF1D4ED8),
              ),
              _buildContextChip(
                icon: Icons.today_outlined,
                label: 'Date: $dateString',
                bg: const Color(0xFFF8FAFC),
                border: const Color(0xFFE2E8F0),
                text: const Color(0xFF475569),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextChip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color border,
    required Color text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // QUICK ACTIONS BAR
  // ==========================================
  Widget _buildQuickActionsSection(BuildContext context) {
    final actions = [
      _QuickActionItem(
        label: 'Review Leave Requests',
        icon: Icons.approval_outlined,
        onTap: () => _scrollToKey(_leavesKey),
      ),
      _QuickActionItem(
        label: 'Create Exam',
        icon: Icons.note_add_outlined,
        onTap: () => _showCreateExamDialog(context),
      ),
      _QuickActionItem(
        label: 'Publish Exam',
        icon: Icons.publish_outlined,
        onTap: () => _scrollToKey(_examsKey),
      ),
      _QuickActionItem(
        label: 'Create Circular',
        icon: Icons.campaign_outlined,
        onTap: () => _showCreateCircularDialog(context),
      ),
      _QuickActionItem(
        label: 'Create Notification',
        icon: Icons.notifications_none_outlined,
        onTap: () => _showCreateNotificationDialog(context),
      ),
      _QuickActionItem(
        label: 'Add School Event',
        icon: Icons.event_outlined,
        onTap: () => _showCreateEventDialog(context),
      ),
      _QuickActionItem(
        label: 'Open Academic Calendar',
        icon: Icons.calendar_month_outlined,
        onTap: () => context.go(AppRoutes.plannerCalendar),
      ),
      _QuickActionItem(
        label: 'Manage Timetable',
        icon: Icons.table_chart_outlined,
        onTap: () => context.go(AppRoutes.timetables),
      ),
      _QuickActionItem(
        label: 'Syllabus & Curriculum',
        icon: Icons.auto_stories_outlined,
        onTap: () => context.go(AppRoutes.syllabusEditor),
      ),
      _QuickActionItem(
        label: 'Completion Analytics',
        icon: Icons.insights_outlined,
        onTap: () => context.go(AppRoutes.academicPlanning),
      ),
      _QuickActionItem(
        label: 'Holiday Recovery',
        icon: Icons.auto_mode_outlined,
        onTap: () => _scrollToKey(_recoveryKey),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt, size: 16, color: Color(0xFF0F766E)),
              SizedBox(width: 6),
              Text(
                'Operational Quick Actions',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map((act) {
              return InkWell(
                onTap: act.onTap,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(act.icon, size: 14, color: const Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      Text(
                        act.label,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ACADEMIC PLANNING INTELLIGENCE BANNER
  // ==========================================
  Widget _buildAcademicPlanningIntelligenceBanner(BuildContext context, String schoolId, String ayId) {
    return Consumer(
      builder: (context, ref, child) {
        final summaryAsync = ref.watch(academicPlanningSummaryProvider((
          schoolId: schoolId,
          academicYearId: ayId,
        )));

        return summaryAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (summary) {
            final atRiskTotal = summary.atRiskCount + summary.likelyToMissCount;
            final hasAdapt = summary.adaptiveRecommendations.isNotEmpty;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology, color: Color(0xFF0F766E), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Academic Planning & Completion Intelligence',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${summary.schoolWideCompletionPct.toStringAsFixed(1)}% Completed',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                              ),
                            ),
                            if (atRiskTotal > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$atRiskTotal At-Risk Subjects',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasAdapt
                              ? 'Continuous timetable recommendations available: +1 period/week suggested to restore exam buffer.'
                              : 'Real-time syllabus pace tracking active across ${summary.totalSubjectsTracked} subjects.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                    ),
                    icon: const Icon(Icons.auto_stories, size: 14),
                    label: const Text('Syllabus Editor'),
                    onPressed: () => context.go(AppRoutes.syllabusEditor),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.insights, size: 14),
                    label: const Text('View Analytics'),
                    onPressed: () => context.go(AppRoutes.academicPlanning),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 1. TEACHER LEAVE APPROVALS SECTION
  // ==========================================
  Widget _buildTeacherLeavesSection(BuildContext context, TeacherLeavesState state) {
    final pendingCount = state.leaves.where((l) => l.status == 'PENDING').length;
    final approvedCount = state.leaves.where((l) => l.status == 'APPROVED').length;
    final rejectedCount = state.leaves.where((l) => l.status == 'REJECTED').length;

    return EduPulseCard(
      padding: EduPulseCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_note_outlined, color: Color(0xFFD97706), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Teacher Leave Approvals',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Review, approve, and manage faculty time-off requests.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final schoolId = ref.read(selectedSchoolIdProvider);
                  if (schoolId != null) {
                    ref.read(teacherLeavesProvider.notifier).fetchLeaves();
                  }
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Review Leave Requests', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics Pills
          Row(
            children: [
              _buildMetricPill('Pending Review', pendingCount.toString(), const Color(0xFFFEF3C7), const Color(0xFFB45309)),
              const SizedBox(width: 8),
              _buildMetricPill('Approved', approvedCount.toString(), const Color(0xFFDCFCE7), const Color(0xFF15803D)),
              const SizedBox(width: 8),
              _buildMetricPill('Rejected', rejectedCount.toString(), const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              _buildMetricPill('Total Logged', state.leaves.length.toString(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
            ],
          ),
          const SizedBox(height: 16),

          // Body Content
          if (state.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (state.leaves.isEmpty)
            _buildEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No teacher leave requests yet.',
              subtitle: 'Leave requests submitted by teachers through their portal will appear here for administrative approval.',
              actionButton: ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.teachers),
                icon: const Icon(Icons.people_outline, size: 14),
                label: const Text('Manage Teachers', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                horizontalMargin: 12,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('TEACHER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('LEAVE TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('DATES & DURATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('REASON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                ],
                rows: state.leaves.map((leave) {
                  final isPending = leave.status == 'PENDING';
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(leave.teacherName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
                            if (leave.teacherDesignation != null)
                              Text(leave.teacherDesignation!, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            leave.leaveType,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${leave.startDate} to ${leave.endDate} (${leave.daysCount}d)',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            leave.reason,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_buildStatusBadge(leave.status)),
                      DataCell(
                        isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _showReviewLeaveDialog(context, leave, isApprove: true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    onPressed: () => _showReviewLeaveDialog(context, leave, isApprove: false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFBE123C),
                                      side: const BorderSide(color: Color(0xFFFECDD3)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ],
                              )
                            : Text(
                                leave.reviewerRemarks ?? 'Reviewed',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. EXAMS & ASSESSMENTS SECTION
  // ==========================================
  Widget _buildExamsSection(BuildContext context, ExamsListState state) {
    final draftCount = state.examinations.where((e) => e.status.toUpperCase() == 'DRAFT').length;
    final scheduledCount = state.examinations.where((e) => e.status.toUpperCase() == 'SCHEDULED').length;
    final publishedCount = state.examinations.where((e) => e.status.toUpperCase() == 'PUBLISHED').length;

    return EduPulseCard(
      padding: EduPulseCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.quiz_outlined, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Exams & Assessments',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Exam cycles, timetable date sheets, and publication status.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateExamDialog(context),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create Exam', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics Pills
          Row(
            children: [
              _buildMetricPill('Draft', draftCount.toString(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
              const SizedBox(width: 8),
              _buildMetricPill('Scheduled', scheduledCount.toString(), const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              _buildMetricPill('Published', publishedCount.toString(), const Color(0xFFDCFCE7), const Color(0xFF15803D)),
              const SizedBox(width: 8),
              _buildMetricPill('Total Cycles', state.examinations.length.toString(), const Color(0xFFF8FAFC), const Color(0xFF0F172A)),
            ],
          ),
          const SizedBox(height: 16),

          if (state.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (state.examinations.isEmpty)
            _buildEmptyState(
              icon: Icons.quiz_outlined,
              title: 'No exams have been created yet.',
              subtitle: 'Exam cycles, date sheets, and room allocations created here will coordinate faculty invigilation.',
              actionButton: ElevatedButton.icon(
                onPressed: () => _showCreateExamDialog(context),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create Exam', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                horizontalMargin: 12,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('EXAM NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('DATE RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('SCHEDULES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                ],
                rows: state.examinations.map((exam) {
                  final canPublish = exam.status.toUpperCase() == 'DRAFT' || exam.status.toUpperCase() == 'SCHEDULED';
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(exam.examName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                          child: Text(exam.examType, style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      DataCell(Text('${exam.startDate} to ${exam.endDate}', style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      DataCell(Text('${exam.schedules.length} papers', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                      DataCell(_buildStatusBadge(exam.status)),
                      DataCell(
                        canPublish
                            ? ElevatedButton.icon(
                                onPressed: () async {
                                  final ok = await ref.read(examsListProvider.notifier).publishExam(exam.id);
                                  if (ok) {
                                    await ref.read(examsListProvider.notifier).fetchExams();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Examination published successfully.')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.publish, size: 12),
                                label: const Text('Publish Exam', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                              )
                            : const Text('Published', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. CIRCULARS & ANNOUNCEMENTS SECTION
  // ==========================================
  Widget _buildCircularsSection(BuildContext context, AnnouncementsListState state) {
    final draftCount = state.announcements.where((a) => a.status == AnnouncementStatus.draft).length;
    final publishedCount = state.announcements.where((a) => a.status == AnnouncementStatus.published).length;

    return EduPulseCard(
      padding: EduPulseCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign_outlined, color: Color(0xFF9333EA), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Circulars & Announcements',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Administrative circulars, directives, and campus broadcast notices.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateCircularDialog(context),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create Circular', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics Pills
          Row(
            children: [
              _buildMetricPill('Draft', draftCount.toString(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
              const SizedBox(width: 8),
              _buildMetricPill('Published', publishedCount.toString(), const Color(0xFFDCFCE7), const Color(0xFF15803D)),
              const SizedBox(width: 8),
              _buildMetricPill('Total Circulars', state.announcements.length.toString(), const Color(0xFFFAF5FF), const Color(0xFF9333EA)),
            ],
          ),
          const SizedBox(height: 16),

          if (state.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (state.announcements.isEmpty)
            _buildEmptyState(
              icon: Icons.campaign_outlined,
              title: 'No circulars have been published yet.',
              subtitle: 'Official administrative notices, directives, and term announcements will appear here.',
              actionButton: ElevatedButton.icon(
                onPressed: () => _showCreateCircularDialog(context),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create Circular', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                horizontalMargin: 12,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('TITLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('AUDIENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('PRIORITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                ],
                rows: state.announcements.map((ann) {
                  final isDraft = ann.status == AnnouncementStatus.draft;
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ann.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
                            Text(ann.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      DataCell(Text(ann.audienceType.name.toUpperCase(), style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      DataCell(
                        Text(ann.priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ann.priority == 'HIGH' ? Colors.red : const Color(0xFF475569))),
                      ),
                      DataCell(_buildStatusBadge(ann.status.name.toUpperCase())),
                      DataCell(
                        isDraft
                            ? ElevatedButton.icon(
                                onPressed: () async {
                                  final ok = await ref.read(announcementsListProvider.notifier).publishAnnouncement(ann.id);
                                  if (ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Circular published successfully.')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send, size: 12),
                                label: const Text('Publish', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                              )
                            : const Text('Published', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. NOTIFICATIONS SECTION
  // ==========================================
  Widget _buildNotificationsSection(BuildContext context, PlannerNotificationsState state) {
    final publishedCount = state.notifications.where((n) => n.status == 'PUBLISHED').length;
    final scheduledCount = state.notifications.where((n) => n.status == 'SCHEDULED').length;

    return EduPulseCard(
      padding: EduPulseCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Notifications & Alerts',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Instant alerts and mobile push notifications to campus community.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateNotificationDialog(context),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create Notification', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics Pills
          Row(
            children: [
              _buildMetricPill('Published', publishedCount.toString(), const Color(0xFFDCFCE7), const Color(0xFF15803D)),
              const SizedBox(width: 8),
              _buildMetricPill('Scheduled', scheduledCount.toString(), const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              _buildMetricPill('Total Logged', state.notifications.length.toString(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
              const SizedBox(width: 8),
              _buildMetricPill('Audience Scope', 'Staff • Teachers • Parents • Leadership', const Color(0xFFF0FDFA), const Color(0xFF0F766E)),
            ],
          ),
          const SizedBox(height: 16),

          if (state.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (state.notifications.isEmpty)
            _buildEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications scheduled yet.',
              subtitle: 'Create high-priority or broadcast notifications to staff, teachers, parents, or school leadership.',
              actionButton: ElevatedButton.icon(
                onPressed: () => _showCreateNotificationDialog(context),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create Notification', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                horizontalMargin: 12,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('TITLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('AUDIENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('PRIORITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                ],
                rows: state.notifications.map((notif) {
                  final isScheduled = notif.status == 'SCHEDULED';
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notif.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
                            Text(notif.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      DataCell(Text(notif.targetAudience, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      DataCell(
                        Text(notif.priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: notif.priority == 'URGENT' || notif.priority == 'HIGH' ? Colors.red : const Color(0xFF475569))),
                      ),
                      DataCell(_buildStatusBadge(notif.status)),
                      DataCell(
                        isScheduled
                            ? ElevatedButton.icon(
                                onPressed: () async {
                                  final ok = await ref.read(plannerNotificationsProvider.notifier).publishNotification(notif.id);
                                  if (ok) {
                                    await ref.read(plannerNotificationsProvider.notifier).fetchNotifications();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Notification published successfully.')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.send, size: 12),
                                label: const Text('Publish Now', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Dispatched', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. SCHOOL EVENTS SECTION
  // ==========================================
  Widget _buildEventsSection(BuildContext context, EventsListState state) {
    final holidaysCount = state.events.where((e) => e.isHoliday).length;
    final regularEventsCount = state.events.length - holidaysCount;

    return EduPulseCard(
      padding: EduPulseCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.celebration_outlined, color: Color(0xFFDB2777), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'School Events & Holidays',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'PTA meetings, holidays, functions, and campus events.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.plannerCalendar),
                    icon: const Icon(Icons.calendar_month, size: 14),
                    label: const Text('Open Calendar', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateEventDialog(context),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Event', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics Pills
          Row(
            children: [
              _buildMetricPill('School Events', regularEventsCount.toString(), const Color(0xFFFDF2F8), const Color(0xFFDB2777)),
              const SizedBox(width: 8),
              _buildMetricPill('Holidays', holidaysCount.toString(), const Color(0xFFFEF3C7), const Color(0xFFB45309)),
              const SizedBox(width: 8),
              _buildMetricPill('Total Logged', state.events.length.toString(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
            ],
          ),
          const SizedBox(height: 16),

          if (state.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (state.events.isEmpty)
            _buildEmptyState(
              icon: Icons.celebration_outlined,
              title: 'No school events scheduled yet.',
              subtitle: 'PTA meetings, annual functions, sports meets, and official academic holidays appear here.',
              actionButton: ElevatedButton.icon(
                onPressed: () => _showCreateEventDialog(context),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add School Event', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                horizontalMargin: 12,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('EVENT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('DATE & TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('VENUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('AUDIENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                ],
                rows: state.events.map((ev) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            if (ev.isHoliday) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                child: const Text('HOLIDAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(ev.eventName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                      DataCell(Text('${ev.eventDate} • ${ev.startTime}', style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      DataCell(Text(ev.venue ?? 'Campus', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                      DataCell(Text(ev.targetAudience.name.toUpperCase(), style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      DataCell(_buildStatusBadge(ev.status.name.toUpperCase())),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. UNIFIED OPERATIONS TIMELINE SECTION
  // ==========================================
  Widget _buildOperationsTimelineSection(List<PlannerTimelineItem> items) {
    return EduPulseCard(
      padding: EduPulseCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.timeline_outlined, color: Color(0xFF0F766E), size: 20),
              SizedBox(width: 8),
              Text(
                'School Operations Timeline',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Unified chronological audit and coordination log across all school operations.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          if (items.isEmpty)
            _buildEmptyState(
              icon: Icons.timeline,
              title: 'No operational events logged yet.',
              subtitle: 'Operations logged across teacher leaves, exams, circulars, notifications, and events will appear here chronologically.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 10 ? 10 : items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = items[index];
                IconData typeIcon;
                Color typeColor;

                switch (item.type) {
                  case PlannerTimelineType.leave:
                    typeIcon = Icons.event_note_outlined;
                    typeColor = const Color(0xFFD97706);
                    break;
                  case PlannerTimelineType.exam:
                    typeIcon = Icons.quiz_outlined;
                    typeColor = const Color(0xFF2563EB);
                    break;
                  case PlannerTimelineType.circular:
                    typeIcon = Icons.campaign_outlined;
                    typeColor = const Color(0xFF9333EA);
                    break;
                  case PlannerTimelineType.notification:
                    typeIcon = Icons.notifications_outlined;
                    typeColor = const Color(0xFF059669);
                    break;
                  case PlannerTimelineType.event:
                    typeIcon = Icons.celebration_outlined;
                    typeColor = const Color(0xFFDB2777);
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusBadge(item.status),
                          const SizedBox(height: 4),
                          Text(
                            item.timestamp.length >= 10 ? item.timestamp.substring(0, 10) : item.timestamp,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildMetricPill(String label, String value, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: text.withOpacity(0.8))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'PUBLISHED':
      case 'COMPLETED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'PENDING':
      case 'SCHEDULED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'REJECTED':
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'DRAFT':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? actionButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 14),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOGS
  // ==========================================
  void _showReviewLeaveDialog(BuildContext context, LeaveRequest leave, {required bool isApprove}) {
    final remarksController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isApprove ? 'Approve Leave Request' : 'Reject Leave Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teacher: ${leave.teacherName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Type: ${leave.leaveType} (${leave.startDate} to ${leave.endDate}, ${leave.daysCount} days)'),
              const SizedBox(height: 4),
              Text('Reason: ${leave.reason}'),
              const SizedBox(height: 14),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Reviewer Remarks (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final decision = isApprove ? 'APPROVE' : 'REJECT';
                final ok = await ref.read(teacherLeavesProvider.notifier).reviewLeave(
                      leave.id,
                      decision: decision,
                      remarks: remarksController.text.trim(),
                    );
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Leave request ${isApprove ? "approved" : "rejected"} successfully.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? const Color(0xFF0F766E) : const Color(0xFFBE123C),
                foregroundColor: Colors.white,
              ),
              child: Text(isApprove ? 'Confirm Approval' : 'Confirm Rejection'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateExamDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String examType = 'UNIT_TEST';
    final startCtrl = TextEditingController(text: '2026-10-01');
    final endCtrl = TextEditingController(text: '2026-10-10');
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Examination Cycle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Exam Name (e.g. Unit Test 1)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SafeDropdownButtonFormField<String>(
                      value: examType,
                      fallbackValue: 'UNIT_TEST',
                      decoration: const InputDecoration(
                        labelText: 'Exam Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'UNIT_TEST', child: Text('Unit Test')),
                        DropdownMenuItem(value: 'WEEKLY_TEST', child: Text('Weekly Test')),
                        DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly Test')),
                        DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly Examination')),
                        DropdownMenuItem(value: 'HALF_YEARLY', child: Text('Half Yearly Examination')),
                        DropdownMenuItem(value: 'PRE_FINAL', child: Text('Pre-Final Examination')),
                        DropdownMenuItem(value: 'ANNUAL', child: Text('Annual Examination')),
                        DropdownMenuItem(value: 'FINAL', child: Text('Final Board Examination')),
                        DropdownMenuItem(value: 'INTERNAL_ASSESSMENT', child: Text('Internal Assessment')),
                        DropdownMenuItem(value: 'PRACTICAL', child: Text('Practical Examination')),
                      ],
                      onChanged: isSubmitting
                          ? null
                          : (v) {
                              if (v != null) setDialogState(() => examType = v);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Start Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'End Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() => errorMessage = 'Please enter an examination name.');
                            return;
                          }

                          final start = startCtrl.text.trim();
                          final end = endCtrl.text.trim();
                          if (start.isEmpty || end.isEmpty) {
                            setDialogState(() => errorMessage = 'Please enter valid start and end dates.');
                            return;
                          }

                          try {
                            final sDate = DateTime.parse(start);
                            final eDate = DateTime.parse(end);
                            if (eDate.isBefore(sDate)) {
                              setDialogState(() => errorMessage = 'End Date cannot be earlier than Start Date.');
                              return;
                            }
                          } catch (_) {
                            setDialogState(() => errorMessage = 'Dates must be in YYYY-MM-DD format.');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          final ok = await ref.read(examsListProvider.notifier).createExaminationWizard(
                                examName: name,
                                examType: examType,
                                startDate: start,
                                endDate: end,
                                schedules: [],
                              );

                          if (ok) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            await ref.read(examsListProvider.notifier).fetchExams();
                            ref.invalidate(calendarFeedProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Exam cycle created successfully.')),
                              );
                            }
                          } else {
                            final err = ref.read(examsListProvider).error;
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = err != null && err.isNotEmpty
                                  ? 'Unable to create examination: $err'
                                  : 'Failed to create exam cycle. Please check dates and try again.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Exam'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateCircularDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String priority = 'NORMAL';
    String audienceType = 'ROLE';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Official Circular'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Circular Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Message Body', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SafeDropdownButtonFormField<String>(
                      value: audienceType,
                      fallbackValue: 'ROLE',
                      decoration: const InputDecoration(labelText: 'Audience Scope', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'ROLE', child: Text('By Role (Staff/Teachers/Parents)')),
                        DropdownMenuItem(value: 'CLASS', child: Text('By Class')),
                        DropdownMenuItem(value: 'SECTION', child: Text('By Section')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => audienceType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    SafeDropdownButtonFormField<String>(
                      value: priority,
                      fallbackValue: 'NORMAL',
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                        DropdownMenuItem(value: 'HIGH', child: Text('High')),
                        DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => priority = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop();
                    final ok = await ref.read(announcementsListProvider.notifier).createAnnouncement(
                          title: titleCtrl.text.trim(),
                          message: messageCtrl.text.trim(),
                          audienceType: audienceType,
                          priority: priority,
                        );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Circular created successfully.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                  child: const Text('Save Circular'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateNotificationDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String audience = 'PARENT';
    String priority = 'NORMAL';
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Instant Notification'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notification Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notification Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SafeDropdownButtonFormField<String>(
                      value: audience,
                      fallbackValue: 'PARENT',
                      decoration: const InputDecoration(
                        labelText: 'Target Audience',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'PARENT', child: Text('Parents')),
                        DropdownMenuItem(value: 'TEACHER', child: Text('Teachers')),
                        DropdownMenuItem(value: 'STAFF', child: Text('Staff & Faculty')),
                        DropdownMenuItem(value: 'PRINCIPAL', child: Text('School Leadership')),
                      ],
                      onChanged: isSubmitting
                          ? null
                          : (v) {
                              if (v != null) setDialogState(() => audience = v);
                            },
                    ),
                    const SizedBox(height: 12),
                    SafeDropdownButtonFormField<String>(
                      value: priority,
                      fallbackValue: 'NORMAL',
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                        DropdownMenuItem(value: 'HIGH', child: Text('High')),
                        DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                      ],
                      onChanged: isSubmitting
                          ? null
                          : (v) {
                              if (v != null) setDialogState(() => priority = v);
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            setDialogState(() => errorMessage = 'Please enter a notification title.');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          final ok = await ref.read(plannerNotificationsProvider.notifier).createNotification(
                                title: title,
                                message: messageCtrl.text.trim(),
                                targetAudience: audience,
                                priority: priority,
                              );

                          if (ok) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            await ref.read(plannerNotificationsProvider.notifier).fetchNotifications();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notification dispatched successfully.')),
                              );
                            }
                          } else {
                            final err = ref.read(plannerNotificationsProvider).error;
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = err ?? 'Failed to dispatch notification. Please try again.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Dispatch'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateEventDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: '2026-10-15');
    final startTimeCtrl = TextEditingController(text: '09:00');
    final endTimeCtrl = TextEditingController(text: '12:00');
    final venueCtrl = TextEditingController(text: 'Main Auditorium');
    bool isHoliday = false;
    String audience = 'ALL';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add School Event / Holiday'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(labelText: 'Event Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startTimeCtrl,
                            decoration: const InputDecoration(labelText: 'Start (HH:MM)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: endTimeCtrl,
                            decoration: const InputDecoration(labelText: 'End (HH:MM)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: venueCtrl,
                      decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: isHoliday,
                      title: const Text('Official Academic Holiday', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        setDialogState(() => isHoliday = v ?? false);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop();
                    final ok = await ref.read(eventsListProvider.notifier).createEvent(
                          eventName: nameCtrl.text.trim(),
                          eventDate: dateCtrl.text.trim(),
                          startTime: startTimeCtrl.text.trim(),
                          endTime: endTimeCtrl.text.trim(),
                          venue: venueCtrl.text.trim(),
                          targetAudience: audience,
                          isHoliday: isHoliday,
                        );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('School event created successfully.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                  child: const Text('Save Event'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // AI TIMETABLE RECOVERY & HOLIDAY REBALANCING
  // ==========================================
  Widget _buildAITimetableRecoverySection(BuildContext context, String schoolId, String ayId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF0F766E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'AI Timetable Recovery Center',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Minimum-Disruption Engine: Analyzes holiday impact and rebalances published timetables.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: Color(0xFF0F766E)),
                    SizedBox(width: 4),
                    Text(
                      'Zero-Cascade Policy Active',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'When public or principal holidays fall on teaching days, the recovery engine detects affected slots, identifies candidate free periods, and prepares surgical slot reassignments while preserving all unaffected periods.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.campaign, size: 18),
                label: const Text('Declare Principal Holiday'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showPrincipalHolidayDeclareDialog(context, schoolId, ayId),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.troubleshoot, size: 18, color: Color(0xFF0F766E)),
                label: const Text('Review Holiday Impact & AI Recovery', style: TextStyle(color: Color(0xFF0F766E))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showReviewHolidayImpactPicker(context, schoolId, ayId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPrincipalHolidayDeclareDialog(BuildContext context, String schoolId, String ayId) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime chosenDate = DateTime.now().add(const Duration(days: 1));
    bool isNonWorking = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Declare Principal Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select holiday date:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: chosenDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2028),
                        );
                        if (picked != null) {
                          setDialogState(() => chosenDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(chosenDate.toIso8601String().substring(0, 10), style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Icon(Icons.calendar_month, size: 18, color: Color(0xFF0F766E)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Holiday Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Cyclone Red Alert / Campus Maintenance',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Administrative justification',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: isNonWorking,
                      onChanged: (val) => setDialogState(() => isNonWorking = val),
                      title: const Text('Designate as Non-Working Day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop();
                    final dateStr = chosenDate.toIso8601String().substring(0, 10);
                    final ok = await ref
                        .read(academicPlanningControllerProvider.notifier)
                        .declarePrincipalHoliday(
                          schoolId: schoolId,
                          academicYearId: ayId,
                          eventDate: dateStr,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          isNonWorkingDay: isNonWorking,
                        );
                    if (ok && mounted) {
                      _refreshAllData();
                      _showHolidayImpactRecoveryDialogDirect(context, schoolId, ayId, dateStr, titleController.text.trim());
                    }
                  },
                  child: const Text('Declare & Review Impact'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReviewHolidayImpactPicker(BuildContext context, String schoolId, String ayId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2028),
    );
    if (picked != null && mounted) {
      final dateStr = picked.toIso8601String().substring(0, 10);
      _showHolidayImpactRecoveryDialogDirect(context, schoolId, ayId, dateStr, 'Scheduled Holiday');
    }
  }

  void _showHolidayImpactRecoveryDialogDirect(
    BuildContext context,
    String schoolId,
    String ayId,
    String holidayDate,
    String holidayTitle,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return FutureBuilder<HolidayImpactData?>(
              future: ref.read(academicPlanningControllerProvider.notifier).fetchHolidayImpact(
                schoolId: schoolId,
                academicYearId: ayId,
                holidayDate: holidayDate,
              ),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    content: SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0F766E)),
                            SizedBox(height: 16),
                            Text('Analyzing Timetable Impact & Syllabus Risks...'),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final impact = snapshot.data;
                final affectedPeriods = impact?.affectedPeriodsCount ?? 0;

                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics_outlined, color: Color(0xFF0F766E), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Holiday Impact: $holidayTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(holidayDate, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 580,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildScheduleMetricBadge('Periods Affected', '$affectedPeriods', const Color(0xFFDC2626)),
                            const SizedBox(width: 10),
                            _buildScheduleMetricBadge('Sections Affected', '${impact?.affectedSectionsCount ?? 0}', const Color(0xFFD97706)),
                            const SizedBox(width: 10),
                            _buildScheduleMetricBadge('Teachers Impacted', '${impact?.affectedTeachersCount ?? 0}', const Color(0xFF7C3AED)),
                            const SizedBox(width: 10),
                            _buildScheduleMetricBadge('Syllabus Risks', '${impact?.syllabusRisksCount ?? 0}', const Color(0xFF0F766E)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (affectedPeriods == 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Zero timetable disruption detected. No published classes were scheduled on this holiday date.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Text(
                              '$affectedPeriods published timetable period(s) require rebalancing. The Minimum-Disruption AI Recovery Engine can generate conflict-free replacement slots without cascading disruptions.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                    if (affectedPeriods > 0)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Generate AI Recovery Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          _showAIEngineExecutionDialog(context, schoolId, ayId, holidayDate, holidayTitle);
                        },
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAIEngineExecutionDialog(
    BuildContext context,
    String schoolId,
    String ayId,
    String holidayDate,
    String holidayTitle,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return FutureBuilder<AIRecoveryPreview?>(
          future: ref.read(academicPlanningControllerProvider.notifier).generateHolidayRecovery(
            schoolId: schoolId,
            academicYearId: ayId,
            holidayDate: holidayDate,
          ),
          builder: (dialogCtx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 220,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0F766E)),
                        SizedBox(height: 16),
                        Text('Running Minimum-Disruption Engine...', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Checking teacher schedules, section rooms, and exam dates...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              );
            }

            final recovery = snap.data;
            if (recovery == null || recovery.changes.isEmpty) {
              return AlertDialog(
                title: const Text('AI Recovery Complete'),
                content: const Text('No rebalancing needed or candidate recovery slots were not required.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.task_alt, color: Color(0xFF0F766E), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('AI Rebalancing Plan: ${recovery.totalSlotsRecovered} Slots Moved', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(recovery.summary, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recovery.changes.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = recovery.changes[i];
                            return ListTile(
                              dense: true,
                              title: Text('${c.className} (${c.sectionName}) - ${c.subjectName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                '${c.originalDay} P${c.originalPeriodNumber} -> ${c.targetDay} P${c.targetPeriodNumber} (${c.targetDate}) | Teacher: ${c.teacherName}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                              ),
                              trailing: Text(c.action, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final rawChanges = recovery.changes.map((c) => c.toJson()).toList();
                    final ok = await ref.read(academicPlanningControllerProvider.notifier).applyHolidayRecovery(
                      recoveryId: recovery.recoveryId,
                      schoolId: schoolId,
                      academicYearId: ayId,
                      changes: rawChanges,
                      remarks: 'Approved by Principal for $holidayTitle',
                    );
                    if (ok && mounted) {
                      Navigator.of(ctx).pop();
                      _refreshAllData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Timetable updated and notifications dispatched to affected teachers.'),
                          backgroundColor: Color(0xFF0F766E),
                        ),
                      );
                    }
                  },
                  child: const Text('Approve & Dispatch Notifications'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleMetricBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}
