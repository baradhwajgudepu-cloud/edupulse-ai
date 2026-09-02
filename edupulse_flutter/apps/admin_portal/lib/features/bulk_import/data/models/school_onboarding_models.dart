import 'dart:typed_data';

enum OnboardingStep {
  school,
  academicYears,
  classes,
  sections,
  subjects,
  teachers,
  guardians,
  students,
  relationships,
  teacherAssignments,
  timetable,
  syllabus,
  exams,
  validation,
  import,
  report,
}

extension OnboardingStepExtension on OnboardingStep {
  String get label {
    switch (this) {
      case OnboardingStep.school:
        return 'School Information';
      case OnboardingStep.academicYears:
        return 'Academic Structure';
      case OnboardingStep.classes:
        return 'Grade Levels (Classes)';
      case OnboardingStep.sections:
        return 'Sections & Rooms';
      case OnboardingStep.subjects:
        return 'Subjects Catalog';
      case OnboardingStep.teachers:
        return 'Teachers Roster';
      case OnboardingStep.guardians:
        return 'Parents & Guardians';
      case OnboardingStep.students:
        return 'Students Register';
      case OnboardingStep.relationships:
        return 'Student-Guardian Links';
      case OnboardingStep.teacherAssignments:
        return 'Teacher Assignments';
      case OnboardingStep.timetable:
        return 'Timetable Slots';
      case OnboardingStep.syllabus:
        return 'Syllabus Metadata';
      case OnboardingStep.exams:
        return 'Exams & Documents';
      case OnboardingStep.validation:
        return 'Pre-Import Validation';
      case OnboardingStep.import:
        return 'Executing Import Job';
      case OnboardingStep.report:
        return 'Completion Summary Report';
    }
  }

  String get fileKey {
    switch (this) {
      case OnboardingStep.school:
        return 'school';
      case OnboardingStep.academicYears:
        return 'academic_years';
      case OnboardingStep.classes:
        return 'classes';
      case OnboardingStep.sections:
        return 'sections';
      case OnboardingStep.subjects:
        return 'subjects';
      case OnboardingStep.teachers:
        return 'teachers';
      case OnboardingStep.guardians:
        return 'guardians';
      case OnboardingStep.students:
        return 'students';
      case OnboardingStep.relationships:
        return 'student_guardians';
      case OnboardingStep.teacherAssignments:
        return 'teacher_assignments';
      case OnboardingStep.timetable:
        return 'timetable';
      case OnboardingStep.syllabus:
        return 'syllabus';
      case OnboardingStep.exams:
        return 'exams';
      default:
        return '';
    }
  }
}

enum OnboardingRowStatus {
  valid,
  warning,
  error,
  duplicate,
  unresolved,
  success,
  failed,
  skipped,
}

class ValidationIssue {
  final String message;
  final bool isBlocking; // true for errors, false for warnings

  const ValidationIssue({
    required this.message,
    required this.isBlocking,
  });

  @override
  String toString() => message;
}

class OnboardingParsedRow {
  final int rowIndex;
  final Map<String, String> data;
  final List<String> errors;
  final List<String> warnings;
  final List<String> duplicates;
  final List<String> unresolvedReferences;
  final OnboardingRowStatus status;
  final String? resolvedId; // holds the resolved DB UUID after creation or lookup
  final String? apiErrorMessage;
  final String? moduleName;
  final String? fileName;
  final int? httpStatus;
  final String? dependencyFailureReason;
  final String? entityCode;
  final String? displayName;
  final String? parentError;
  final String? endpoint;
  final String? tempPassword;
  final String? loginId;

  const OnboardingParsedRow({
    required this.rowIndex,
    required this.data,
    required this.errors,
    required this.warnings,
    required this.duplicates,
    required this.unresolvedReferences,
    required this.status,
    this.resolvedId,
    this.apiErrorMessage,
    this.moduleName,
    this.fileName,
    this.httpStatus,
    this.dependencyFailureReason,
    this.entityCode,
    this.displayName,
    this.parentError,
    this.endpoint,
    this.tempPassword,
    this.loginId,
  });

