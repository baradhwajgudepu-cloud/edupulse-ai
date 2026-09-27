import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../../core/routing/routes.dart';

enum AlertSeverity { critical, warning, info }

class NeedsAttentionItem {
  final String id;
  final String title;
  final String subtitle;
  final AlertSeverity severity;
  final String actionLabel;
  final String actionRoute;
  final IconData icon;

  const NeedsAttentionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.actionLabel,
    required this.actionRoute,
    required this.icon,
  });
}

class CommandCenterMetrics {
  final int totalStudents;
  final double studentAttendancePct;
  final int teachersPresent;
  final int totalTeachers;
  final double todayFeeCollection;
  final double outstandingFees;
  final int studentsRequiringAttention;
  final int defaultersCount;
  final List<NeedsAttentionItem> alerts;
  final List<Map<String, dynamic>> recentPayments;
  final bool isLoading;
  final String? error;

  const CommandCenterMetrics({
    this.totalStudents = 0,
    this.studentAttendancePct = 0.0,
    this.teachersPresent = 0,
    this.totalTeachers = 0,
    this.todayFeeCollection = 0.0,
    this.outstandingFees = 0.0,
    this.studentsRequiringAttention = 0,
    this.defaultersCount = 0,
    this.alerts = const [],
    this.recentPayments = const [],
    this.isLoading = false,
    this.error,
  });

  CommandCenterMetrics copyWith({
    int? totalStudents,
    double? studentAttendancePct,
    int? teachersPresent,
    int? totalTeachers,
    double? todayFeeCollection,
    double? outstandingFees,
    int? studentsRequiringAttention,
    int? defaultersCount,
    List<NeedsAttentionItem>? alerts,
    List<Map<String, dynamic>>? recentPayments,
    bool? isLoading,
    String? error,
  }) {
    return CommandCenterMetrics(
      totalStudents: totalStudents ?? this.totalStudents,
      studentAttendancePct: studentAttendancePct ?? this.studentAttendancePct,
      teachersPresent: teachersPresent ?? this.teachersPresent,
      totalTeachers: totalTeachers ?? this.totalTeachers,
      todayFeeCollection: todayFeeCollection ?? this.todayFeeCollection,
      outstandingFees: outstandingFees ?? this.outstandingFees,
      studentsRequiringAttention: studentsRequiringAttention ?? this.studentsRequiringAttention,
      defaultersCount: defaultersCount ?? this.defaultersCount,
      alerts: alerts ?? this.alerts,
      recentPayments: recentPayments ?? this.recentPayments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CommandCenterNotifier extends StateNotifier<CommandCenterMetrics> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  CommandCenterNotifier(this._apiClient, this._ref) : super(const CommandCenterMetrics(isLoading: true)) {
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        state = const CommandCenterMetrics(isLoading: true);
        loadDashboard();
      } else {
        state = const CommandCenterMetrics(isLoading: false);
      }
    });

