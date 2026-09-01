import 'package:equatable/equatable.dart';

enum HomeworkPriority {
  low,
  normal,
  high,
}

enum HomeworkStatus {
  draft,
  published,
  archived,
}

class HomeworkEntity extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final HomeworkPriority priority;
  final HomeworkStatus status;
  final String attachmentUrl;
  final String subjectId;
  final String classId;
  final String sectionId;

  const HomeworkEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.attachmentUrl,
    required this.subjectId,
    required this.classId,
    required this.sectionId,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        dueDate,
        priority,
        status,
        attachmentUrl,
        subjectId,
        classId,
        sectionId,
      ];
}
