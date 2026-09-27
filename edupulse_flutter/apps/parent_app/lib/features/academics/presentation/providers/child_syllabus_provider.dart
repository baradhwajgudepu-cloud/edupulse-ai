import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/datasources/child_syllabus_datasource.dart';
import '../../data/models/child_syllabus_models.dart';

sealed class ChildSyllabusState {
  const ChildSyllabusState();
}

class ChildSyllabusInitial extends ChildSyllabusState {
  const ChildSyllabusInitial();
}

class ChildSyllabusLoading extends ChildSyllabusState {
  const ChildSyllabusLoading();
}

class ChildSyllabusSuccess extends ChildSyllabusState {
  final ChildSyllabusProgressResponse progress;
  const ChildSyllabusSuccess(this.progress);
}

class ChildSyllabusError extends ChildSyllabusState {
  final String message;
  const ChildSyllabusError(this.message);
}

final childSyllabusDatasourceProvider = Provider<ChildSyllabusDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChildSyllabusDatasource(apiClient);
});

class ChildSyllabusNotifier extends Notifier<ChildSyllabusState> {
  @override
  ChildSyllabusState build() {
    return const ChildSyllabusInitial();
  }

  Future<void> fetchChildProgress({
    required String studentId,
    required String schoolId,
    required String academicYearId,
  }) async {
    state = const ChildSyllabusLoading();
    final ds = ref.read(childSyllabusDatasourceProvider);

    final res = await ds.getChildSyllabusProgress(
      studentId: studentId,
      schoolId: schoolId,
      academicYearId: academicYearId,
    );

    res.when(
      onSuccess: (data) {
        state = ChildSyllabusSuccess(data);
      },
      onFailure: (failure) {
        state = ChildSyllabusError(failure.message);
      },
    );
  }
}

final childSyllabusStateProvider =
    NotifierProvider<ChildSyllabusNotifier, ChildSyllabusState>(() {
  return ChildSyllabusNotifier();
});
