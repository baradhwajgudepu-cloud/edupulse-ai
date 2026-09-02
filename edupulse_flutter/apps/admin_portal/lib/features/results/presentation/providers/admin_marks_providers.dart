import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/admin_marks_models.dart';
import '../../data/models/examination_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import 'results_download_helper.dart';

// ==================================================
// Filter State & Notifier
// ==================================================
class AdminMarksFiltersState {
  final String? academicYearId;
  final String? examinationId;
  final String? classId;
  final String? sectionId;
  final String? scheduleId;

  const AdminMarksFiltersState({
    this.academicYearId,
    this.examinationId,
    this.classId,
    this.sectionId,
    this.scheduleId,
  });

  AdminMarksFiltersState copyWith({
    String? academicYearId,
    bool clearAcademicYear = false,
    String? examinationId,
    bool clearExamination = false,
    String? classId,
    bool clearClass = false,
    String? sectionId,
    bool clearSection = false,
    String? scheduleId,
    bool clearSchedule = false,
  }) {
    return AdminMarksFiltersState(
      academicYearId: clearAcademicYear ? null : (academicYearId ?? this.academicYearId),
      examinationId: clearExamination ? null : (examinationId ?? this.examinationId),
      classId: clearClass ? null : (classId ?? this.classId),
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      scheduleId: clearSchedule ? null : (scheduleId ?? this.scheduleId),
    );
  }
}

class AdminMarksFiltersNotifier extends StateNotifier<AdminMarksFiltersState> {
  AdminMarksFiltersNotifier() : super(const AdminMarksFiltersState());

  void setAcademicYear(String? ayId) {
    state = state.copyWith(
      academicYearId: ayId,
      clearExamination: true,
      clearClass: true,
      clearSection: true,
      clearSchedule: true,
    );
  }

  void setExamination(String? examId) {
    state = state.copyWith(
      examinationId: examId,
      clearSchedule: true,
    );
  }

  void setClass(String? classId) {
    state = state.copyWith(
      classId: classId,
      clearSection: true,
      clearSchedule: true,
    );
  }

  void setSection(String? sectionId) {
    state = state.copyWith(
      sectionId: sectionId,
      clearSchedule: true,
    );
  }

  void setSchedule(String? scheduleId) {
    state = state.copyWith(scheduleId: scheduleId);
  }

  void reset() {
    state = const AdminMarksFiltersState();
  }
}

final adminMarksFiltersProvider = StateNotifierProvider<AdminMarksFiltersNotifier, AdminMarksFiltersState>((ref) {
  final notifier = AdminMarksFiltersNotifier();
  ref.listen<String?>(selectedSchoolIdProvider, (prev, next) {
    if (prev != next) {
      notifier.reset();
    }
  });
  return notifier;
});

// ==================================================
// Marks Examinations Provider (Academic Year Scoped)
// ==================================================
final marksExaminationsProvider = FutureProvider.autoDispose.family<List<ExaminationModel>, String?>((ref, academicYearId) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null || schoolId.isEmpty) return [];

  final apiClient = ref.watch(apiClientProvider);
  final queryParams = <String, dynamic>{
    'school_id': schoolId,
  };
  if (academicYearId != null && academicYearId.isNotEmpty) {
    queryParams['academic_year_id'] = academicYearId;
  }

  final result = await apiClient.get(
    '/examinations',
    queryParameters: queryParams,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list.map((item) => ExaminationModel.fromJson(item as Map<String, dynamic>)).toList();
    },
  );

  return result.when(
    onSuccess: (exams) => exams,
    onFailure: (failure) => [],
  );
});

// ==================================================
// Marks Exam Schedules Provider
// ==================================================
final marksExamSchedulesProvider = FutureProvider.autoDispose.family<List<AdminExamScheduleOption>, String>((ref, examId) async {
  if (examId.isEmpty) return [];
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null || schoolId.isEmpty) return [];

  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/examinations/schedules',
    queryParameters: {
      'school_id': schoolId,
      'exam_id': examId,
    },
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list.map((item) => AdminExamScheduleOption.fromJson(item as Map<String, dynamic>)).toList();
    },
  );

  return result.when(
    onSuccess: (schedules) => schedules,
    onFailure: (failure) => [],
  );
});

// ==================================================
// Board State Notifier
// ==================================================
class AdminMarksBoardNotifier extends StateNotifier<AdminMarksBoardState> {
  final Ref _ref;

  AdminMarksBoardNotifier(this._ref) : super(const AdminMarksBoardState());

  void clearActiveSchedule() {
    state = const AdminMarksBoardState();
  }

