enum AnnouncementAudienceType {
  role,
  className,
  section;

  String toJson() {
    if (this == AnnouncementAudienceType.className) return 'CLASS';
    return name.toUpperCase();
  }

  static AnnouncementAudienceType fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'CLASS':
        return AnnouncementAudienceType.className;
      case 'SECTION':
        return AnnouncementAudienceType.section;
      case 'ROLE':
      default:
        return AnnouncementAudienceType.role;
    }
  }
}

enum AnnouncementStatus {
  draft,
  published,
  cancelled;

  String toJson() => name.toUpperCase();

  static AnnouncementStatus fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'PUBLISHED':
        return AnnouncementStatus.published;
      case 'CANCELLED':
        return AnnouncementStatus.cancelled;
      case 'DRAFT':
      default:
        return AnnouncementStatus.draft;
    }
  }
}

class Announcement {
  final String id;
  final String title;
  final String message;
  final AnnouncementAudienceType audienceType;
  final String? targetRole;
  final String? targetClassId;
  final String? targetSectionId;
  final String? publishAt;
  final String? expiresAt;
  final String priority;
  final String? attachmentUrl;
  final AnnouncementStatus status;
  final String createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.audienceType,
    this.targetRole,
    this.targetClassId,
    this.targetSectionId,
    this.publishAt,
    this.expiresAt,
    required this.priority,
    this.attachmentUrl,
    required this.status,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      audienceType: AnnouncementAudienceType.fromJson(json['audience_type'] as String? ?? 'ROLE'),
      targetRole: json['target_role'] as String?,
      targetClassId: json['target_class_id'] as String?,
      targetSectionId: json['target_section_id'] as String?,
      publishAt: json['publish_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      priority: json['priority'] as String? ?? 'NORMAL',
      attachmentUrl: json['attachment_url'] as String?,
      status: AnnouncementStatus.fromJson(json['status'] as String? ?? 'DRAFT'),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
