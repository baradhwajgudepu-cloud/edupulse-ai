import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

final currentSchoolProvider = FutureProvider.autoDispose<SchoolDto>((ref) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) {
    throw Exception('No school context selected');
  }

  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return SchoolDto.fromJson(payload['data'] as Map<String, dynamic>);
    },
  );

  return result.when(
    onSuccess: (school) => school,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  SettingsNotifier(this._apiClient, this._ref) : super(const AsyncValue.data(null));

  Future<bool> updateSchool({
    required String schoolId,
    required String name,
    required String code,
    required String board,
    required String schoolType,
    required String email,
    String? phone,
    String? website,
    String? principalName,
    String? address,
    String? city,
    String? regionState,
    String? country,
    String? postalCode,
    String? logoUrl,
    Map<String, dynamic>? settings,
  }) async {
    state = const AsyncValue.loading();
    
    final payload = {
      'name': name,
      'code': code,
      'board': board,
      'school_type': schoolType,
      'email': email,
      'phone': phone,
      'website': website,
      'principal_name': principalName,
      'address': address,
      'city': city,
      'state': regionState,
      'country': country,
      'postal_code': postalCode,
      'logo_url': logoUrl,
      'settings': settings,
    };

    final result = await _apiClient.put(
      '/schools/$schoolId',
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(currentSchoolProvider);
        _ref.read(schoolsListProvider.notifier).fetchSchools();
        return true;
      },
      onFailure: (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> updateTenantPreferences(Map<String, dynamic> payload) async {
    state = const AsyncValue.loading();
    final result = await _apiClient.put(
      '/notifications/tenant-preferences',
      data: payload,
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(tenantPreferencesProvider);
        return true;
      },
      onFailure: (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<void>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SettingsNotifier(apiClient, ref);
});

class DeliveryDto {
  final String id;
  final String channel;
  final String status;
  final String provider;
  final String? providerMessageId;
  final String? errorCode;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final String recipientId;

  DeliveryDto({
    required this.id,
    required this.channel,
    required this.status,
    required this.provider,
    this.providerMessageId,
    this.errorCode,
    this.errorMessage,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.failedAt,
    required this.recipientId,
  });

  factory DeliveryDto.fromJson(Map<String, dynamic> json) {
    return DeliveryDto(
      id: json['id'] as String,
      channel: json['channel'] as String,
      status: json['status'] as String,
      provider: json['provider'] as String? ?? 'mock',
      providerMessageId: json['provider_message_id'] as String?,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at'] as String) : null,
      failedAt: json['failed_at'] != null ? DateTime.parse(json['failed_at'] as String) : null,
      recipientId: json['recipient_id'] as String? ?? '',
    );
  }
}

final tenantPreferencesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/notifications/tenant-preferences',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return payload['data'] as Map<String, dynamic>? ?? {};
    },
  );
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => <String, dynamic>{},
  );
});

final deliveriesProvider = FutureProvider.autoDispose<List<DeliveryDto>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/notifications/deliveries',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list.map((item) => DeliveryDto.fromJson(item as Map<String, dynamic>)).toList();
    },
  );
  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => [],
  );
});
