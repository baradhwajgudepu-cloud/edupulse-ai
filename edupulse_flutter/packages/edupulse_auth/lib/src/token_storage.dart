import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _schoolIdKey = 'auth_school_id';
  static const String _tenantIdKey = 'auth_tenant_id';

  final FlutterSecureStorage _secureStorage;

  const TokenStorage(this._secureStorage);

  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<String?> getTenantId() async {
    final value = await _secureStorage.read(key: _tenantIdKey);
    if (value == null) return null;
    final uuidRegExp = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );
    final match = uuidRegExp.firstMatch(value);
    if (match != null) {
      final cleanUuid = match.group(0);
      if (cleanUuid != value) {
        await saveTenantId(cleanUuid!);
      }
      return cleanUuid;
    }
    return null;
  }

  Future<String?> getSchoolId() async {
    final value = await _secureStorage.read(key: _schoolIdKey);
    if (value == null) return null;
    final uuidRegExp = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );
    final match = uuidRegExp.firstMatch(value);
    if (match != null) {
      final cleanUuid = match.group(0);
      if (cleanUuid != value) {
        await saveSchoolId(cleanUuid!);
      }
      return cleanUuid;
    }
    return null;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(
        key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveTenantId(String tenantId) async {
    await _secureStorage.write(key: _tenantIdKey, value: tenantId);
  }

  Future<void> saveSchoolId(String schoolId) async {
    await _secureStorage.write(key: _schoolIdKey, value: schoolId);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _schoolIdKey);
    await _secureStorage.delete(key: _tenantIdKey);
  }
}
