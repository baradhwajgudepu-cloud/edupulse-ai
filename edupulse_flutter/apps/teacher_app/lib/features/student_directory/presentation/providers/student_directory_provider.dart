import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../my_classes/domain/entities/student.dart';
import '../../../my_classes/domain/repositories/my_classes_repository.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

sealed class StudentDirectoryState {
  const StudentDirectoryState();
}

class StudentDirectoryInitial extends StudentDirectoryState {
  const StudentDirectoryInitial();
}

class StudentDirectoryLoading extends StudentDirectoryState {
  const StudentDirectoryLoading();
}

class StudentDirectorySuccess extends StudentDirectoryState {
  final List<StudentEntity> allStudents;
  final List<StudentEntity> filteredStudents;
  final String query;
  const StudentDirectorySuccess({
    required this.allStudents,
    required this.filteredStudents,
    this.query = '',
  });
}

class StudentDirectoryRefreshing extends StudentDirectoryState {
  final List<StudentEntity> allStudents;
  final List<StudentEntity> filteredStudents;
  final String query;
  const StudentDirectoryRefreshing({
    required this.allStudents,
    required this.filteredStudents,
    this.query = '',
  });
}

class StudentDirectoryEmpty extends StudentDirectoryState {
  const StudentDirectoryEmpty();
}

class StudentDirectoryError extends StudentDirectoryState {
  final String message;
  const StudentDirectoryError(this.message);
}

class StudentDirectoryNotifier extends StateNotifier<StudentDirectoryState> {
  final MyClassesRepository _repository;
  final Ref _ref;

  StudentDirectoryNotifier(this._repository, this._ref) : super(const StudentDirectoryInitial());

  Future<void> fetchStudents() async {
    final current = state;
    if (current is StudentDirectorySuccess) {
      state = StudentDirectoryRefreshing(
        allStudents: current.allStudents,
        filteredStudents: current.filteredStudents,
        query: current.query,
      );
    } else if (current is! StudentDirectoryRefreshing) {
      state = const StudentDirectoryLoading();
    }

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const StudentDirectoryError('User is not authenticated.');
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      state = const StudentDirectoryError('Dashboard data must load first.');
      return;
    }

    final academicYearId = dashboardState is DashboardSuccess
        ? (dashboardState as DashboardSuccess).data.academicYear.id
        : (dashboardState as DashboardRefreshing).data.academicYear.id;

    final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
    if (schoolId == null) {
      state = const StudentDirectoryError('No school associated with this account.');
      return;
    }

    final result = await _repository.getTeacherStudents(
      schoolId: schoolId,
      academicYearId: academicYearId,
    );

    result.when(
      onSuccess: (data) {
        if (data.isEmpty) {
          state = const StudentDirectoryEmpty();
        } else {
          state = StudentDirectorySuccess(
            allStudents: data,
            filteredStudents: data,
          );
        }
      },
      onFailure: (failure) {
        state = StudentDirectoryError(failure.message);
      },
    );
  }

  void searchLocal(String query) {
    final current = state;
    if (current is StudentDirectorySuccess) {
      final filtered = _filter(current.allStudents, query);
      state = StudentDirectorySuccess(
        allStudents: current.allStudents,
        filteredStudents: filtered,
        query: query,
      );
    } else if (current is StudentDirectoryRefreshing) {
      final filtered = _filter(current.allStudents, query);
      state = StudentDirectoryRefreshing(
        allStudents: current.allStudents,
        filteredStudents: filtered,
        query: query,
      );
    }
  }

  List<StudentEntity> _filter(List<StudentEntity> list, String query) {
    if (query.trim().isEmpty) return list;
    final lower = query.toLowerCase().trim();
    return list.where((s) {
      final nameMatches = s.fullName.toLowerCase().contains(lower);
      final rollMatches = s.rollNumber.toLowerCase().contains(lower);
      final admissionMatches = s.admissionNumber.toLowerCase().contains(lower);
      final classMatches = s.className.toLowerCase().contains(lower);
      final sectionMatches = s.sectionName.toLowerCase().contains(lower);
      return nameMatches || rollMatches || admissionMatches || classMatches || sectionMatches;
    }).toList();
  }
}

final studentDirectoryStateProvider = StateNotifierProvider<StudentDirectoryNotifier, StudentDirectoryState>((ref) {
  final repo = ref.watch(myClassesRepositoryProvider);
  return StudentDirectoryNotifier(repo, ref);
});
