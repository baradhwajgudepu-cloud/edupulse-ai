import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/models/school_onboarding_models.dart';
import '../../data/models/school_onboarding_validators.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';

final schoolOnboardingProvider = StateNotifierProvider<SchoolOnboardingNotifier, OnboardingState>((ref) {
  final notifier = SchoolOnboardingNotifier(ref);
  // Reset onboarding state if the school context is modified and we are not processing
  ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
    notifier.resetIfNotProcessing();
  });
  return notifier;
});

class SchoolOnboardingNotifier extends StateNotifier<OnboardingState> {
  final Ref _ref;
  static bool bypassApproval = false;

  SchoolOnboardingNotifier(this._ref) : super(OnboardingState.initial());

  void resetIfNotProcessing() {
    if (!state.isProcessing) {
      reset();
    }
  }

  void reset() {
    state = OnboardingState.initial();
  }

  void setStep(OnboardingStep step) {
    state = state.copyWith(currentStep: step);
  }

  void approveAndStartImport(String schoolId, BaseApiClient apiClient, {required String approvedBy}) {
    state = state.copyWith(
      approvalStatus: OnboardingApprovalStatus.approved,
      approvedBy: approvedBy,
      approvedAt: DateTime.now(),
    );
    executeOnboarding(schoolId, apiClient);
  }

  void updateApprovalStatus() {
    if (_hasBlockingErrors(state)) {
      state = state.copyWith(
        approvalStatus: OnboardingApprovalStatus.awaitingValidation,
        approvedBy: null,
        approvedAt: null,
      );
    } else {
      if (state.approvalStatus == OnboardingApprovalStatus.awaitingValidation ||
          state.approvalStatus == OnboardingApprovalStatus.failed) {
        state = state.copyWith(
          approvalStatus: OnboardingApprovalStatus.awaitingApproval,
          approvedBy: null,
          approvedAt: null,
        );
      }
    }
  }

  void stopOnboarding() {
    state = state.copyWith(
      isProcessing: false,
      isCompleted: true,
      isCancelled: true,
      currentStep: OnboardingStep.report,
      activeImportStep: null,
      globalErrorMessage: 'Onboarding stopped by user.',
    );
  }

  Future<void> selectSpreadsheetFile(OnboardingStep step, String fileName, Uint8List bytes, {String? sheetName}) async {
    state = state.copyWith(isProcessing: true);

    try {
      final apiClient = _ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
      });

