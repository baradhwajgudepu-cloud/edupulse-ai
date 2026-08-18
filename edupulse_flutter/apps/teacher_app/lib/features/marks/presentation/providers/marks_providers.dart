import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/examination_entity.dart';
import '../../domain/entities/student_mark_entity.dart';
import '../../domain/entities/marks_wizard_entity.dart';
import '../../domain/entities/marks_publish_summary_entity.dart';
import '../../domain/repositories/marks_repository.dart';
import '../../data/datasources/marks_remote_datasource.dart';
import '../../data/repositories/marks_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

final marksRemoteDatasourceProvider = Provider<MarksRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MarksRemoteDatasource(apiClient);
});

final marksRepositoryProvider = Provider<MarksRepository>((ref) {
  final remote = ref.watch(marksRemoteDatasourceProvider);
  return MarksRepositoryImpl(remote);
});

// FutureProvider for Examinations list
final marksExaminationsProvider = FutureProvider.family<List<ExaminationEntity>, String?>((ref, academicYearId) async {
  final repository = ref.watch(marksRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  if (authState is! Authenticated) return [];
  final schoolId = authState.user.schools.first;
  final result = await repository.getExaminations(
    schoolId: schoolId,
    academicYearId: academicYearId,
  );
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw failure,
  );
});

// FutureProvider for Remarks Templates
final remarksTemplatesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(marksRepositoryProvider);
  final result = await repository.getRemarksTemplates();
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw failure,
  );
});

class MarksWizardState {
  final MarksWizardEntity? wizardData;
  final bool isLoading;
  final String? errorMessage;
  // Local drafts mapping: studentId -> SingleMarkInput
  final Map<String, SingleMarkInput> localDrafts;
  final String searchQuery;
  final Map<String, String> validationErrors;
  final bool isDirty;
  
  // Save states
  final bool isSaving;
  final String? saveStatusText; // "Saving...", "Saved", "Save failed", "Unsaved changes"
  final bool hasSaveError;
  final bool isSaveSuccess;
  
  // Publish states
  final bool isPublishing;
  final MarksPublishSummaryEntity? publishSummary;
  final bool isPublishSuccess;

  const MarksWizardState({
    this.wizardData,
    required this.isLoading,
    this.errorMessage,
    required this.localDrafts,
    required this.searchQuery,
    required this.validationErrors,
    required this.isDirty,
    required this.isSaving,
    this.saveStatusText,
    required this.hasSaveError,
    required this.isSaveSuccess,
    required this.isPublishing,
    this.publishSummary,
    required this.isPublishSuccess,
  });

  MarksWizardState copyWith({
    MarksWizardEntity? wizardData,
    bool? isLoading,
    String? errorMessage,
    Map<String, SingleMarkInput>? localDrafts,
    String? searchQuery,
    Map<String, String>? validationErrors,
    bool? isDirty,
    bool? isSaving,
    String? saveStatusText,
    bool? hasSaveError,
    bool? isSaveSuccess,
    bool? isPublishing,
    MarksPublishSummaryEntity? publishSummary,
    bool? isPublishSuccess,
  }) {
    return MarksWizardState(
      wizardData: wizardData ?? this.wizardData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      localDrafts: localDrafts ?? this.localDrafts,
      searchQuery: searchQuery ?? this.searchQuery,
      validationErrors: validationErrors ?? this.validationErrors,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      saveStatusText: saveStatusText ?? this.saveStatusText,
      hasSaveError: hasSaveError ?? this.hasSaveError,
      isSaveSuccess: isSaveSuccess ?? this.isSaveSuccess,
      isPublishing: isPublishing ?? this.isPublishing,
      publishSummary: publishSummary ?? this.publishSummary,
      isPublishSuccess: isPublishSuccess ?? this.isPublishSuccess,
    );
  }
}

class MarksWizardNotifier extends StateNotifier<MarksWizardState> {
  final MarksRepository _repository;
  final String _examScheduleId;
  final Ref _ref;
  Timer? _debounceTimer;

  MarksWizardNotifier(this._repository, this._examScheduleId, this._ref)
      : super(const MarksWizardState(
          isLoading: true,
          localDrafts: {},
          searchQuery: '',
          validationErrors: {},
          isDirty: false,
          isSaving: false,
          hasSaveError: false,
          isSaveSuccess: false,
          isPublishing: false,
          isPublishSuccess: false,
        )) {
    loadWizardData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadWizardData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = state.copyWith(isLoading: false, errorMessage: 'User is not authenticated.');
      return;
    }
    final schoolId = authState.user.schools.first;

