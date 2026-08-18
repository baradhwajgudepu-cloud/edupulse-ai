// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_card_preview_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReportCardSubjectMarkRowDtoImpl _$$ReportCardSubjectMarkRowDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$ReportCardSubjectMarkRowDtoImpl(
      subjectName: json['subject_name'] as String,
      maximumMarks: (json['maximum_marks'] as num).toInt(),
      marksObtained: (json['marks_obtained'] as num?)?.toDouble(),
      resultStatus: json['result_status'] as String,
      grade: json['grade'] as String,
      remarks: json['remarks'] as String?,
    );

Map<String, dynamic> _$$ReportCardSubjectMarkRowDtoImplToJson(
        _$ReportCardSubjectMarkRowDtoImpl instance) =>
    <String, dynamic>{
      'subject_name': instance.subjectName,
      'maximum_marks': instance.maximumMarks,
      'marks_obtained': instance.marksObtained,
      'result_status': instance.resultStatus,
      'grade': instance.grade,
      'remarks': instance.remarks,
    };

_$ReportCardPreviewDtoImpl _$$ReportCardPreviewDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$ReportCardPreviewDtoImpl(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      admissionNumber: json['admission_number'] as String,
      rollNumber: json['roll_number'] as String,
      className: json['class_name'] as String,
      sectionName: json['section_name'] as String,
      attendanceTotal: (json['attendance_total'] as num).toInt(),
      attendancePresent: (json['attendance_present'] as num).toInt(),
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
      overallPercentage: (json['overall_percentage'] as num).toDouble(),
      overallGrade: json['overall_grade'] as String,
      promotionStatus: json['promotion_status'] as String,
      subjectMarks: (json['subject_marks'] as List<dynamic>)
          .map((e) =>
              ReportCardSubjectMarkRowDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      teacherRemarks: json['teacher_remarks'] as String?,
      principalRemarks: json['principal_remarks'] as String?,
      aiNarrative: json['ai_narrative'] as String,
      isValid: json['is_valid'] as bool,
      missingReasons: (json['missing_reasons'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$ReportCardPreviewDtoImplToJson(
        _$ReportCardPreviewDtoImpl instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'student_name': instance.studentName,
      'admission_number': instance.admissionNumber,
      'roll_number': instance.rollNumber,
      'class_name': instance.className,
      'section_name': instance.sectionName,
      'attendance_total': instance.attendanceTotal,
      'attendance_present': instance.attendancePresent,
      'attendance_percentage': instance.attendancePercentage,
      'overall_percentage': instance.overallPercentage,
      'overall_grade': instance.overallGrade,
      'promotion_status': instance.promotionStatus,
      'subject_marks': instance.subjectMarks,
      'teacher_remarks': instance.teacherRemarks,
      'principal_remarks': instance.principalRemarks,
      'ai_narrative': instance.aiNarrative,
      'is_valid': instance.isValid,
      'missing_reasons': instance.missingReasons,
    };
