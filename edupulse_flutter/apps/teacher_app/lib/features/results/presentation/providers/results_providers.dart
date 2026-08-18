import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/result_summary_entity.dart';
import '../../domain/entities/report_card_entity.dart';
import '../../domain/entities/report_card_preview_entity.dart';
import '../../domain/entities/bulk_class_generate_entity.dart';
import '../../domain/repositories/results_repository.dart';
import '../../data/datasources/results_remote_datasource.dart';
import '../../data/repositories/results_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final resultsRepositoryProvider = Provider<ResultsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ResultsRepositoryImpl(ResultsRemoteDatasource(apiClient));
});

final resultsSummaryProvider = FutureProvider.family<ResultSummaryEntity, String>((ref, examScheduleId) async {
  final repo = ref.watch(resultsRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final schoolId = authState is Authenticated ? authState.user.schools.firstOrNull ?? '' : '';
  final result = await repo.getResultSummary(examScheduleId: examScheduleId, schoolId: schoolId);
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw failure,
  );
});

final reportCardsProvider = FutureProvider.family<List<ReportCardEntity>, ({String classId, String sectionId})>((ref, arg) async {
  final repo = ref.watch(resultsRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final schoolId = authState is Authenticated ? authState.user.schools.firstOrNull ?? '' : '';
  final result = await repo.getReportCards(
    schoolId: schoolId,
    classId: arg.classId,
    sectionId: arg.sectionId,
  );
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw failure,
  );
});

class StudentResultPreviewState {
  final bool isLoading;
  final String? error;
  final ReportCardPreviewEntity? preview;
  final ReportCardEntity? reportCard;
  final String? teacherRemarks;
  final bool isSaving;
  final bool isSubmitting;

  const StudentResultPreviewState({
    this.isLoading = false,
    this.error,
    this.preview,
    this.reportCard,
    this.teacherRemarks,
    this.isSaving = false,
    this.isSubmitting = false,
  });

  StudentResultPreviewState copyWith({
    bool? isLoading,
    String? error,
    ReportCardPreviewEntity? preview,
    ReportCardEntity? reportCard,
    String? teacherRemarks,
    bool? isSaving,
    bool? isSubmitting,
  }) {
    return StudentResultPreviewState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      preview: preview ?? this.preview,
      reportCard: reportCard ?? this.reportCard,
      teacherRemarks: teacherRemarks ?? this.teacherRemarks,
      isSaving: isSaving ?? this.isSaving,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class StudentResultPreviewNotifier extends FamilyNotifier<StudentResultPreviewState, String> {
  @override
  StudentResultPreviewState build(String arg) {
    return const StudentResultPreviewState();
  }

  Future<void> fetchPreviewAndReportCard({
    required String studentId,
    required String schoolId,
    required String classId,
    required String sectionId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = ref.read(resultsRepositoryProvider);

    final previewRes = await repo.getReportCardPreview(studentId: studentId, schoolId: schoolId);
    final listRes = await repo.getReportCards(schoolId: schoolId, classId: classId, sectionId: sectionId);

    previewRes.when(
      onSuccess: (previewData) {
        listRes.when(
          onSuccess: (listData) {
            final card = listData.firstWhere(
              (element) => element.studentId == studentId,
              orElse: () => ReportCardEntity(
                id: '',
                verificationUuid: '',
                status: ReportCardStatus.DRAFT,
                pdfHistory: const [],
                settings: const {},
                aiMetrics: const {},
                isActive: false,
                version: 0,
                tenantId: '',
                schoolId: '',
                academicYearId: '',
                studentId: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            state = state.copyWith(
              isLoading: false,
              preview: previewData,
              reportCard: card.id.isNotEmpty ? card : null,
              teacherRemarks: previewData.teacherRemarks,
            );
          },
          onFailure: (err) {
            state = state.copyWith(
              isLoading: false,
              error: err.message,
            );
          },
        );
      },
      onFailure: (err) {
        state = state.copyWith(
          isLoading: false,
          error: err.message,
        );
      },
    );
  }

  void updateRemarks(String remarks) {
    state = state.copyWith(teacherRemarks: remarks);
  }

  Future<bool> generateDraft({
    required String studentId,
    required String schoolId,
    required String classId,
    required String sectionId,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    final repo = ref.read(resultsRepositoryProvider);

    final res = await repo.generateReportCard(
      studentId: studentId,
      schoolId: schoolId,
      remarks: state.teacherRemarks,
    );

    return res.when(
      onSuccess: (card) {
        state = state.copyWith(
          isSaving: false,
          reportCard: card,
        );
        ref.invalidate(reportCardsProvider((classId: classId, sectionId: sectionId)));
        return true;
      },
      onFailure: (err) {
        state = state.copyWith(
          isSaving: false,
          error: err.message,
        );
        return false;
      },
    );
  }

  Future<bool> submitReview({
    required String schoolId,
    required String classId,
    required String sectionId,
  }) async {
    final cardId = state.reportCard?.id;
    if (cardId == null || cardId.isEmpty) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    final repo = ref.read(resultsRepositoryProvider);

    final res = await repo.submitForReview(id: cardId, schoolId: schoolId);

    return res.when(
      onSuccess: (card) {
        state = state.copyWith(
          isSubmitting: false,
          reportCard: card,
        );
        ref.invalidate(reportCardsProvider((classId: classId, sectionId: sectionId)));
        return true;
      },
      onFailure: (err) {
        state = state.copyWith(
          isSubmitting: false,
          error: err.message,
        );
        return false;
      },
    );
  }
}

final studentResultPreviewProvider =
    NotifierProviderFamily<StudentResultPreviewNotifier, StudentResultPreviewState, String>(
  StudentResultPreviewNotifier.new,
);

class BulkClassGenerateNotifier extends StateNotifier<AsyncValue<BulkClassGenerateEntity?>> {
  final ResultsRepository _repository;
  BulkClassGenerateNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> runBulkGenerate({
    required String classId,
    required String sectionId,
    required String schoolId,
  }) async {
    state = const AsyncValue.loading();
    final res = await _repository.bulkGenerateClass(
      classId: classId,
      sectionId: sectionId,
      schoolId: schoolId,
    );
    state = res.when(
      onSuccess: (data) => AsyncValue.data(data),
      onFailure: (err) => AsyncValue.error(err.message, StackTrace.current),
    );
  }
}

final bulkClassGenerateProvider =
    StateNotifierProvider<BulkClassGenerateNotifier, AsyncValue<BulkClassGenerateEntity?>>((ref) {
  final repo = ref.watch(resultsRepositoryProvider);
  return BulkClassGenerateNotifier(repo);
});
