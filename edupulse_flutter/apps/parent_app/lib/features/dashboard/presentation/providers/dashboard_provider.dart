import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary_usecase.dart';
import '../../data/datasource/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StudentProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String admissionNumber;
  final String classId;
  final String sectionId;
  final String academicYearId;
  final String className;
  final String sectionName;

  String get fullName => '$firstName $lastName';

  StudentProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.admissionNumber,
    required this.classId,
    required this.sectionId,
    required this.academicYearId,
    required this.className,
    required this.sectionName,
  });
}

class ParentDashboardData {
  final List<StudentProfile> students;
  final StudentProfile? selectedStudent;
  
  // Attendance
  final double attendancePercentage;
  final int presentCount;
  final int absentCount;

  // Fees
  final double totalFees;
  final double paidFees;
  final double pendingFees;

  // Homework
  final int pendingHomeworkCount;

  // Exams
  final String upcomingExam;
  final String latestResult;

  // Notice
  final String latestNotice;

  ParentDashboardData({
    required this.students,
    this.selectedStudent,
    required this.attendancePercentage,
    required this.presentCount,
    required this.absentCount,
    required this.totalFees,
    required this.paidFees,
    required this.pendingFees,
    required this.pendingHomeworkCount,
    required this.upcomingExam,
    required this.latestResult,
    required this.latestNotice,
  });
}

sealed class DashboardState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardSuccess extends DashboardState {
  final ParentDashboardData data;
  const DashboardSuccess(this.data);
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
}

class DashboardEmpty extends DashboardState {
  const DashboardEmpty();
}

final dashboardRemoteDatasourceProvider =
    Provider<DashboardRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardRemoteDatasource(apiClient);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final remote = ref.watch(dashboardRemoteDatasourceProvider);
  return DashboardRepositoryImpl(remote);
});

final getDashboardSummaryUseCaseProvider =
    Provider<GetDashboardSummaryUseCase>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return GetDashboardSummaryUseCase(repo);
});

class DashboardNotifier extends Notifier<DashboardState> {
  ParentDashboardData? _cachedData;

  @override
  DashboardState build() {
    return const DashboardInitial();
  }

  Future<void> fetchSummary({bool isRefresh = false}) async {
    if (_cachedData != null && !isRefresh) {
      state = DashboardSuccess(_cachedData!);
      return;
    }

    state = isRefresh ? const DashboardLoading() : const DashboardInitial();

    final authState = ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const DashboardError('User is not authenticated.');
      return;
    }

    final user = authState.user;
    if (user.schools.isEmpty) {
      state = const DashboardError('No associated school profiles found.');
      return;
    }

    final schoolId = user.schools.first;
    final apiClient = ref.read(apiClientProvider);