  OnboardingParsedRow copyWith({
    int? rowIndex,
    Map<String, String>? data,
    List<String>? errors,
    List<String>? warnings,
    List<String>? duplicates,
    List<String>? unresolvedReferences,
    OnboardingRowStatus? status,
    String? resolvedId,
    String? apiErrorMessage,
    String? moduleName,
    String? fileName,
    int? httpStatus,
    String? dependencyFailureReason,
    String? entityCode,
    String? displayName,
    String? parentError,
    String? endpoint,
    String? tempPassword,
    String? loginId,
  }) {
    return OnboardingParsedRow(
      rowIndex: rowIndex ?? this.rowIndex,
      data: data ?? this.data,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      duplicates: duplicates ?? this.duplicates,
      unresolvedReferences: unresolvedReferences ?? this.unresolvedReferences,
      status: status ?? this.status,
      resolvedId: resolvedId ?? this.resolvedId,
      apiErrorMessage: apiErrorMessage ?? this.apiErrorMessage,
      moduleName: moduleName ?? this.moduleName,
      fileName: fileName ?? this.fileName,
      httpStatus: httpStatus ?? this.httpStatus,
      dependencyFailureReason: dependencyFailureReason ?? this.dependencyFailureReason,
      entityCode: entityCode ?? this.entityCode,
      displayName: displayName ?? this.displayName,
      parentError: parentError ?? this.parentError,
      endpoint: endpoint ?? this.endpoint,
      tempPassword: tempPassword ?? this.tempPassword,
      loginId: loginId ?? this.loginId,
    );
  }
}

class OnboardingSheetData {
  final OnboardingStep step;
  final String fileName;
  final List<String> headers;
  final List<OnboardingParsedRow> rows;
  final String? sheetErrorMessage;
  final List<String> sheetsList;
  final String? selectedSheet;
  final Uint8List? rawBytes;

  const OnboardingSheetData({
    required this.step,
    required this.fileName,
    required this.headers,
    required this.rows,
    this.sheetErrorMessage,
    this.sheetsList = const [],
    this.selectedSheet,
    this.rawBytes,
  });

  bool get hasErrors => rows.any((r) => r.errors.isNotEmpty || r.status == OnboardingRowStatus.error) || sheetErrorMessage != null;
  bool get hasWarnings => rows.any((r) => r.warnings.isNotEmpty);

  OnboardingSheetData copyWith({
    OnboardingStep? step,
    String? fileName,
    List<String>? headers,
    List<OnboardingParsedRow>? rows,
    String? sheetErrorMessage,
    List<String>? sheetsList,
    String? selectedSheet,
    Uint8List? rawBytes,
  }) {
    return OnboardingSheetData(
      step: step ?? this.step,
      fileName: fileName ?? this.fileName,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      sheetErrorMessage: sheetErrorMessage ?? this.sheetErrorMessage,
      sheetsList: sheetsList ?? this.sheetsList,
      selectedSheet: selectedSheet ?? this.selectedSheet,
      rawBytes: rawBytes ?? this.rawBytes,
    );
  }
}

enum OnboardingApprovalStatus {
  awaitingValidation,
  validationReady,
  awaitingApproval,
  approved,
  executing,
  completed,
  failed,
}

class OnboardingState {
  final OnboardingStep currentStep;
  final String? selectedSchoolId;
  final Map<OnboardingStep, OnboardingSheetData> sheets;
  final bool isProcessing;
  final bool isCompleted;
  final String? globalErrorMessage;
  final bool isCancelled;
  final OnboardingApprovalStatus approvalStatus;

  // Tenant Lifecycle Fields
  final bool createNewTenant;
  final String? newTenantName;
  final String? newTenantCode;
  final String? newTenantEmail;
  final String? selectedTenantId;
  final String? resolvedTenantId;
  final String? resolvedTenantName;
  final String? resolvedSchoolName;

  // Audit Fields
  final String? approvedBy;
  final DateTime? approvedAt;

  // Running execution progress
  final OnboardingStep? activeImportStep;
  final int currentProgressRow;
  final int totalProgressRows;
  final int successCount;
  final int failureCount;
  final int skipCount;

  // Local business codes resolution maps
  final Map<String, String> resolvedSchools;       // school_code -> school_id
  final Map<String, String> resolvedAcademicYears;  // academic_year_code -> academic_year_id
  final Map<String, String> resolvedClasses;        // class_code -> class_id
  final Map<String, String> resolvedSections;       // class_code + section_code -> section_id
  final Map<String, String> resolvedSubjects;       // subject_code -> subject_id
  final Map<String, String> resolvedTeachers;       // teacher_code -> teacher_id
  final Map<String, String> resolvedGuardians;      // guardian_code -> guardian_id
  final Map<String, String> resolvedStudents;       // admission_number -> student_id
  final Map<String, String> resolvedAssignments;    // teacher_code + subject_code + class_code + section_code -> assignment_id
  final Map<String, String> resolvedExaminations;   // exam_code -> exam_id

