import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/teacher_class_group.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/my_classes_repository.dart';
import '../../data/datasource/my_classes_remote_datasource.dart';
import '../../data/repositories/my_classes_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/domain/entities/dashboard_data.dart';

// --- MY CLASSES STATES ---
sealed class MyClassesState {
  const MyClassesState();
}

class MyClassesInitial extends MyClassesState {
  const MyClassesInitial();
}

class MyClassesLoading extends MyClassesState {
  const MyClassesLoading();
}

class MyClassesSuccess extends MyClassesState {
  final List<TeacherClassGroupEntity> classes;
  const MyClassesSuccess(this.classes);
}

class MyClassesRefreshing extends MyClassesState {
  final List<TeacherClassGroupEntity> classes;
  const MyClassesRefreshing(this.classes);
}

class MyClassesEmpty extends MyClassesState {
  const MyClassesEmpty();
}

class MyClassesError extends MyClassesState {
  final String message;
  const MyClassesError(this.message);
}

// --- STUDENT ROSTER STATES ---
sealed class StudentRosterState {
  const StudentRosterState();
}

class StudentRosterInitial extends StudentRosterState {
  const StudentRosterInitial();
}

class StudentRosterLoading extends StudentRosterState {
  const StudentRosterLoading();
}

class StudentRosterSuccess extends StudentRosterState {
  final List<StudentEntity> allStudents;
  final List<StudentEntity> filteredStudents;
  final String query;
  const StudentRosterSuccess({
    required this.allStudents,
    required this.filteredStudents,
    this.query = '',
  });
}

class StudentRosterRefreshing extends StudentRosterState {
  final List<StudentEntity> allStudents;
  final List<StudentEntity> filteredStudents;
  final String query;
  const StudentRosterRefreshing({
    required this.allStudents,
    required this.filteredStudents,
    this.query = '',
  });
}

class StudentRosterEmpty extends StudentRosterState {
  const StudentRosterEmpty();
}

class StudentRosterError extends StudentRosterState {
  final String message;
  const StudentRosterError(this.message);
}

// --- PROVIDERS ---

final myClassesRemoteDatasourceProvider = Provider<MyClassesRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MyClassesRemoteDatasource(apiClient);
});

final myClassesRepositoryProvider = Provider<MyClassesRepository>((ref) {
  final remote = ref.watch(myClassesRemoteDatasourceProvider);
  return MyClassesRepositoryImpl(remote);
});

class MyClassesNotifier extends Notifier<MyClassesState> {
  @override
  MyClassesState build() {
    return const MyClassesInitial();
  }

  Future<void> fetchClasses() async {
    final current = state;
    if (current is MyClassesSuccess) {
      state = MyClassesRefreshing(current.classes);
    } else if (current is! MyClassesRefreshing) {
      state = const MyClassesLoading();
    }

    final authState = ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const MyClassesError('User is not authenticated.');
      return;
    }

    final dashboardState = ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      state = const MyClassesError('Dashboard must load first.');
      return;
    }

    final DashboardDataEntity dashboardData;
    if (dashboardState is DashboardSuccess) {
      dashboardData = dashboardState.data;
    } else {
      dashboardData = (dashboardState as DashboardRefreshing).data;
    }

    final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
    if (schoolId == null) {
      state = const MyClassesError('No school associated with this account.');
      return;
    }

    final teacherId = dashboardData.teacherProfile.id;
    final academicYearId = dashboardData.academicYear.id;
    final repo = ref.read(myClassesRepositoryProvider);

    final result = await repo.getTeacherClasses(
      schoolId: schoolId,
      academicYearId: academicYearId,
      teacherId: teacherId,
    );

    result.when(
      onSuccess: (data) {
        if (data.isEmpty) {
          state = const MyClassesEmpty();
        } else {
          state = MyClassesSuccess(data);
        }
      },
      onFailure: (failure) {
        state = MyClassesError(failure.message);
      },
    );
  }
}

final myClassesStateProvider = NotifierProvider<MyClassesNotifier, MyClassesState>(
  MyClassesNotifier.new,
);

class StudentRosterNotifier extends StateNotifier<StudentRosterState> {
  final MyClassesRepository _repository;
  final Ref _ref;
  final String _classId;
  final String _sectionId;

  StudentRosterNotifier(
    this._repository,
    this._ref,
    this._classId,
    this._sectionId,
  ) : super(const StudentRosterInitial());

  Future<void> fetchStudents() async {
    final current = state;
    if (current is StudentRosterSuccess) {
      state = StudentRosterRefreshing(
        allStudents: current.allStudents,
        filteredStudents: current.filteredStudents,
        query: current.query,
      );
    } else if (current is! StudentRosterRefreshing) {
      state = const StudentRosterLoading();
    }

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const StudentRosterError('User is not authenticated.');
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      state = const StudentRosterError('Dashboard must load first.');
      return;
    }

    final DashboardDataEntity dashboardData;
    if (dashboardState is DashboardSuccess) {
      dashboardData = dashboardState.data;
    } else {
      dashboardData = (dashboardState as DashboardRefreshing).data;
    }

    final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
    if (schoolId == null) {
      state = const StudentRosterError('No school associated with this account.');
      return;
    }

    final academicYearId = dashboardData.academicYear.id;

    final result = await _repository.getClassStudents(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: _classId,
      sectionId: _sectionId,
    );

    result.when(
      onSuccess: (data) {
        if (data.isEmpty) {
          state = const StudentRosterEmpty();
        } else {
          state = StudentRosterSuccess(
            allStudents: data,
            filteredStudents: data,
          );
        }
      },
      onFailure: (failure) {
        state = StudentRosterError(failure.message);
      },
    );
  }

  void searchLocal(String query) {
    final current = state;
    if (current is StudentRosterSuccess) {
      final filtered = _filter(current.allStudents, query);
      state = StudentRosterSuccess(
        allStudents: current.allStudents,
        filteredStudents: filtered,
        query: query,
      );
    } else if (current is StudentRosterRefreshing) {
      final filtered = _filter(current.allStudents, query);
      state = StudentRosterRefreshing(
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
      return nameMatches || rollMatches || admissionMatches;
    }).toList();
  }
}

final studentRosterStateProvider = StateNotifierProvider.family<StudentRosterNotifier, StudentRosterState, String>((ref, arg) {
  final parts = arg.split(':');
  final classId = parts[0];
  final sectionId = parts[1];
  final repo = ref.watch(myClassesRepositoryProvider);
  return StudentRosterNotifier(repo, ref, classId, sectionId);
});