      final queryParams = sheetName != null ? '?sheet_name=${Uri.encodeComponent(sheetName)}' : '';
      final result = await apiClient.post<Map<String, dynamic>>(
        '/import-jobs/parse$queryParams',
        data: formData,
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return (payload['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        },
      );

      state = state.copyWith(isProcessing: false);

      result.when(
        onSuccess: (data) {
          final parsedData = data;
          final sheetsList = List<String>.from(parsedData['sheets'] ?? const <String>[]);
          final activeSheet = parsedData['selected_sheet'] as String?;
          // Read full parsed rows for complete validation and execution
          final fullRawRows = (parsedData['rows'] as List<dynamic>?) ?? (parsedData['preview_rows'] as List<dynamic>?) ?? const [];

          final List<List<String>> parsedRows = [];
          for (var row in fullRawRows) {
            if (row is List) {
              parsedRows.add(row.map((e) => e?.toString() ?? '').toList());
            }
          }

          final sheetData = SchoolOnboardingValidators.validateSheet(step, fileName, parsedRows).copyWith(
            sheetsList: sheetsList,
            selectedSheet: activeSheet,
            rawBytes: bytes,
          );

          final updatedSheets = Map<OnboardingStep, OnboardingSheetData>.from(state.sheets);
          updatedSheets[step] = sheetData;

          state = state.copyWith(
            sheets: updatedSheets,
            globalErrorMessage: null,
          );
          _runCrossSheetValidation();
          updateApprovalStatus();
        },
        onFailure: (failure) {
          state = state.copyWith(
            globalErrorMessage: failure.message,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        globalErrorMessage: 'Network or parsing error: ${e.toString()}',
      );
    }
  }

  void loadCsvFile(OnboardingStep step, String fileName, String content) {
    final csvRows = SchoolOnboardingValidators.parseCsv(content);
    final sheetData = SchoolOnboardingValidators.validateSheet(step, fileName, csvRows);

    final updatedSheets = Map<OnboardingStep, OnboardingSheetData>.from(state.sheets);
    updatedSheets[step] = sheetData;

    state = state.copyWith(
      sheets: updatedSheets,
      globalErrorMessage: null,
    );
    _runCrossSheetValidation();
    updateApprovalStatus();
  }

  void removeCsvFile(OnboardingStep step) {
    final updatedSheets = Map<OnboardingStep, OnboardingSheetData>.from(state.sheets);
    updatedSheets.remove(step);

    state = state.copyWith(
      sheets: updatedSheets,
      globalErrorMessage: null,
    );
    _runCrossSheetValidation();
    updateApprovalStatus();
  }

  // Populate pre-configured synthetic data for demo/tests
  void loadSyntheticFixture() {
    // Generate Deterministic UUID formats
    const ayCode = 'AY2026';
    const classCode = 'CLASS08';
    const sectionCode = 'SEC_A';
    const subCode = 'SUB_MATH';
    const tCode = 'T001';
    const gCode = 'PAR001';
    const student1 = 'ADM001';
    const student2 = 'ADM002';

    // 1. School
    loadCsvFile(
      OnboardingStep.school,
      'school.csv',
      'school_code,school_name,board,school_type,address,city,state,postal_code,phone,email,website,status\n'
      'DPSH,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,Gachibowli,Hyderabad,Telangana,500032,9876543210,contact@dpsh.in,www.dpsh.in,ACTIVE',
    );

    // 2. Academic Years
    loadCsvFile(
      OnboardingStep.academicYears,
      'academic_years.csv',
      'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
      'DPSH,$ayCode,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
    );

    // 3. Classes
    loadCsvFile(
      OnboardingStep.classes,
      'classes.csv',
      'academic_year_code,class_code,display_label,level,grade_category,specialization_stream,max_capacity,promotion_order_index,status\n'
      '$ayCode,$classCode,Class 8,8,MIDDLE,General,40,8,ACTIVE',
    );

    // 4. Sections
    loadCsvFile(
      OnboardingStep.sections,
      'sections.csv',
      'class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
      '$classCode,$sectionCode,Section A,40,Room 101,1,ACTIVE',
    );

    // 5. Subjects
    loadCsvFile(
      OnboardingStep.subjects,
      'subjects.csv',
      'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
      '$subCode,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,35,1,$ayCode',
    );

    // 6. Teachers
    loadCsvFile(
      OnboardingStep.teachers,
      'teachers.csv',
      'teacher_code,first_name,middle_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
      '$tCode,Priya,,Sharma,FEMALE,1985-04-12,9876543211,priya@dpsh.in,EMP001,PGT Maths,2020-06-01,ACTIVE,FULL_TIME',
    );

    // 7. Guardians
    loadCsvFile(
      OnboardingStep.guardians,
      'guardians.csv',
      'guardian_code,first_name,middle_name,last_name,gender,date_of_birth,mobile,email,guardian_type,address,city,state,status\n'
      '$gCode,Ramesh,,Kumar,MALE,1980-05-15,9876543212,ramesh@gmail.com,FATHER,Madhapur,Hyderabad,Telangana,ACTIVE',
    );

    // 8. Students
    loadCsvFile(
      OnboardingStep.students,
      'students.csv',
      'admission_number,first_name,middle_name,last_name,gender,date_of_birth,blood_group,aadhaar_number,emis_number,mobile,email,photo_url,admission_date,roll_number,academic_year_code,class_code,section_code,address_line,city,state,status\n'
      '$student1,Aarav,,Kumar,MALE,2014-05-12,A+,123456789012,EMIS001,9876543213,aarav@gmail.com,,2026-06-01,1,$ayCode,$classCode,$sectionCode,Madhapur,Hyderabad,Telangana,ACTIVE\n'
      '$student2,Ananya,,Kumar,FEMALE,2014-05-12,A+,123456789013,EMIS002,9876543214,ananya@gmail.com,,2026-06-01,2,$ayCode,$classCode,$sectionCode,Madhapur,Hyderabad,Telangana,ACTIVE',
    );

    // 9. Student-Guardian Relationships
    loadCsvFile(
      OnboardingStep.relationships,
      'student_guardians.csv',
      'admission_number,guardian_code,relationship,is_primary,authorized_for_pickup,receives_notifications\n'
      '$student1,$gCode,FATHER,true,true,true\n'
      '$student2,$gCode,FATHER,true,true,true',
    );

    // 10. Teacher Assignments
    loadCsvFile(
      OnboardingStep.teacherAssignments,
      'teacher_assignments.csv',
      'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
      '$tCode,$subCode,$classCode,$sectionCode,$ayCode,PRIMARY,6,2026-06-01',
    );

    // 11. Timetable
    loadCsvFile(
      OnboardingStep.timetable,
      'timetable.csv',
      'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
      '$ayCode,MONDAY,1,09:00:00,09:45:00,$classCode,$sectionCode,$subCode,$tCode,Room 101,REGULAR',
    );

    // 12. Syllabus
    loadCsvFile(
      OnboardingStep.syllabus,
      'syllabus.csv',
      'academic_year_code,class_code,subject_code,syllabus_code,unit_name,chapter_name,topic_name,description,sequence_order\n'
      '$ayCode,$classCode,$subCode,SYLL_MATH_08,Unit 1,Rational Numbers,Operations,Rational operations description,1',
    );

    // 13. Exams
    loadCsvFile(
      OnboardingStep.exams,
      'exams.csv',
      'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
      '$ayCode,EXAM_MID,Mid Term Examination,HALF_YEARLY,$classCode,$subCode,2026-10-15,80,180',
    );
  }

  Future<void> executeOnboarding(String schoolId, BaseApiClient apiClient) async {
    if (state.isProcessing) return;

    if (!bypassApproval && state.approvalStatus != OnboardingApprovalStatus.approved) {
      state = state.copyWith(
        globalErrorMessage: 'Cannot start import: Administrator approval is required.',
      );
      return;
    }

    final initialSchoolId = (_ref.read(selectedSchoolIdProvider) ?? '').trim();
    final incomingSchoolId = schoolId.trim();
    if (initialSchoolId.isNotEmpty && incomingSchoolId.isNotEmpty && initialSchoolId != incomingSchoolId) {
      state = state.copyWith(globalErrorMessage: 'Selected school context mismatch. Operation aborted.');
      return;
    }

    if (_hasBlockingErrors(state)) {
      state = state.copyWith(
        globalErrorMessage: 'Cannot start migration: Pre-Import Validation contains blocking errors.',
      );
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      isCompleted: false,
      globalErrorMessage: null,
      approvalStatus: OnboardingApprovalStatus.executing,
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
    );

    // Steps sequence in strict dependency order
    final importOrder = [
      OnboardingStep.school,
      OnboardingStep.academicYears,
      OnboardingStep.classes,
      OnboardingStep.sections,
      OnboardingStep.subjects,
      OnboardingStep.teachers,
      OnboardingStep.guardians,
      OnboardingStep.students,
      OnboardingStep.relationships,
      OnboardingStep.teacherAssignments,
      OnboardingStep.timetable,
      OnboardingStep.syllabus,
      OnboardingStep.exams,
    ];

    String targetSchoolId = incomingSchoolId;

    try {
      await _prepopulateResolutionMaps(
        incomingSchoolId.isNotEmpty ? incomingSchoolId : initialSchoolId,
        apiClient,
      );

      for (final step in importOrder) {
        if (state.isCancelled || !state.isProcessing) return;
        // If school changed during active loop run, stop immediately
        final currentSelected = (_ref.read(selectedSchoolIdProvider) ?? '').trim();
        if (targetSchoolId.isNotEmpty && currentSelected != targetSchoolId) {
          state = state.copyWith(
            isProcessing: false,
            globalErrorMessage: 'Active school context modified during execution. Import stopped.',
            approvalStatus: OnboardingApprovalStatus.failed,
          );
          return;
        }

        final sheet = state.sheets[step];
        if (sheet == null || sheet.rows.isEmpty) {
          continue;
        }

        state = state.copyWith(
          activeImportStep: step,
          currentProgressRow: 0,
          totalProgressRows: sheet.rows.length,
        );

        final updatedRows = List<OnboardingParsedRow>.from(sheet.rows);
        final fileName = sheet.fileName;

        for (int i = 0; i < sheet.rows.length; i++) {
          if (state.isCancelled || !state.isProcessing) return;
          var row = sheet.rows[i];
          final meta = _getRowCodeAndName(step, row.data);
          row = row.copyWith(
            moduleName: step.label,
            fileName: fileName,
            entityCode: meta['code'],
            displayName: meta['name'],
          );

          if (row.status == OnboardingRowStatus.error) {
            updatedRows[i] = row.copyWith(
              status: OnboardingRowStatus.skipped,
              apiErrorMessage: 'Skipped due to parsing errors.',
              dependencyFailureReason: 'Validation failed during parsing.',
            );
            final updatedSheets = Map<OnboardingStep, OnboardingSheetData>.from(state.sheets);
            updatedSheets[step] = sheet.copyWith(rows: updatedRows);
            state = state.copyWith(
              sheets: updatedSheets,
              skipCount: state.skipCount + 1,
              currentProgressRow: i + 1,
            );
            continue;
          }

          String activeSchoolId = targetSchoolId;
          if (state.resolvedSchools.isNotEmpty) {
            activeSchoolId = state.resolvedSchools.values.first;
          }

          final res = await _processRow(step, row, activeSchoolId, apiClient);
          if (state.isCancelled || !state.isProcessing) return;
          updatedRows[i] = res;

          final updatedSheets = Map<OnboardingStep, OnboardingSheetData>.from(state.sheets);
          updatedSheets[step] = sheet.copyWith(rows: updatedRows);

          if (res.status == OnboardingRowStatus.success) {
            state = state.copyWith(sheets: updatedSheets, successCount: state.successCount + 1, currentProgressRow: i + 1);
            if (step == OnboardingStep.school) {
              final newlyCreatedId = res.resolvedId;
              if (newlyCreatedId != null && newlyCreatedId.isNotEmpty) {
                targetSchoolId = newlyCreatedId;
                try {
                  final sessionManager = _ref.read(sessionManagerProvider);
                  await sessionManager.saveSchoolId(newlyCreatedId);
                } catch (_) {}
                _ref.read(selectedSchoolIdProvider.notifier).state = newlyCreatedId;
                _ref.read(schoolsListProvider.notifier).fetchSchools();
              } else {
                final failureRow = res.copyWith(
                  status: OnboardingRowStatus.failed,
                  apiErrorMessage: 'School creation did not return a valid UUID/ID.',
                );
                updatedRows[i] = failureRow;
                updatedSheets[step] = sheet.copyWith(rows: updatedRows);
                state = state.copyWith(
                  sheets: updatedSheets,
                  failureCount: state.failureCount + 1,
                  currentProgressRow: i + 1,
                );
              }
            }
          } else if (res.status == OnboardingRowStatus.failed) {
            state = state.copyWith(sheets: updatedSheets, failureCount: state.failureCount + 1, currentProgressRow: i + 1);
          } else {
            state = state.copyWith(sheets: updatedSheets, skipCount: state.skipCount + 1, currentProgressRow: i + 1);
          }

          if (state.globalErrorMessage != null) {
            return;
          }
        }
      }
    } on PrepopulationException catch (e) {
      // ignore: avoid_print
      print('=== [ONBOARDING PREPOPULATION FAILURE] ===: $e');
      state = state.copyWith(globalErrorMessage: e.toString());
    } catch (e) {
      // ignore: avoid_print
      print('=== [ONBOARDING EXCEPTION IN PIPELINE] ===: $e');
      state = state.copyWith(globalErrorMessage: 'Execution failed: $e');
    } finally {
      state = state.copyWith(
        isProcessing: false,
        isCompleted: true,
        currentStep: OnboardingStep.report,
        activeImportStep: null,
        approvalStatus: state.globalErrorMessage != null
            ? OnboardingApprovalStatus.failed
            : OnboardingApprovalStatus.completed,
      );
      _ref.read(schoolsListProvider.notifier).fetchSchools();
      _invalidateRelevantProviders(targetSchoolId);
    }
  }

  Future<OnboardingParsedRow> _processRow(OnboardingStep step, OnboardingParsedRow row, String schoolId, BaseApiClient apiClient) async {
    // If school step was present and failed completely, prevent subsequent steps
    final schoolSheet = state.sheets[OnboardingStep.school];
    final schoolFailed = schoolSheet != null && schoolSheet.rows.isNotEmpty && state.resolvedSchools.isEmpty;
    if (schoolFailed && step != OnboardingStep.school) {
      return _createDependencySkipRow(row, OnboardingStep.school, 'school_code', '', 'school');
    }

    switch (step) {
      case OnboardingStep.school:
        final code = row.data['school_code'] ?? '';
        final result = await apiClient.post(
          '/schools',
          data: {
            'name': row.data['school_name'],
            'code': code,
            'board': (row.data['board'] ?? 'CBSE').toUpperCase(),
            'school_type': (row.data['school_type'] ?? 'HIGH_SCHOOL').toUpperCase(),
            'email': row.data['email'] ?? 'contact@school.edu',
            'phone': row.data['phone'],
            'address': row.data['address'],
            'city': row.data['city'],
            'state': row.data['state'],
            'postal_code': row.data['postal_code'],
            'is_active': true,
            'status': 'ACTIVE',
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          state = state.copyWith(resolvedSchools: Map.from(state.resolvedSchools)..[code] = uuid);
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.school,
              schoolId: '',
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedSchools: Map.from(state.resolvedSchools)..[code] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/schools',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/schools');
        }

      case OnboardingStep.academicYears:
        final code = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        final name = row.data['academic_year_name'] ?? '';
        if (state.resolvedAcademicYears.containsKey(code)) {
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: state.resolvedAcademicYears[code]!);
        }
        final schoolCode = row.data['school_code'] ?? '';
        var targetSchoolId = state.resolvedSchools[schoolCode];
        if (targetSchoolId == null || targetSchoolId.isEmpty) {
          final activeSchoolCode = state.resolvedSchools.entries
              .where((entry) => entry.value == schoolId)
              .map((entry) => entry.key)
              .firstWhere((_) => true, orElse: () => '');
          
          if (activeSchoolCode.isNotEmpty && activeSchoolCode != schoolCode) {
            // ignore: avoid_print
            print('[ONBOARDING][RESOLUTION][ERROR] School code mismatch: Row schoolCode="$schoolCode" does not match active schoolCode="$activeSchoolCode" (schoolId="$schoolId")');
            return _createDependencySkipRow(row, OnboardingStep.school, 'school_code', schoolCode, 'school');
          }
          targetSchoolId = schoolId;
          // ignore: avoid_print
          print('[ONBOARDING][RESOLUTION] Fallback to active school context for schoolCode="$schoolCode" -> schoolId="$schoolId"');
        }
        if (targetSchoolId.isEmpty) {
          final tenantId = _ref.read(activeTenantIdProvider) ?? '';
          // ignore: avoid_print
          print('[ONBOARDING][RESOLUTION][FAIL] OnboardingStep.academicYears: schoolCode="$schoolCode", selected schoolId="$schoolId", resolved schoolId="$targetSchoolId", tenantId="$tenantId"');
          return _createDependencySkipRow(row, OnboardingStep.school, 'school_code', schoolCode, 'school');
        }

        final result = await apiClient.post(
          '/schools/$targetSchoolId/academic-years',
          data: {
            'name': name,
            'code': code,
            'start_date': row.data['start_date'],
            'end_date': row.data['end_date'],
            'is_current': row.data['is_current']?.toLowerCase() == 'true',
            'status': (row.data['status'] ?? 'ACTIVE').toUpperCase(),
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          state = state.copyWith(resolvedAcademicYears: Map.from(state.resolvedAcademicYears)..[code] = uuid);
          // ignore: avoid_print
          print('[DIAGNOSTIC] ACADEMIC STRUCTURE PARENT MAP ADDED (Success): key = $code | value = $uuid');
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.academicYears,
              schoolId: targetSchoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedAcademicYears: Map.from(state.resolvedAcademicYears)..[code] = existingId);
              // ignore: avoid_print
              print('[DIAGNOSTIC] ACADEMIC STRUCTURE PARENT MAP ADDED (Conflict/Resolve): key = $code | value = $existingId');
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/schools/$targetSchoolId/academic-years',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/schools/$targetSchoolId/academic-years');
        }

      case OnboardingStep.classes:
        final code = row.data['class_code'] ?? '';
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        if (ayCode.isEmpty) {
          return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', '', 'academic year');
        }
        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null || ayId.isEmpty) {
          return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');
        }
        final result = await apiClient.post(
          '/classes',
          data: {
            'name': row.data['display_label'],
            'code': code,
            'level': int.tryParse(row.data['level'] ?? '1') ?? 1,
            'category': (row.data['grade_category'] ?? 'PRIMARY').toUpperCase(),
            'capacity': int.tryParse(row.data['max_capacity'] ?? '40') ?? 40,
            'school_id': schoolId,
            'academic_year_id': ayId,
            'status': (row.data['status'] ?? 'ACTIVE').toUpperCase(),
            'is_active': true,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          state = state.copyWith(resolvedClasses: Map.from(state.resolvedClasses)..[code] = uuid);
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.classes,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedClasses: Map.from(state.resolvedClasses)..[code] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/classes',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/classes');
        }

      case OnboardingStep.sections:
        final classCode = row.data['class_code'] ?? '';
        final sectionCode = row.data['section_code'] ?? '';
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();

        if (ayCode.isEmpty) {
          return row.copyWith(
            status: OnboardingRowStatus.failed,
            apiErrorMessage: 'academic_year_code is required for Sections & Rooms.',
          );
        }

        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null) {
          return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');
        }

