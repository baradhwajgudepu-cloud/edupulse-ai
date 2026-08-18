import 'package:freezed_annotation/freezed_annotation.dart';

part 'timetable_dto.freezed.dart';
part 'timetable_dto.g.dart';

@freezed
class TimetableDto with _$TimetableDto {
  const factory TimetableDto({
    required String id,
    @JsonKey(name: 'day_of_week') required String dayOfWeek,
    @JsonKey(name: 'period_number') required int periodNumber,
    @JsonKey(name: 'start_time') required String startTime,
    @JsonKey(name: 'end_time') required String endTime,
    @JsonKey(name: 'period_type') required String periodType,
    @JsonKey(name: 'room_id') String? roomId,
    @JsonKey(name: 'is_available') required bool isAvailable,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'teacher_id') String? teacherId,
  }) = _TimetableDto;

  factory TimetableDto.fromJson(Map<String, dynamic> json) =>
      _$TimetableDtoFromJson(json);
}