  Future<void> loadMarksForSchedule(AdminExamScheduleOption schedule) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(errorMessage: 'No active school selected.');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      activeScheduleId: schedule.id,
      activeSchedule: schedule,
    );

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.get(
      '/marks/wizard/entry',
      queryParameters: {
        'exam_schedule_id': schedule.id,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>? ?? {};
        final rawEntries = data['entries'] as List<dynamic>? ?? [];

        return rawEntries.map((entry) {
          final entryMap = entry as Map<String, dynamic>;
          final studentMap = entryMap['student'] as Map<String, dynamic>? ?? {};
          final markMap = entryMap['mark_record'] as Map<String, dynamic>?;

          double? marksObtained;
          if (markMap != null && markMap['marks_obtained'] != null) {
            marksObtained = (markMap['marks_obtained'] as num).toDouble();
          }

          AdminMarkResultStatus resultStatus = AdminMarkResultStatus.present;
          if (markMap != null && markMap['result_status'] != null) {
            resultStatus = AdminMarkResultStatus.fromBackendValue(markMap['result_status'].toString());
          }

          AdminMarkStatus markStatus = AdminMarkStatus.draft;
          if (markMap != null && markMap['status'] != null) {
            markStatus = AdminMarkStatus.fromBackendValue(markMap['status'].toString());
          }

          final rawAudit = markMap?['audit_history'] as List<dynamic>? ?? [];
          final auditHistory = rawAudit.map((a) => MarksAuditEntry.fromJson(a as Map<String, dynamic>)).toList();

          return AdminStudentMarkRow(
            studentId: (studentMap['id'] ?? '').toString(),
            firstName: (studentMap['first_name'] ?? '').toString(),
            lastName: (studentMap['last_name'] ?? '').toString(),
            rollNumber: (studentMap['roll_number'] ?? '-').toString(),
            maxMarks: schedule.maxMarks,
            marksObtained: marksObtained,
            resultStatus: resultStatus,
            status: markStatus,
            remarks: markMap?['remarks'] as String?,
            auditHistory: auditHistory,
          );
        }).toList();
      },
    );

    result.when(
      onSuccess: (rows) {
        state = state.copyWith(
          isLoading: false,
          rows: rows,
          hasUnsavedChanges: false,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  void updateStudentMark(String studentId, double? marks) {
    final schedule = state.activeSchedule;
    final maxMarks = schedule?.maxMarks ?? 100;

    String? error;
    if (marks != null) {
      if (marks < 0) {
        error = 'Marks cannot be negative';
      } else if (marks > maxMarks) {
        error = 'Marks cannot exceed maximum ($maxMarks)';
      }
    }

    final updatedRows = state.rows.map((row) {
      if (row.studentId == studentId) {
        return row.copyWith(
          marksObtained: marks,
          clearMarks: marks == null,
          isModified: true,
          validationError: error,
          clearError: error == null,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(
      rows: updatedRows,
      hasUnsavedChanges: true,
      clearSuccess: true,
    );
  }

  void updateStudentStatus(String studentId, AdminMarkResultStatus newStatus) {
    final updatedRows = state.rows.map((row) {
      if (row.studentId == studentId) {
        double? adjustedMarks = row.marksObtained;
        String? error;
        if (newStatus == AdminMarkResultStatus.absent || newStatus == AdminMarkResultStatus.exempted) {
          adjustedMarks = null;
        }

        if (newStatus == AdminMarkResultStatus.malpractice && (row.remarks == null || row.remarks!.trim().isEmpty)) {
          error = 'Remarks required for malpractice';
        }

        return row.copyWith(
          resultStatus: newStatus,
          marksObtained: adjustedMarks,
          clearMarks: adjustedMarks == null,
          isModified: true,
          validationError: error,
          clearError: error == null,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(
      rows: updatedRows,
      hasUnsavedChanges: true,
      clearSuccess: true,
    );
  }

  void updateStudentRemarks(String studentId, String remarks) {
    final updatedRows = state.rows.map((row) {
      if (row.studentId == studentId) {
        String? error;
        if (row.resultStatus == AdminMarkResultStatus.malpractice && remarks.trim().isEmpty) {
          error = 'Remarks required for malpractice';
        }
        return row.copyWith(
          remarks: remarks,
          isModified: true,
          validationError: error,
          clearError: error == null,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(
      rows: updatedRows,
      hasUnsavedChanges: true,
      clearSuccess: true,
    );
  }

  void applyAdministrativeOverride(String studentId, double? newMarks, String reason) {
    final schedule = state.activeSchedule;
    final maxMarks = schedule?.maxMarks ?? 100;

    String? error;
    if (newMarks != null) {
      if (newMarks < 0) {
        error = 'Marks cannot be negative';
      } else if (newMarks > maxMarks) {
        error = 'Marks cannot exceed maximum ($maxMarks)';
      }
    }

    if (reason.trim().isEmpty) {
      error = 'Override reason is mandatory';
    }

    final updatedRows = state.rows.map((row) {
      if (row.studentId == studentId) {
        return row.copyWith(
          marksObtained: newMarks,
          clearMarks: newMarks == null,
          overrideReason: reason.trim(),
          isModified: true,
          validationError: error,
          clearError: error == null,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(
      rows: updatedRows,
      hasUnsavedChanges: true,
      clearSuccess: true,
    );
  }

  Future<bool> bulkSaveMarks({bool submit = false}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final schedule = state.activeSchedule;
    if (schoolId == null || schedule == null) return false;

    // Check validation errors across all rows
    for (final row in state.rows) {
      if (row.validationError != null) {
        state = state.copyWith(errorMessage: 'Please fix validation errors before saving: ${row.validationError}');
        return false;
      }
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final marksPayload = state.rows.map((row) {
      return {
        'student_id': row.studentId,
        'marks_obtained': row.marksObtained,
        'result_status': row.resultStatus.toBackendValue(),
        'remarks': row.remarks,
        if (row.overrideReason != null && row.overrideReason!.isNotEmpty)
          'override_reason': row.overrideReason,
        if (submit) 'status': 'SUBMITTED',
      };
    }).toList();

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.post(
      '/marks/bulk',
      queryParameters: {
        'school_id': schoolId,
        'autosave': false,
      },
      data: {
        'exam_schedule_id': schedule.id,
        'marks': marksPayload,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) async {
        await loadMarksForSchedule(schedule);
        state = state.copyWith(
          isSaving: false,
          successMessage: submit ? 'Marks successfully submitted!' : 'Marks saved as draft successfully.',
          hasUnsavedChanges: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save marks: ${failure.message}',
        );
        return false;
      },
    );
  }

  Future<bool> publishMarks() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final schedule = state.activeSchedule;
    if (schoolId == null || schedule == null) return false;

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.post(
      '/marks/publish',
      queryParameters: {
        'exam_schedule_id': schedule.id,
        'school_id': schoolId,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) async {
        await loadMarksForSchedule(schedule);
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Marks successfully published to parent portal!',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to publish marks: ${failure.message}',
        );
        return false;
      },
    );
  }

  Future<bool> lockMarks() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final schedule = state.activeSchedule;
    if (schoolId == null || schedule == null) return false;

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.post(
      '/marks/lock',
      queryParameters: {'school_id': schoolId},
      data: {'exam_schedule_id': schedule.id},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) async {
        await loadMarksForSchedule(schedule);
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Marks entries successfully locked.',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to lock marks: ${failure.message}',
        );
        return false;
      },
    );
  }

  Future<bool> unlockMarks(String reason) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final schedule = state.activeSchedule;
    if (schoolId == null || schedule == null) return false;

    if (reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'An administrative unlock reason is mandatory.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.post(
      '/marks/unlock',
      queryParameters: {'school_id': schoolId},
      data: {
        'exam_schedule_id': schedule.id,
        'reason': reason.trim(),
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) async {
        await loadMarksForSchedule(schedule);
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Marks entries successfully unlocked.',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to unlock marks: ${failure.message}',
        );
        return false;
      },
    );
  }

  Future<Map<String, dynamic>> uploadMarksExcel({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final schedule = state.activeSchedule;
    if (schoolId == null || schedule == null) {
      throw Exception('Please select an examination schedule slot first.');
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final apiClient = _ref.read(apiClientProvider);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    final result = await apiClient.post(
      '/marks/upload-excel',
      queryParameters: {
        'school_id': schoolId,
        'exam_schedule_id': schedule.id,
      },
      data: formData,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (response) async {
        await loadMarksForSchedule(schedule);
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final savedCount = data['saved_count'] ?? 0;
        final errors = (data['errors'] as List?)?.map((e) => e.toString()).toList() ?? [];

        final successMsg = 'Imported marks for $savedCount students successfully.' +
            (errors.isNotEmpty ? ' (${errors.length} warning(s))' : '');

        state = state.copyWith(
          isSaving: false,
          successMessage: successMsg,
        );

        return {
          'savedCount': savedCount,
          'errors': errors,
          'totalRows': data['total_rows'] ?? 0,
        };
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to upload marks: ${failure.message}',
        );
        throw Exception(failure.message);
      },
    );
  }

  Future<void> downloadMarksTemplate({String format = 'xlsx'}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final schedule = state.activeSchedule;
    if (schoolId == null || schedule == null) {
      throw Exception('Please select an examination schedule slot first.');
    }

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.get<List<int>>(
      '/marks/template',
      queryParameters: {
        'school_id': schoolId,
        'exam_schedule_id': schedule.id,
        'file_format': format,
      },
      options: Options(responseType: ResponseType.bytes),
      mapper: (data) {
        if (data is List<int>) return data;
        if (data is List) return data.cast<int>();
        return <int>[];
      },
    );

    result.when(
      onSuccess: (bytes) {
        final cleanSubject = schedule.subjectName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        final cleanClass = schedule.className.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        final filename = 'marks_template_${cleanSubject}_$cleanClass.$format';
        final mimeType = format == 'csv'
            ? 'text/csv'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        downloadBytes(filename, bytes, mimeType);
      },
      onFailure: (failure) {
        state = state.copyWith(
          errorMessage: 'Failed to download template: ${failure.message}',
        );
      },
    );
  }

  Future<ExamWideUploadPreviewModel> previewExamWideUpload({
    required String examId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      throw Exception('Please select a school first.');
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final apiClient = _ref.read(apiClientProvider);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    final result = await apiClient.post(
      '/marks/examinations/$examId/bulk-upload-preview',
      queryParameters: {'school_id': schoolId},
      data: formData,
      mapper: (json) => ExamWideUploadPreviewModel.fromJson(json['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (preview) {
        state = state.copyWith(isSaving: false);
        return preview;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Validation preview failed: ${failure.message}',
        );
        throw Exception(failure.message);
      },
    );
  }

  Future<ExamWideUploadResultModel> confirmExamWideUpload({
    required String examId,
    required List<ExamWideUploadRowModel> rows,
    bool autoApprove = false,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      throw Exception('Please select a school first.');
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final apiClient = _ref.read(apiClientProvider);
    final payload = {
      'exam_id': examId,
      'school_id': schoolId,
      'rows': rows.map((r) => r.toJson()).toList(),
      'auto_approve': autoApprove,
    };

    final result = await apiClient.post(
      '/marks/examinations/$examId/bulk-upload-confirm',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => ExamWideUploadResultModel.fromJson(json['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (summary) async {
        if (state.activeSchedule != null) {
          await loadMarksForSchedule(state.activeSchedule!);
        }
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Successfully imported ${summary.savedCount} marks records for ${summary.studentsProcessed} students.',
        );
        return summary;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Bulk import failed: ${failure.message}',
        );
        throw Exception(failure.message);
      },
    );
  }

  Future<ExaminationPublishSummaryModel> publishCompleteExamination({
    required String examId,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      throw Exception('Please select a school first.');
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.post(
      '/marks/examinations/$examId/publish',
      queryParameters: {'school_id': schoolId},
      data: {},
      mapper: (json) => ExaminationPublishSummaryModel.fromJson(json['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (summary) async {
        if (state.activeSchedule != null) {
          await loadMarksForSchedule(state.activeSchedule!);
        }
        state = state.copyWith(
          isSaving: false,
          successMessage: summary.isFullyPublished
              ? 'Complete Examination published successfully (${summary.publishedCount} records).'
              : 'Partial publication complete (${summary.publishedCount} published, ${summary.missingCount} missing).',
        );
        return summary;
      },
      onFailure: (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to publish examination: ${failure.message}',
        );
        throw Exception(failure.message);
      },
    );
  }

  Future<void> downloadExamWideTemplate({required String examId, String examName = 'Examination'}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) {
      throw Exception('Please select a school first.');
    }

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.get<List<int>>(
      '/marks/examinations/$examId/template',
      queryParameters: {'school_id': schoolId},
      options: Options(responseType: ResponseType.bytes),
      mapper: (data) {
        if (data is List<int>) return data;
        if (data is List) return data.cast<int>();
        return <int>[];
      },
    );

    result.when(
      onSuccess: (bytes) {
        final cleanExam = examName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        final filename = '${cleanExam}_Marks_Template.xlsx';
        const mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        downloadBytes(filename, bytes, mimeType);
      },
      onFailure: (failure) {
        state = state.copyWith(
          errorMessage: 'Failed to download exam template: ${failure.message}',
        );
      },
    );
  }

  void clear() {
    state = const AdminMarksBoardState();
  }
}

final adminMarksBoardProvider = StateNotifierProvider<AdminMarksBoardNotifier, AdminMarksBoardState>((ref) {
  final notifier = AdminMarksBoardNotifier(ref);

  // Clear marks when active school changes
  ref.listen<String?>(selectedSchoolIdProvider, (prev, next) {
    if (prev != next) {
      notifier.clear();
    }
  });

  return notifier;
});
