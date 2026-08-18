import 'package:equatable/equatable.dart';
import 'teacher_profile.dart';
import 'academic_year.dart';
import 'timetable_entry.dart';

class DashboardDataEntity extends Equatable {
  final TeacherProfileEntity teacherProfile;
  final AcademicYearEntity academicYear;
  final List<TimetableEntryEntity> schedule;

  const DashboardDataEntity({
    required this.teacherProfile,
    required this.academicYear,
    required this.schedule,
  });

  @override
  List<Object?> get props => [teacherProfile, academicYear, schedule];
}
