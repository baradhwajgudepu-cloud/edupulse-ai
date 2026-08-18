import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/datasources/teacher_datasource.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../data/models/teacher_model.dart';

// Datasource Provider
final teacherDatasourceProvider = Provider<TeacherDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TeacherDatasource(apiClient);
});

// Repository Provider
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final datasource = ref.watch(teacherDatasourceProvider);
  return TeacherRepository(datasource);
});

sealed class TeachersState {
  const TeachersState();
}

class TeachersInitial extends TeachersState {
  const TeachersInitial();
}

class TeachersLoading extends TeachersState {
  const TeachersLoading();
}

class TeachersSuccess extends TeachersState {
  final List<Teacher> teachers;
  final bool hasReachedMax;
  final String searchQuery;

  const TeachersSuccess({
    required this.teachers,
    required this.hasReachedMax,
    required this.searchQuery,
  });
}

class TeachersError extends TeachersState {
  final String message;
  const TeachersError(this.message);
}

class TeachersNotifier extends StateNotifier<TeachersState> {
  final TeacherRepository _repository;
  final SessionManager _sessionManager;

  TeachersNotifier(this._repository, this._sessionManager) : super(const TeachersInitial());

  Future<void> fetchTeachers({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = const TeachersLoading();
    }

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const TeachersError('No active school context found.');
      return;
    }

    final result = await _repository.getTeachers(
      schoolId: schoolId,
      skip: 0,
      limit: 20,
    );

    result.when(
      onSuccess: (list) {
        state = TeachersSuccess(
          teachers: list,
          hasReachedMax: list.length < 20,
          searchQuery: '',
        );
      },
      onFailure: (failure) {
        state = TeachersError(failure.message);
      },
    );
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! TeachersSuccess || currentState.hasReachedMax) return;

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    final result = await _repository.getTeachers(
      schoolId: schoolId,
      skip: currentState.teachers.length,
      limit: 20,
      search: currentState.searchQuery.isNotEmpty ? currentState.searchQuery : null,
    );

    result.when(
      onSuccess: (list) {
        state = TeachersSuccess(
          teachers: List<Teacher>.from(currentState.teachers)..addAll(list),
          hasReachedMax: list.length < 20,
          searchQuery: currentState.searchQuery,
        );
      },
      onFailure: (failure) {
        // Log error, don't crash
      },
    );
  }

  Future<void> search(String query) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    state = const TeachersLoading();

    final result = await _repository.getTeachers(
      schoolId: schoolId,
      skip: 0,
      limit: 20,
      search: query.isNotEmpty ? query : null,
    );

    result.when(
      onSuccess: (list) {
        state = TeachersSuccess(
          teachers: list,
          hasReachedMax: list.length < 20,
          searchQuery: query,
        );
      },
      onFailure: (failure) {
        state = TeachersError(failure.message);
      },
    );
  }
}

final teachersStateProvider = StateNotifierProvider<TeachersNotifier, TeachersState>((ref) {
  final repo = ref.watch(teacherRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return TeachersNotifier(repo, session);
});
