import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/bulk_import_models.dart';
import '../../../students/data/models/student_models.dart';
import '../../../school_setup/data/models/school_setup_models.dart';
import '../../data/models/csv_helper.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';
import 'package:edupulse_network/edupulse_network.dart';
class BulkImportState {
  final ImportType selectedType;
  final String? fileName;
  final List<ParsedRow> rows;
  final List<String> headers;
  final bool isUploading;
  final int currentProgress;
  final int totalProgress;
  final String? currentItemName;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final bool isCompleted;
  final String? globalErrorMessage;
  final Map<String, int> existingSectionCounts;
  final Set<String> existingAdmissionNumbers;
  final Set<String> existingRollSectionKeys;
  
  // Excel Sheet Selection Fields
  final List<String> sheets;
  final String? selectedSheet;
  final Uint8List? rawBytes;

  // Dependency Resolution Fields
  final List<ClassDto> cachedClasses;
  final List<SectionDto> cachedSections;
  final Map<String, String> resolvedClassIds;
  final Map<String, String> resolvedSectionIds;
  final int dependencyTotalClasses;
  final int dependencyExistingClasses;
  final int dependencyNewClasses;
  final int dependencyTotalSections;
  final int dependencyExistingSections;
  final int dependencyNewSections;
  final bool dependenciesDirty;
  final bool dependenciesPreparing;
  final bool dependenciesReady;
  final String? dependencyError;
  final Set<String> createdClassIds;
  final Set<String> createdSectionIds;

  // Retry Fields
  final bool isRetrying;
  final int retryTotal;
  final int retryProgress;
  final int retrySuccessCount;
  final int retryAlreadyExistsCount;
  final int retryStillFailedCount;
  final String? retryCurrentItemName;

  BulkImportState({
    required this.selectedType,
    this.fileName,
    required this.rows,
    required this.headers,
    required this.isUploading,
    required this.currentProgress,
    required this.totalProgress,
    this.currentItemName,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.isCompleted,
    this.globalErrorMessage,
    required this.existingSectionCounts,
    required this.existingAdmissionNumbers,
    required this.existingRollSectionKeys,
    // Dependency fields
    required this.cachedClasses,
    required this.cachedSections,
    required this.resolvedClassIds,
    required this.resolvedSectionIds,
    required this.dependencyTotalClasses,
    required this.dependencyExistingClasses,
    required this.dependencyNewClasses,
    required this.dependencyTotalSections,
    required this.dependencyExistingSections,
    required this.dependencyNewSections,
    required this.dependenciesDirty,
    required this.dependenciesPreparing,
    required this.dependenciesReady,
    this.dependencyError,
    required this.createdClassIds,
    required this.createdSectionIds,
    // Retry fields
    this.isRetrying = false,
    this.retryTotal = 0,
    this.retryProgress = 0,
    this.retrySuccessCount = 0,
    this.retryAlreadyExistsCount = 0,
    this.retryStillFailedCount = 0,
    this.retryCurrentItemName,
    this.sheets = const [],
    this.selectedSheet,
    this.rawBytes,
  });

  factory BulkImportState.initial() {
    return BulkImportState(
      selectedType: ImportType.students,
      fileName: null,
      rows: const [],
      headers: const [],
      isUploading: false,
      currentProgress: 0,
      totalProgress: 0,
      currentItemName: null,
      successCount: 0,
      failedCount: 0,
      skippedCount: 0,
      isCompleted: false,
      globalErrorMessage: null,
      existingSectionCounts: const {},
      existingAdmissionNumbers: const {},
      existingRollSectionKeys: const {},
      // Dependency fields init
      cachedClasses: const [],
      cachedSections: const [],
      resolvedClassIds: const {},
      resolvedSectionIds: const {},
      dependencyTotalClasses: 0,
      dependencyExistingClasses: 0,
      dependencyNewClasses: 0,
      dependencyTotalSections: 0,
      dependencyExistingSections: 0,
      dependencyNewSections: 0,
      dependenciesDirty: false,
      dependenciesPreparing: false,
      dependenciesReady: true,
      dependencyError: null,
      createdClassIds: const {},
      createdSectionIds: const {},
      // Retry init
      isRetrying: false,
      retryTotal: 0,
      retryProgress: 0,
      retrySuccessCount: 0,
      retryAlreadyExistsCount: 0,
      retryStillFailedCount: 0,
      retryCurrentItemName: null,
      sheets: const [],
      selectedSheet: null,
      rawBytes: null,
    );
  }

  int get networkErrorCount => rows.where((r) => r.status == ImportRowStatus.networkError).length;
  int get alreadyExistsCount => rows.where((r) => r.status == ImportRowStatus.alreadyExists).length;
  int get apiErrorCount => rows.where((r) => r.status == ImportRowStatus.apiError || (r.status == ImportRowStatus.failed && r.status != ImportRowStatus.networkError)).length;
  int get validationErrorCount => rows.where((r) =>
      r.status == ImportRowStatus.validationError ||
      r.status == ImportRowStatus.error ||
      r.status == ImportRowStatus.duplicate ||
      r.status == ImportRowStatus.capacityError ||
      r.status == ImportRowStatus.dependencyError).length;
  int get totalSuccessCount => rows.where((r) => r.status == ImportRowStatus.success).length;
  int get totalSkippedCount => rows.where((r) => r.status == ImportRowStatus.skipped).length;

