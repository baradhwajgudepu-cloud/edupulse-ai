import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/datasources/homework_datasource.dart';
import '../../data/repositories/homework_repository.dart';
import '../../data/models/homework_model.dart';

// Datasource Provider
final homeworkDatasourceProvider = Provider<HomeworkDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HomeworkDatasource(apiClient);
});

// Repository Provider
final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  final datasource = ref.watch(homeworkDatasourceProvider);
  return HomeworkRepository(datasource);
});

sealed class HomeworkState {
  const HomeworkState();
}

class HomeworkInitial extends HomeworkState {
  const HomeworkInitial();
}

class HomeworkLoading extends HomeworkState {
  const HomeworkLoading();
}

class HomeworkSuccess extends HomeworkState {
  final List<Homework> homeworks;
  const HomeworkSuccess(this.homeworks);
}

class HomeworkError extends HomeworkState {
  final String message;
  const HomeworkError(this.message);
}

class HomeworkNotifier extends StateNotifier<HomeworkState> {
  final HomeworkRepository _repository;
  final SessionManager _sessionManager;

  HomeworkNotifier(this._repository, this._sessionManager) : super(const HomeworkInitial());

  Future<void> fetchHomeworks({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = const HomeworkLoading();
    }

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const HomeworkError('No active school context found.');
      return;
    }

    final result = await _repository.getHomeworks(schoolId: schoolId);

    result.when(
      onSuccess: (list) {
        state = HomeworkSuccess(list);
      },
      onFailure: (failure) {
        state = HomeworkError(failure.message);
      },
    );
  }
}

final homeworkStateProvider = StateNotifierProvider<HomeworkNotifier, HomeworkState>((ref) {
  final repo = ref.watch(homeworkRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return HomeworkNotifier(repo, session);
});
