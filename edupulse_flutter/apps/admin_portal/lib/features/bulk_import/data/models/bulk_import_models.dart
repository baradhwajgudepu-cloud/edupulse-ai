enum ImportSeverity {
  valid,
  warning,
  error,
}

enum ImportRowStatus {
  valid,
  warning,
  error,
  duplicate,
  capacityError,
  dependencyError,
  success,
  failed,
  skipped,
  networkError,
  alreadyExists,
  apiError,
  validationError,
}

class ParsedRow {
  final int rowIndex;
  final Map<String, String> data;
  final List<String> errors;
  final List<String> warnings;
  final ImportRowStatus status;
  final String? apiErrorMessage;
  final Set<String> editedFields;
  final Map<String, String> originalData;

  ParsedRow({
    required this.rowIndex,
    required this.data,
    required this.errors,
    required this.warnings,
    required this.status,
    this.apiErrorMessage,
    this.editedFields = const {},
    this.originalData = const {},
  });

  ParsedRow copyWith({
    int? rowIndex,
    Map<String, String>? data,
    List<String>? errors,
    List<String>? warnings,
    ImportRowStatus? status,
    String? apiErrorMessage,
    Set<String>? editedFields,
    Map<String, String>? originalData,
  }) {
    return ParsedRow(
      rowIndex: rowIndex ?? this.rowIndex,
      data: data ?? this.data,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      status: status ?? this.status,
      apiErrorMessage: apiErrorMessage ?? this.apiErrorMessage,
      editedFields: editedFields ?? this.editedFields,
      originalData: originalData ?? this.originalData,
    );
  }
}

enum ImportType {
  students('Students', 'students'),
  guardians('Guardians', 'guardians'),
  classes('Classes / Grade Levels', 'classes'),
  sections('Sections & Rooms', 'sections'),
  subjects('Subject Catalog', 'subjects');

  final String label;
  final String apiKey;
  const ImportType(this.label, this.apiKey);
}

class ImportFailureClassification {
  final ImportRowStatus status;
  final String userMessage;
  final String debugMessage;
  final bool isGlobal;

  const ImportFailureClassification({
    required this.status,
    required this.userMessage,
    required this.debugMessage,
    this.isGlobal = false,
  });
}