  BulkImportState copyWith({
    ImportType? selectedType,
    String? fileName,
    List<ParsedRow>? rows,
    List<String>? headers,
    bool? isUploading,
    int? currentProgress,
    int? totalProgress,
    String? currentItemName,
    int? successCount,
    int? failedCount,
    int? skippedCount,
    bool? isCompleted,
    String? globalErrorMessage,
    Map<String, int>? existingSectionCounts,
    Set<String>? existingAdmissionNumbers,
    Set<String>? existingRollSectionKeys,
    // Dependency fields
    List<ClassDto>? cachedClasses,
    List<SectionDto>? cachedSections,
    Map<String, String>? resolvedClassIds,
    Map<String, String>? resolvedSectionIds,
    int? dependencyTotalClasses,
    int? dependencyExistingClasses,
    int? dependencyNewClasses,
    int? dependencyTotalSections,
    int? dependencyExistingSections,
    int? dependencyNewSections,
    bool? dependenciesDirty,
    bool? dependenciesPreparing,
    bool? dependenciesReady,
    String? dependencyError,
    Set<String>? createdClassIds,
    Set<String>? createdSectionIds,
    // Retry fields
    bool? isRetrying,
    int? retryTotal,
    int? retryProgress,
    int? retrySuccessCount,
    int? retryAlreadyExistsCount,
    int? retryStillFailedCount,
    String? retryCurrentItemName,
    List<String>? sheets,
    String? selectedSheet,
    Uint8List? rawBytes,
  }) {
    return BulkImportState(
      selectedType: selectedType ?? this.selectedType,
      fileName: fileName ?? this.fileName,
      rows: rows ?? this.rows,
      headers: headers ?? this.headers,
      isUploading: isUploading ?? this.isUploading,
      currentProgress: currentProgress ?? this.currentProgress,
      totalProgress: totalProgress ?? this.totalProgress,
      currentItemName: currentItemName ?? this.currentItemName,
      successCount: successCount ?? this.successCount,
      failedCount: failedCount ?? this.failedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      isCompleted: isCompleted ?? this.isCompleted,
      globalErrorMessage: globalErrorMessage ?? this.globalErrorMessage,
      existingSectionCounts: existingSectionCounts ?? this.existingSectionCounts,
      existingAdmissionNumbers: existingAdmissionNumbers ?? this.existingAdmissionNumbers,
      existingRollSectionKeys: existingRollSectionKeys ?? this.existingRollSectionKeys,
      // Dependency fields
      cachedClasses: cachedClasses ?? this.cachedClasses,
      cachedSections: cachedSections ?? this.cachedSections,
      resolvedClassIds: resolvedClassIds ?? this.resolvedClassIds,
      resolvedSectionIds: resolvedSectionIds ?? this.resolvedSectionIds,
      dependencyTotalClasses: dependencyTotalClasses ?? this.dependencyTotalClasses,
      dependencyExistingClasses: dependencyExistingClasses ?? this.dependencyExistingClasses,
      dependencyNewClasses: dependencyNewClasses ?? this.dependencyNewClasses,
      dependencyTotalSections: dependencyTotalSections ?? this.dependencyTotalSections,
      dependencyExistingSections: dependencyExistingSections ?? this.dependencyExistingSections,
      dependencyNewSections: dependencyNewSections ?? this.dependencyNewSections,
      dependenciesDirty: dependenciesDirty ?? this.dependenciesDirty,
      dependenciesPreparing: dependenciesPreparing ?? this.dependenciesPreparing,
      dependenciesReady: dependenciesReady ?? this.dependenciesReady,
      dependencyError: dependencyError ?? this.dependencyError,
      createdClassIds: createdClassIds ?? this.createdClassIds,
      createdSectionIds: createdSectionIds ?? this.createdSectionIds,
      // Retry fields
      isRetrying: isRetrying ?? this.isRetrying,
      retryTotal: retryTotal ?? this.retryTotal,
      retryProgress: retryProgress ?? this.retryProgress,
      retrySuccessCount: retrySuccessCount ?? this.retrySuccessCount,
      retryAlreadyExistsCount: retryAlreadyExistsCount ?? this.retryAlreadyExistsCount,
      retryStillFailedCount: retryStillFailedCount ?? this.retryStillFailedCount,
      retryCurrentItemName: retryCurrentItemName ?? this.retryCurrentItemName,
      sheets: sheets ?? this.sheets,
      selectedSheet: selectedSheet ?? this.selectedSheet,
      rawBytes: rawBytes ?? this.rawBytes,
    );
  }
}
class BulkImportNotifier extends StateNotifier<BulkImportState> {
  final Ref _ref;
  BulkImportNotifier(this._ref) : super(BulkImportState.initial()) {
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (previous != next) {
        reset();
      }
    });
    // Listen to academic year context changes to auto-reset
    _ref.listen<String?>(selectedAcademicYearIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        reset();
      }
    });
  }

  String sanitizeCode(String code, {int minLength = 2}) {
    var sanitized = code
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    
    // Trim leading/trailing underscores
    if (sanitized.startsWith('_') && sanitized.length > 1) {
      sanitized = sanitized.substring(1);
    }
    if (sanitized.endsWith('_') && sanitized.length > 1) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    if (sanitized.isEmpty) {
      sanitized = 'CODE';
    }
    while (sanitized.length < minLength) {
      sanitized += 'X';
    }
    return sanitized;
  }
  void setImportType(ImportType type) {
    if (state.isUploading) return;
    state = state.copyWith(
      selectedType: type,
      fileName: null,
      rows: [],
      isCompleted: false,
      globalErrorMessage: null,
      successCount: 0,
      failedCount: 0,
      skippedCount: 0,
      sheets: const [],
      selectedSheet: null,
      rawBytes: null,
    );
  }

  Future<void> selectSpreadsheetFile(String fileName, Uint8List bytes, {String? sheetName}) async {
    if (state.isUploading) return;

    state = state.copyWith(
      fileName: fileName,
      rawBytes: bytes,
      isUploading: true,
      globalErrorMessage: null,
      rows: [],
      sheets: const [],
      selectedSheet: null,
    );

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

      state = state.copyWith(isUploading: false);

      result.when(
        onSuccess: (data) {
          final parsedData = data;
          final sheetsList = List<String>.from(parsedData['sheets'] ?? const <String>[]);
          final activeSheet = parsedData['selected_sheet'] as String?;
          final rawRows = (parsedData['rows'] as List<dynamic>?) ?? (parsedData['preview_rows'] as List<dynamic>?) ?? const [];

          final List<List<String>> parsedRows = [];
          for (var row in rawRows) {
            if (row is List) {
              parsedRows.add(row.map((e) => e?.toString() ?? '').toList());
            }
          }

          if (parsedRows.isEmpty) {
            state = state.copyWith(
              rows: [],
              headers: const [],
              sheets: sheetsList,
              selectedSheet: activeSheet,
              globalErrorMessage: 'Missing header row or empty data.',
            );
            return;
          }

          final fileHeaders = parsedRows.first.map((h) => h.toLowerCase().trim()).toList();

          final validated = CsvHelper.validateCsv(
            parsedRows,
            state.selectedType,
            existingAdmissionNumbers: state.existingAdmissionNumbers,
            existingRollSectionKeys: state.existingRollSectionKeys,
          );

          if (validated.length == 1 && validated.first.rowIndex == 1 && validated.first.errors.isNotEmpty) {
            state = state.copyWith(
              rows: validated,
              headers: fileHeaders,
              sheets: sheetsList,
              selectedSheet: activeSheet,
              globalErrorMessage: validated.first.errors.join(', '),
            );
            return;
          }

          state = state.copyWith(
            rows: validated,
            headers: fileHeaders,
            sheets: sheetsList,
            selectedSheet: activeSheet,
            globalErrorMessage: null,
          );
        },
        onFailure: (failure) {
          state = state.copyWith(
            globalErrorMessage: failure.message ?? 'Failed to parse spreadsheet file.',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        globalErrorMessage: 'Network or parsing error: ${e.toString()}',
      );
    }
  }



  final RegExp _uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  Future<void> selectFile(String fileName, String csvContent) async {
    if (state.isUploading) return;
    
    // Check file extension
    if (!fileName.toLowerCase().endsWith('.csv')) {
      state = state.copyWith(
        fileName: fileName,
        rows: [],
        globalErrorMessage: 'Only CSV files (.csv) are supported.',
      );
      return;
    }

    if (csvContent.trim().isEmpty) {
      state = state.copyWith(
        fileName: fileName,
        rows: [],
        globalErrorMessage: 'Selected file is empty.',
      );
      return;
    }

    try {
      final parsed = CsvHelper.parseCsv(csvContent);
      if (parsed.isEmpty) {
        state = state.copyWith(
          fileName: fileName,
          rows: [],
          headers: const [],
          globalErrorMessage: 'Missing header row or empty data.',
        );
        return;
      }

      final fileHeaders = parsed.first.map((h) => h.toLowerCase().trim()).toList();

      final validated = CsvHelper.validateCsv(
        parsed,
        state.selectedType,
        existingAdmissionNumbers: state.existingAdmissionNumbers,
        existingRollSectionKeys: state.existingRollSectionKeys,
      );
      
      // Check if headers failed validation
      if (validated.length == 1 && validated.first.rowIndex == 1 && validated.first.errors.isNotEmpty) {
        state = state.copyWith(
          fileName: fileName,
          rows: validated,
          headers: fileHeaders,
          globalErrorMessage: validated.first.errors.join(', '),
        );
        return;
      }

      state = state.copyWith(
        fileName: fileName,
        rows: validated,
        headers: fileHeaders,
        globalErrorMessage: null,
        isCompleted: false,
        successCount: 0,
        failedCount: 0,
        skippedCount: 0,
        // Reset old dependencies state
        cachedClasses: const [],
        cachedSections: const [],
        resolvedClassIds: const {},
        resolvedSectionIds: const {},
        dependencyTotalClasses: 0,
        dependencyExistingClasses: 0,
        dependencyNewClasses: 0,
        dependencyTotalSections: 0,
        dependencyExistingSections: 0,
        dependencyNewSections: 0,
        dependenciesDirty: false,
        dependenciesPreparing: false,
        dependenciesReady: true,
        dependencyError: null,
      );

      if (state.selectedType == ImportType.students) {
        await checkDependencies(validated);
        if (!mounted) return;
      } else {
        _revalidateAndUpdateRows(state.rows);
      }

      final schoolId = _ref.read(selectedSchoolIdProvider);
      if (schoolId != null && state.selectedType == ImportType.students) {
        fetchExistingStudentCounts(schoolId);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        fileName: fileName,
        rows: [],
        globalErrorMessage: 'Error parsing CSV file: ${e.toString()}',
      );
    }
  }

  Future<void> checkDependencies(List<ParsedRow> rows) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    // Collect all unique academic_year_ids from rows
    final academicYearIds = rows
        .map((r) => r.data['academic_year_id'] ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (academicYearIds.isEmpty) return;

    // Fetch active academic years from backend
    final ayState = _ref.read(academicYearsProvider(schoolId));
    if (ayState.years.isEmpty && !ayState.isLoading) {
      await _ref.read(academicYearsProvider(schoolId).notifier).fetchYears();
      if (!mounted) return;
    }

    // Populate classes and sections providers for client-side validation
    await _ref.read(classesProvider(schoolId).notifier).fetchClasses();
    if (!mounted) return;
    await _ref.read(sectionsProvider(schoolId).notifier).fetchSections();
    if (!mounted) return;

    final latestAyState = _ref.read(academicYearsProvider(schoolId));

    // Verify invalid academic years
    final invalidAcademicYears = <String>{};
    for (final ayId in academicYearIds) {
      if (!latestAyState.years.any((y) => y.id == ayId)) {
        invalidAcademicYears.add(ayId);
      }
    }

    final validAcademicYearIds = academicYearIds.where((id) => !invalidAcademicYears.contains(id)).toList();

    // Fetch latest classes & sections from the backend for the valid academic years
    final apiClient = _ref.read(apiClientProvider);
    final List<ClassDto> classesList = [];
    final List<SectionDto> sectionsList = [];

    for (final ayId in validAcademicYearIds) {
      final classesRes = await apiClient.get(
        '/classes?school_id=$schoolId&academic_year_id=$ayId',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>;
          return list.map((item) => ClassDto.fromJson(item as Map<String, dynamic>)).toList();
        },
      );
      if (!mounted) return;

      classesRes.when(
        onSuccess: (list) => classesList.addAll(list),
        onFailure: (_) {},
      );

      final sectionsRes = await apiClient.get(
        '/sections?school_id=$schoolId&academic_year_id=$ayId',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>;
          return list.map((item) => SectionDto.fromJson(item as Map<String, dynamic>)).toList();
        },
      );
      if (!mounted) return;

      sectionsRes.when(
        onSuccess: (list) => sectionsList.addAll(list),
        onFailure: (_) {},
      );
    }

    // Run resolution checks
    final Map<String, String> resolvedClassIds = {};
    final Map<String, String> resolvedSectionIds = {};

    // Map of unique classes in the CSV: key is '$ayId|$classRef' (lowercase)
    final csvClasses = <String, Map<String, String>>{};
    // Map of unique sections in the CSV: key is '$ayId|$classRef|$secRef' (lowercase)
    final csvSections = <String, Map<String, String>>{};

    for (final r in rows) {
      final ayId = r.data['academic_year_id'] ?? '';
      if (ayId.isEmpty || invalidAcademicYears.contains(ayId)) continue;

      final classId = (r.data['class_id'] ?? '').trim();
      final className = (r.data['class_name'] ?? '').trim();
      final classCode = (r.data['class_code'] ?? '').trim();

      final sectionId = (r.data['section_id'] ?? '').trim();
      final sectionName = (r.data['section_name'] ?? '').trim();
      final sectionCode = (r.data['section_code'] ?? '').trim();

      String classRef = '';
      String classValName = '';
      String classValCode = '';
      bool isClassId = false;

      if (classId.isNotEmpty) {
        classRef = classId.toLowerCase();
        isClassId = true;
        final matchedClass = classesList.firstWhere((c) => c.id == classId, orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: '', code: '', level: 1, category: '', capacity: 40, status: '', isActive: true, version: 1));
        if (matchedClass.id.isNotEmpty) {
          classValName = matchedClass.name;
          classValCode = matchedClass.code;
        } else {
          classValName = classId;
          classValCode = classId;
        }
      } else if (classCode.isNotEmpty || className.isNotEmpty) {
        classRef = (classCode.isNotEmpty ? classCode : className).trim().toLowerCase();
        classValName = className.isNotEmpty ? className : classCode;
        classValCode = classCode.isNotEmpty ? classCode : className;
      }

      if (classRef.isNotEmpty) {
        final classKey = '$ayId|$classRef';
        if (!csvClasses.containsKey(classKey)) {
          csvClasses[classKey] = {
            'academic_year_id': ayId,
            'name': classValName,
            'code': classValCode,
            'class_id': isClassId ? classId : '',
          };
        }

        String secRef = '';
        String secValName = '';
        String secValCode = '';
        bool isSecId = false;

        if (sectionId.isNotEmpty) {
          secRef = sectionId.toLowerCase();
          isSecId = true;
          final matchedSec = sectionsList.firstWhere((s) => s.id == sectionId, orElse: () => const SectionDto(id: '', tenantId: '', schoolId: '', academicYearId: '', classId: '', name: '', code: '', capacity: 40, sortOrder: 1, status: '', isActive: true, version: 1));
          if (matchedSec.id.isNotEmpty) {
            secValName = matchedSec.name;
            secValCode = matchedSec.code;
          } else {
            secValName = sectionId;
            secValCode = sectionId;
          }
        } else if (sectionCode.isNotEmpty || sectionName.isNotEmpty) {
          secRef = (sectionCode.isNotEmpty ? sectionCode : sectionName).trim().toLowerCase();
          secValName = sectionName.isNotEmpty ? sectionName : sectionCode;
          secValCode = sectionCode.isNotEmpty ? sectionCode : sectionName;
        }

        if (secRef.isNotEmpty) {
          final sectionKey = '$ayId|$classRef|$secRef';
          if (!csvSections.containsKey(sectionKey)) {
            csvSections[sectionKey] = {
              'academic_year_id': ayId,
              'class_ref': classRef,
              'name': secValName,
              'code': secValCode,
              'section_id': isSecId ? sectionId : '',
            };
          }
        }
      }
    }

    int existingClassesCount = 0;
    int newClassesCount = 0;
    int existingSectionsCount = 0;
    int newSectionsCount = 0;

    for (final entry in csvClasses.entries) {
      final val = entry.value;
      final ayId = val['academic_year_id']!;
      final name = val['name']!;
      final code = val['code']!;
      final csvClassId = val['class_id']!;

      ClassDto? matched;
      if (csvClassId.isNotEmpty) {
        matched = classesList.firstWhere((c) => c.id == csvClassId, orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: '', code: '', level: 1, category: '', capacity: 40, status: '', isActive: true, version: 1));
        if (matched.id.isEmpty) matched = null;
      } else {
        final sanitized = sanitizeCode(code, minLength: 2);
        for (final c in classesList) {
          if (c.academicYearId == ayId) {
            if (code.isNotEmpty &&
                (c.code.trim().toUpperCase() == sanitized ||
                 c.code.trim().toLowerCase() == code.trim().toLowerCase())) {
              matched = c;
              break;
            }
            if (name.isNotEmpty && c.name.trim().toLowerCase() == name.trim().toLowerCase()) {
              matched = c;
              break;
            }
          }
        }
      }

      final normalizedCode = code.trim().toLowerCase();
      final normalizedName = name.trim().toLowerCase();
      if (matched != null) {
        existingClassesCount++;
        resolvedClassIds['$schoolId|$ayId|$normalizedCode'] = matched.id;
        resolvedClassIds['$schoolId|$ayId|$normalizedName'] = matched.id;
        if (csvClassId.isNotEmpty) {
          resolvedClassIds['$schoolId|$ayId|${csvClassId.toLowerCase()}'] = matched.id;
        }
      } else {
        newClassesCount++;
        resolvedClassIds['$schoolId|$ayId|$normalizedCode'] = '';
        resolvedClassIds['$schoolId|$ayId|$normalizedName'] = '';
      }
    }

    for (final entry in csvSections.entries) {
      final val = entry.value;
      final ayId = val['academic_year_id']!;
      final classRef = val['class_ref']!;
      final name = val['name']!;
      final code = val['code']!;
      final csvSectionId = val['section_id']!;

      final lookupClassKey = '$schoolId|$ayId|$classRef';
      final parentClassId = resolvedClassIds[lookupClassKey] ?? '';

      SectionDto? matched;
      if (csvSectionId.isNotEmpty) {
        matched = sectionsList.firstWhere((s) => s.id == csvSectionId, orElse: () => const SectionDto(id: '', tenantId: '', schoolId: '', academicYearId: '', classId: '', name: '', code: '', capacity: 40, sortOrder: 1, status: '', isActive: true, version: 1));
        if (matched.id.isEmpty) matched = null;
      } else if (parentClassId.isNotEmpty) {
        final sanitized = sanitizeCode(code, minLength: 1);
        for (final s in sectionsList) {
          if (s.academicYearId == ayId && s.classId == parentClassId) {
            if (code.isNotEmpty &&
                (s.code.trim().toUpperCase() == sanitized ||
                 s.code.trim().toLowerCase() == code.trim().toLowerCase())) {
              matched = s;
              break;
            }
            if (name.isNotEmpty && s.name.trim().toLowerCase() == name.trim().toLowerCase()) {
              matched = s;
              break;
            }
          }
        }
      }

      final normalizedCode = code.trim().toLowerCase();
      final normalizedName = name.trim().toLowerCase();
      if (matched != null) {
        existingSectionsCount++;
        resolvedSectionIds['$schoolId|$ayId|$parentClassId|$normalizedCode'] = matched.id;
        resolvedSectionIds['$schoolId|$ayId|$parentClassId|$normalizedName'] = matched.id;
        if (csvSectionId.isNotEmpty) {
          resolvedSectionIds['$schoolId|$ayId|$parentClassId|${csvSectionId.toLowerCase()}'] = matched.id;
        }
      } else {
        newSectionsCount++;
        resolvedSectionIds['$schoolId|$ayId|$parentClassId|$normalizedCode'] = '';
        resolvedSectionIds['$schoolId|$ayId|$parentClassId|$normalizedName'] = '';
      }
    }

    final ready = newClassesCount == 0 && newSectionsCount == 0 && invalidAcademicYears.isEmpty;

    List<ParsedRow> rebuiltRows = List.from(rows);
    if (ready) {
      rebuiltRows = _rebuildRowsWithUUIDs(rows, resolvedClassIds, resolvedSectionIds);
    }

    final List<ParsedRow> updatedRowsWithErrors = rebuiltRows.map((row) {
      final ayId = row.data['academic_year_id'] ?? '';
      final List<String> updatedErrors = List.from(row.errors);
      ImportRowStatus updatedStatus = row.status;

      if (invalidAcademicYears.contains(ayId)) {
        if (!updatedErrors.contains('Academic year with UUID "$ayId" does not exist for this school.')) {
          updatedErrors.add('Academic year with UUID "$ayId" does not exist for this school.');
        }
        updatedStatus = ImportRowStatus.dependencyError;
      }
      return row.copyWith(errors: updatedErrors, status: updatedStatus);
    }).toList();

    state = state.copyWith(
      cachedClasses: classesList,
      cachedSections: sectionsList,
      resolvedClassIds: resolvedClassIds,
      resolvedSectionIds: resolvedSectionIds,
      dependencyTotalClasses: csvClasses.length,
      dependencyExistingClasses: existingClassesCount,
      dependencyNewClasses: newClassesCount,
      dependencyTotalSections: csvSections.length,
      dependencyExistingSections: existingSectionsCount,
      dependencyNewSections: newSectionsCount,
      dependenciesReady: ready,
      rows: updatedRowsWithErrors,
    );

    // Debug summary logs
    final totalRows = rows.length;
    final uniqueAy = rows.map((r) => r.data['academic_year_id'] ?? '').where((id) => id.isNotEmpty).toSet().length;
    final resolvedClassUUIDs = resolvedClassIds.values.where((id) => id.isNotEmpty).toSet().length;
    final resolvedSectionUUIDs = resolvedSectionIds.values.where((id) => id.isNotEmpty).toSet().length;
    final RegExp uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final rowsWithClassIdUUID = updatedRowsWithErrors.map((r) => r.data['class_id'] ?? '').where((id) => uuidRegex.hasMatch(id)).length;
    final rowsWithSectionIdUUID = updatedRowsWithErrors.map((r) => r.data['section_id'] ?? '').where((id) => uuidRegex.hasMatch(id)).length;

    debugPrint('CSV rows: $totalRows');
    debugPrint('Academic years detected: $uniqueAy');
    debugPrint('Unique classes detected: ${csvClasses.length}');
    debugPrint('Unique sections detected: ${csvSections.length}');
    debugPrint('Existing classes resolved: $existingClassesCount');
    debugPrint('New classes: $newClassesCount');
    debugPrint('Existing sections resolved: $existingSectionsCount');
    debugPrint('New sections: $newSectionsCount');
    debugPrint('Resolved class UUIDs: $resolvedClassUUIDs');
    debugPrint('Resolved section UUIDs: $resolvedSectionUUIDs');
    debugPrint('Rows with class_id UUID: $rowsWithClassIdUUID');
    debugPrint('Rows with section_id UUID: $rowsWithSectionIdUUID');

    _revalidateAndUpdateRows(updatedRowsWithErrors);
  }

  List<ParsedRow> _rebuildRowsWithUUIDs(
    List<ParsedRow> rows,
    Map<String, String> classIds,
    Map<String, String> sectionIds,
  ) {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return rows;

    return rows.map((row) {
      final ayId = row.data['academic_year_id'] ?? '';
      if (ayId.isEmpty) return row;

      final classId = (row.data['class_id'] ?? '').trim();
      final className = (row.data['class_name'] ?? '').trim();
      final classCode = (row.data['class_code'] ?? '').trim();

      final sectionId = (row.data['section_id'] ?? '').trim();
      final sectionName = (row.data['section_name'] ?? '').trim();
      final sectionCode = (row.data['section_code'] ?? '').trim();

      String targetClassId = classId;
      if (targetClassId.isEmpty && (classCode.isNotEmpty || className.isNotEmpty)) {
        final codeOrName = classCode.isNotEmpty ? classCode : className;
        targetClassId = classIds['$schoolId|$ayId|${codeOrName.trim().toLowerCase()}'] ?? '';
      }

      String targetSectionId = sectionId;
      if (targetSectionId.isEmpty && (sectionCode.isNotEmpty || sectionName.isNotEmpty) && targetClassId.isNotEmpty) {
        final codeOrName = sectionCode.isNotEmpty ? sectionCode : sectionName;
        targetSectionId = sectionIds['$schoolId|$ayId|$targetClassId|${codeOrName.trim().toLowerCase()}'] ?? '';
      }

      final updatedData = Map<String, String>.from(row.data);
      if (targetClassId.isNotEmpty) {
        updatedData['class_id'] = targetClassId;
      }
      if (targetSectionId.isNotEmpty) {
        updatedData['section_id'] = targetSectionId;
      }

      return row.copyWith(data: updatedData);
    }).toList();
  }

  Future<void> prepareDependencies(
    int defaultClassCapacity,
    int defaultClassLevel,
    int defaultSectionCapacity,
  ) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(
      dependenciesPreparing: true,
      dependencyError: null,
    );

    final apiClient = _ref.read(apiClientProvider);

    // Fetch latest classes & sections from the backend
    List<ClassDto> latestClasses = [];
    List<SectionDto> latestSections = [];

    final academicYearIds = state.rows
        .map((r) => r.data['academic_year_id'] ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    for (final ayId in academicYearIds) {
      final classesRes = await apiClient.get(
        '/classes?school_id=$schoolId&academic_year_id=$ayId',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>;
          return list.map((item) => ClassDto.fromJson(item as Map<String, dynamic>)).toList();
        },
      );
      classesRes.when(
        onSuccess: (list) => latestClasses.addAll(list),
        onFailure: (_) {},
      );

      final sectionsRes = await apiClient.get(
        '/sections?school_id=$schoolId&academic_year_id=$ayId',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>;
          return list.map((item) => SectionDto.fromJson(item as Map<String, dynamic>)).toList();
        },
      );
      sectionsRes.when(
        onSuccess: (list) => latestSections.addAll(list),
        onFailure: (_) {},
      );
    }

    final resolvedClassIds = Map<String, String>.from(state.resolvedClassIds);
    final resolvedSectionIds = Map<String, String>.from(state.resolvedSectionIds);
    final createdClassIds = <String>{};
    final createdSectionIds = <String>{};
    final List<String> dependencyErrorsList = [];

    // Discover missing items from state.rows
    final csvClasses = <String, Map<String, String>>{};
    final csvSections = <String, Map<String, String>>{};

    for (final r in state.rows) {
      final ayId = r.data['academic_year_id'] ?? '';
      if (ayId.isEmpty) continue;

      final classId = (r.data['class_id'] ?? '').trim();
      final className = (r.data['class_name'] ?? '').trim();
      final classCode = (r.data['class_code'] ?? '').trim();

      final sectionId = (r.data['section_id'] ?? '').trim();
      final sectionName = (r.data['section_name'] ?? '').trim();
      final sectionCode = (r.data['section_code'] ?? '').trim();

      if (classId.isEmpty && (classCode.isNotEmpty || className.isNotEmpty)) {
        final codeOrName = classCode.isNotEmpty ? classCode : className;
        final classKey = '$ayId|${codeOrName.trim().toLowerCase()}';
        if (!csvClasses.containsKey(classKey)) {
          csvClasses[classKey] = {
            'academic_year_id': ayId,
            'name': className.isNotEmpty ? className : classCode,
            'code': classCode.isNotEmpty ? classCode : className,
          };
        }
      }

      if (sectionId.isEmpty && (sectionCode.isNotEmpty || sectionName.isNotEmpty)) {
        final classRef = (classCode.isNotEmpty ? classCode : className).trim().toLowerCase();
        final codeOrName = (sectionCode.isNotEmpty ? sectionCode : sectionName).trim().toLowerCase();
        final sectionKey = '$ayId|$classRef|$codeOrName';
        if (!csvSections.containsKey(sectionKey)) {
          csvSections[sectionKey] = {
            'academic_year_id': ayId,
            'class_ref': classRef,
            'name': sectionName.isNotEmpty ? sectionName : sectionCode,
            'code': sectionCode.isNotEmpty ? sectionCode : sectionName,
          };
        }
      }
    }

    final failedClasses = <String>{};
    final failedSections = <String>{};

    // Create classes (Idempotent)
    for (final entry in csvClasses.entries) {
      final val = entry.value;
      final ayId = val['academic_year_id']!;
      final code = val['code']!;
      final name = val['name']!;

      final normalizedCode = code.trim().toLowerCase();
      final normalizedName = name.trim().toLowerCase();

      final sanitizedCode = sanitizeCode(code, minLength: 2);

      ClassDto? matched;
      for (final c in latestClasses) {
        if (c.academicYearId == ayId) {
          if (c.code.trim().toUpperCase() == sanitizedCode ||
              c.code.trim().toLowerCase() == normalizedCode ||
              c.name.trim().toLowerCase() == normalizedName) {
            matched = c;
            break;
          }
        }
      }

      final lookupKey = '$schoolId|$ayId|$normalizedCode';
      final lookupNameKey = '$schoolId|$ayId|$normalizedName';
      if (matched != null) {
        resolvedClassIds[lookupKey] = matched.id;
        resolvedClassIds[lookupNameKey] = matched.id;
        continue;
      }

      // Log Class Create Payload (excluding secrets)
      debugPrint('CLASS CREATE REQUEST: school_id=$schoolId, academic_year_id=$ayId, name=$name, code=$sanitizedCode, level=$defaultClassLevel, category=PRIMARY, capacity=$defaultClassCapacity, status=ACTIVE');

      final classPayload = {
        'school_id': schoolId,
        'academic_year_id': ayId,
        'name': name,
        'code': sanitizedCode,
        'level': defaultClassLevel,
        'category': 'PRIMARY',
        'capacity': defaultClassCapacity,
        'status': 'ACTIVE',
      };

      final createRes = await apiClient.post<dynamic>(
        '/classes',
        data: classPayload,
        mapper: (json) => json,
      );

      bool success = false;
      await createRes.when(
        onSuccess: (resp) {
          final payload = resp as Map<String, dynamic>;
          final data = payload['data'] as Map<String, dynamic>;
          final newId = data['id'] as String;
          resolvedClassIds[lookupKey] = newId;
          resolvedClassIds[lookupNameKey] = newId;
          createdClassIds.add(newId);
          success = true;
          latestClasses.add(ClassDto.fromJson(data));
        },
        onFailure: (failure) async {
          // Re-fetch class in case it was created concurrently
          final refetchRes = await apiClient.get(
            '/classes?school_id=$schoolId&academic_year_id=$ayId',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              final list = payload['data'] as List<dynamic>;
              return list.map((item) => ClassDto.fromJson(item as Map<String, dynamic>)).toList();
            },
          );
          refetchRes.when(
            onSuccess: (list) {
              latestClasses.clear();
              latestClasses.addAll(list);
            },
            onFailure: (_) {},
          );

          ClassDto? refetchedMatch;
          for (final c in latestClasses) {
            if (c.academicYearId == ayId) {
              if (c.code.trim().toUpperCase() == sanitizedCode ||
                  c.code.trim().toLowerCase() == normalizedCode ||
                  c.name.trim().toLowerCase() == normalizedName) {
                refetchedMatch = c;
                break;
              }
            }
          }
          if (refetchedMatch != null) {
            resolvedClassIds[lookupKey] = refetchedMatch.id;
            resolvedClassIds[lookupNameKey] = refetchedMatch.id;
            success = true;
          } else {
            failedClasses.add(lookupKey);
            failedClasses.add(lookupNameKey);
            final errorDetail = 'Class "$name" ($sanitizedCode) creation failed: ${failure.message}';
            dependencyErrorsList.add(errorDetail);
          }
        },
      );

      if (!success) {
        resolvedClassIds[lookupKey] = '';
        resolvedClassIds[lookupNameKey] = '';
      }
    }

    // Create sections (Idempotent)
    for (final entry in csvSections.entries) {
      final val = entry.value;
      final ayId = val['academic_year_id']!;
      final classRef = val['class_ref']!;
      final code = val['code']!;
      final name = val['name']!;

      final lookupClassKey = '$schoolId|$ayId|$classRef';
      final classId = resolvedClassIds[lookupClassKey] ?? '';

      final normalizedCode = code.trim().toLowerCase();
      final normalizedName = name.trim().toLowerCase();

      final lookupKey = '$schoolId|$ayId|$classId|$normalizedCode';
      final lookupNameKey = '$schoolId|$ayId|$classId|$normalizedName';

      if (classId.isEmpty || failedClasses.contains(lookupClassKey)) {
        failedSections.add(lookupKey);
        failedSections.add(lookupNameKey);
        final parentMsg = dependencyErrorsList.firstWhere(
          (err) => err.contains(classRef),
          orElse: () => 'Parent class "$classRef" could not be resolved.',
        );
        dependencyErrorsList.add('Section "$name" ($normalizedCode) blocked: parent class could not be resolved. Reason: $parentMsg');
        continue;
      }

      final sanitizedCode = sanitizeCode(code, minLength: 1);

      SectionDto? matched;
      for (final s in latestSections) {
        if (s.academicYearId == ayId && s.classId == classId) {
          if (s.code.trim().toUpperCase() == sanitizedCode ||
              s.code.trim().toLowerCase() == normalizedCode ||
              s.name.trim().toLowerCase() == normalizedName) {
            matched = s;
            break;
          }
        }
      }

      if (matched != null) {
        resolvedSectionIds[lookupKey] = matched.id;
        resolvedSectionIds[lookupNameKey] = matched.id;
        continue;
      }

      // Log Section Create Payload (excluding secrets)
      debugPrint('SECTION CREATE REQUEST: school_id=$schoolId, academic_year_id=$ayId, class_id=$classId, name=$name, code=$sanitizedCode, capacity=$defaultSectionCapacity, status=ACTIVE');

      final sectionPayload = {
        'school_id': schoolId,
        'academic_year_id': ayId,
        'class_id': classId,
        'name': name,
        'code': sanitizedCode,
        'capacity': defaultSectionCapacity,
        'sort_order': 1,
        'status': 'ACTIVE',
      };

      final createRes = await apiClient.post<dynamic>(
        '/sections',
        data: sectionPayload,
        mapper: (json) => json,
      );

      bool success = false;
      await createRes.when(
        onSuccess: (resp) {
          final payload = resp as Map<String, dynamic>;
          final data = payload['data'] as Map<String, dynamic>;
          final newId = data['id'] as String;
          resolvedSectionIds[lookupKey] = newId;
          resolvedSectionIds[lookupNameKey] = newId;
          createdSectionIds.add(newId);
          success = true;
          latestSections.add(SectionDto.fromJson(data));
        },
        onFailure: (failure) async {
          // Re-fetch section in case it was created concurrently
          final refetchRes = await apiClient.get(
            '/sections?school_id=$schoolId&academic_year_id=$ayId',
            mapper: (json) {
              final payload = json as Map<String, dynamic>;
              final list = payload['data'] as List<dynamic>;
              return list.map((item) => SectionDto.fromJson(item as Map<String, dynamic>)).toList();
            },
          );
          refetchRes.when(
            onSuccess: (list) {
              latestSections.clear();
              latestSections.addAll(list);
            },
            onFailure: (_) {},
          );

          SectionDto? refetchedMatch;
          for (final s in latestSections) {
            if (s.academicYearId == ayId && s.classId == classId) {
              if (s.code.trim().toUpperCase() == sanitizedCode ||
                  s.code.trim().toLowerCase() == normalizedCode ||
                  s.name.trim().toLowerCase() == normalizedName) {
                refetchedMatch = s;
                break;
              }
            }
          }
          if (refetchedMatch != null) {
            resolvedSectionIds[lookupKey] = refetchedMatch.id;
            resolvedSectionIds[lookupNameKey] = refetchedMatch.id;
            success = true;
          } else {
            failedSections.add(lookupKey);
            failedSections.add(lookupNameKey);
            final errorDetail = 'Section "$name" ($sanitizedCode) creation failed: ${failure.message}';
            dependencyErrorsList.add(errorDetail);
          }
        },
      );

      if (!success) {
        resolvedSectionIds[lookupKey] = '';
        resolvedSectionIds[lookupNameKey] = '';
      }
    }

    final List<ParsedRow> rebuiltRows = [];
    for (final row in state.rows) {
      final ayId = row.data['academic_year_id'] ?? '';
      if (ayId.isEmpty) {
        rebuiltRows.add(row);
        continue;
      }

      final classId = (row.data['class_id'] ?? '').trim();
      final className = (row.data['class_name'] ?? '').trim();
      final classCode = (row.data['class_code'] ?? '').trim();

      final sectionId = (row.data['section_id'] ?? '').trim();
      final sectionName = (row.data['section_name'] ?? '').trim();
      final sectionCode = (row.data['section_code'] ?? '').trim();

      String targetClassId = classId;
      final lookupClassKey = '$schoolId|$ayId|${(classCode.isNotEmpty ? classCode : className).trim().toLowerCase()}';
      if (targetClassId.isEmpty && (classCode.isNotEmpty || className.isNotEmpty)) {
        targetClassId = resolvedClassIds[lookupClassKey] ?? '';
      }

      String targetSectionId = sectionId;
      final lookupSectionKey = '$schoolId|$ayId|$targetClassId|${(sectionCode.isNotEmpty ? sectionCode : sectionName).trim().toLowerCase()}';
      if (targetSectionId.isEmpty && (sectionCode.isNotEmpty || sectionName.isNotEmpty) && targetClassId.isNotEmpty) {
        targetSectionId = resolvedSectionIds[lookupSectionKey] ?? '';
      }

      final updatedData = Map<String, String>.from(row.data);
      final List<String> updatedErrors = List.from(row.errors);
      ImportRowStatus updatedStatus = row.status;

      if (failedClasses.contains(lookupClassKey)) {
        updatedErrors.add('Class dependency could not be created.');
        updatedStatus = ImportRowStatus.dependencyError;
      } else if (failedSections.contains(lookupSectionKey)) {
        updatedErrors.add('Section dependency could not be created.');
        updatedStatus = ImportRowStatus.dependencyError;
      } else {
        if (targetClassId.isNotEmpty) {
          updatedData['class_id'] = targetClassId;
        }
        if (targetSectionId.isNotEmpty) {
          updatedData['section_id'] = targetSectionId;
        }
        // If both are resolved successfully, clear stale dependency errors!
        if (targetClassId.isNotEmpty && targetSectionId.isNotEmpty) {
          updatedErrors.removeWhere((e) =>
              e.contains('class_id') ||
              e.contains('section_id') ||
              e.contains('Class identifier') ||
              e.contains('Section identifier') ||
              e.contains('dependency') ||
              e.contains('resolution incomplete')
          );
          if (updatedStatus == ImportRowStatus.dependencyError) {
            updatedStatus = ImportRowStatus.valid;
          }
        }
      }

      rebuiltRows.add(row.copyWith(
        data: updatedData,
        errors: updatedErrors,
        status: updatedStatus,
      ));
    }

    final String? depErrorMsg = dependencyErrorsList.isNotEmpty
        ? 'Dependency preparation completed with failures.\nDetails:\n- ${dependencyErrorsList.join('\n- ')}'
        : null;

    state = state.copyWith(
      cachedClasses: latestClasses,
      cachedSections: latestSections,
      resolvedClassIds: resolvedClassIds,
      resolvedSectionIds: resolvedSectionIds,
      dependenciesPreparing: false,
      dependenciesReady: failedClasses.isEmpty && failedSections.isEmpty,
      dependencyError: depErrorMsg,
      rows: rebuiltRows,
      createdClassIds: createdClassIds,
      createdSectionIds: createdSectionIds,
    );

    _revalidateAndUpdateRows(rebuiltRows);
    if (createdClassIds.isNotEmpty || createdSectionIds.isNotEmpty) {
      _ref.invalidate(classesProvider(schoolId));
      _ref.invalidate(sectionsProvider(schoolId));
      await _ref.read(classesProvider(schoolId).notifier).fetchClasses();
      await _ref.read(sectionsProvider(schoolId).notifier).fetchSections();
    }
  }

  void skipConflictingRows() {
    final updatedRows = state.rows.map((row) {
      if (row.status == ImportRowStatus.duplicate) {
        return row.copyWith(
          status: ImportRowStatus.skipped,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(rows: updatedRows);
    _revalidateAndUpdateRows(updatedRows);
  }

  Future<void> fetchExistingStudentCounts(String schoolId) async {
    final apiClient = _ref.read(apiClientProvider);
    state = state.copyWith(
      existingSectionCounts: {},
      existingAdmissionNumbers: {},
      existingRollSectionKeys: {},
    );
    
    try {
      int skip = 0;
      final Map<String, int> counts = {};
      final Set<String> admissionNumbers = {};
      final Set<String> rollSectionKeys = {};
      while (true) {
        final result = await apiClient.get(
          '/students?school_id=$schoolId&limit=100&skip=$skip',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            final list = payload['data'] as List<dynamic>;
            return list.map((item) => StudentDto.fromJson(item as Map<String, dynamic>)).toList();
          },
        );
        
        final students = result.when(
          onSuccess: (list) => list,
          onFailure: (_) => <StudentDto>[],
        );
        
        if (students.isEmpty) break;
        
        for (final s in students) {
          counts[s.sectionId] = (counts[s.sectionId] ?? 0) + 1;
          if (s.admissionNumber.isNotEmpty) {
            admissionNumbers.add(s.admissionNumber);
          }
          if (s.rollNumber.isNotEmpty) {
            rollSectionKeys.add('${s.rollNumber}|${s.sectionId}');
          }
        }
        
        if (students.length < 100) break;
        skip += 100;
        
        if (skip >= 10000) break;
      }
      
      state = state.copyWith(
        existingSectionCounts: counts,
        existingAdmissionNumbers: admissionNumbers,
        existingRollSectionKeys: rollSectionKeys,
      );

      // Trigger instant re-validation using the fetched DB data
      if (state.rows.isNotEmpty && !state.isUploading && !state.isCompleted) {
        _revalidateAndUpdateRows(state.rows);
      }
    } catch (_) {
      // Keep empty if fails
    }
  }

  void resumeEditing() {
    final updatedRows = state.rows.map((row) {
      if (row.status == ImportRowStatus.skipped) {
        return row.copyWith(
          status: row.errors.isNotEmpty ? ImportRowStatus.error : ImportRowStatus.valid,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(
      isCompleted: false,
      isUploading: false,
      rows: updatedRows,
    );
  }

  void reset() {
    state = BulkImportState.initial();
  }
  Future<void> importRecords(String schoolId, BaseApiClient apiClient) async {
    if (state.isUploading || state.rows.isEmpty) return;

    final initialSchoolId = _ref.read(selectedSchoolIdProvider);
    if (initialSchoolId != schoolId) {
      state = state.copyWith(globalErrorMessage: 'School context mismatch. Import aborted.');
      return;
    }

    final List<ParsedRow> updatedRows = List.from(state.rows);
    
    // Convert initial non-importable rows (error, duplicate, capacityError, dependencyError) to skipped
    int initialSkippedCount = 0;
    for (int i = 0; i < updatedRows.length; i++) {
      final row = updatedRows[i];
      if (row.status == ImportRowStatus.error ||
          row.status == ImportRowStatus.duplicate ||
          row.status == ImportRowStatus.capacityError ||
          row.status == ImportRowStatus.dependencyError) {
        updatedRows[i] = row.copyWith(status: ImportRowStatus.skipped);
        initialSkippedCount++;
      } else if (row.status == ImportRowStatus.skipped) {
        initialSkippedCount++;
      }
    }

    state = state.copyWith(
      isUploading: true,
      globalErrorMessage: null,
      isCompleted: false,
      currentProgress: initialSkippedCount,
      totalProgress: updatedRows.length,
      successCount: 0,
      failedCount: 0,
      skippedCount: initialSkippedCount,
      rows: updatedRows,
    );

    int successes = 0;
    int failures = 0;
    int skippedCount = initialSkippedCount;
    bool hasGlobalError = false;
    String? globalErrorMsg;

    // Collect indices of rows to be imported (valid or warning)
    final List<int> processIndices = [];
    for (int i = 0; i < updatedRows.length; i++) {
      if (updatedRows[i].status == ImportRowStatus.valid || updatedRows[i].status == ImportRowStatus.warning) {
        processIndices.add(i);
      }
    }

    // Controlled concurrency worker pool (max 5 simultaneous requests)
    const int maxConcurrency = 5;
    int nextProcessIdx = 0;
    int activeRequests = 0;
    int maxObserved = 0;

    Future<void> worker() async {
      while (true) {
        if (!mounted || hasGlobalError) break;

        int i;
        if (nextProcessIdx >= processIndices.length) {
          break;
        }
        i = processIndices[nextProcessIdx++];

        final row = updatedRows[i];

        // Safety check: has school context changed DURING import?
        final currentSchoolId = _ref.read(selectedSchoolIdProvider);
        if (currentSchoolId != initialSchoolId) {
          hasGlobalError = true;
          globalErrorMsg = 'School context changed during active import. Queue stopped.';
          break;
        }

        final rowName = _resolveRowName(row, state.selectedType);
        state = state.copyWith(currentItemName: rowName);

        if (state.selectedType == ImportType.students) {
          final ayId = row.data['academic_year_id'] ?? '';
          final classId = row.data['class_id'] ?? '';
          final sectionId = row.data['section_id'] ?? '';

          final RegExp uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
          final isAyValid = uuidRegex.hasMatch(ayId);
          final isClassValid = uuidRegex.hasMatch(classId);
          final isSecValid = uuidRegex.hasMatch(sectionId);

          if (!isAyValid || !isClassValid || !isSecValid) {
            failures++;
            updatedRows[i] = row.copyWith(
              status: ImportRowStatus.dependencyError,
              errors: [...row.errors, 'Student dependency UUID resolution incomplete.'],
              apiErrorMessage: 'Dependency Error: Missing resolved UUIDs for academic year, class, or section.',
            );
            
            final completed = successes + failures + skippedCount;
            state = state.copyWith(
              currentProgress: completed,
              successCount: successes,
              failedCount: failures,
              skippedCount: skippedCount,
              rows: List.from(updatedRows),
            );
            continue;
          }
        }

        final data = _resolvePostData(row, state.selectedType, schoolId);
        final admissionNo = row.data['admission_number'] ?? 'N/A';
        final path = '/${state.selectedType.apiKey}';

        activeRequests++;
        if (activeRequests > maxObserved) {
          maxObserved = activeRequests;
        }
        // ignore: avoid_print
        print('[BULK CONCURRENCY] active=$activeRequests max=5 row=${i + 1}');

        try {
          // ignore: avoid_print
          print('[IMPORT POST START]\nURL: $path\nStudent: $rowName\nAdmission: $admissionNo');

          final ApiResult<dynamic> result = await apiClient.post<dynamic>(
            path,
            data: data,
            options: Options(
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'X-School-ID': schoolId,
              },
              extra: {'disable_retry': true},
            ),
            mapper: (json) => json,
          );

          result.when(
            onSuccess: (_) {
              // ignore: avoid_print
              print('[IMPORT POST RESULT]\nHTTP STATUS: 200/201 (SUCCESS)\nStudent: $rowName\nAdmission: $admissionNo');
              successes++;
              updatedRows[i] = row.copyWith(
                status: ImportRowStatus.success,
                apiErrorMessage: null,
              );
              // ignore: avoid_print
              print('[IMPORT SUCCESS] Student: $rowName | Admission: $admissionNo');
            },
            onFailure: (failure) {
              // ignore: avoid_print
              print('[IMPORT POST RESULT]\nHTTP STATUS: ${failure.statusCode}\nStudent: $rowName\nAdmission: $admissionNo');
              final classification = _classifyFailure(
                failure,
                row,
                rowName,
                admissionNo,
                dioExceptionType: failure.originalError is DioException
                    ? (failure.originalError as DioException).type.toString()
                    : null,
                requestUrl: path,
                rowNumber: i + 1,
                activeRequestCount: activeRequests,
                isRetry: false,
              );
              if (classification.isGlobal) {
                hasGlobalError = true;
                globalErrorMsg = classification.debugMessage;
              }
              if (classification.status == ImportRowStatus.alreadyExists) {
                skippedCount++;
              } else {
                failures++;
              }
              updatedRows[i] = row.copyWith(
                status: classification.status,
                apiErrorMessage: classification.userMessage,
              );
            },
          );
        } catch (e) {
          failures++;
          final timestamp = DateTime.now().toIso8601String();
          String? dioType;
          String? reqUrl = path;
          if (e is DioException) {
            dioType = e.type.toString();
            reqUrl = e.requestOptions.uri.toString();
          }
          final isTimeout = e.toString().toLowerCase().contains('timeout');
          final userMsg = isTimeout
              ? 'Connection timed out. Please check your connection and try again.'
              : 'Browser network/CORS connection failure';

          // ignore: avoid_print
          print('[IMPORT POST EXCEPTION] '
              'Timestamp: $timestamp | '
              'Row: ${i + 1} | '
              'Admission: $admissionNo | '
              'Student: $rowName | '
              'URL: $reqUrl | '
              'Exception: ${e.runtimeType} ($e) | '
              'DioExceptionType: ${dioType ?? "N/A"} | '
              'Active Requests: $activeRequests | '
              'State: INITIAL | '
              'Reason: $userMsg');

          updatedRows[i] = row.copyWith(
            status: ImportRowStatus.networkError,
            apiErrorMessage: userMsg,
          );
        } finally {
          activeRequests--;
        }

        // Live update Riverpod state after each completed student
        final completed = successes + failures + skippedCount;
        state = state.copyWith(
          currentProgress: completed,
          successCount: successes,
          failedCount: failures,
          skippedCount: skippedCount,
          rows: List.from(updatedRows),
        );
      }
    }

    final poolSize = (processIndices.length < maxConcurrency) ? processIndices.length : maxConcurrency;
    if (poolSize > 0) {
      final workers = List.generate(poolSize, (_) => worker());
      await Future.wait(workers);
    }

    // If queue stopped early due to global failure, mark rest of valid rows as skipped
    if (hasGlobalError) {
      for (int i = 0; i < updatedRows.length; i++) {
        if (updatedRows[i].status == ImportRowStatus.valid || updatedRows[i].status == ImportRowStatus.warning) {
          updatedRows[i] = updatedRows[i].copyWith(
            status: ImportRowStatus.skipped,
            apiErrorMessage: 'Aborted due to global import failure',
          );
          skippedCount++;
        }
      }
    }

    int finalSuccessful = 0;
    int finalNetworkErrors = 0;
    int finalApiErrors = 0;
    int finalAlreadyExists = 0;
    for (final r in updatedRows) {
      if (r.status == ImportRowStatus.success) finalSuccessful++;
      if (r.status == ImportRowStatus.networkError) finalNetworkErrors++;
      if (r.status == ImportRowStatus.apiError) finalApiErrors++;
      if (r.status == ImportRowStatus.alreadyExists) finalAlreadyExists++;
    }

    // ignore: avoid_print
    print('[BULK CONCURRENCY SUMMARY]\n'
        'maxObserved=$maxObserved\n'
        'totalRows=${updatedRows.length}\n'
        'successful=$finalSuccessful\n'
        'networkErrors=$finalNetworkErrors\n'
        'apiErrors=$finalApiErrors\n'
        'alreadyExists=$finalAlreadyExists');

    state = state.copyWith(
      isUploading: false,
      rows: updatedRows,
      currentProgress: successes + failures + skippedCount,
      successCount: successes,
      failedCount: failures,
      skippedCount: skippedCount,
      isCompleted: true,
      globalErrorMessage: globalErrorMsg,
    );

    // Invalidate list providers upon completion if any row succeeded
    if (successes > 0) {
      _invalidateRelevantProviders(schoolId);
    }
  }

  Future<void> retryNetworkFailures(String schoolId, [BaseApiClient? customClient]) async {
    if (state.isUploading || state.isRetrying || state.rows.isEmpty) return;

    final List<int> retryIndices = [];
    for (int i = 0; i < state.rows.length; i++) {
      if (state.rows[i].status == ImportRowStatus.networkError) {
        retryIndices.add(i);
      }
    }

    if (retryIndices.isEmpty) return;

    final apiClient = customClient ?? _ref.read(apiClientProvider);
    if (apiClient == null) {
      state = state.copyWith(
        isRetrying: false,
        globalErrorMessage: 'API client is not available.',
      );
      return;
    }
    final List<ParsedRow> updatedRows = List.from(state.rows);

    int retrySuccess = 0;
    int retryAlreadyExists = 0;
    int retryStillFailed = 0;
    int completedRetry = 0;

    state = state.copyWith(
      isRetrying: true,
      retryTotal: retryIndices.length,
      retryProgress: 0,
      retrySuccessCount: 0,
      retryAlreadyExistsCount: 0,
      retryStillFailedCount: 0,
      retryCurrentItemName: null,
      globalErrorMessage: null,
    );

    const int maxConcurrency = 5;
    int nextIdx = 0;
    int activeRequests = 0;
    int maxObserved = 0;
    bool hasGlobalError = false;
    String? globalErrorMsg;

    Future<void> retryWorker() async {
      while (true) {
        if (!mounted || hasGlobalError) break;
        int targetIdx;
        if (nextIdx >= retryIndices.length) break;
        targetIdx = retryIndices[nextIdx++];

        final row = updatedRows[targetIdx];
        final rowName = _resolveRowName(row, state.selectedType);
        state = state.copyWith(
          retryCurrentItemName: rowName,
        );

        final data = _resolvePostData(row, state.selectedType, schoolId);
        final admissionNo = row.data['admission_number'] ?? 'N/A';

        final path = '/${state.selectedType.apiKey}';

        activeRequests++;
        if (activeRequests > maxObserved) {
          maxObserved = activeRequests;
        }
        // ignore: avoid_print
        print('[BULK CONCURRENCY] active=$activeRequests max=5 row=${targetIdx + 1}');

        try {
          // ignore: avoid_print
          print('[IMPORT POST START]\nURL: $path\nStudent: $rowName\nAdmission: $admissionNo');

          final ApiResult<dynamic> result = await apiClient.post<dynamic>(
            path,
            data: data,
            options: Options(
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'X-School-ID': schoolId,
              },
              extra: {'disable_retry': true},
            ),
            mapper: (json) => json,
          );

          result.when(
            onSuccess: (_) {
              // ignore: avoid_print
              print('[IMPORT POST RESULT]\nHTTP STATUS: 200/201 (SUCCESS)\nStudent: $rowName\nAdmission: $admissionNo');
              retrySuccess++;
              updatedRows[targetIdx] = row.copyWith(
                status: ImportRowStatus.success,
                apiErrorMessage: null,
              );
              // ignore: avoid_print
              print('[IMPORT SUCCESS] Student: $rowName | Admission: $admissionNo');
            },
            onFailure: (failure) {
              // ignore: avoid_print
              print('[IMPORT POST RESULT]\nHTTP STATUS: ${failure.statusCode}\nStudent: $rowName\nAdmission: $admissionNo');
              final classification = _classifyFailure(
                failure,
                row,
                rowName,
                admissionNo,
                dioExceptionType: failure.originalError is DioException
                    ? (failure.originalError as DioException).type.toString()
                    : null,
                requestUrl: path,
                rowNumber: targetIdx + 1,
                activeRequestCount: activeRequests,
                isRetry: true,
              );
              if (classification.isGlobal) {
                hasGlobalError = true;
                globalErrorMsg = classification.debugMessage;
              }
              if (classification.status == ImportRowStatus.alreadyExists) {
                retryAlreadyExists++;
              } else {
                retryStillFailed++;
              }
              updatedRows[targetIdx] = row.copyWith(
                status: classification.status,
                apiErrorMessage: classification.userMessage,
              );
            },
          );
        } catch (e) {
          retryStillFailed++;
          final timestamp = DateTime.now().toIso8601String();
          String? dioType;
          String? reqUrl = path;
          if (e is DioException) {
            dioType = e.type.toString();
            reqUrl = e.requestOptions.uri.toString();
          }
          final isTimeout = e.toString().toLowerCase().contains('timeout');
          final userMsg = isTimeout
              ? 'Connection timed out. Please check your connection and try again.'
              : 'Browser network/CORS connection failure';

          // ignore: avoid_print
          print('[IMPORT POST EXCEPTION] '
              'Timestamp: $timestamp | '
              'Row: ${targetIdx + 1} | '
              'Admission: $admissionNo | '
              'Student: $rowName | '
              'URL: $reqUrl | '
              'Exception: ${e.runtimeType} ($e) | '
              'DioExceptionType: ${dioType ?? "N/A"} | '
              'Active Requests: $activeRequests | '
              'State: RETRY | '
              'Reason: $userMsg');

          updatedRows[targetIdx] = row.copyWith(
            status: ImportRowStatus.networkError,
            apiErrorMessage: userMsg,
          );
        } finally {
          activeRequests--;
        }

        completedRetry++;
        state = state.copyWith(
          retryProgress: completedRetry,
          retrySuccessCount: retrySuccess,
          retryAlreadyExistsCount: retryAlreadyExists,
          retryStillFailedCount: retryStillFailed,
          rows: List.from(updatedRows),
          successCount: updatedRows.where((r) => r.status == ImportRowStatus.success).length,
          failedCount: updatedRows.where((r) => r.status == ImportRowStatus.networkError || r.status == ImportRowStatus.apiError || r.status == ImportRowStatus.failed).length,
          skippedCount: updatedRows.where((r) => r.status == ImportRowStatus.skipped || r.status == ImportRowStatus.alreadyExists).length,
        );
      }
    }

    final poolSize = (retryIndices.length < maxConcurrency) ? retryIndices.length : maxConcurrency;
    if (poolSize > 0) {
      final workers = List.generate(poolSize, (_) => retryWorker());
      await Future.wait(workers);
    }

    int finalSuccessful = 0;
    int finalNetworkErrors = 0;
    int finalApiErrors = 0;
    int finalAlreadyExists = 0;
    for (final r in updatedRows) {
      if (r.status == ImportRowStatus.success) finalSuccessful++;
      if (r.status == ImportRowStatus.networkError) finalNetworkErrors++;
      if (r.status == ImportRowStatus.apiError) finalApiErrors++;
      if (r.status == ImportRowStatus.alreadyExists) finalAlreadyExists++;
    }

    // ignore: avoid_print
    print('[BULK CONCURRENCY SUMMARY]\n'
        'maxObserved=$maxObserved\n'
        'totalRows=${updatedRows.length}\n'
        'successful=$finalSuccessful\n'
        'networkErrors=$finalNetworkErrors\n'
        'apiErrors=$finalApiErrors\n'
        'alreadyExists=$finalAlreadyExists');

    state = state.copyWith(
      isRetrying: false,
      rows: updatedRows,
      successCount: updatedRows.where((r) => r.status == ImportRowStatus.success).length,
      failedCount: updatedRows.where((r) => r.status == ImportRowStatus.networkError || r.status == ImportRowStatus.apiError || r.status == ImportRowStatus.failed).length,
      skippedCount: updatedRows.where((r) => r.status == ImportRowStatus.skipped || r.status == ImportRowStatus.alreadyExists).length,
      globalErrorMessage: globalErrorMsg,
    );

    if (retrySuccess > 0) {
      _invalidateRelevantProviders(schoolId);
    }
  }

  ImportFailureClassification _classifyFailure(
    ApiFailure failure,
    ParsedRow row,
    String rowName,
    String admissionNo, {
    required String? dioExceptionType,
    required String requestUrl,
    required int rowNumber,
    required int activeRequestCount,
    required bool isRetry,
  }) {
    final msgLower = failure.message.toLowerCase();
    final isTimeout = (failure.type == ApiFailureType.network || failure.statusCode == null) &&
        (msgLower.contains('timed out') ||
         msgLower.contains('timeout') ||
         msgLower.contains('connectiontimeout') ||
         msgLower.contains('sendtimeout') ||
         msgLower.contains('receivetimeout'));

    // 1. Explicit Network / Connectivity Failure
    if (failure.type == ApiFailureType.network ||
        msgLower.contains('no internet') ||
        msgLower.contains('socketexception') ||
        msgLower.contains('connection refused') ||
        msgLower.contains('connection closed') ||
        msgLower.contains('connection error') ||
        msgLower.contains('connectionerror') ||
        msgLower.contains('handshakeexception') ||
        msgLower.contains('network error') ||
        (failure.statusCode == null && isTimeout)) {
      final userMsg = isTimeout
          ? 'Connection timed out. Please check your connection and try again.'
          : 'Browser network/CORS connection failure';
      final timestamp = DateTime.now().toIso8601String();
      final retryStateStr = isRetry ? 'RETRY' : 'INITIAL';
      final debugMsg = '[IMPORT NETWORK_ERROR] '
          'Timestamp: $timestamp | '
          'Row: $rowNumber | '
          'Admission: $admissionNo | '
          'Student: $rowName | '
          'URL: $requestUrl | '
          'DioExceptionType: ${dioExceptionType ?? "N/A"} | '
          'Active Requests: $activeRequestCount | '
          'State: $retryStateStr | '
          'Reason: $userMsg | '
          'Technical: ${failure.message}';
      // ignore: avoid_print
      print(debugMsg);
      return ImportFailureClassification(
        status: ImportRowStatus.networkError,
        userMessage: userMsg,
        debugMessage: debugMsg,
        isGlobal: _isGlobalFailure(failure),
      );
    }

    // 2. HTTP 409 Conflict / Already Exists
    if (failure.statusCode == 409) {
      final isAdmissionSpecific = msgLower.contains('admission_number') ||
          msgLower.contains('admission number') ||
          msgLower.contains('already exists');
      final userMsg = isAdmissionSpecific
          ? 'Student with admission number already exists.'
          : 'Student already exists or conflicts with an existing record.';
      final debugMsg = '[IMPORT ALREADY_EXISTS] Student: $rowName | Admission: $admissionNo | Reason: $userMsg';
      // ignore: avoid_print
      print(debugMsg);
      return ImportFailureClassification(
        status: ImportRowStatus.alreadyExists,
        userMessage: userMsg,
        debugMessage: debugMsg,
      );
    }

    // 3. HTTP Server / API Rejection (400, 401, 403, 404, 422, 500, 502, 503)
    if (failure.statusCode != null) {
      String sectionSuffix = '';
      final secId = row.data['section_id'];
      if (secId != null && secId.isNotEmpty) {
        final schoolId = _ref.read(selectedSchoolIdProvider);
        if (schoolId != null) {
          final sectionsState = _ref.read(sectionsProvider(schoolId));
          SectionDto? matchedSec;
          for (final s in sectionsState.sections) {
            if (s.id == secId) {
              matchedSec = s;
              break;
            }
          }
          if (matchedSec != null) {
            sectionSuffix = ' (Section: ${matchedSec.name})';
          }
        }
      }

      String userMsg;
      if (failure.statusCode == 500) {
        userMsg = 'Server error while importing this student.';
      } else if (failure.statusCode == 422) {
        userMsg = failure.message.isNotEmpty ? '${failure.message}$sectionSuffix' : 'Validation failed on server.';
      } else {
        userMsg = 'HTTP ${failure.statusCode}: ${failure.message}$sectionSuffix';
      }

      final isGlobal = _isGlobalFailure(failure);
      final debugMsg = '[IMPORT API_ERROR] Student: $rowName | Admission: $admissionNo | HTTP Status: ${failure.statusCode} | Reason: $userMsg';
      // ignore: avoid_print
      print(debugMsg);
      return ImportFailureClassification(
        status: ImportRowStatus.apiError,
        userMessage: userMsg,
        debugMessage: debugMsg,
        isGlobal: isGlobal,
      );
    }

    // 4. Unknown client-side or unclassified failure without status code
    final userMsg = failure.message.isNotEmpty ? failure.message : 'Unknown import error occurred.';
    final debugMsg = '[IMPORT API_ERROR] Student: $rowName | Admission: $admissionNo | Reason: $userMsg';
    // ignore: avoid_print
    print(debugMsg);
    return ImportFailureClassification(
      status: ImportRowStatus.apiError,
      userMessage: userMsg,
      debugMessage: debugMsg,
    );
  }

  String _resolveRowName(ParsedRow row, ImportType type) {
    if (type == ImportType.students || type == ImportType.guardians) {
      final first = row.data['first_name'] ?? '';
      final last = row.data['last_name'] ?? '';
      return '$first $last'.trim();
    } else if (type == ImportType.classes || type == ImportType.sections) {
      return row.data['name'] ?? 'Row ${row.rowIndex}';
    } else {
      return row.data['subject_name'] ?? 'Row ${row.rowIndex}';
    }
  }

  Map<String, dynamic> _resolvePostData(ParsedRow row, ImportType type, String schoolId) {
    switch (type) {
      case ImportType.students:
        final rawAddress = row.data['address'] ?? '';
        final payload = <String, dynamic>{
          'first_name': row.data['first_name'],
          'last_name': row.data['last_name'],
          'gender': row.data['gender']?.toUpperCase(),
          'date_of_birth': row.data['date_of_birth'],
          'admission_number': row.data['admission_number'],
          'roll_number': row.data['roll_number'],
          'admission_date': row.data['admission_date'],
          'school_id': schoolId,
          'academic_year_id': row.data['academic_year_id'],
          'class_id': row.data['class_id'],
          'section_id': row.data['section_id'],
          'address': rawAddress.isNotEmpty ? {'line': rawAddress} : <String, dynamic>{},
          'medical_information': <String, dynamic>{},
          'status': row.data['status']?.toUpperCase() ?? 'ACTIVE',
        };

        final optionalFields = {
          'middle_name': row.data['middle_name'],
          'blood_group': row.data['blood_group'],
          'aadhaar_number': row.data['aadhaar_number'],
          'emis_number': row.data['emis_number'],
          'mobile': row.data['mobile'] ?? row.data['phone'],
          'email': row.data['email'],
          'photo_url': row.data['photo_url'],
        };

        optionalFields.forEach((key, value) {
          final sanitized = sanitizeOptionalString(value);
          if (sanitized != null) {
            payload[key] = sanitized;
          }
        });

        return payload;
      case ImportType.guardians:
        return {
          'guardian_type': row.data['guardian_type']?.toUpperCase(),
          'first_name': row.data['first_name'],
          'middle_name': row.data['middle_name'],
          'last_name': row.data['last_name'],
          'gender': row.data['gender']?.toUpperCase(),
          'date_of_birth': row.data['date_of_birth'],
          'aadhaar_number': row.data['aadhaar_number'],
          'pan_number': row.data['pan_number']?.toUpperCase(),
          'occupation': row.data['occupation'],
          'qualification': row.data['qualification'],
          'organization': row.data['organization'],
          'annual_income': row.data['annual_income'] != null ? double.tryParse(row.data['annual_income']!) : null,
          'mobile': row.data['mobile'],
          'alternate_mobile': row.data['alternate_mobile'],
          'email': row.data['email'],
          'school_id': schoolId,
          'address': {},
          'communication_preferences': {},
        };
      case ImportType.classes:
        return {
          'name': row.data['name'],
          'display_name': row.data['display_name'],
          'code': row.data['code']?.toUpperCase(),
          'level': int.tryParse(row.data['level'] ?? '0') ?? 0,
          'category': (row.data['category'] ?? 'PRIMARY').toUpperCase(),
          'stream': row.data['stream'],
          'description': row.data['description'],
          'capacity': int.tryParse(row.data['capacity'] ?? '40') ?? 40,
          'promotion_order': row.data['promotion_order'] != null ? int.tryParse(row.data['promotion_order']!) : null,
          'next_class_id': row.data['next_class_id'],
          'school_id': schoolId,
          'academic_year_id': row.data['academic_year_id'],
          'settings': {},
          'ai_metrics': {},
        };
      case ImportType.sections:
        return {
          'name': row.data['name'],
          'code': row.data['code']?.toUpperCase(),
          'capacity': int.tryParse(row.data['capacity'] ?? '40') ?? 40,
          'room_number': row.data['room_number'],
          'sort_order': int.tryParse(row.data['sort_order'] ?? '1') ?? 1,
          'description': row.data['description'],
          'class_id': row.data['class_id'],
          'school_id': schoolId,
          'academic_year_id': row.data['academic_year_id'],
          'settings': {},
          'ai_metrics': {},
        };
      case ImportType.subjects:
        return {
          'subject_code': row.data['subject_code']?.toUpperCase(),
          'subject_name': row.data['subject_name'],
          'short_name': row.data['short_name'],
          'category': (row.data['category'] ?? 'CORE').toUpperCase(),
          'subject_type': (row.data['subject_type'] ?? 'THEORY').toUpperCase(),
          'description': row.data['description'],
          'credit_hours': row.data['credit_hours'] != null ? int.tryParse(row.data['credit_hours']!) : null,
          'weekly_periods': row.data['weekly_periods'] != null ? int.tryParse(row.data['weekly_periods']!) : null,
          'theory_marks': int.tryParse(row.data['theory_marks'] ?? '0') ?? 0,
          'practical_marks': int.tryParse(row.data['practical_marks'] ?? '0') ?? 0,
          'pass_marks': int.tryParse(row.data['pass_marks'] ?? '0') ?? 0,
          'display_color': row.data['display_color'],
          'display_order': row.data['display_order'] != null ? int.tryParse(row.data['display_order']!) : null,
          'school_id': schoolId,
          'academic_year_id': row.data['academic_year_id'],
          'settings': {},
          'ai_metrics': {},
        };
    }
  }

  bool _isGlobalFailure(ApiFailure failure) {
    if (failure.statusCode == 401 || failure.statusCode == 403 || failure.statusCode == 503) {
      return true;
    }
    return false;
  }

  void _invalidateRelevantProviders(String schoolId) {
    switch (state.selectedType) {
      case ImportType.students:
        _ref.invalidate(studentListProvider);
        break;
      case ImportType.guardians:
        // Invalidates related student guardians lists
        break;
      case ImportType.classes:
        _ref.invalidate(classesProvider(schoolId));
        break;
      case ImportType.sections:
        _ref.invalidate(sectionsProvider(schoolId));
        break;
      case ImportType.subjects:
        _ref.invalidate(subjectsProvider(schoolId));
        break;
    }
  }

  Future<void> updateCell(int rowIndex, String columnName, String newValue) async {
    if (state.isUploading) return;

    final updatedRows = state.rows.map((row) {
      if (row.rowIndex == rowIndex) {
        final newOriginalData = Map<String, String>.from(row.originalData);
        final newEditedFields = Set<String>.from(row.editedFields);

        if (!newOriginalData.containsKey(columnName)) {
          newOriginalData[columnName] = row.data[columnName] ?? '';
        }
        newEditedFields.add(columnName);

        final newData = Map<String, String>.from(row.data);
        newData[columnName] = newValue;

        if (columnName == 'class_id') {
          final matched = state.cachedClasses.firstWhere((c) => c.id == newValue, orElse: () => const ClassDto(id: '', tenantId: '', schoolId: '', academicYearId: '', name: '', code: '', level: 1, category: '', capacity: 40, status: '', isActive: true, version: 1));
          if (matched.id.isNotEmpty) {
            newData['class_name'] = matched.name;
            newData['class_code'] = matched.code;
          }
        } else if (columnName == 'section_id') {
          final matched = state.cachedSections.firstWhere((s) => s.id == newValue, orElse: () => const SectionDto(id: '', tenantId: '', schoolId: '', academicYearId: '', classId: '', name: '', code: '', capacity: 40, sortOrder: 1, status: '', isActive: true, version: 1));
          if (matched.id.isNotEmpty) {
            newData['section_name'] = matched.name;
            newData['section_code'] = matched.code;
          }
        } else if (columnName == 'class_name' || columnName == 'class_code') {
          newData['class_id'] = '';
          newData['section_id'] = '';
        } else if (columnName == 'section_name' || columnName == 'section_code') {
          newData['section_id'] = '';
        }

        return row.copyWith(
          data: newData,
          editedFields: newEditedFields,
          originalData: newOriginalData,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(rows: updatedRows);

    if (state.selectedType == ImportType.students &&
        (columnName == 'class_name' ||
            columnName == 'class_code' ||
            columnName == 'section_name' ||
            columnName == 'section_code')) {
      state = state.copyWith(
        dependenciesDirty: true,
        dependenciesReady: false,
      );
      await checkDependencies(updatedRows);
      if (!mounted) return;
      _revalidateAndUpdateRows(state.rows);
    } else if (state.selectedType == ImportType.students &&
        (columnName == 'class_id' || columnName == 'section_id')) {
      await checkDependencies(updatedRows);
      if (!mounted) return;
      _revalidateAndUpdateRows(state.rows);
    } else {
      _revalidateAndUpdateRows(updatedRows);
    }
  }

  void updateSelectedRows(List<int> rowIndices, String columnName, String newValue) {
    if (state.isUploading) return;

    final updatedRows = state.rows.map((row) {
      if (rowIndices.contains(row.rowIndex)) {
        final newOriginalData = Map<String, String>.from(row.originalData);
        final newEditedFields = Set<String>.from(row.editedFields);

        if (!newOriginalData.containsKey(columnName)) {
          newOriginalData[columnName] = row.data[columnName] ?? '';
        }
        newEditedFields.add(columnName);

        final newData = Map<String, String>.from(row.data);
        newData[columnName] = newValue;

        return row.copyWith(
          data: newData,
          editedFields: newEditedFields,
          originalData: newOriginalData,
        );
      }
      return row;
    }).toList();

    _revalidateAndUpdateRows(updatedRows);
  }

  Map<int, String> suggestRollNumbers() {
    final suggestions = <int, String>{};
    if (state.selectedType != ImportType.students) return suggestions;

    final sectionActiveRolls = <String, Set<String>>{};

    // 1. Initialize with existing DB roll numbers
    for (final key in state.existingRollSectionKeys) {
      final parts = key.split('|');
      if (parts.length == 2) {
        final roll = parts[0];
        final secId = parts[1];
        sectionActiveRolls.putIfAbsent(secId, () => {}).add(roll);
      }
    }

    // 2. Initialize with CSV roll numbers for rows that do NOT have duplicate errors
    for (final row in state.rows) {
      final secId = row.data['section_id'] ?? '';
      final roll = row.data['roll_number'] ?? '';
      final hasDuplicateError = row.errors.any((err) =>
          err.toLowerCase().contains('duplicate') ||
          err.toLowerCase().contains('already exists'));

      if (secId.isNotEmpty && roll.isNotEmpty && !hasDuplicateError) {
        sectionActiveRolls.putIfAbsent(secId, () => {}).add(roll);
      }
    }

    // 3. Suggest roll numbers
    for (final row in state.rows) {
      final secId = row.data['section_id'] ?? '';
      final roll = row.data['roll_number'] ?? '';
      final hasDuplicateError = row.errors.any((err) =>
          err.toLowerCase().contains('duplicate') ||
          err.toLowerCase().contains('already exists') &&
          err.toLowerCase().contains('roll number'));

      if (secId.isNotEmpty && roll.isNotEmpty && hasDuplicateError) {
        final activeSet = sectionActiveRolls.putIfAbsent(secId, () => {});
        int candidate = 1;
        while (activeSet.contains(candidate.toString())) {
          candidate++;
        }
        suggestions[row.rowIndex] = candidate.toString();
        activeSet.add(candidate.toString());
      }
    }

    return suggestions;
  }

  void _revalidateAndUpdateRows(List<ParsedRow> updatedRows) {
    if (updatedRows.isEmpty) return;

    final firstRow = updatedRows.first;
    final headers = firstRow.data.keys.toList();

    final List<List<String>> csvRows = [];
    csvRows.add(headers);
    for (final r in updatedRows) {
      final List<String> rawRow = [];
      for (final h in headers) {
        rawRow.add(r.data[h] ?? '');
      }
      csvRows.add(rawRow);
    }

    final newValidated = CsvHelper.validateCsv(
      csvRows,
      state.selectedType,
      existingAdmissionNumbers: state.existingAdmissionNumbers,
      existingRollSectionKeys: state.existingRollSectionKeys,
    );

    final schoolId = _ref.read(selectedSchoolIdProvider);
    final sectionsState = schoolId != null ? _ref.read(sectionsProvider(schoolId)) : null;
    final sections = sectionsState?.sections ?? <SectionDto>[];

    final merged = newValidated.map((newRow) {
      final prevRow = updatedRows.firstWhere(
        (r) => r.rowIndex == newRow.rowIndex,
        orElse: () => newRow,
      );
      final isTerminal = prevRow.status == ImportRowStatus.skipped ||
          prevRow.status == ImportRowStatus.success ||
          prevRow.status == ImportRowStatus.failed;

      if (isTerminal) {
        return newRow.copyWith(
          editedFields: prevRow.editedFields,
          originalData: prevRow.originalData,
          errors: prevRow.errors,
          status: prevRow.status,
        );
      }

      final List<String> mergedErrors = List.from(newRow.errors);
      ImportRowStatus mergedStatus = newRow.status;

      final dependencyErrors = prevRow.errors.where((err) =>
          err.contains('dependency') ||
          err.contains('does not exist for this school') ||
          err.contains('resolution incomplete')
      ).toList();

      final classId = (newRow.data['class_id'] ?? '').trim();
      final sectionId = (newRow.data['section_id'] ?? '').trim();
      final RegExp uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

      final hasClassId = uuidRegex.hasMatch(classId);
      final hasSectionId = uuidRegex.hasMatch(sectionId);

      if (!hasClassId) {
        final classDepErrors = dependencyErrors.where((err) => err.toLowerCase().contains('class') || err.contains('academic')).toList();
        for (final err in classDepErrors) {
          if (!mergedErrors.contains(err)) mergedErrors.add(err);
        }
      }

      if (!hasSectionId) {
        final secDepErrors = dependencyErrors.where((err) => err.toLowerCase().contains('section')).toList();
        for (final err in secDepErrors) {
          if (!mergedErrors.contains(err)) mergedErrors.add(err);
        }
      }

      final hasActiveDepErrors = mergedErrors.any((err) =>
          err.contains('dependency') ||
          err.contains('does not exist for this school') ||
          err.contains('resolution incomplete')
      );

      if (hasActiveDepErrors) {
        mergedStatus = ImportRowStatus.dependencyError;
      }

      return newRow.copyWith(
        editedFields: prevRow.editedFields,
        originalData: prevRow.originalData,
        errors: mergedErrors,
        status: mergedStatus,
      );
    }).toList();

    // Capacity checking
    if (state.selectedType == ImportType.students && sections.isNotEmpty) {
      final incomingCounts = <String, int>{};
      for (final r in merged) {
        if (r.status != ImportRowStatus.success && r.status != ImportRowStatus.skipped) {
          final sId = r.data['section_id'] ?? '';
          if (sId.isNotEmpty) {
            incomingCounts[sId] = (incomingCounts[sId] ?? 0) + 1;
          }
        }
      }

      for (int i = 0; i < merged.length; i++) {
        final row = merged[i];
        final secId = row.data['section_id'] ?? '';
        if (secId.isNotEmpty) {
          SectionDto? matchedSec;
          for (final s in sections) {
            if (s.id == secId) {
              matchedSec = s;
              break;
            }
          }

          if (matchedSec != null) {
            final existing = state.existingSectionCounts[secId] ?? 0;
            final incoming = incomingCounts[secId] ?? 0;
            final capacity = matchedSec.capacity;
            final projected = existing + incoming;
            if (projected > capacity) {
              final available = capacity - existing;
              final updatedErrors = List<String>.from(row.errors);
              updatedErrors.add(
                'Section ${matchedSec.name} capacity exceeded. Capacity: $capacity, Current students: $existing, Available seats: $available, Import rows assigned: $incoming'
              );
              merged[i] = row.copyWith(
                errors: updatedErrors,
                status: ImportRowStatus.capacityError,
              );
            }
          }
        }
      }
    }

    String? globalErr = state.globalErrorMessage;
    if (merged.length == 1 && merged.first.data.isEmpty && merged.first.errors.isNotEmpty) {
      globalErr = merged.first.errors.join(', ');
    } else {
      globalErr = null;
    }

    state = state.copyWith(
      rows: merged,
      globalErrorMessage: globalErr,
    );
  }
}

final bulkImportProvider = StateNotifierProvider<BulkImportNotifier, BulkImportState>((ref) {
  return BulkImportNotifier(ref);
});

String? sanitizeOptionalString(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}
