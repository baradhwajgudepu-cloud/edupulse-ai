import 'package:flutter/foundation.dart';
import 'domain/entities/session_token.dart';
import 'token_storage.dart';
import 'package:edupulse_core/edupulse_core.dart';

class SessionManager {
  final TokenStorage _tokenStorage;

  SessionManager({
    required TokenStorage tokenStorage,
  }) : _tokenStorage = tokenStorage;

  Future<String?> getAccessToken() async {
    return _tokenStorage.getAccessToken();
  }

  Future<String?> getRefreshToken() async {
    return _tokenStorage.getRefreshToken();
  }

  Future<String?> getSchoolId() async {
    return _tokenStorage.getSchoolId();
  }

  Future<String?> getTenantId() async {
    return _tokenStorage.getTenantId();
  }

  Future<String?> getTenantName() async {
    return _tokenStorage.getTenantName();
  }

  Future<String?> getSchoolName() async {
    return _tokenStorage.getSchoolName();
  }

  Future<void> saveTenantId(String tenantId) async {
    await _tokenStorage.saveTenantId(tenantId);
    EduLogger.i('Tenant ID successfully cached.');
  }

  Future<void> saveSchoolId(String schoolId) async {
    await _tokenStorage.saveSchoolId(schoolId);
    EduLogger.i('School ID successfully cached.');
  }

  Future<void> saveTenantName(String tenantName) async {
    await _tokenStorage.saveTenantName(tenantName);
    EduLogger.i('Tenant Name successfully cached.');
  }

  Future<void> saveSchoolName(String schoolName) async {
    await _tokenStorage.saveSchoolName(schoolName);
    EduLogger.i('School Name successfully cached.');
  }

  Future<void> saveSession(SessionToken token) async {
    await _tokenStorage.saveTokens(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
    );
    final tenantId = token.tenantId;
    if (tenantId != null && tenantId.isNotEmpty) {
      await _tokenStorage.saveTenantId(tenantId);
    }
    EduLogger.i('Active authentication session tokens successfully cached.');
  }

  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {
    AuthIncidentLogger.log('CLEAR_SESSION_CALLED', {
      'source': source,
    });
    debugPrintStack(
      label: '[AUTH INCIDENT] CALL STACK FOR CLEAR_SESSION_CALLED',
    );
    await _tokenStorage.clearTokens(source);
    EduLogger.i('Authentication session cache cleared.');
  }

  Future<bool> hasSession() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    final hasValidAccess = access != null && access.trim().isNotEmpty && access != 'null' && access != 'undefined';
    final hasValidRefresh = refresh != null && refresh.trim().isNotEmpty && refresh != 'null' && refresh != 'undefined';
    return hasValidAccess && hasValidRefresh;
  }
}
