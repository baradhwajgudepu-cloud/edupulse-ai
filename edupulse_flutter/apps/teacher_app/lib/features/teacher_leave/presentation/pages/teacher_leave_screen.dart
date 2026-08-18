import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';

import '../../../../core/router/routes.dart';
import '../providers/teacher_leave_provider.dart';
import '../widgets/leave_request_card.dart';

class TeacherLeaveScreen extends ConsumerStatefulWidget {
  const TeacherLeaveScreen({super.key});

  @override
  ConsumerState<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends ConsumerState<TeacherLeaveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherLeaveListProvider.notifier).fetchLeaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final state = ref.watch(teacherLeaveListProvider);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Leave'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: SafeArea(
          child: Builder(
            builder: (context) {
              switch (state) {
                case TeacherLeaveListInitial():
                case TeacherLeaveListLoading():
                  return const Center(child: CircularProgressIndicator());
                case TeacherLeaveListError(:final message):
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          SizedBox(height: spacing.md),
                          ElevatedButton(
                            onPressed: () => ref.read(teacherLeaveListProvider.notifier).fetchLeaves(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                case TeacherLeaveListLoaded(:final leaves):
                  return TabBarView(
                    children: [
                      _buildLeaveList(leaves),
                      _buildLeaveList(leaves.where((l) => l.status == 'PENDING').toList()),
                      _buildLeaveList(leaves.where((l) => l.status == 'APPROVED').toList()),
                      _buildLeaveList(leaves.where((l) => l.status == 'REJECTED').toList()),
                      _buildLeaveList(leaves.where((l) => l.status == 'CANCELLED').toList()),
                    ],
                  );
              }
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            ref.read(teacherLeaveFormNotifierProvider.notifier).reset();
            context.push(AppRoutes.teacherLeaveCreate);
          },
          icon: const Icon(Icons.add),
          label: const Text('Request Leave'),
        ),
      ),
    );
  }

  Widget _buildLeaveList(List<dynamic> list) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(teacherLeaveListProvider.notifier).fetchLeaves(isSilent: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            padding: EdgeInsets.all(spacing.lg),
            child: Text(
              'No leave requests found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(teacherLeaveListProvider.notifier).fetchLeaves(isSilent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(spacing.md),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final leave = list[index];
          return LeaveRequestCard(
            leave: leave,
            onTap: () {
              context.push('${AppRoutes.teacherLeaveList}/${leave.id}');
            },
          );
        },
      ),
    );
  }
}
