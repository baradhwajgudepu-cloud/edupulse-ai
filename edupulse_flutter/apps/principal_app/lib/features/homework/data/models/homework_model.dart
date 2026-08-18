class Homework {
  final String id;
  final String teacherId;
  final String classId;
  final String sectionId;
  final String subjectId;
  final String title;
  final String description;
  final String dueDate;
  final String priority;
  final String status; // DRAFT, PUBLISHED, ARCHIVED

  Homework({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: json['due_date'] as String? ?? '',
      priority: json['priority'] as String? ?? 'MEDIUM',
      status: json['status'] as String? ?? 'PUBLISHED',
    );
  }
}