    final result = await _repository.getMarksWizard(
      examScheduleId: _examScheduleId,
      schoolId: schoolId,
    );

    result.when(
      onSuccess: (data) {
        final drafts = <String, SingleMarkInput>{};
        for (final entry in data.entries) {
          final mark = entry.markRecord;
          if (mark != null) {
            drafts[entry.student.id] = SingleMarkInput(
              studentId: entry.student.id,
              marksObtained: mark.marksObtained,
              resultStatus: mark.resultStatus,
              remarks: mark.remarks,
            );
          } else {
            // New marks should default to PRESENT
            drafts[entry.student.id] = SingleMarkInput(
              studentId: entry.student.id,
              marksObtained: null,
              resultStatus: ExamResult.PRESENT,
              remarks: null,
            );
          }
        }
        state = state.copyWith(
          wizardData: data,
          localDrafts: drafts,
          isLoading: false,
          isDirty: false,
          saveStatusText: data.enteredCount > 0 ? 'Saved' : null,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void updateMark(String studentId, {double? marksObtained, ExamResult? resultStatus, String? remarks, required int maxMarks}) {
    final drafts = Map<String, SingleMarkInput>.from(state.localDrafts);
    final current = drafts[studentId];

    if (current == null) return;

    // Resolve changes
    var newMarks = marksObtained ?? current.marksObtained;
    final newStatus = resultStatus ?? current.resultStatus;
    final newRemarks = remarks ?? current.remarks;

    // If status is ABSENT or MALPRACTICE, backend forces score to null
    if (newStatus == ExamResult.ABSENT || newStatus == ExamResult.MALPRACTICE) {
      newMarks = null;
    }

    drafts[studentId] = SingleMarkInput(
      studentId: studentId,
      marksObtained: newMarks,
      resultStatus: newStatus,
      remarks: newRemarks,
    );

    // Local validation
    final errors = Map<String, String>.from(state.validationErrors);
    if (newStatus == ExamResult.PRESENT && newMarks != null) {
      if (newMarks < 0) {
        errors[studentId] = 'Marks cannot be negative.';
      } else if (newMarks > maxMarks) {
        errors[studentId] = 'Marks cannot exceed maximum marks ($maxMarks).';
      } else {
        errors.remove(studentId);
      }
    } else {
      errors.remove(studentId);
    }

    state = state.copyWith(
      localDrafts: drafts,
      validationErrors: errors,
      isDirty: true,
      saveStatusText: 'Unsaved changes',
      isSaveSuccess: false,
      hasSaveError: false,
    );

    // Controlled autosave debounce
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      final authState = _ref.read(authStateProvider);
      if (authState is Authenticated) {
        final currentTsaId = _getTeacherSubjectAssignmentId();
        if (currentTsaId != null) {
          saveDraft(teacherSubjectAssignmentId: currentTsaId, autosave: true);
        }
      }
    });
  }

  String? _getTeacherSubjectAssignmentId() {
    final entry = state.wizardData?.entries.firstOrNull;
    if (entry != null && entry.markRecord != null) {
      return entry.markRecord!.teacherSubjectAssignmentId;
    }
    return null;
  }

  Future<void> saveDraft({required String teacherSubjectAssignmentId, bool autosave = false}) async {
    // If validations have error, block save
    if (state.validationErrors.isNotEmpty) {
      state = state.copyWith(
        hasSaveError: true,
        saveStatusText: 'Save failed: validation errors',
      );
      return;
    }

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) return;
    final schoolId = authState.user.schools.first;

    state = state.copyWith(isSaving: true, saveStatusText: 'Saving...');

    final expectedMarks = state.localDrafts.values.toList();
    final isUpdate = state.wizardData != null && state.wizardData!.enteredCount > 0;

    final result = await _repository.bulkSaveMarks(
      schoolId: schoolId,
      examScheduleId: _examScheduleId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      marks: expectedMarks,
      autosave: autosave,
      isUpdate: isUpdate,
    );

    await result.when(
      onSuccess: (data) async {
        // Successfully saved - reload sheet stats
        await loadWizardData();
        state = state.copyWith(
          isSaving: false,
          isSaveSuccess: true,
          saveStatusText: 'Saved',
        );
      },
      onFailure: (failure) async {
        if (failure.message.contains('timeout') || failure.message.contains('Network') || failure.message.contains('Connection')) {
          // Timeout reconciliation
          state = state.copyWith(saveStatusText: 'Connection lost. Checking server...');
          await _reconcileWithBackend(schoolId, teacherSubjectAssignmentId, expectedMarks);
        } else {
          state = state.copyWith(
            isSaving: false,
            hasSaveError: true,
            saveStatusText: 'Save failed',
          );
        }
      },
    );
  }

