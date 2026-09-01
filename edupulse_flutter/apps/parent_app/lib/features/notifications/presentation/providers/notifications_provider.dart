import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_core/edupulse_core.dart';

class NotificationDto {
  final String id;
  final String type;
  final String title;
  final String message;
  final String priority;
  final String? studentId;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;

  NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    this.studentId,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'UNREAD';
    return NotificationDto(
      id: json['id'] as String,
      type: json['notification_type'] as String? ?? 'GENERAL',
      title: json['title'] as String? ?? 'Notification',
      message: (json['message'] ?? json['content'] ?? '') as String,
      priority: json['priority'] as String? ?? 'NORMAL',
      studentId: json['student_id'] as String?,
      relatedEntityType: json['related_module'] as String?,
      relatedEntityId: json['related_record_id'] as String?,
      metadata: (json['settings'] ?? json['metadata'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      isRead: statusStr == 'READ',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationPreferencesDto {
  final bool enableHomework;
  final bool enableAttendance;
  final bool enableMarks;
  final bool enableReportCard;
  final bool enableAnnouncements;
  final bool enableEvents;
  final bool enableFee;
  final bool enablePush;
  final bool enableEmail;
  final bool enableSms;
  final bool enableWhatsapp;
  final bool enableInApp;

  NotificationPreferencesDto({
    required this.enableHomework,
    required this.enableAttendance,
    required this.enableMarks,
    required this.enableReportCard,
    required this.enableAnnouncements,
    required this.enableEvents,
    required this.enableFee,
    required this.enablePush,
    required this.enableEmail,
    required this.enableSms,
    required this.enableWhatsapp,
    required this.enableInApp,
  });

  factory NotificationPreferencesDto.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesDto(
      enableHomework: json['enable_homework'] as bool? ?? true,
      enableAttendance: json['enable_attendance'] as bool? ?? true,
      enableMarks: json['enable_marks'] as bool? ?? true,
      enableReportCard: json['enable_report_card'] as bool? ?? true,
      enableAnnouncements: json['enable_announcements'] as bool? ?? true,
      enableEvents: json['enable_events'] as bool? ?? true,
      enableFee: json['enable_fee'] as bool? ?? true,
      enablePush: json['enable_push'] as bool? ?? true,
      enableEmail: json['enable_email'] as bool? ?? true,
      enableSms: json['enable_sms'] as bool? ?? true,
      enableWhatsapp: json['enable_whatsapp'] as bool? ?? true,
      enableInApp: json['enable_in_app'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable_homework': enableHomework,
      'enable_attendance': enableAttendance,
      'enable_marks': enableMarks,
      'enable_report_card': enableReportCard,
      'enable_announcements': enableAnnouncements,
      'enable_events': enableEvents,
      'enable_fee': enableFee,
      'enable_push': enablePush,
      'enable_email': enableEmail,
      'enable_sms': enableSms,
      'enable_whatsapp': enableWhatsapp,
      'enable_in_app': enableInApp,
    };
  }
}

sealed class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsSuccess extends NotificationsState {
  final List<NotificationDto> list;
  final int unreadCount;
  final NotificationPreferencesDto? preferences;
  const NotificationsSuccess(this.list, this.unreadCount, {this.preferences});
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final BaseApiClient _apiClient;

  NotificationsNotifier(this._apiClient) : super(const NotificationsInitial());

  Future<void> fetchNotifications({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = const NotificationsLoading();
    }

    try {
      // 1. Fetch notifications
      final resultNotifs = await _apiClient.get<List<dynamic>>(
        '/notifications',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as List<dynamic>? ?? [];
        },
      );

      // 2. Fetch unread count
      final resultCount = await _apiClient.get<int>(
        '/notifications/unread-count',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return (payload['data']?['unread_count'] as num?)?.toInt() ?? 0;
        },
      );

      // 3. Fetch preferences
      final resultPrefs = await _apiClient.get<Map<String, dynamic>>(
        '/notification-preferences',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>? ?? {};
        },
      );

      resultNotifs.when(
        onSuccess: (listPayload) {
          final list = listPayload.map((item) => NotificationDto.fromJson(item as Map<String, dynamic>)).toList();
          final unreadCount = resultCount.dataOrNull ?? 0;
          final preferences = resultPrefs.dataOrNull != null ? NotificationPreferencesDto.fromJson(resultPrefs.dataOrNull!) : null;
          state = NotificationsSuccess(list, unreadCount, preferences: preferences);
        },
        onFailure: (failure) {
          state = NotificationsError(failure.message);
        },
      );
    } catch (e) {
      state = NotificationsError('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final result = await _apiClient.put<Map<String, dynamic>>(
        '/notifications/$id/read',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>? ?? {};
        },
      );

      result.when(
        onSuccess: (response) {
          fetchNotifications(isRefresh: true);
        },
        onFailure: (failure) {
          EduLogger.e('Failed to mark notification read: ${failure.message}');
        },
      );
    } catch (e) {
      EduLogger.e('Unexpected error marking notification read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final result = await _apiClient.put<int>(
        '/notifications/read-all',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return (payload['data'] as num?)?.toInt() ?? 0;
        },
      );

      result.when(
        onSuccess: (response) {
          fetchNotifications(isRefresh: true);
        },
        onFailure: (failure) {
          EduLogger.e('Failed to mark all notifications read: ${failure.message}');
        },
      );
    } catch (e) {
      EduLogger.e('Unexpected error marking all notifications read: $e');
    }
  }

  Future<void> updatePreferences(NotificationPreferencesDto updated) async {
    try {
      final result = await _apiClient.put<Map<String, dynamic>>(
        '/notification-preferences',
        data: updated.toJson(),
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>? ?? {};
        },
      );

      result.when(
        onSuccess: (response) {
          fetchNotifications(isRefresh: true);
        },
        onFailure: (failure) {
          EduLogger.e('Failed to update preferences: ${failure.message}');
        },
      );
    } catch (e) {
      EduLogger.e('Unexpected error updating preferences: $e');
    }
  }
}

final notificationsStateProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationsNotifier(apiClient);
});
