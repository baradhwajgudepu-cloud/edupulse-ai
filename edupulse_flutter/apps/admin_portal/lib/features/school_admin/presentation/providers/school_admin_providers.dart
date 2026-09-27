import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/school_admin_models.dart';

// -------------------------------------------------------------
// Read Providers
// -------------------------------------------------------------

final schoolProfileProvider =
    FutureProvider.family<SchoolProfileDto, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId/profile',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return SchoolProfileDto.fromJson(
          Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final complianceDashboardProvider =
    FutureProvider.family<ComplianceDashboardDto, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId/compliance',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return ComplianceDashboardDto.fromJson(
          Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final schoolRecognitionsProvider =
    FutureProvider.family<List<SchoolRecognitionDto>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId/recognitions',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => SchoolRecognitionDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final schoolCustomFieldsProvider =
    FutureProvider.family<List<SchoolCustomFieldDto>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId/custom-fields',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => SchoolCustomFieldDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final schoolDocumentsProvider =
    FutureProvider.family<List<SchoolDocumentDto>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId/documents',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => SchoolDocumentDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final documentExpiryMonitorProvider =
    FutureProvider.family<DocumentExpiryMonitorDto, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId/documents/expiry-monitor',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return DocumentExpiryMonitorDto.fromJson(
          Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final documentAccessLogsProvider =
    FutureProvider.family<List<DocumentAccessLogDto>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/schools/$schoolId/documents/access-logs',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => DocumentAccessLogDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// -------------------------------------------------------------
// Mutation Action State & Notifier
// -------------------------------------------------------------

class SchoolAdminActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const SchoolAdminActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  SchoolAdminActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return SchoolAdminActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class SchoolAdminActionNotifier extends StateNotifier<SchoolAdminActionState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  SchoolAdminActionNotifier(this._apiClient, this._ref)
      : super(const SchoolAdminActionState());

  Future<bool> updateProfile(String schoolId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.put(
      '/schools/$schoolId/profile',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolProfileProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'School profile updated successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> verifyUdise(String schoolId, bool isVerified, {String? notes}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/schools/$schoolId/udise/verify',
      data: {'is_verified': isVerified, 'notes': notes},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolProfileProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'UDISE+ verification status updated',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> createRecognition(String schoolId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/schools/$schoolId/recognitions',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolRecognitionsProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Recognition record added successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteRecognition(String schoolId, String recognitionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.delete(
      '/recognitions/$recognitionId',
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolRecognitionsProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Recognition record deleted',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> createCustomField(String schoolId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/schools/$schoolId/custom-fields',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolCustomFieldsProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Custom field added successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> createDocument(String schoolId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/schools/$schoolId/documents',
      data: data,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolDocumentsProvider(schoolId));
        _ref.invalidate(documentExpiryMonitorProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Document uploaded and registered successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> uploadDocumentWithFile({
    required String schoolId,
    required List<int> fileBytes,
    required String fileName,
    required String category,
    required String title,
    String? issuingAuthority,
    String? documentNumber,
    String? issueDate,
    String? expiryDate,
    String confidentialityLevel = 'STANDARD',
    bool isPasswordProtected = false,
    String? passcode,
    String? remarks,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    final formMap = <String, dynamic>{
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'category': category,
      'title': title,
      'confidentiality_level': confidentialityLevel,
      'is_password_protected': isPasswordProtected.toString(),
    };
    if (issuingAuthority != null && issuingAuthority.trim().isNotEmpty) {
      formMap['issuing_authority'] = issuingAuthority.trim();
    }
    if (documentNumber != null && documentNumber.trim().isNotEmpty) {
      formMap['document_number'] = documentNumber.trim();
    }
    if (issueDate != null && issueDate.trim().isNotEmpty) {
      formMap['issue_date'] = issueDate.trim();
    }
    if (expiryDate != null && expiryDate.trim().isNotEmpty) {
      formMap['expiry_date'] = expiryDate.trim();
    }
    if (isPasswordProtected && passcode != null && passcode.trim().isNotEmpty) {
      formMap['passcode'] = passcode.trim();
    }
    if (remarks != null && remarks.trim().isNotEmpty) {
      formMap['remarks'] = remarks.trim();
    }

    final formData = FormData.fromMap(formMap);

    final result = await _apiClient.post(
      '/schools/$schoolId/documents/upload',
      data: formData,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolDocumentsProvider(schoolId));
        _ref.invalidate(documentExpiryMonitorProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Document uploaded and registered successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> replaceDocumentFile({
    required String schoolId,
    required String documentId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    final result = await _apiClient.put(
      '/documents/$documentId/file',
      data: formData,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolDocumentsProvider(schoolId));
        _ref.invalidate(documentExpiryMonitorProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Document file replaced successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<Uint8List?> fetchDocumentBytes({
    required String documentId,
    String? unlockToken,
    bool inline = true,
  }) async {
    final dio = _ref.read(dioProvider);
    try {
      final qp = <String, dynamic>{
        'inline': inline,
        if (unlockToken != null && unlockToken.isNotEmpty) 'unlock_token': unlockToken,
      };
      final response = await dio.get<List<int>>(
        '/documents/$documentId/download',
        queryParameters: qp,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null && response.data!.isNotEmpty) {
        return Uint8List.fromList(response.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> unlockDocument(String documentId, String passcode) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.post(
      '/documents/$documentId/unlock',
      data: {'passcode': passcode},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>?;
        return data?['unlock_token']?.toString();
      },
    );

    return result.when(
      onSuccess: (token) {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Document unlocked successfully',
        );
        return token;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> deleteDocument(String schoolId, String documentId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    final result = await _apiClient.delete(
      '/documents/$documentId',
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        _ref.invalidate(schoolDocumentsProvider(schoolId));
        _ref.invalidate(documentExpiryMonitorProvider(schoolId));
        _ref.invalidate(complianceDashboardProvider(schoolId));
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Document archived successfully',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final schoolAdminActionProvider =
    StateNotifierProvider<SchoolAdminActionNotifier, SchoolAdminActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SchoolAdminActionNotifier(apiClient, ref);
});