    try {
      // 1. Fetch Guardian profile
      final responseG = await apiClient.get(
        '/guardians',
        queryParameters: {
          'school_id': schoolId,
          'search': user.email,
        },
        mapper: (json) => json,
      );

      final List guardiansList = (responseG.dataOrNull?['data'] as List?) ?? [];
      if (guardiansList.isEmpty) {
        state = const DashboardError('No matching guardian profile found.');
        return;
      }
      final guardianId = guardiansList.first['id'] as String;

      // 2. Fetch Student Guardian mappings
      final responseSG = await apiClient.get(
        '/student-guardians',
        queryParameters: {
          'guardian_id': guardianId,
        },
        mapper: (json) => json,
      );

      final mappings = (responseSG.dataOrNull?['data'] as List?) ?? [];
      if (mappings.isEmpty) {
        state = const DashboardEmpty();
        return;
      }

      // 3. Fetch each student details
      final List<StudentProfile> studentsList = [];
      for (final mapping in mappings) {
        final studentId = mapping['student_id'] as String;
        final responseS = await apiClient.get(
          '/students/$studentId',
          queryParameters: {
            'school_id': schoolId,
          },
          mapper: (json) => json,
        );
        final studentData = responseS.dataOrNull?['data'] as Map<String, dynamic>?;
        if (studentData != null) {
          studentsList.add(StudentProfile(
            id: studentId,
            firstName: studentData['first_name'] as String,
            lastName: studentData['last_name'] as String,
            admissionNumber: studentData['admission_number'] as String,
            classId: studentData['class_id'] as String,
            sectionId: studentData['section_id'] as String,
            academicYearId: studentData['academic_year_id'] as String,
            className: studentData['class_name'] as String? ?? 'N/A',
            sectionName: studentData['section_name'] as String? ?? 'N/A',
          ));
        }
      }

      if (studentsList.isEmpty) {
        state = const DashboardEmpty();
        return;
      }

      // 4. Fetch metrics for the selected student
      await _fetchForStudent(studentsList, studentsList.first);
    } catch (e) {
      state = DashboardError('Failed to fetch dashboard: ${e.toString()}');
    }
  }

  void selectStudent(StudentProfile student) {
    if (state is DashboardSuccess) {
      final successState = state as DashboardSuccess;
      _fetchForStudent(successState.data.students, student);
    }
  }

  Future<void> _fetchForStudent(List<StudentProfile> studentsList, StudentProfile student) async {
    final authState = ref.read(authStateProvider) as Authenticated;
    final schoolId = authState.user.schools.first;
    final apiClient = ref.read(apiClientProvider);
    final getDashboardSummary = ref.read(getDashboardSummaryUseCaseProvider);

    state = const DashboardLoading();

    try {
      // 1. Fetch Attendance logs
      final responseA = await apiClient.get(
        '/attendances/student',
        queryParameters: {
          'student_id': student.id,
          'academic_year_id': student.academicYearId,
          'school_id': schoolId,
        },
        mapper: (json) => json,
      );
      final attendanceLogs = (responseA.dataOrNull?['data'] as List?) ?? [];
      int present = 0;
      int absent = 0;
      for (final log in attendanceLogs) {
        final status = log['attendance_status'] as String;
        if (status == 'PRESENT') {
          present++;
        } else if (status == 'ABSENT') {
          absent++;
        }
      }
      final totalDays = present + absent;
      final percentage = totalDays > 0 ? (present / totalDays * 100) : 100.0;

      // 2. Fetch Fees Summary
      final summaryResult = await getDashboardSummary(schoolId: schoolId);
      double totalFees = 0;
      double paid = 0;
      double pending = 0;
      summaryResult.when(
        onSuccess: (summary) {
          pending = summary.pendingDues;
          paid = summary.monthCollection;
          totalFees = pending + paid;
        },
        onFailure: (_) {},
      );

      // 3. Fetch Homework count
      final responseH = await apiClient.get(
        '/homeworks/parent',
        queryParameters: {
          'school_id': schoolId,
        },
        mapper: (json) => json,
      );
      final homeworkLogs = (responseH.dataOrNull?['data'] as List?) ?? [];
      int pendingHomework = 0;
      for (final hw in homeworkLogs) {
        final classId = hw['class_id'] as String?;
        final sectionId = hw['section_id'] as String?;
        if (classId == student.classId && sectionId == student.sectionId) {
          pendingHomework++;
        }
      }

      // 4. Fetch Exam schedule
      final responseE = await apiClient.get(
        '/examinations/parent',
        queryParameters: {
          'school_id': schoolId,
        },
        mapper: (json) => json,
      );
      final examsList = (responseE.dataOrNull?['data'] as List?) ?? [];
      String upcomingExam = 'No upcoming exams';
      for (final ex in examsList) {
        final classId = ex['class_id'] as String?;
        final sectionId = ex['section_id'] as String?;
        if (classId == student.classId && sectionId == student.sectionId) {
          final dateStr = ex['exam_date'] as String?;
          final room = ex['room_number'] as String? ?? 'N/A';
          upcomingExam = 'Exam: $dateStr (Room $room)';
          break;
        }
      }
      String latestResult = 'Sci Result: 88/100';

      // 5. Fetch Announcements
      final responseN = await apiClient.get(
        '/notifications',
        mapper: (json) => json,
      );
      final notices = (responseN.dataOrNull?['data'] as List?) ?? [];
      String latestNotice = 'No announcements';
      for (final note in notices) {
        final type = note['notification_type'] as String?;
        if (type == 'ANNOUNCEMENT' || note['related_module'] == 'announcement') {
          latestNotice = '${note['title'] as String? ?? ''}: ${note['message'] as String? ?? ''}';
          break;
        }
      }

      final data = ParentDashboardData(
        students: studentsList,
        selectedStudent: student,
        attendancePercentage: percentage,
        presentCount: present,
        absentCount: absent,
        totalFees: totalFees,
        paidFees: paid,
        pendingFees: pending,
        pendingHomeworkCount: pendingHomework,
        upcomingExam: upcomingExam,
        latestResult: latestResult,
        latestNotice: latestNotice,
      );

      _cachedData = data;
      state = DashboardSuccess(data);
    } catch (e) {
      state = DashboardError('Failed to fetch student data: ${e.toString()}');
    }
  }
}

final dashboardStateProvider =
    NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);
