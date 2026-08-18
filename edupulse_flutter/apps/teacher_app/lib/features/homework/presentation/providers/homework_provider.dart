import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/homework_entity.dart';
import '../../domain/repositories/homework_repository.dart';
import '../../data/datasource/homework_remote_datasource.dart';
import '../../data/repositories/homework_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

// --- PROVIDER DEFINITIONS ---

final homeworkRemoteDatasourceProvider = Provider<HomeworkRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HomeworkRemoteDatasource(apiClient);
});

final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  final remote = ref.watch(homeworkRemoteDatasourceProvider);
  return HomeworkRepositoryImpl(remote);
});

// --- STATE REPRESENTATIONS ---

sealed class HomeworkListState {
  const HomeworkListState();
}

class HomeworkListInitial extends HomeworkListState {
  const HomeworkListInitial();
}

class HomeworkListLoading extends HomeworkListState {
  const HomeworkListLoading();
}

class HomeworkListSuccess extends HomeworkListState {
  final List<HomeworkEntity> homeworks;
  const HomeworkListSuccess(this.homeworks);
}

class HomeworkListError extends HomeworkListState {
  final String message;
  const HomeworkListError(this.message);
}

class HomeworkListNotifier extends StateNotifier<HomeworkListState> {
  final HomeworkRepository _repository;
  final Ref _ref;

  HomeworkListNotifier(this._repository, this._ref) : super(const HomeworkListInitial());

  Future<void> fetchHomeworks({
    HomeworkStatus? status,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? search,
  }) async {
    state = const HomeworkListLoading();

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const HomeworkListError('User is not authenticated.');
      return;
    }

    final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
    if (schoolId == null) {
      state = const HomeworkListError('No school associated with this user.');
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      state = const HomeworkListError('Dashboard data must be loaded first.');
      return;
    }

    final academicYearId = dashboardState is DashboardSuccess
        ? dashboardState.data.academicYear.id
        : (dashboardState as DashboardRefreshing).data.academicYear.id;

    final teacherId = dashboardState is DashboardSuccess
        ? dashboardState.data.teacherProfile.id
        : (dashboardState as DashboardRefreshing).data.teacherProfile.id;

    final result = await _repository.listHomeworks(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      teacherId: teacherId,
      status: status,
      search: search,
    );

    result.when(
      onSuccess: (list) {
        state = HomeworkListSuccess(list);
      },
      onFailure: (err) {
        state = HomeworkListError(err.message);
      },
    );
  }
}

final homeworkListProvider = StateNotifierProvider<HomeworkListNotifier, HomeworkListState>((ref) {
  final repo = ref.watch(homeworkRepositoryProvider);
  return HomeworkListNotifier(repo, ref);
});

// --- SINGLE HOMEWORK DETAIL ---

sealed class HomeworkDetailState {
  const HomeworkDetailState();
}

class HomeworkDetailInitial extends HomeworkDetailState {
  const HomeworkDetailInitial();
}

class HomeworkDetailLoading extends HomeworkDetailState {
  const HomeworkDetailLoading();
}

class HomeworkDetailSuccess extends HomeworkDetailState {
  final HomeworkEntity homework;
  const HomeworkDetailSuccess(this.homework);
}

class HomeworkDetailError extends HomeworkDetailState {
  final String message;
  const HomeworkDetailError(this.message);
}

class HomeworkDetailNotifier extends StateNotifier<HomeworkDetailState> {
  final HomeworkRepository _repository;
  final Ref _ref;
  final String _homeworkId;

  HomeworkDetailNotifier(this._repository, this._ref, this._homeworkId)
      : super(const HomeworkDetailInitial());

  Future<void> fetchDetails() async {
    state = const HomeworkDetailLoading();

    final authState = _ref.read(authStateProvider);
    final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty
        ? authState.user.schools.first
        : null;

    if (schoolId == null) {
      state = const HomeworkDetailError('Authentication mismatch.');
      return;
    }

    final result = await _repository.getHomeworkById(
      schoolId: schoolId,
      id: _homeworkId,
    );

    result.when(
      onSuccess: (hw) {
        state = HomeworkDetailSuccess(hw);
      },
      onFailure: (err) {
        state = HomeworkDetailError(err.message);
      },
    );
  }

  Future<bool> publish() async {
    final authState = _ref.read(authStateProvider);
    final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty
        ? authState.user.schools.first
        : null;

    if (schoolId == null) return false;

    final result = await _repository.publishHomework(
      schoolId: schoolId,
      id: _homeworkId,
    );

    return result.when(
      onSuccess: (updated) {
        state = HomeworkDetailSuccess(updated);
        return true;
      },
      onFailure: (err) {
        state = HomeworkDetailError(err.message);
        return false;
      },
    );
  }

  Future<bool> delete() async {
    final authState = _ref.read(authStateProvider);
    final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty
        ? authState.user.schools.first
        : null;

    if (schoolId == null) return false;

    final result = await _repository.deleteHomework(
      schoolId: schoolId,
      id: _homeworkId,
    );

    return result.when(
      onSuccess: (_) {
        return true;
      },
      onFailure: (err) {
        state = HomeworkDetailError(err.message);
        return false;
      },
    );
  }
}

final homeworkDetailProvider = StateNotifierProvider.family<HomeworkDetailNotifier, HomeworkDetailState, String>((ref, id) {
  final repo = ref.watch(homeworkRepositoryProvider);
  return HomeworkDetailNotifier(repo, ref, id);
});

