import 'package:dio/dio.dart' as dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_models/edupulse_models.dart';

class CommunicationApiClient {
  final BaseApiClient _apiClient;

  CommunicationApiClient(this._apiClient);

  Future<ApiResult<CommunicationRequest>> createRequest({
    required String studentId,
    required String recipientType,
    required String category,
    required String subject,
    required String priority,
    required String message,
  }) async {
    return _apiClient.post(
      '/communication/requests',
      data: {
        'student_id': studentId,
        'recipient_type': recipientType,
        'category': category,
        'subject': subject,
        'priority': priority,
        'message': message,
      },
      mapper: (json) => CommunicationRequest.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<List<CommunicationRequest>>> getRequests({
    String? status,
    String? category,
    String? priority,
    String? studentId,
    String? creatorId,
    String? assignedToId,
    String? search,
    int skip = 0,
    int limit = 100,
  }) async {
    final Map<String, dynamic> params = {
      'skip': skip,
      'limit': limit,
    };
    if (status != null) params['status'] = status;
    if (category != null) params['category'] = category;
    if (priority != null) params['priority'] = priority;
    if (studentId != null) params['student_id'] = studentId;
    if (creatorId != null) params['creator_id'] = creatorId;
    if (assignedToId != null) params['assigned_to_id'] = assignedToId;
    if (search != null) params['search'] = search;

    return _apiClient.get(
      '/communication/requests',
      queryParameters: params,
      mapper: (json) {
        final list = json['data'] as List? ?? [];
        return list.map((e) => CommunicationRequest.fromJson(e as Map<String, dynamic>)).toList();
      },
    );
  }

  Future<ApiResult<CommunicationRequestDetail>> getRequestDetails(String requestId) async {
    return _apiClient.get(
      '/communication/requests/$requestId',
      mapper: (json) => CommunicationRequestDetail.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<CommunicationMessage>> replyToRequest({
    required String requestId,
    required String message,
  }) async {
    return _apiClient.post(
      '/communication/requests/$requestId/messages',
      data: {'message': message},
      mapper: (json) => CommunicationMessage.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<CommunicationRequest>> updateStatus({
    required String requestId,
    required String status,
  }) async {
    return _apiClient.patch(
      '/communication/requests/$requestId/status',
      data: {'status': status},
      mapper: (json) => CommunicationRequest.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<CommunicationRequest>> assignRequest({
    required String requestId,
    required String assigneeId,
  }) async {
    return _apiClient.post(
      '/communication/requests/$requestId/assign',
      data: {'assignee_id': assigneeId},
      mapper: (json) => CommunicationRequest.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<CommunicationRequest>> escalateRequest(String requestId) async {
    return _apiClient.post(
      '/communication/requests/$requestId/escalate',
      mapper: (json) => CommunicationRequest.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<CommunicationRequest>> resolveRequest(String requestId) async {
    return _apiClient.post(
      '/communication/requests/$requestId/resolve',
      mapper: (json) => CommunicationRequest.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<CommunicationRequest>> reopenRequest(String requestId) async {
    return _apiClient.post(
      '/communication/requests/$requestId/reopen',
      mapper: (json) => CommunicationRequest.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<int>> getUnreadCount() async {
    return _apiClient.get(
      '/communication/unread-count',
      mapper: (json) => json['data']['unread_count'] as int? ?? 0,
    );
  }

  Future<ApiResult<CommunicationAnalytics>> getAnalytics() async {
    return _apiClient.get(
      '/communication/analytics',
      mapper: (json) => CommunicationAnalytics.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getAiInsights(String requestId) async {
    return _apiClient.get(
      '/communication/requests/$requestId/ai-insights',
      mapper: (json) => json['data'] as Map<String, dynamic>,
    );
  }

  Future<ApiResult<CommunicationAttachment>> uploadAttachment({
    required String messageId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    final formData = dio.FormData.fromMap({
      'message_id': messageId,
      'file': dio.MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: dio.DioMediaType.parse(mimeType),
      ),
    });

    return _apiClient.post(
      '/communication/attachments',
      data: formData,
      options: dio.Options(contentType: 'multipart/form-data'),
      mapper: (json) => CommunicationAttachment.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

final communicationApiClientProvider = Provider<CommunicationApiClient>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CommunicationApiClient(apiClient);
});
