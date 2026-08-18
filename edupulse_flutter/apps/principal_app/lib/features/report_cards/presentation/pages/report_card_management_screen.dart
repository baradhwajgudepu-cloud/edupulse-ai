import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../providers/report_cards_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';

class ReportCardManagementScreen extends ConsumerStatefulWidget {
  const ReportCardManagementScreen({super.key});

  @override
  ConsumerState<ReportCardManagementScreen> createState() => _ReportCardManagementScreenState();
}

class _ReportCardManagementScreenState extends ConsumerState<ReportCardManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportCardsStateProvider.notifier).fetchReportCards();
      // Load student list to map names
      ref.read(studentsStateProvider.notifier).init();
    });
  }

  Future<void> _handleDownloadPdf(String studentId, String studentName) async {
    final theme = Theme.of(context);
    final apiClient = ref.read(apiClientProvider);
    final session = ref.read(sessionManagerProvider);
    final schoolId = await session.getSchoolId();

    if (schoolId == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compiling Report Card PDF for $studentName...')),
    );

    // Call download endpoint which triggers PDF generation on backend
    final result = await apiClient.get<dynamic>(
      '/report-cards/download/$studentId',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json, // Endpoint returns PDF file stream directly
    );

    result.when(
      onSuccess: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Successfully compiled PDF file for $studentName on backend.'),
          ),
        );
      },
      onFailure: (failure) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: theme.colorScheme.error,
            content: Text('PDF Compile Failed: ${failure.message}'),
          ),
        );
      },
    );
  }

  Future<void> _showBulkPublishDialog() async {
    final state = ref.read(reportCardsStateProvider);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    // Dynamically find class/sections in APPROVED state that can be published
    final approvedCards = state.reportCards.where((c) => c.status == 'APPROVED').toList();
    if (approvedCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No approved report cards available to publish.')),
      );
      return;
    }

    // Map unique class/section combinations from approved report cards
    final classSectionList = approvedCards.map((c) => '${c.classId}|${c.sectionId}').toSet().toList();

    String? selectedPair = classSectionList.isNotEmpty ? classSectionList.first : null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String classId = '';
            String sectionId = '';
            int count = 0;

            if (selectedPair != null) {
              final split = selectedPair!.split('|');
              classId = split[0];
              sectionId = split[1];
              count = approvedCards.where((c) => c.classId == classId && c.sectionId == sectionId).length;
            }

            return AlertDialog(
              title: const Text('Bulk Publish Approved Cards'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select class and section to publish approved report cards to parent portal:'),
                  SizedBox(height: spacing.md),
                  DropdownButtonFormField<String>(
                    value: selectedPair,
                    decoration: InputDecoration(
                      labelText: 'Target Class/Section',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.sm)),
                    ),
                    items: classSectionList.map((pair) {
                      final split = pair.split('|');
                      // Find matching cards to display details
                      final matching = approvedCards.firstWhere((c) => c.classId == split[0] && c.sectionId == split[1]);
                      return DropdownMenuItem(
                        value: pair,
                        child: Text('Class ${matching.classId.substring(0, 5)} - Sec ${matching.sectionId.substring(0, 5)}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedPair = val;
                      });
                    },
                  ),
                  SizedBox(height: spacing.sm),
                  if (selectedPair != null)
                    Text(
                      'Approved Cards Affected: $count',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedPair == null
                      ? null
                      : () async {
                          Navigator.pop(context);
                          final ok = await ref
                              .read(reportCardsStateProvider.notifier)
                              .bulkPublish(classId, sectionId);
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.green,
                                content: Text('Bulk publishing execution completed successfully.'),
                              ),
                            );
                          }
                        },
                  child: const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    
    final state = ref.watch(reportCardsStateProvider);
    final studentsState = ref.watch(studentsStateProvider);

    // Map student names
    final Map<String, String> studentNames = {};
    if (studentsState is StudentsSuccess) {
      for (final s in studentsState.students) {
        studentNames[s.id] = s.fullName;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Cards Approval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.publish_rounded),
            tooltip: 'Bulk Publish Class',
            onPressed: state.actionInProgress ? null : _showBulkPublishDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Choice Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            child: Row(
              children: [
                _buildChip(state, 'UNDER_REVIEW', 'Under Review'),
                SizedBox(width: spacing.xs),
                _buildChip(state, 'APPROVED', 'Approved'),
                SizedBox(width: spacing.xs),
                _buildChip(state, 'PUBLISHED', 'Published'),
                SizedBox(width: spacing.xs),
                _buildChip(state, 'LOCKED', 'Locked'),
                SizedBox(width: spacing.xs),
                _buildChip(state, 'ALL', 'All'),
              ],
            ),
          ),

          if (state.actionInProgress)
            const LinearProgressIndicator(),

          if (state.errorMessage != null)
            Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: Text(
                state.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(reportCardsStateProvider.notifier).fetchReportCards(isRefresh: true),
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.reportCards.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf_outlined, size: 56, color: Colors.grey),
                                SizedBox(height: spacing.sm),
                                Text(
                                  'No Report Cards Found',
                                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.all(spacing.md),
                          itemCount: state.reportCards.length,
                          separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
                          itemBuilder: (context, index) {
                            final card = state.reportCards[index];
                            final name = studentNames[card.studentId] ?? 'Student #${card.studentId.substring(0, 6)}';

                            final Color statusColor = card.status == 'PUBLISHED'
                                ? Colors.green
                                : card.status == 'APPROVED'
                                    ? Colors.blue
                                    : card.status == 'UNDER_REVIEW'
                                        ? Colors.orange
                                        : Colors.purple;

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius.md),
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(spacing.md),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(radius.sm),
                                          ),
                                          child: Text(
                                            card.status,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: spacing.xs),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Class ID: ${card.classId.substring(0, 8)} | Sec ID: ${card.sectionId.substring(0, 8)}',
                                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.black54),
                                        ),
                                        Text(
                                          'v${card.version}',
                                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // PDF compilation/download action
                                        IconButton(
                                          icon: const Icon(Icons.download_rounded, size: 20),
                                          tooltip: 'Compile / Download PDF',
                                          onPressed: state.actionInProgress
                                              ? null
                                              : () => _handleDownloadPdf(card.studentId, name),
                                        ),
                                        const Spacer(),
                                        // Approve action
                                        if (card.status == 'UNDER_REVIEW')
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.check, size: 14),
                                            label: const Text('Approve'),
                                            onPressed: state.actionInProgress
                                                ? null
                                                : () => ref
                                                    .read(reportCardsStateProvider.notifier)
                                                    .approveCard(card.id),
                                          ),
                                        // Lock action
                                        if (card.status == 'APPROVED' || card.status == 'PUBLISHED')
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.lock_outline, size: 14),
                                            label: const Text('Lock'),
                                            onPressed: state.actionInProgress
                                                ? null
                                                : () => ref
                                                    .read(reportCardsStateProvider.notifier)
                                                    .lockCard(card.id),
                                          ),
                                        // Unlock action
                                        if (card.status == 'LOCKED')
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.lock_open, size: 14),
                                            label: const Text('Unlock'),
                                            onPressed: state.actionInProgress
                                                ? null
                                                : () => ref
                                                    .read(reportCardsStateProvider.notifier)
                                                    .unlockCard(card.id),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(ReportCardsState state, String filterVal, String label) {
    final isSelected = state.selectedStatus == filterVal;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          ref.read(reportCardsStateProvider.notifier).fetchReportCards(status: filterVal);
        }
      },
    );
  }
}
