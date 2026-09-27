import 'package:equatable/equatable.dart';

class TimetableEntryEntity extends Equatable {
  final String id;
  final String dayOfWeek;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String periodType;
  final String? roomId;
  final bool isAvailable;
  
  final String classId;
  final String className;
  
  final String sectionId;
  final String sectionName;
  
  final String? subjectId;
  final String subjectName;
  final String subjectCode;
  final String? displayColor;
  final String? plannedTopic;
  final bool isRecovery;
  final String? recoveryType;
  final String? recoveryLabel;
  final String? primaryTeacherName;
  final String? supportTeacherName;

  const TimetableEntryEntity({
    required this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.periodType,
    this.roomId,
    required this.isAvailable,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    this.displayColor,
    this.plannedTopic,
    this.isRecovery = false,
    this.recoveryType,
    this.recoveryLabel,
    this.primaryTeacherName,
    this.supportTeacherName,
  });

  @override
  List<Object?> get props => [
        id,
        dayOfWeek,
        periodNumber,
        startTime,
        endTime,
        periodType,
        roomId,
        isAvailable,
        classId,
        className,
        sectionId,
        sectionName,
        subjectId,
        subjectName,
        subjectCode,
        displayColor,
        plannedTopic,
        isRecovery,
        recoveryType,
        recoveryLabel,
        primaryTeacherName,
        supportTeacherName,
      ];
}
