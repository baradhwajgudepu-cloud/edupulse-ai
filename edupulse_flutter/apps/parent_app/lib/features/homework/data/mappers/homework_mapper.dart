import '../../domain/entities/homework.dart';
import '../models/homework_dto.dart';

extension HomeworkDtoMapper on HomeworkDto {
  HomeworkEntity toEntity() {
    final parsedDueDate = DateTime.tryParse(dueDate) ?? DateTime.now();

    final parsedPriority = switch (priority.toUpperCase()) {
      'LOW' => HomeworkPriority.low,
      'NORMAL' => HomeworkPriority.normal,
      'HIGH' => HomeworkPriority.high,
      _ => HomeworkPriority.normal,
    };

    final parsedStatus = switch (status.toUpperCase()) {
      'DRAFT' => HomeworkStatus.draft,
      'PUBLISHED' => HomeworkStatus.published,
      'ARCHIVED' => HomeworkStatus.archived,
      _ => HomeworkStatus.published,
    };

    return HomeworkEntity(
      id: id,
      title: title,
      description: description,
      dueDate: parsedDueDate,
      priority: parsedPriority,
      status: parsedStatus,
      attachmentUrl: attachmentUrl ?? '',
      subjectId: subjectId,
      classId: classId,
      sectionId: sectionId,
    );
  }
}
