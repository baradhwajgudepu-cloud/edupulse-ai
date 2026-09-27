import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/child_syllabus_provider.dart';
import '../../data/models/child_syllabus_models.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ChildSyllabusScreen extends ConsumerStatefulWidget {
  final String? studentId;
  final String? schoolId;
  final String? academicYearId;

  const ChildSyllabusScreen({
    super.key,
    this.studentId,
    this.schoolId,
    this.academicYearId,
  });

  @override
  ConsumerState<ChildSyllabusScreen> createState() => _ChildSyllabusScreenState();
}

class _ChildSyllabusScreenState extends ConsumerState<ChildSyllabusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final dashState = ref.read(dashboardStateProvider);
    final authState = ref.read(authStateProvider);

    String? sId = widget.studentId;
    String? ayId = widget.academicYearId;
    String? schId = widget.schoolId;

    if (dashState is DashboardSuccess && dashState.data.selectedStudent != null) {
      final st = dashState.data.selectedStudent!;
      sId ??= st.id;
      ayId ??= st.academicYearId;
    }

    if (authState is Authenticated && authState.user.schools.isNotEmpty) {
      schId ??= authState.user.schools.first;
    }

    if (sId != null && schId != null && ayId != null) {
      ref.read(childSyllabusStateProvider.notifier).fetchChildProgress(
            studentId: sId,
            schoolId: schId,
            academicYearId: ayId,
          );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('d MMM yyyy').format(dt);
  }

  Color _badgeColor(String badge) {
    final b = badge.toLowerCase();
    if (b.contains('recovery')) {
      return const Color(0xFF0D9488);
    } else if (b.contains('behind')) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final state = ref.watch(childSyllabusStateProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Syllabus & Learning Pace',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: switch (state) {
        ChildSyllabusLoading() => const Center(child: CircularProgressIndicator()),
        ChildSyllabusError(:final message) => Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                  SizedBox(height: spacing.sm),
                  const Text('Unable to load syllabus progress', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: spacing.xs),
                  Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  SizedBox(height: spacing.md),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ChildSyllabusSuccess(:final progress) => RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [
                // Top Header Card
                _buildHeaderCard(progress, theme, spacing, radius),
                SizedBox(height: spacing.md),

                // Neutral Disclaimer Banner
                _buildParentSafeBanner(theme, spacing, radius),
                SizedBox(height: spacing.md),

                Text(
                  'Subjects & Curriculum Coverage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: spacing.sm),

                if (progress.subjects.isEmpty)
                  Container(
                    padding: EdgeInsets.all(spacing.xl),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey.shade400),
                        SizedBox(height: spacing.sm),
                        const Text('No subjects tracked for this term.'),
                      ],
                    ),
                  )
                else
                  ...progress.subjects.map(
                    (subj) => _buildSubjectCard(subj, theme, spacing, radius),
                  ),
              ],
            ),
          ),
        ChildSyllabusInitial() => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildHeaderCard(
    ChildSyllabusProgressResponse progress,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius.md),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.studentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    '${progress.className} - ${progress.sectionName}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${progress.overallCompletionPercentage.toStringAsFixed(1)}% Done',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(radius.sm),
            child: LinearProgressIndicator(
              value: (progress.overallCompletionPercentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentSafeBanner(
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF16A34A)),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              'Verified curriculum progress updated by subject faculty following each completed classroom period.',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(
    ChildSubjectProgress subj,
    ThemeData theme,
    AppSpacing spacing,
    AppRadius radius,
  ) {
    final bColor = _badgeColor(subj.statusBadge);

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: spacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.book_outlined, color: theme.colorScheme.primary, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                subj.subjectName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                subj.statusBadge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: bColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subj.teacherName != null) ...[
                Text(
                  'Faculty: ${subj.teacherName}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4.0),
              ],
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius.xs),
                      child: LinearProgressIndicator(
                        value: (subj.completionPercentage / 100.0).clamp(0.0, 1.0),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(bColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    '${subj.completedTopics}/${subj.totalTopics} (${subj.completionPercentage.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (subj.targetCompletionDate != null || subj.forecastCompletionDate != null) ...[
                SizedBox(height: spacing.xs),
                Wrap(
                  spacing: 12,
                  children: [
                    if (subj.targetCompletionDate != null)
                      Text(
                        'Target completion: ${_formatDate(subj.targetCompletionDate)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    if (subj.forecastCompletionDate != null)
                      Text(
                        'Expected completion: ${_formatDate(subj.forecastCompletionDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: bColor,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          if (subj.topics.isEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: const Text('No topic breakdown available.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...subj.topics.map((t) => _buildTopicItem(t, theme, spacing)),
        ],
      ),
    );
  }

  Widget _buildTopicItem(ChildTopicProgress topic, ThemeData theme, AppSpacing spacing) {
    IconData icon;
    Color iconColor;
    String statusLabel;

    if (topic.isCompleted) {
      icon = Icons.check_circle_rounded;
      iconColor = const Color(0xFF10B981);
      statusLabel = 'Completed';
    } else if (topic.isInProgress) {
      icon = Icons.timelapse_rounded;
      iconColor = const Color(0xFFD97706);
      statusLabel = 'In Progress';
    } else {
      icon = Icons.radio_button_unchecked_rounded;
      iconColor = Colors.grey.shade400;
      statusLabel = 'Upcoming';
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(
        topic.topicName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: topic.isCompleted ? FontWeight.normal : FontWeight.w500,
          color: topic.isCompleted ? Colors.grey.shade700 : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        '${topic.chapterName} • $statusLabel',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      trailing: topic.completedAt != null
          ? Text(
              _formatDate(topic.completedAt),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            )
          : null,
    );
  }
}