  const OnboardingState({
    required this.currentStep,
    this.selectedSchoolId,
    required this.sheets,
    required this.isProcessing,
    required this.isCompleted,
    this.globalErrorMessage,
    required this.isCancelled,
    required this.approvalStatus,
    this.createNewTenant = true,
    this.newTenantName,
    this.newTenantCode,
    this.newTenantEmail,
    this.selectedTenantId,
    this.resolvedTenantId,
    this.resolvedTenantName,
    this.resolvedSchoolName,
    this.approvedBy,
    this.approvedAt,
    this.activeImportStep,
    required this.currentProgressRow,
    required this.totalProgressRows,
    required this.successCount,
    required this.failureCount,
    required this.skipCount,
    required this.resolvedSchools,
    required this.resolvedAcademicYears,
    required this.resolvedClasses,
    required this.resolvedSections,
    required this.resolvedSubjects,
    required this.resolvedTeachers,
    required this.resolvedGuardians,
    required this.resolvedStudents,
    required this.resolvedAssignments,
    required this.resolvedExaminations,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(
      currentStep: OnboardingStep.school,
      sheets: {},
      isProcessing: false,
      isCompleted: false,
      isCancelled: false,
      approvalStatus: OnboardingApprovalStatus.awaitingValidation,
      createNewTenant: true,
      newTenantName: 'Telangana Educational Society',
      newTenantCode: 'TS_EDU',
      newTenantEmail: 'admin@telanganaedu.org',
      selectedTenantId: null,
      resolvedTenantId: null,
      resolvedTenantName: null,
      resolvedSchoolName: null,
      approvedBy: null,
      approvedAt: null,
      currentProgressRow: 0,
      totalProgressRows: 0,
      successCount: 0,
      failureCount: 0,
      skipCount: 0,
      resolvedSchools: {},
      resolvedAcademicYears: {},
      resolvedClasses: {},
      resolvedSections: {},
      resolvedSubjects: {},
      resolvedTeachers: {},
      resolvedGuardians: {},
      resolvedStudents: {},
      resolvedAssignments: {},
      resolvedExaminations: {},
    );
  }

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    String? selectedSchoolId,
    Map<OnboardingStep, OnboardingSheetData>? sheets,
    bool? isProcessing,
    bool? isCompleted,
    String? globalErrorMessage,
    bool? isCancelled,
    OnboardingApprovalStatus? approvalStatus,
    bool? createNewTenant,
    String? newTenantName,
    String? newTenantCode,
    String? newTenantEmail,
    String? selectedTenantId,
    String? resolvedTenantId,
    String? resolvedTenantName,
    String? resolvedSchoolName,
    String? approvedBy,
    DateTime? approvedAt,
    OnboardingStep? activeImportStep,
    int? currentProgressRow,
    int? totalProgressRows,
    int? successCount,
    int? failureCount,
    int? skipCount,
    Map<String, String>? resolvedSchools,
    Map<String, String>? resolvedAcademicYears,
    Map<String, String>? resolvedClasses,
    Map<String, String>? resolvedSections,
    Map<String, String>? resolvedSubjects,
    Map<String, String>? resolvedTeachers,
    Map<String, String>? resolvedGuardians,
    Map<String, String>? resolvedStudents,
    Map<String, String>? resolvedAssignments,
    Map<String, String>? resolvedExaminations,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      selectedSchoolId: selectedSchoolId ?? this.selectedSchoolId,
      sheets: sheets ?? this.sheets,
      isProcessing: isProcessing ?? this.isProcessing,
      isCompleted: isCompleted ?? this.isCompleted,
      globalErrorMessage: globalErrorMessage ?? this.globalErrorMessage,
      isCancelled: isCancelled ?? this.isCancelled,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createNewTenant: createNewTenant ?? this.createNewTenant,
      newTenantName: newTenantName ?? this.newTenantName,
      newTenantCode: newTenantCode ?? this.newTenantCode,
      newTenantEmail: newTenantEmail ?? this.newTenantEmail,
      selectedTenantId: selectedTenantId ?? this.selectedTenantId,
      resolvedTenantId: resolvedTenantId ?? this.resolvedTenantId,
      resolvedTenantName: resolvedTenantName ?? this.resolvedTenantName,
      resolvedSchoolName: resolvedSchoolName ?? this.resolvedSchoolName,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      activeImportStep: activeImportStep ?? this.activeImportStep,
      currentProgressRow: currentProgressRow ?? this.currentProgressRow,
      totalProgressRows: totalProgressRows ?? this.totalProgressRows,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      skipCount: skipCount ?? this.skipCount,
      resolvedSchools: resolvedSchools ?? this.resolvedSchools,
      resolvedAcademicYears: resolvedAcademicYears ?? this.resolvedAcademicYears,
      resolvedClasses: resolvedClasses ?? this.resolvedClasses,
      resolvedSections: resolvedSections ?? this.resolvedSections,
      resolvedSubjects: resolvedSubjects ?? this.resolvedSubjects,
      resolvedTeachers: resolvedTeachers ?? this.resolvedTeachers,
      resolvedGuardians: resolvedGuardians ?? this.resolvedGuardians,
      resolvedStudents: resolvedStudents ?? this.resolvedStudents,
      resolvedAssignments: resolvedAssignments ?? this.resolvedAssignments,
      resolvedExaminations: resolvedExaminations ?? this.resolvedExaminations,
    );
  }
}