  Future<void> _reconcileWithBackend(String schoolId, String teacherSubjectAssignmentId, List<SingleMarkInput> expectedMarks) async {
    final result = await _repository.getMarksWizard(
      examScheduleId: _examScheduleId,
      schoolId: schoolId,
    );

    result.when(
      onSuccess: (data) {
        // Compare expected vs loaded
        var allMatched = true;
        for (final expected in expectedMarks) {
          final matching = data.entries.firstWhere(
            (e) => e.student.id == expected.studentId,
            orElse: () => throw Exception('Student matching expected not found'),
          );
          final record = matching.markRecord;
          if (record == null) {
            allMatched = false;
            break;
          }
          if (record.resultStatus != expected.resultStatus) {
            allMatched = false;
            break;
          }
          if (expected.resultStatus == ExamResult.PRESENT && record.marksObtained != expected.marksObtained) {
            allMatched = false;
            break;
          }
        }

        if (allMatched) {
          // Yes, server has updated data!
          final drafts = <String, SingleMarkInput>{};
          for (final entry in data.entries) {
            final mark = entry.markRecord;
            if (mark != null) {
              drafts[entry.student.id] = SingleMarkInput(
                studentId: entry.student.id,
                marksObtained: mark.marksObtained,
                resultStatus: mark.resultStatus,
                remarks: mark.remarks,
              );
            }
          }
          state = state.copyWith(
            wizardData: data,
            localDrafts: drafts,
            isSaving: false,
            isSaveSuccess: true,
            isDirty: false,
            saveStatusText: 'Saved (Reconciled)',
          );
        } else {
          // Merge whatever server has and alert user
          final drafts = <String, SingleMarkInput>{};
          for (final entry in data.entries) {
            final mark = entry.markRecord;
            if (mark != null) {
              drafts[entry.student.id] = SingleMarkInput(
                studentId: entry.student.id,
                marksObtained: mark.marksObtained,
                resultStatus: mark.resultStatus,
                remarks: mark.remarks,
              );
            }
          }
          state = state.copyWith(
            wizardData: data,
            localDrafts: drafts,
            isSaving: false,
            hasSaveError: true,
            saveStatusText: 'Reconciled: Save incomplete',
          );
        }
      },
      onFailure: (_) {
        state = state.copyWith(
          isSaving: false,
          hasSaveError: true,
          saveStatusText: 'Reconciliation failed',
        );
      },
    );
  }

  Future<void> fetchPublishSummary() async {
    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) return;
    final schoolId = authState.user.schools.first;

    final result = await _repository.getPublishSummary(
      examScheduleId: _examScheduleId,
      schoolId: schoolId,
    );

    result.when(
      onSuccess: (summary) {
        state = state.copyWith(publishSummary: summary);
      },
      onFailure: (failure) {
        // Handle failure
      },
    );
  }

  Future<bool> publishMarks() async {
    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) return false;
    final schoolId = authState.user.schools.first;

    state = state.copyWith(isPublishing: true);

    final result = await _repository.publishMarks(
      examScheduleId: _examScheduleId,
      schoolId: schoolId,
    );

    return result.when(
      onSuccess: (data) {
        state = state.copyWith(
          isPublishing: false,
          isPublishSuccess: true,
        );
        loadWizardData();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isPublishing: false);
        return false;
      },
    );
  }
}

final marksWizardProvider = StateNotifierProvider.family<MarksWizardNotifier, MarksWizardState, String>((ref, examScheduleId) {
  final repo = ref.watch(marksRepositoryProvider);
  return MarksWizardNotifier(repo, examScheduleId, ref);
});