// --- FORM AND OPERATIONS ---

sealed class HomeworkFormState {
  const HomeworkFormState();
}

class HomeworkFormInitial extends HomeworkFormState {
  const HomeworkFormInitial();
}

class HomeworkFormSubmitting extends HomeworkFormState {
  const HomeworkFormSubmitting();
}

class HomeworkFormSuccess extends HomeworkFormState {
  final HomeworkEntity homework;
  const HomeworkFormSuccess(this.homework);
}

class HomeworkFormError extends HomeworkFormState {
  final String message;
  const HomeworkFormError(this.message);
}

class HomeworkFormNotifier extends StateNotifier<HomeworkFormState> {
  final HomeworkRepository _repository;
  final Ref _ref;

  HomeworkFormNotifier(this._repository, this._ref) : super(const HomeworkFormInitial());

  Future<bool> createHomework({
    required String title,
    required String description,
    required DateTime dueDate,
    required HomeworkPriority priority,
    required HomeworkStatus status,
    required String teacherSubjectAssignmentId,
    required String subjectId,
    required String classId,
    required String sectionId,
    String? timetableId,
    int? estimatedMinutes,
    String? attachmentUrl,
  }) async {
    state = const HomeworkFormSubmitting();

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const HomeworkFormError('User is not authenticated.');
      return false;
    }

    final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
    if (schoolId == null) {
      state = const HomeworkFormError('No school associated.');
      return false;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      state = const HomeworkFormError('Dashboard data must be loaded first.');
      return false;
    }

    final academicYearId = dashboardState is DashboardSuccess
        ? dashboardState.data.academicYear.id
        : (dashboardState as DashboardRefreshing).data.academicYear.id;

    final teacherId = dashboardState is DashboardSuccess
        ? dashboardState.data.teacherProfile.id
        : (dashboardState as DashboardRefreshing).data.teacherProfile.id;

    final result = await _repository.createHomework(
      schoolId: schoolId,
      academicYearId: academicYearId,
      teacherId: teacherId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      subjectId: subjectId,
      classId: classId,
      sectionId: sectionId,
      timetableId: timetableId,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      status: status,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
    );

    return result.when(
      onSuccess: (hw) {
        state = HomeworkFormSuccess(hw);
        return true;
      },
      onFailure: (err) {
        state = HomeworkFormError(err.message);
        return false;
      },
    );
  }

  Future<bool> createFromTimetable({
    required String timetableId,
    required String title,
    required String description,
    required DateTime dueDate,
    required HomeworkPriority priority,
    required HomeworkStatus status,
    int? estimatedMinutes,
    String? attachmentUrl,
  }) async {
    state = const HomeworkFormSubmitting();

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const HomeworkFormError('User is not authenticated.');
      return false;
    }

    final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
    if (schoolId == null) {
      state = const HomeworkFormError('No school associated.');
      return false;
    }

    final result = await _repository.createFromTimetable(
      schoolId: schoolId,
      timetableId: timetableId,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      status: status,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
    );

    return result.when(
      onSuccess: (hw) {
        state = HomeworkFormSuccess(hw);
        return true;
      },
      onFailure: (err) {
        state = HomeworkFormError(err.message);
        return false;
      },
    );
  }

  Future<bool> updateHomework({
    required String id,
    String? title,
    String? description,
    DateTime? dueDate,
    HomeworkPriority? priority,
    HomeworkStatus? status,
    int? estimatedMinutes,
    String? attachmentUrl,
  }) async {
    state = const HomeworkFormSubmitting();

    final authState = _ref.read(authStateProvider);
    final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty
        ? authState.user.schools.first
        : null;

    if (schoolId == null) {
      state = const HomeworkFormError('Authentication mismatch.');
      return false;
    }

    final result = await _repository.updateHomework(
      schoolId: schoolId,
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      status: status,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
    );

    return result.when(
      onSuccess: (hw) {
        state = HomeworkFormSuccess(hw);
        return true;
      },
      onFailure: (err) {
        state = HomeworkFormError(err.message);
        return false;
      },
    );
  }

  Future<bool> copyToSections({
    required String homeworkId,
    required List<String> targetSectionIds,
  }) async {
    state = const HomeworkFormSubmitting();

    final authState = _ref.read(authStateProvider);
    final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty
        ? authState.user.schools.first
        : null;

    if (schoolId == null) {
      state = const HomeworkFormError('Authentication mismatch.');
      return false;
    }

    final result = await _repository.copyHomework(
      schoolId: schoolId,
      homeworkId: homeworkId,
      targetSectionIds: targetSectionIds,
    );

    return result.when(
      onSuccess: (_) {
        state = const HomeworkFormInitial();
        return true;
      },
      onFailure: (err) {
        state = HomeworkFormError(err.message);
        return false;
      },
    );
  }
}

final homeworkFormNotifierProvider = StateNotifierProvider<HomeworkFormNotifier, HomeworkFormState>((ref) {
  final repo = ref.watch(homeworkRepositoryProvider);
  return HomeworkFormNotifier(repo, ref);
});

// --- TEMPLATES UTILITY ---

final homeworkTemplatesProvider = FutureProvider.family<List<String>, String?>((ref, subjectId) async {
  final repo = ref.watch(homeworkRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty
      ? authState.user.schools.first
      : null;

  if (schoolId == null) return [];

  final result = await repo.getTemplates(schoolId: schoolId, subjectId: subjectId);
  return result.when(
    onSuccess: (list) => list,
    onFailure: (_) => [],
  );
});
