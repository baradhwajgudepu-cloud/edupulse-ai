import 'package:flutter/foundation.dart';

@immutable
class ImportJobDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String importType;
  final String status;
  final String sourceFilename;
  final String? fileChecksum;
  final int totalRows;
  final int processedRows;
  final int successfulRows;
  final int failedRows;
  final int skippedRows;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorSummary;
  final Map<String, dynamic> jobMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const ImportJobDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.importType,
    required this.status,
    required this.sourceFilename,
    this.fileChecksum,
    required this.totalRows,
    required this.processedRows,
    required this.successfulRows,
    required this.failedRows,
    required this.skippedRows,
    this.startedAt,
    this.completedAt,
    this.errorSummary,
    required this.jobMetadata,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory ImportJobDto.fromJson(Map<String, dynamic> json) {
    return ImportJobDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      importType: json['import_type'] as String? ?? 'STUDENTS',
      status: json['status'] as String? ?? 'DRAFT',
      sourceFilename: json['source_filename'] as String? ?? '',
      fileChecksum: json['file_checksum'] as String?,
      totalRows: json['total_rows'] as int? ?? 0,
      processedRows: json['processed_rows'] as int? ?? 0,
      successfulRows: json['successful_rows'] as int? ?? 0,
      failedRows: json['failed_rows'] as int? ?? 0,
      skippedRows: json['skipped_rows'] as int? ?? 0,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      errorSummary: json['error_summary'] as String?,
      jobMetadata: json['job_metadata'] != null ? Map<String, dynamic>.from(json['job_metadata'] as Map) : <String, dynamic>{},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }
}

@immutable
class ImportJobRowDto {
  final String id;
  final String importJobId;
  final int rowNumber;
  final String status;
  final String? errorCode;
  final String? errorMessage;
  final String? sourceIdentifier;
  final String? entityId;
  final Map<String, dynamic> rowMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ImportJobRowDto({
    required this.id,
    required this.importJobId,
    required this.rowNumber,
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.sourceIdentifier,
    this.entityId,
    required this.rowMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ImportJobRowDto.fromJson(Map<String, dynamic> json) {
    return ImportJobRowDto(
      id: json['id'] as String,
      importJobId: json['import_job_id'] as String,
      rowNumber: json['row_number'] as int? ?? 0,
      status: json['status'] as String? ?? 'failed',
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      sourceIdentifier: json['source_identifier'] as String?,
      entityId: json['entity_id'] as String?,
      rowMetadata: json['row_metadata'] != null ? Map<String, dynamic>.from(json['row_metadata'] as Map) : <String, dynamic>{},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