        final classId = state.resolvedClasses[classCode];
        if (classId == null) return _createDependencySkipRow(row, OnboardingStep.classes, 'class_code', classCode, 'class');
        final result = await apiClient.post(
          '/sections',
          data: {
            'name': row.data['section_name'],
            'code': sectionCode,
            'capacity': int.tryParse(row.data['capacity'] ?? '40') ?? 40,
            'room_number': row.data['room_number'],
            'sort_order': int.tryParse(row.data['display_sort_order'] ?? '1') ?? 1,
            'class_id': classId,
            'school_id': schoolId,
            'academic_year_id': ayId,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          state = state.copyWith(resolvedSections: Map.from(state.resolvedSections)..['$classCode-$sectionCode'] = uuid);
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.sections,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedSections: Map.from(state.resolvedSections)..['$classCode-$sectionCode'] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/sections',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/sections');
        }

      case OnboardingStep.subjects:
        final code = row.data['subject_code'] ?? '';
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null) return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');

        final type = (row.data['subject_type'] ?? 'THEORY').toUpperCase();
        final rawTheory = row.data['theory_marks'] ?? '';
        final rawPractical = row.data['practical_marks'] ?? '';

        int? theoryMarks = int.tryParse(rawTheory);
        int? practicalMarks = int.tryParse(rawPractical);

        if (type == 'THEORY') {
          theoryMarks ??= 100;
          practicalMarks = null;
        } else if (type == 'PRACTICAL') {
          theoryMarks = null;
          practicalMarks ??= 100;
        } else { // THEORY_PRACTICAL
          theoryMarks ??= 80;
          practicalMarks ??= 20;
        }

        int? passMarks = int.tryParse(row.data['pass_marks'] ?? '');
        passMarks ??= 33;

        final result = await apiClient.post(
          '/subjects',
          data: {
            'subject_code': code,
            'subject_name': row.data['subject_name'],
            'category': (row.data['category'] ?? 'CORE').toUpperCase(),
            'subject_type': type,
            'credit_hours': int.tryParse(row.data['credit_hours'] ?? '') ?? 4,
            'weekly_periods': int.tryParse(row.data['weekly_periods'] ?? '') ?? 4,
            'theory_marks': theoryMarks,
            'practical_marks': practicalMarks,
            'pass_marks': passMarks,
            'display_order': int.tryParse(row.data['display_order'] ?? '') ?? 1,
            'school_id': schoolId,
            'academic_year_id': ayId,
            'is_active': true,
            'version': 1,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          state = state.copyWith(resolvedSubjects: Map.from(state.resolvedSubjects)..[code] = uuid);
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.subjects,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedSubjects: Map.from(state.resolvedSubjects)..[code] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/subjects',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/subjects');
        }

      case OnboardingStep.teachers:
        final code = row.data['teacher_code'] ?? '';
        final result = await apiClient.post(
          '/teachers',
          data: {
            'first_name': row.data['first_name'],
            'middle_name': row.data['middle_name'],
            'last_name': row.data['last_name'],
            'gender': (row.data['gender'] ?? 'MALE').toUpperCase(),
            'date_of_birth': row.data['date_of_birth'],
            'mobile': row.data['mobile'],
            'official_email': row.data['email'] ?? row.data['official_email'],
            'employee_code': row.data['employee_code'] ?? row.data['teacher_code'] ?? code,
            'staff_code': row.data['staff_code'] ?? row.data['teacher_code'] ?? code,
            'employment_type': (row.data['employment_type'] ?? '').toUpperCase(),
            'designation': row.data['designation'] ?? 'TGT',
            'joining_date': row.data['joining_date'] ?? '2026-06-01',
            'school_id': schoolId,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          final creds = result.data['credentials'] as Map<String, dynamic>?;
          final tempPassword = creds?['temporary_password'] as String?;
          final loginId = creds?['login_id'] as String? ?? creds?['email'] as String?;
          state = state.copyWith(resolvedTeachers: Map.from(state.resolvedTeachers)..[code] = uuid);
          return row.copyWith(
            status: OnboardingRowStatus.success,
            resolvedId: uuid,
            tempPassword: tempPassword,
            loginId: loginId,
          );
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.teachers,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedTeachers: Map.from(state.resolvedTeachers)..[code] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/teachers',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/teachers');
        }

      case OnboardingStep.guardians:
        final code = row.data['guardian_code'] ?? '';
        if (state.resolvedGuardians.containsKey(code)) return row.copyWith(status: OnboardingRowStatus.success, resolvedId: state.resolvedGuardians[code]!);
        final result = await apiClient.post(
          '/guardians',
          data: {
            'first_name': row.data['first_name'],
            'last_name': row.data['last_name'],
            'gender': (row.data['gender'] ?? 'MALE').toUpperCase(),
            'date_of_birth': row.data['date_of_birth'],
            'mobile': row.data['mobile'] ?? '9999999999',
            'email': row.data['email'],
            'guardian_type': (row.data['guardian_type'] ?? 'FATHER').toUpperCase(),
            'school_id': schoolId,
            'is_active': true,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          final creds = result.data['credentials'] as Map<String, dynamic>?;
          final tempPassword = creds?['temporary_password'] as String?;
          final loginId = creds?['login_id'] as String? ?? creds?['email'] as String?;
          state = state.copyWith(resolvedGuardians: Map.from(state.resolvedGuardians)..[code] = uuid);
          return row.copyWith(
            status: OnboardingRowStatus.success,
            resolvedId: uuid,
            tempPassword: tempPassword,
            loginId: loginId,
          );
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.guardians,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedGuardians: Map.from(state.resolvedGuardians)..[code] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/guardians',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/guardians');
        }

      case OnboardingStep.students:
        final adm = row.data['admission_number'] ?? '';
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        final classCode = row.data['class_code'] ?? '';
        final secCode = row.data['section_code'] ?? '';
        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null) return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');
        final classId = state.resolvedClasses[classCode];
        if (classId == null) return _createDependencySkipRow(row, OnboardingStep.classes, 'class_code', classCode, 'class');
        final secId = state.resolvedSections['$classCode-$secCode'];
        if (secId == null) return _createStudentSectionSkipRow(row, classCode, secCode);
        final result = await apiClient.post(
          '/students',
          data: {
            'first_name': row.data['first_name'],
            'last_name': row.data['last_name'],
            'gender': (row.data['gender'] ?? 'MALE').toUpperCase(),
            'date_of_birth': row.data['date_of_birth'],
            'roll_number': row.data['roll_number'],
            'admission_date': row.data['admission_date'],
            'admission_number': adm,
            'academic_year_id': ayId,
            'class_id': classId,
            'section_id': secId,
            'school_id': schoolId,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          state = state.copyWith(resolvedStudents: Map.from(state.resolvedStudents)..[adm] = uuid);
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.students,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedStudents: Map.from(state.resolvedStudents)..[adm] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/students',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/students');
        }

      case OnboardingStep.relationships:
        final adm = row.data['admission_number'] ?? '';
        final gCode = row.data['guardian_code'] ?? '';
        final studentId = state.resolvedStudents[adm];
        if (studentId == null) return _createDependencySkipRow(row, OnboardingStep.students, 'admission_number', adm, 'student');
        final guardianId = state.resolvedGuardians[gCode];
        if (guardianId == null) return _createDependencySkipRow(row, OnboardingStep.guardians, 'guardian_code', gCode, 'guardian');
        final result = await apiClient.post(
          '/student-guardians',
          data: {
            'student_id': studentId,
            'guardian_id': guardianId,
            'relationship': (row.data['relationship'] ?? 'FATHER').toUpperCase(),
            'is_primary': (row.data['is_primary']?.toLowerCase() == 'true'),
            'school_id': schoolId,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.relationships,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/student-guardians',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/student-guardians');
        }

      case OnboardingStep.teacherAssignments:
        final tCode = row.data['teacher_code'] ?? '';
        final sCode = row.data['subject_code'] ?? '';
        final cCode = row.data['class_code'] ?? '';
        final secCode = row.data['section_code'] ?? '';
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        final tId = state.resolvedTeachers[tCode];
        if (tId == null) return _createDependencySkipRow(row, OnboardingStep.teachers, 'teacher_code', tCode, 'teacher');
        final sId = state.resolvedSubjects[sCode];
        if (sId == null) return _createDependencySkipRow(row, OnboardingStep.subjects, 'subject_code', sCode, 'subject');
        final cId = state.resolvedClasses[cCode];
        if (cId == null) return _createDependencySkipRow(row, OnboardingStep.classes, 'class_code', cCode, 'class');
        final secId = state.resolvedSections['$cCode-$secCode'];
        if (secId == null) return _createStudentSectionSkipRow(row, cCode, secCode);
        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null) return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');

        // Parse and normalize parameters
        final weeklyPeriodsRaw = row.data['weekly_periods'] ?? '';
        final parsedPeriods = double.tryParse(weeklyPeriodsRaw)?.toInt();
        if (parsedPeriods == null) {
          return row.copyWith(
            status: OnboardingRowStatus.failed,
            apiErrorMessage: 'weekly_periods is required for Teacher Assignments.',
          );
        }

        final rawEffective = row.data['effective_from'] ?? '';
        var cleanEffective = rawEffective.trim().split(' ').first.split('T').first.replaceAll('/', '-');
        if (cleanEffective.isEmpty) {
          return row.copyWith(
            status: OnboardingRowStatus.failed,
            apiErrorMessage: 'effective_from is required for Teacher Assignments.',
          );
        }

        final result = await apiClient.post(
          '/teacher-subject-assignments',
          data: {
            'teacher_id': tId,
            'subject_id': sId,
            'class_id': cId,
            'section_id': secId,
            'academic_year_id': ayId,
            'school_id': schoolId,
            'assignment_type': (row.data['assignment_type'] ?? 'PRIMARY').toUpperCase(),
            'weekly_periods': parsedPeriods,
            'effective_from': cleanEffective,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          state = state.copyWith(resolvedAssignments: Map.from(state.resolvedAssignments)..['$tCode-$sCode-$cCode-$secCode'] = uuid);
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          if (failure.statusCode == 409) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.teacherAssignments,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              state = state.copyWith(resolvedAssignments: Map.from(state.resolvedAssignments)..['$tCode-$sCode-$cCode-$secCode'] = existingId);
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/teacher-subject-assignments',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/teacher-subject-assignments');
        }

      case OnboardingStep.timetable:
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        final cCode = row.data['class_code'] ?? '';
        final secCode = row.data['section_code'] ?? '';
        final sCode = row.data['subject_code'] ?? '';
        final tCode = row.data['teacher_code'] ?? '';
        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null) return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');
        final cId = state.resolvedClasses[cCode];
        if (cId == null) return _createDependencySkipRow(row, OnboardingStep.classes, 'class_code', cCode, 'class');
        final secId = state.resolvedSections['$cCode-$secCode'];
        if (secId == null) return _createStudentSectionSkipRow(row, cCode, secCode);
        final assignmentId = state.resolvedAssignments['$tCode-$sCode-$cCode-$secCode'];
        if (assignmentId == null || assignmentId.isEmpty) {
          return _createDependencySkipRow(row, OnboardingStep.teacherAssignments, 'teacher_code', tCode, 'teacher subject assignment');
        }
        final result = await apiClient.post(
          '/timetables',
          data: {
            'day_of_week': (row.data['day_of_week'] ?? 'MONDAY').toUpperCase(),
            'period_number': int.tryParse(row.data['period_number'] ?? '1') ?? 1,
            'start_time': row.data['start_time'] ?? '09:00:00',
            'end_time': row.data['end_time'] ?? '09:45:00',
            'academic_year_id': ayId,
            'class_id': cId,
            'section_id': secId,
            'teacher_subject_assignment_id': assignmentId,
            'school_id': schoolId,
            'period_type': (row.data['period_type'] ?? 'REGULAR').toUpperCase(),
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          final isConflict = failure.statusCode == 409 ||
              (failure.statusCode == 422 && failure.message.contains('already has a booked period'));
          if (isConflict) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.timetable,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/timetables',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/timetables');
        }

      case OnboardingStep.syllabus:
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        final cCode = row.data['class_code'] ?? '';
        final sCode = row.data['subject_code'] ?? '';
        final syllabusCode = row.data['syllabus_code'] ?? '';
        if (syllabusCode.isEmpty) {
          return row.copyWith(
            status: OnboardingRowStatus.failed,
            apiErrorMessage: 'syllabus_code is required for Syllabus Metadata.',
          );
        }
        // ignore: avoid_print
        print('[DIAGNOSTIC] SYLLABUS LOOKUP: requested academic_year_code = $ayCode | available parent keys = ${state.resolvedAcademicYears.keys.toList()} | resolved values = ${state.resolvedAcademicYears}');
        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null) return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');
        final cId = state.resolvedClasses[cCode];
        if (cId == null) return _createDependencySkipRow(row, OnboardingStep.classes, 'class_code', cCode, 'class');
        final sId = state.resolvedSubjects[sCode];
        if (sId == null) return _createDependencySkipRow(row, OnboardingStep.subjects, 'subject_code', sCode, 'subject');

        final result = await apiClient.post(
          '/syllabuses?school_id=$schoolId&academic_year_id=$ayId',
          data: {
            'class_id': cId,
            'subject_id': sId,
            'syllabus_code': syllabusCode,
            'unit_name': row.data['unit_name'] ?? '',
            'chapter_name': row.data['chapter_name'] ?? '',
            'topic_name': row.data['topic_name'] ?? '',
            'description': row.data['description'],
            'sequence_order': int.tryParse(row.data['sequence_order'] ?? '1') ?? 1,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          final isConflict = failure.statusCode == 409 ||
              (failure.statusCode == 422 && failure.message.contains('already exists'));
          if (isConflict) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.syllabus,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/syllabuses',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/syllabuses');
        }

      case OnboardingStep.exams:
        final ayCode = (row.data['academic_year_code'] ?? '').trim().toUpperCase();
        final cCode = row.data['class_code'] ?? '';
        final sCode = row.data['subject_code'] ?? '';
        final examTypeRaw = row.data['exam_type'] ?? '';
        if (examTypeRaw.isEmpty) {
          return row.copyWith(
            status: OnboardingRowStatus.failed,
            apiErrorMessage: 'exam_type is required for Exams & Documents.',
          );
        }
        final examDateRaw = row.data['exam_date'] ?? '';
        if (examDateRaw.isEmpty) {
          return row.copyWith(
            status: OnboardingRowStatus.failed,
            apiErrorMessage: 'exam_date is required for Exams & Documents.',
          );
        }
        final ayId = state.resolvedAcademicYears[ayCode];
        if (ayId == null) return _createDependencySkipRow(row, OnboardingStep.academicYears, 'academic_year_code', ayCode, 'academic year');
        final cId = state.resolvedClasses[cCode];
        if (cId == null) return _createDependencySkipRow(row, OnboardingStep.classes, 'class_code', cCode, 'class');
        final sId = state.resolvedSubjects[sCode];
        if (sId == null) return _createDependencySkipRow(row, OnboardingStep.subjects, 'subject_code', sCode, 'subject');
        final result = await apiClient.post(
          '/examinations',
          data: {
            'exam_name': row.data['exam_name'],
            'exam_type': examTypeRaw.toUpperCase(),
            'start_date': examDateRaw,
            'end_date': examDateRaw,
            'exam_code': row.data['exam_code'],
            'max_marks': int.tryParse(row.data['maximum_marks'] ?? '100') ?? 100,
            'duration_minutes': int.tryParse(row.data['duration_minutes'] ?? '180') ?? 180,
            'school_id': schoolId,
            'academic_year_id': ayId,
            'class_id': cId,
            'subject_id': sId,
          },
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as Map<String, dynamic>;
          },
        );
        if (result is Success<Map<String, dynamic>>) {
          final uuid = result.data['id'] as String;
          final examCode = row.data['exam_code'] ?? '';
          if (examCode.isNotEmpty) {
            state = state.copyWith(resolvedExaminations: Map.from(state.resolvedExaminations)..[examCode] = uuid);
          }
          return row.copyWith(status: OnboardingRowStatus.success, resolvedId: uuid);
        } else {
          final failure = (result as Failure<Map<String, dynamic>>).failure;
          final isConflict = failure.statusCode == 409 ||
              (failure.statusCode == 422 && failure.message.contains('already exists'));
          if (isConflict) {
            final existingId = await _resolveExistingId(
              step: OnboardingStep.exams,
              schoolId: schoolId,
              rowData: row.data,
              apiClient: apiClient,
            );
            if (existingId != null) {
              final examCode = row.data['exam_code'] ?? '';
              if (examCode.isNotEmpty) {
                state = state.copyWith(resolvedExaminations: Map.from(state.resolvedExaminations)..[examCode] = existingId);
              }
              return row.copyWith(status: OnboardingRowStatus.success, resolvedId: existingId);
            } else {
              return _handleFailure(
                ApiFailure(
                  message: 'Record already exists, but existing record could not be resolved.',
                  type: failure.type,
                  statusCode: failure.statusCode,
                  originalError: failure.originalError,
                ),
                row,
                endpoint: '/examinations',
              );
            }
          }
          return _handleFailure(failure, row, endpoint: '/examinations');
        }

      default:
        return row.copyWith(status: OnboardingRowStatus.skipped, apiErrorMessage: 'Unknown execution step.');
    }
  }

  Future<String?> _resolveExistingId({
    required OnboardingStep step,
    required String schoolId,
    required Map<String, String> rowData,
    required BaseApiClient apiClient,
  }) async {
    switch (step) {
      case OnboardingStep.school:
        final code = rowData['school_code'] ?? '';
        if (code.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/schools?skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final schoolsList = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (schoolsList.isEmpty) break;
          for (final s in schoolsList) {
            if (s['code'] == code) {
              return s['id'] as String;
            }
          }
          if (schoolsList.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.academicYears:
        final code = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        if (code.isEmpty) return null;
        print('[_resolveExistingId] Academic Years lookup for code="$code" in schoolId="$schoolId"');
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/schools/$schoolId/academic-years?skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) {
              print('[_resolveExistingId] GET academic-years returned ${data.length} items');
              return data;
            },
            onFailure: (failure) {
              print('[_resolveExistingId] GET academic-years failed: ${failure.message} (status: ${failure.statusCode})');
              return const [];
            },
          );
          if (list.isEmpty) break;
          for (final item in list) {
            final itemCode = (item['code'] ?? '').toString().trim().toUpperCase();
            final itemId = item['id'] as String?;
            print('[_resolveExistingId] Checking item: code="$itemCode", id="$itemId"');
            if (itemCode == code) {
              print('[_resolveExistingId] Found match! Returning $itemId');
              return itemId;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.classes:
        final code = rowData['class_code'] ?? '';
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        if (code.isEmpty || ayId.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/classes?school_id=$schoolId&academic_year_id=$ayId&skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['code'] == code) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.sections:
        final code = rowData['section_code'] ?? '';
        final classCode = rowData['class_code'] ?? '';
        final classId = state.resolvedClasses[classCode] ?? '';
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        if (code.isEmpty || classId.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          String queryUrl = '/sections?school_id=$schoolId&class_id=$classId';
          if (ayId.isNotEmpty) {
            queryUrl += '&academic_year_id=$ayId';
          }
          queryUrl += '&skip=$skip&limit=$limit';
          final listResult = await apiClient.get(
            queryUrl,
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['code'] == code) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.subjects:
        final code = rowData['subject_code'] ?? '';
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        if (code.isEmpty || ayId.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/subjects?school_id=$schoolId&academic_year_id=$ayId&skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['subject_code'] == code) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.teachers:
        final code = rowData['teacher_code'] ?? rowData['employee_code'] ?? '';
        if (code.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/teachers?school_id=$schoolId&skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['employee_code'] == code || item['staff_code'] == code) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.guardians:
        final code = rowData['guardian_code'] ?? '';
        if (code.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/guardians?school_id=$schoolId&skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['mobile'] == rowData['mobile'] || item['email'] == rowData['email']) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.students:
        final adm = rowData['admission_number'] ?? '';
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        if (adm.isEmpty || ayId.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/students?school_id=$schoolId&academic_year_id=$ayId&skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['admission_number'] == adm) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.relationships:
        final adm = rowData['admission_number'] ?? '';
        final gCode = rowData['guardian_code'] ?? '';
        final studentId = state.resolvedStudents[adm] ?? '';
        final guardianId = state.resolvedGuardians[gCode] ?? '';
        if (studentId.isEmpty || guardianId.isEmpty) return null;
        final listResult = await apiClient.get(
          '/student-guardians?student_id=$studentId',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return payload['data'] as List<dynamic>;
          },
        );
        final list = listResult.when(
          onSuccess: (data) => data,
          onFailure: (_) => const [],
        );
        for (final item in list) {
          if (item['student_id'] == studentId && item['guardian_id'] == guardianId) {
            return item['id'] as String;
          }
        }
        return null;

      case OnboardingStep.teacherAssignments:
        final tCode = rowData['teacher_code'] ?? '';
        final sCode = rowData['subject_code'] ?? '';
        final cCode = rowData['class_code'] ?? '';
        final secCode = rowData['section_code'] ?? '';
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final tId = state.resolvedTeachers[tCode] ?? '';
        final sId = state.resolvedSubjects[sCode] ?? '';
        final cId = state.resolvedClasses[cCode] ?? '';
        final secId = state.resolvedSections['$cCode-$secCode'] ?? '';
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        if (tId.isEmpty || sId.isEmpty || cId.isEmpty || secId.isEmpty || ayId.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/teacher-subject-assignments?school_id=$schoolId&academic_year_id=$ayId&skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['teacher_id'] == tId &&
                item['subject_id'] == sId &&
                item['class_id'] == cId &&
                item['section_id'] == secId) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.timetable:
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final cCode = rowData['class_code'] ?? '';
        final secCode = rowData['section_code'] ?? '';
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        final cId = state.resolvedClasses[cCode] ?? '';
        final secId = state.resolvedSections['$cCode-$secCode'] ?? '';
        final dayOfWeek = (rowData['day_of_week'] ?? 'MONDAY').toUpperCase();
        final period = int.tryParse(rowData['period_number'] ?? '1') ?? 1;
        if (ayId.isEmpty || cId.isEmpty || secId.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/timetables?school_id=$schoolId&academic_year_id=$ayId&skip=$skip&limit=$limit',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              return payload['data'] as List<dynamic>;
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['class_id'] == cId &&
                item['section_id'] == secId &&
                item['day_of_week']?.toString().toUpperCase() == dayOfWeek &&
                item['period_number'] == period) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.exams:
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        final examName = rowData['exam_name'] ?? '';
        if (ayId.isEmpty || examName.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/examinations?school_id=$schoolId&academic_year_id=$ayId&skip=$skip&limit=$limit',
            mapper: (json) {
              if (json is List) {
                return json;
              } else if (json is Map<String, dynamic>) {
                final data = json['data'];
                if (data is List) return data;
                final items = json['items'];
                if (items is List) return items;
              }
              return const [];
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            final existingName = (item['exam_name']?.toString() ?? '').trim().toLowerCase();
            final targetName = examName.trim().toLowerCase();

            final existingType = (item['exam_type']?.toString() ?? '').trim().toUpperCase();
            final targetType = (rowData['exam_type']?.toString() ?? '').trim().toUpperCase();

            final rawExistStart = item['start_date']?.toString() ?? '';
            final existingStart = rawExistStart.length >= 10 ? rawExistStart.substring(0, 10) : rawExistStart.trim();
            final rawTargetStart = rowData['exam_date']?.toString() ?? '';
            final targetStart = rawTargetStart.length >= 10 ? rawTargetStart.substring(0, 10) : rawTargetStart.trim();

            if (existingName == targetName &&
                existingType == targetType &&
                existingStart == targetStart) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      case OnboardingStep.syllabus:
        final code = rowData['syllabus_code'] ?? '';
        final classCode = rowData['class_code'] ?? '';
        final classId = state.resolvedClasses[classCode] ?? '';
        final subjectCode = rowData['subject_code'] ?? '';
        final subjectId = state.resolvedSubjects[subjectCode] ?? '';
        final ayCode = (rowData['academic_year_code'] ?? '').trim().toUpperCase();
        final ayId = state.resolvedAcademicYears[ayCode] ?? '';
        if (code.isEmpty || classId.isEmpty || subjectId.isEmpty || ayId.isEmpty) return null;
        int skip = 0;
        const int limit = 100;
        while (true) {
          final listResult = await apiClient.get(
            '/syllabuses?school_id=$schoolId&academic_year_id=$ayId&class_id=$classId&subject_id=$subjectId&skip=$skip&limit=$limit',
            mapper: (json) {
              if (json is List) {
                return json;
              } else if (json is Map<String, dynamic>) {
                final data = json['data'];
                if (data is List) return data;
                final items = json['items'];
                if (items is List) return items;
              }
              return const [];
            },
          );
          final list = listResult.when(
            onSuccess: (data) => data,
            onFailure: (_) => const [],
          );
          if (list.isEmpty) break;
          for (final item in list) {
            if (item['syllabus_code'] == code) {
              return item['id'] as String;
            }
          }
          if (list.length < limit) break;
          skip += limit;
        }
        return null;

      default:
        return null;
    }
  }

  void _checkAndFlagGlobalFailure(ApiFailure failure) {
    if (failure.statusCode == 401 || failure.statusCode == 403 || failure.statusCode == 503) {
      state = state.copyWith(globalErrorMessage: failure.message);
    }
  }

  bool _hasBlockingErrors(OnboardingState state) {
    if (state.sheets.isEmpty) return true;
    for (final sheet in state.sheets.values) {
      if (sheet.sheetErrorMessage != null) return true;
      for (final r in sheet.rows) {
        if (r.errors.isNotEmpty || r.unresolvedReferences.isNotEmpty) return true;
      }
    }
    return false;
  }

  void _runCrossSheetValidation() {
    final updatedSheets = Map<OnboardingStep, OnboardingSheetData>.from(state.sheets);
    final schoolSheet = updatedSheets[OnboardingStep.school];
    
    final selectedSchoolId = _ref.read(selectedSchoolIdProvider) ?? '';
    final schoolListState = _ref.read(schoolsListProvider);
    final Set<String> existingSchoolCodes = schoolListState.schools.map((s) => s.code).toSet();

    final Set<String> existingAyCodes = {};
    if (selectedSchoolId.isNotEmpty) {
      try {
        final ayState = _ref.read(academicYearsProvider(selectedSchoolId));
        existingAyCodes.addAll(ayState.years.map((y) => y.code.toUpperCase()));
      } catch (_) {}
    }

    final Set<String> schoolCodes = {};
    if (schoolSheet != null && schoolSheet.rows.isNotEmpty) {
      for (final r in schoolSheet.rows) {
        final code = r.data['school_code'] ?? '';
        if (code.isNotEmpty) {
          schoolCodes.add(code);
        }
      }
    }

    final aySheet = updatedSheets[OnboardingStep.academicYears];
    final Set<String> ayCodes = {};
    if (aySheet != null && aySheet.rows.isNotEmpty) {
      for (final r in aySheet.rows) {
        final code = (r.data['academic_year_code'] ?? '').trim().toUpperCase();
        if (code.isNotEmpty) {
          ayCodes.add(code);
        }
      }
    }

    for (final step in updatedSheets.keys) {
      final sheet = updatedSheets[step]!;
      if (sheet.rows.isEmpty) continue;

      final updatedRows = List<OnboardingParsedRow>.from(sheet.rows);
      bool sheetChanged = false;

      for (int i = 0; i < updatedRows.length; i++) {
        final row = updatedRows[i];
        final currentRefs = List<String>.from(row.unresolvedReferences);
        
        final originalLength = currentRefs.length;
        currentRefs.removeWhere((ref) => ref.contains('does not resolve to a school row') || ref.contains('does not resolve to an academic year row'));

        if (step == OnboardingStep.academicYears) {
          final schoolCode = row.data['school_code'] ?? '';
          if (schoolCode.isNotEmpty) {
            if (!schoolCodes.contains(schoolCode) && !existingSchoolCodes.contains(schoolCode)) {
              currentRefs.add('school_code "$schoolCode" does not resolve to a school row in the same workbook.');
            }
          }
        }

        if (step == OnboardingStep.classes) {
          final ayCodeRaw = row.data['academic_year_code'] ?? '';
          if (ayCodeRaw.isNotEmpty) {
            final normalizedAy = ayCodeRaw.trim().toUpperCase();
            if (!ayCodes.contains(normalizedAy) && !existingAyCodes.contains(normalizedAy)) {
              currentRefs.add('academic_year_code "$ayCodeRaw" does not resolve to an academic year row in the same workbook.');
            }
          }
        }

        if (currentRefs.length != originalLength ||
            !currentRefs.every((r) => row.unresolvedReferences.contains(r))) {
          updatedRows[i] = row.copyWith(unresolvedReferences: currentRefs);
          sheetChanged = true;
        }
      }

      if (sheetChanged) {
        updatedSheets[step] = sheet.copyWith(rows: updatedRows);
      }
    }

    state = state.copyWith(sheets: updatedSheets);
  }

  void _invalidateRelevantProviders(String schoolId) {
    _ref.invalidate(studentListProvider);
    _ref.invalidate(classesProvider(schoolId));
    _ref.invalidate(sectionsProvider(schoolId));
    _ref.invalidate(subjectsProvider(schoolId));
  }

  Map<String, String> _getRowCodeAndName(OnboardingStep step, Map<String, String> data) {
    String code = '';
    String name = '';
    switch (step) {
      case OnboardingStep.school:
        code = data['school_code'] ?? '';
        name = data['school_name'] ?? '';
        break;
      case OnboardingStep.academicYears:
        code = data['academic_year_code'] ?? '';
        name = data['academic_year_name'] ?? '';
        break;
      case OnboardingStep.classes:
        code = data['class_code'] ?? '';
        name = data['display_label'] ?? '';
        break;
      case OnboardingStep.sections:
        code = data['section_code'] ?? '';
        name = data['section_name'] ?? '';
        break;
      case OnboardingStep.subjects:
        code = data['subject_code'] ?? '';
        name = data['subject_name'] ?? '';
        break;
      case OnboardingStep.teachers:
        code = data['teacher_code'] ?? '';
        name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
        break;
      case OnboardingStep.guardians:
        code = data['guardian_code'] ?? '';
        name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
        break;
      case OnboardingStep.students:
        code = data['admission_number'] ?? '';
        name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
        break;
      case OnboardingStep.relationships:
        code = '${data['admission_number'] ?? ''} -> ${data['guardian_code'] ?? ''}';
        name = data['relationship'] ?? '';
        break;
      case OnboardingStep.teacherAssignments:
        code = '${data['teacher_code'] ?? ''} -> ${data['subject_code'] ?? ''}';
        name = '${data['class_code'] ?? ''} ${data['section_code'] ?? ''}';
        break;
      case OnboardingStep.timetable:
        code = '${data['day_of_week'] ?? ''} ${data['start_time'] ?? ''}';
        name = data['subject_code'] ?? '';
        break;
      case OnboardingStep.syllabus:
        code = data['subject_code'] ?? '';
        name = data['topic_title'] ?? '';
        break;
      case OnboardingStep.exams:
        code = data['exam_code'] ?? '';
        name = data['exam_name'] ?? '';
        break;
      default:
        break;
    }
    return {'code': code, 'name': name};
  }

  OnboardingParsedRow? _findParentRow(OnboardingStep parentStep, String keyField, String keyValue) {
    final sheet = state.sheets[parentStep];
    if (sheet == null) {
      print('[_findParentRow] Sheet ${parentStep.name} is null');
      return null;
    }
    print('[_findParentRow] Searching in ${parentStep.name} for $keyField = "$keyValue"');
    for (final row in sheet.rows) {
      print('[_findParentRow] Row keys: ${row.data.keys.toList()} | Row value for $keyField: "${row.data[keyField]}"');
      // Normalize values for safe comparison
      final rowVal = (row.data[keyField] ?? '').trim().toUpperCase();
      final searchVal = keyValue.trim().toUpperCase();
      if (rowVal == searchVal) {
        return row;
      }
    }
    return null;
  }

  OnboardingParsedRow _createDependencySkipRow(
    OnboardingParsedRow row,
    OnboardingStep parentStep,
    String keyField,
    String keyValue,
    String entityType,
  ) {
    final parentRow = _findParentRow(parentStep, keyField, keyValue);
    String failureReason = 'Skipped because $entityType code $keyValue could not be resolved.';
    String? parentErrorDetail;

    if (parentRow != null) {
      if (parentRow.status == OnboardingRowStatus.failed) {
        parentErrorDetail = 'Parent ${parentStep.label} row failed: HTTP ${parentRow.httpStatus ?? "Unknown"} - ${parentRow.apiErrorMessage ?? "No error details available"}';
      } else if (parentRow.status == OnboardingRowStatus.skipped) {
        parentErrorDetail = 'Parent ${parentStep.label} row was skipped: ${parentRow.dependencyFailureReason ?? "No skip reason available"}';
      } else {
        parentErrorDetail = 'Parent ${parentStep.label} row status is: ${parentRow.status.name}';
      }
    } else {
      parentErrorDetail = 'Parent row with $keyField = "$keyValue" was not found in ${parentStep.label} sheet.';
    }

    return row.copyWith(
      status: OnboardingRowStatus.skipped,
      dependencyFailureReason: failureReason,
      parentError: parentErrorDetail,
      apiErrorMessage: '$failureReason ${parentErrorDetail}',
    );
  }

  OnboardingParsedRow? _findParentSectionRow(String classCode, String sectionCode) {
    final sheet = state.sheets[OnboardingStep.sections];
    if (sheet == null) return null;
    for (final r in sheet.rows) {
      if (r.data['class_code'] == classCode && r.data['section_code'] == sectionCode) {
        return r;
      }
    }
    return null;
  }

  OnboardingParsedRow _createStudentSectionSkipRow(
    OnboardingParsedRow row,
    String classCode,
    String sectionCode,
  ) {
    final parentRow = _findParentSectionRow(classCode, sectionCode);
    String failureReason = 'Skipped because section code $sectionCode of class $classCode could not be resolved.';
    String? parentErrorDetail;

    if (parentRow != null) {
      if (parentRow.status == OnboardingRowStatus.failed) {
        parentErrorDetail = 'Parent Sections row failed: HTTP ${parentRow.httpStatus ?? "Unknown"} - ${parentRow.apiErrorMessage ?? "No error details available"}';
      } else if (parentRow.status == OnboardingRowStatus.skipped) {
        parentErrorDetail = 'Parent Sections row was skipped: ${parentRow.dependencyFailureReason ?? "No skip reason available"}';
      } else {
        parentErrorDetail = 'Parent Sections row status is: ${parentRow.status.name}';
      }
    } else {
      parentErrorDetail = 'Parent row with class_code = "$classCode" and section_code = "$sectionCode" was not found in Sections sheet.';
    }

    return row.copyWith(
      status: OnboardingRowStatus.skipped,
      dependencyFailureReason: failureReason,
      parentError: parentErrorDetail,
      apiErrorMessage: '$failureReason ${parentErrorDetail}',
    );
  }

  String _cleanErrorMessage(String message) {
    var clean = message;
    final regexBearer = RegExp(r'bearer\s+[a-zA-Z0-9\-\._~\+\/]+=*', caseSensitive: false);
    final regexAuth = RegExp(r'authorization\s*:\s*[^\s]+', caseSensitive: false);
    final regexJwt = RegExp(r'eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+', caseSensitive: false);
    
    clean = clean.replaceAll(regexBearer, 'Bearer [REDACTED]');
    clean = clean.replaceAll(regexAuth, 'Authorization: [REDACTED]');
    clean = clean.replaceAll(regexJwt, '[REDACTED_JWT_TOKEN]');
    return clean;
  }

  OnboardingParsedRow _handleFailure(ApiFailure failure, OnboardingParsedRow row, {String? endpoint}) {
    _checkAndFlagGlobalFailure(failure);
    return row.copyWith(
      status: OnboardingRowStatus.failed,
      httpStatus: failure.statusCode,
      apiErrorMessage: _cleanErrorMessage(failure.message),
      endpoint: endpoint,
    );
  }

  String debugCleanErrorMessage(String message) => _cleanErrorMessage(message);

  Future<void> _prepopulateResolutionMaps(String schoolId, BaseApiClient apiClient) async {
    if (schoolId.isEmpty) return;
    final tenantId = _ref.read(activeTenantIdProvider) ?? '';
    try {
      // 1. Fetch active school details to resolve schoolCode -> schoolId
      final schoolResult = await apiClient.get<List<dynamic>>(
        '/schools?limit=100',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return (payload['data'] as List<dynamic>?) ?? const [];
        },
      );
      bool schoolFound = false;
      schoolResult.when(
        onSuccess: (list) {
          for (final school in list) {
            final s = school as Map<String, dynamic>;
            if (s['id'] == schoolId) {
              final code = s['code'] as String?;
              if (code != null && code.isNotEmpty) {
                state = state.copyWith(
                  resolvedSchools: Map.from(state.resolvedSchools)..[code] = schoolId,
                );
                schoolFound = true;
                // ignore: avoid_print
                print('[ONBOARDING][RESOLUTION] School: $code | School ID: $schoolId');
              }
              break;
            }
          }
        },
        onFailure: (failure) {
          throw PrepopulationException(
            endpoint: '/schools?limit=100',
            statusCode: failure.statusCode,
            schoolId: schoolId,
            tenantId: tenantId,
            entity: 'school details',
            errorMessage: failure.message,
          );
        },
      );

      if (!schoolFound) {
        // ignore: avoid_print
        print('[ONBOARDING][RESOLUTION][MISS] Entity: School | ID: $schoolId | School context details not preloaded (clean slate tenant/school)');
      }

      // 2. Fetch academic years under this school to resolve academic_year_code -> id
      int skip = 0;
      const int limit = 100;
      int ayCount = 0;
      while (true) {
        final ayResult = await apiClient.get<List<dynamic>>(
          '/schools/$schoolId/academic-years?skip=$skip&limit=$limit',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return (payload['data'] as List<dynamic>?) ?? const [];
          },
        );
        bool finished = false;
        ayResult.when(
          onSuccess: (list) {
            if (list.isEmpty) {
              finished = true;
              return;
            }
            final updatedYears = Map<String, String>.from(state.resolvedAcademicYears);
            for (final item in list) {
              final code = (item['code'] ?? '').toString().trim().toUpperCase();
              final id = item['id'] as String?;
              if (code.isNotEmpty && id != null) {
                updatedYears[code] = id;
                ayCount++;
              }
            }
            state = state.copyWith(resolvedAcademicYears: updatedYears);
            if (list.length < limit) {
              finished = true;
            }
          },
          onFailure: (failure) {
            throw PrepopulationException(
              endpoint: '/schools/$schoolId/academic-years',
              statusCode: failure.statusCode,
              schoolId: schoolId,
              tenantId: tenantId,
              entity: 'academic years',
              errorMessage: failure.message,
            );
          },
        );
        if (finished) break;
        skip += limit;
      }
      // ignore: avoid_print
      print('[ONBOARDING][RESOLUTION] Academic Years Loaded: $ayCount');

      // 3. Fetch classes under this school to resolve class_code -> id
      skip = 0;
      int classCount = 0;
      while (true) {
        final classesResult = await apiClient.get<List<dynamic>>(
          '/classes?school_id=$schoolId&skip=$skip&limit=$limit',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return (payload['data'] as List<dynamic>?) ?? const [];
          },
        );
        bool finished = false;
        classesResult.when(
          onSuccess: (list) {
            if (list.isEmpty) {
              finished = true;
              return;
            }
            final updatedClasses = Map<String, String>.from(state.resolvedClasses);
            for (final item in list) {
              final code = (item['code'] ?? '').toString().trim();
              final id = item['id'] as String?;
              if (code.isNotEmpty && id != null) {
                updatedClasses[code] = id;
                classCount++;
              }
            }
            state = state.copyWith(resolvedClasses: updatedClasses);
            if (list.length < limit) {
              finished = true;
            }
          },
          onFailure: (failure) {
            throw PrepopulationException(
              endpoint: '/classes?school_id=$schoolId',
              statusCode: failure.statusCode,
              schoolId: schoolId,
              tenantId: tenantId,
              entity: 'classes',
              errorMessage: failure.message,
            );
          },
        );
        if (finished) break;
        skip += limit;
      }
      // ignore: avoid_print
      print('[ONBOARDING][RESOLUTION] Classes Loaded: $classCount');

      // 4. Fetch subjects under this school to resolve subject_code -> id
      skip = 0;
      int subjectCount = 0;
      while (true) {
        final subjectsResult = await apiClient.get<List<dynamic>>(
          '/subjects?school_id=$schoolId&skip=$skip&limit=$limit',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return (payload['data'] as List<dynamic>?) ?? const [];
          },
        );
        bool finished = false;
        subjectsResult.when(
          onSuccess: (list) {
            if (list.isEmpty) {
              finished = true;
              return;
            }
            final updatedSubjects = Map<String, String>.from(state.resolvedSubjects);
            for (final item in list) {
              final code = (item['subject_code'] ?? '').toString().trim();
              final id = item['id'] as String?;
              if (code.isNotEmpty && id != null) {
                updatedSubjects[code] = id;
                subjectCount++;
              }
            }
            state = state.copyWith(resolvedSubjects: updatedSubjects);
            if (list.length < limit) {
              finished = true;
            }
          },
          onFailure: (failure) {
            throw PrepopulationException(
              endpoint: '/subjects?school_id=$schoolId',
              statusCode: failure.statusCode,
              schoolId: schoolId,
              tenantId: tenantId,
              entity: 'subjects',
              errorMessage: failure.message,
            );
          },
        );
        if (finished) break;
        skip += limit;
      }
      // ignore: avoid_print
      print('[ONBOARDING][RESOLUTION] Subjects Loaded: $subjectCount');

      // 5. Fetch sections under this school to resolve class_code + section_code -> id
      skip = 0;
      int sectionCount = 0;
      final classIdToCode = state.resolvedClasses.map((code, id) => MapEntry(id, code));
      while (true) {
        final sectionsResult = await apiClient.get<List<dynamic>>(
          '/sections?school_id=$schoolId&skip=$skip&limit=$limit',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            return (payload['data'] as List<dynamic>?) ?? const [];
          },
        );
        bool finished = false;
        sectionsResult.when(
          onSuccess: (list) {
            if (list.isEmpty) {
              finished = true;
              return;
            }
            final updatedSections = Map<String, String>.from(state.resolvedSections);
            for (final item in list) {
              final sectionCode = (item['code'] ?? '').toString().trim();
              final classId = item['class_id'] as String?;
              final id = item['id'] as String?;
              if (sectionCode.isNotEmpty && classId != null && id != null) {
                final classCode = classIdToCode[classId];
                if (classCode != null) {
                  updatedSections['$classCode-$sectionCode'] = id;
                  sectionCount++;
                }
              }
            }
            state = state.copyWith(resolvedSections: updatedSections);
            if (list.length < limit) {
              finished = true;
            }
          },
          onFailure: (failure) {
            throw PrepopulationException(
              endpoint: '/sections?school_id=$schoolId',
              statusCode: failure.statusCode,
              schoolId: schoolId,
              tenantId: tenantId,
              entity: 'sections',
              errorMessage: failure.message,
            );
          },
        );
        if (finished) break;
        skip += limit;
      }
      // ignore: avoid_print
      print('[ONBOARDING][RESOLUTION] Sections Loaded: $sectionCount');

    } on PrepopulationException {
      rethrow;
    } catch (e) {
      throw PrepopulationException(
        endpoint: 'Prepopulate resolution maps',
        schoolId: schoolId,
        tenantId: tenantId,
        entity: 'resolution context maps',
        errorMessage: e.toString(),
      );
    }
  }

  Future<ApiResult<Map<String, dynamic>>> provisionPrincipal(String schoolId) async {
    final r = Random.secure();
    const hexDigits = '0123456789abcdef';
    final chars = List<String>.generate(36, (index) {
      if (index == 8 || index == 13 || index == 18 || index == 23) {
        return '-';
      }
      if (index == 14) {
        return '4';
      }
      final val = r.nextInt(16);
      if (index == 19) {
        return hexDigits[(val & 0x3) | 0x8];
      }
      return hexDigits[val];
    });
    final principalId = chars.join();

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.post(
      '/identity/provision/principal/$principalId',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>;
      },
    );
    return result;
  }
}

class PrepopulationException implements Exception {
  final String endpoint;
  final int? statusCode;
  final String schoolId;
  final String tenantId;
  final String entity;
  final String errorMessage;

  PrepopulationException({
    required this.endpoint,
    this.statusCode,
    required this.schoolId,
    required this.tenantId,
    required this.entity,
    required this.errorMessage,
  });

  @override
  String toString() {
    return 'Unable to preload $entity for school $schoolId: HTTP ${statusCode ?? "Unknown"} on $endpoint - $errorMessage';
  }
}
