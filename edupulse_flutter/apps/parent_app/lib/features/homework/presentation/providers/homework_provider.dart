import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_files/edupulse_files.dart';
import '../../domain/entities/homework.dart';
import '../../domain/repositories/homework_repository.dart';
import '../../domain/usecases/get_homework_usecase.dart';
import '../../domain/usecases/download_attachment_usecase.dart';
import '../../data/datasource/homework_remote_datasource.dart';
import '../../data/repositories/homework_repository_impl.dart';

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
  final List<HomeworkEntity> homeworks;
  final bool isFromCache;
  const HomeworkSuccess(this.homeworks, {this.isFromCache = false});
}

class HomeworkError extends HomeworkState {
  final String message;
  const HomeworkError(this.message);
}

class HomeworkEmpty extends HomeworkState {
  const HomeworkEmpty();
}

final homeworkRemoteDatasourceProvider =
    Provider<HomeworkRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HomeworkRemoteDatasource(apiClient);
});

final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  final remote = ref.watch(homeworkRemoteDatasourceProvider);
  return HomeworkRepositoryImpl(remote);
});

final getHomeworkUseCaseProvider = Provider<GetHomeworkUseCase>((ref) {
  final repo = ref.watch(homeworkRepositoryProvider);
  return GetHomeworkUseCase(repo);
});

final storageManagerProvider = Provider<StorageManager>((ref) {
  return const StorageManager();
});

final fileDownloadServiceProvider = Provider<FileDownloadService>((ref) {
  final storage = ref.watch(storageManagerProvider);
  final dio = ref.watch(dioProvider);
  return FileDownloadService(storage, dio);
});

final downloadAttachmentUseCaseProvider =
    Provider<DownloadAttachmentUseCase>((ref) {
  final fileService = ref.watch(fileDownloadServiceProvider);
  return DownloadAttachmentUseCase(fileService);
});

class HomeworkNotifier extends Notifier<HomeworkState> {
  @override
  HomeworkState build() {
    return const HomeworkInitial();
  }

  Future<void> fetchHomework({
    required String schoolId,
    bool isRefresh = false,
  }) async {
    state = isRefresh ? const HomeworkLoading() : const HomeworkInitial();

    final getHomework = ref.read(getHomeworkUseCaseProvider);
    final result = await getHomework(
      schoolId: schoolId,
      forceRefresh: isRefresh,
    );

    result.when(
      onSuccess: (list) {
        if (list.isEmpty) {
          state = const HomeworkEmpty();
        } else {
          state = HomeworkSuccess(list);
        }
      },
      onFailure: (failure) {
        state = HomeworkError(failure.message);
      },
    );
  }
}

final homeworkStateProvider = NotifierProvider<HomeworkNotifier, HomeworkState>(
  HomeworkNotifier.new,
);
