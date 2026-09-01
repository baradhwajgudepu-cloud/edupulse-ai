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

  Future<void> saveTenantId(String tenantId) async {
    await _tokenStorage.saveTenantId(tenantId);
    EduLogger.i('Tenant ID successfully cached.');
  }

  Future<void> saveSchoolId(String schoolId) async {
    await _tokenStorage.saveSchoolId(schoolId);
    EduLogger.i('School ID successfully cached.');
  }

  Future<void> saveSession(SessionToken token) async {
    await _tokenStorage.saveTokens(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
    );
    EduLogger.i('Active authentication session tokens successfully cached.');
  }

  Future<void> clearSession() async {
    await _tokenStorage.clearTokens();
    EduLogger.i('Authentication session cache cleared.');
  }

  Future<bool> hasSession() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    return access != null && refresh != null;
  }
}