    final initialSchoolId = _ref.read(selectedSchoolIdProvider);
    if (initialSchoolId != null) {
      loadDashboard();
    } else {
      state = const CommandCenterMetrics(isLoading: false);
    }
  }

  Future<void> loadDashboard() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      state = const CommandCenterMetrics(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    int totalStudents = 0;
    double studentAttendancePct = 0.0;
    int studentsRequiringAttention = 0;
    int teachersPresent = 0;
    int totalTeachers = 0;
    double todayFeeCollection = 0.0;
    double outstandingFees = 0.0;
    int defaultersCount = 0;
    List<Map<String, dynamic>> recentPayments = [];

    // 1. Fetch general reports dashboard
    try {
      final res = await _apiClient.get(
        '/reports/dashboard?school_id=$schoolId',
        mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
      );
      res.when(
        onSuccess: (data) {
          if (data != null) {
            totalStudents = (data['total_students'] as num?)?.toInt() ?? 0;
            studentAttendancePct = (data['average_attendance'] as num?)?.toDouble() ?? 0.0;
            totalTeachers = (data['active_teachers'] as num?)?.toInt() ?? 0;
            studentsRequiringAttention = (data['students_requiring_attention'] as num?)?.toInt() ?? 0;
          }
        },
        onFailure: (_) {},
      );
    } catch (_) {}

    // 2. Fetch fee collection dashboard
    try {
      final res = await _apiClient.get(
        '/fees/reports/dashboard',
        options: Options(headers: {'X-School-ID': schoolId}),
        mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
      );
      res.when(
        onSuccess: (data) {
          if (data != null) {
            todayFeeCollection = (data['today_collection'] as num?)?.toDouble() ?? 0.0;
            outstandingFees = (data['pending_dues'] as num?)?.toDouble() ?? 0.0;
            defaultersCount = (data['defaulters_count'] as num?)?.toInt() ?? 0;
          }
        },
        onFailure: (_) {},
      );
    } catch (_) {}

    // 3. Fetch staff attendance daily
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final res = await _apiClient.get(
        '/staff-attendance/daily?school_id=$schoolId&attendance_date=$todayStr',
        mapper: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>?,
      );
      res.when(
        onSuccess: (data) {
          if (data != null) {
            teachersPresent = (data['present_teachers'] as num?)?.toInt() ?? 0;
            final count = (data['total_teachers'] as num?)?.toInt() ?? 0;
            if (count > 0) totalTeachers = count;
          }
        },
        onFailure: (_) {},
      );
    } catch (_) {}

    // 4. Fetch real recent fee payments
    try {
      final res = await _apiClient.get(
        '/fees/payments',
        queryParameters: {'school_id': schoolId, 'limit': 5},
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>? ?? [];
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        },
      );
      res.when(
        onSuccess: (data) {
          recentPayments = data;
        },
        onFailure: (_) {},
      );
    } catch (_) {}

    // 5. Build Actionable Needs Attention items
    final List<NeedsAttentionItem> alerts = [];

    if (totalStudents == 0 || totalTeachers == 0) {
      alerts.add(
        const NeedsAttentionItem(
          id: 'setup_incomplete',
          title: 'School setup is incomplete.',
          subtitle: 'Academic year, class sections, or faculty accounts are pending initial setup.',
          severity: AlertSeverity.warning,
          actionLabel: 'Setup Checklist',
          actionRoute: AppRoutes.schoolSetup,
          icon: Icons.app_registration_rounded,
        ),
      );
    }

    if (studentsRequiringAttention > 0) {
      alerts.add(
        NeedsAttentionItem(
          id: 'students_risk',
          title: '$studentsRequiringAttention Students Need Attention',
          subtitle: 'Irregular attendance (<75%) or consecutive academic drops detected.',
          severity: AlertSeverity.critical,
          actionLabel: 'View Students',
          actionRoute: '${AppRoutes.students}?filter=needs_attention',
          icon: Icons.warning_amber_rounded,
        ),
      );
    }

    if (outstandingFees > 0) {
      alerts.add(
        NeedsAttentionItem(
          id: 'overdue_fees',
          title: '₹${outstandingFees.toStringAsFixed(0)} Outstanding Fees Pending',
          subtitle: '$defaultersCount student accounts currently have overdue fee installments.',
          severity: AlertSeverity.warning,
          actionLabel: 'View Fees',
          actionRoute: AppRoutes.fees,
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    if (totalTeachers > 0 && teachersPresent < totalTeachers) {
      final absent = totalTeachers - teachersPresent;
      alerts.add(
        NeedsAttentionItem(
          id: 'staff_attendance',
          title: '$absent Staff Members Not Checked In',
          subtitle: '$teachersPresent of $totalTeachers staff members recorded on campus today.',
          severity: AlertSeverity.info,
          actionLabel: 'Staff Logs',
          actionRoute: AppRoutes.teachers,
          icon: Icons.person_off_outlined,
        ),
      );
    }

    state = state.copyWith(
      totalStudents: totalStudents,
      studentAttendancePct: studentAttendancePct,
      teachersPresent: teachersPresent,
      totalTeachers: totalTeachers,
      todayFeeCollection: todayFeeCollection,
      outstandingFees: outstandingFees,
      studentsRequiringAttention: studentsRequiringAttention,
      defaultersCount: defaultersCount,
      alerts: alerts,
      recentPayments: recentPayments,
      isLoading: false,
    );
  }
}

final commandCenterProvider = StateNotifierProvider<CommandCenterNotifier, CommandCenterMetrics>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CommandCenterNotifier(apiClient, ref);
});
