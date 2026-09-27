import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse_core/edupulse_core.dart';

class TokenStorage {
  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _schoolIdKey = 'auth_school_id';
  static const String _tenantIdKey = 'auth_tenant_id';
  static const String _tenantNameKey = 'auth_tenant_name';
  static const String _schoolNameKey = 'auth_school_name';

  final FlutterSecureStorage _secureStorage;

  const TokenStorage(this._secureStorage);

  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: _accessTokenKey);
      if (token != null && token.trim().isNotEmpty && token != 'null' && token != 'undefined') {
        debugPrint('[AUTH STORAGE] Reading access token: EXISTS');
        return token;
      }
    } catch (e) {
      debugPrint('[AUTH STORAGE] SecureStorage read error: $e');
    }

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_accessTokenKey);
        if (token != null && token.trim().isNotEmpty && token != 'null' && token != 'undefined') {
          debugPrint('[AUTH STORAGE] Reading access token from web SharedPreferences fallback: EXISTS');
          return token;
        }
      } catch (_) {}
    }

    debugPrint('[AUTH STORAGE] Reading access token: MISSING');
    return null;
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: _refreshTokenKey);
      if (token != null && token.trim().isNotEmpty && token != 'null' && token != 'undefined') {
        debugPrint('[AUTH STORAGE] Reading refresh token: EXISTS');
        return token;
      }
    } catch (e) {
      debugPrint('[AUTH STORAGE] SecureStorage read error: $e');
    }

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_refreshTokenKey);
        if (token != null && token.trim().isNotEmpty && token != 'null' && token != 'undefined') {
          debugPrint('[AUTH STORAGE] Reading refresh token from web SharedPreferences fallback: EXISTS');
          return token;
        }
      } catch (_) {}
    }

    debugPrint('[AUTH STORAGE] Reading refresh token: MISSING');
    return null;
  }

  Future<String?> getTenantId() async {
    String? value;
    try {
      value = await _secureStorage.read(key: _tenantIdKey);
    } catch (e) {
      debugPrint('[AUTH STORAGE] SecureStorage read error for tenantId: $e');
    }

    if ((value == null || value.isEmpty) && kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        value = prefs.getString(_tenantIdKey);
      } catch (_) {}
    }

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
    String? value;
    try {
      value = await _secureStorage.read(key: _schoolIdKey);
    } catch (e) {
      debugPrint('[AUTH STORAGE] SecureStorage read error for schoolId: $e');
    }

    if ((value == null || value.isEmpty) && kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        value = prefs.getString(_schoolIdKey);
      } catch (_) {}
    }

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

  Future<String?> getTenantName() async {
    try {
      final value = await _secureStorage.read(key: _tenantNameKey);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_tenantNameKey);
      } catch (_) {}
    }
    return null;
  }

  Future<String?> getSchoolName() async {
    try {
      final value = await _secureStorage.read(key: _schoolNameKey);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_schoolNameKey);
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    debugPrint('[AUTH STORAGE] Saving access token: YES');
    debugPrint('[AUTH STORAGE] Saving refresh token: YES');
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(
        key: _refreshTokenKey, value: refreshToken);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, accessToken);
        await prefs.setString(_refreshTokenKey, refreshToken);
      } catch (_) {}
    }
  }

  Future<void> saveAccessToken(String token) async {
    debugPrint('[AUTH STORAGE] Saving access token: YES');
    await _secureStorage.write(key: _accessTokenKey, value: token);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, token);
      } catch (_) {}
    }
  }

  Future<void> saveRefreshToken(String token) async {
    debugPrint('[AUTH STORAGE] Saving refresh token: YES');
    await _secureStorage.write(key: _refreshTokenKey, value: token);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_refreshTokenKey, token);
      } catch (_) {}
    }
  }

  Future<void> saveTenantId(String tenantId) async {
    await _secureStorage.write(key: _tenantIdKey, value: tenantId);
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tenantIdKey, tenantId);
      } catch (_) {}
    }
  }

  Future<void> saveSchoolId(String schoolId) async {
    await _secureStorage.write(key: _schoolIdKey, value: schoolId);
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_schoolIdKey, schoolId);
      } catch (_) {}
    }
  }

  Future<void> saveTenantName(String tenantName) async {
    await _secureStorage.write(key: _tenantNameKey, value: tenantName);
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tenantNameKey, tenantName);
      } catch (_) {}
    }
  }

  Future<void> saveSchoolName(String schoolName) async {
    await _secureStorage.write(key: _schoolNameKey, value: schoolName);
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_schoolNameKey, schoolName);
      } catch (_) {}
    }
  }

  Future<void> clearTokens([String source = 'TokenStorage.clearTokens']) async {
    debugPrint('[AUTH STORAGE] Clearing tokens');
    debugPrint('[AUTH STORAGE] Token clear source: $source');
    AuthIncidentLogger.log('TOKENS_CLEARED', {
      'source': source,
    });
    debugPrintStack(
      label: '[AUTH INCIDENT] CALL STACK FOR TOKENS_CLEARED',
    );
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _schoolIdKey);
    await _secureStorage.delete(key: _tenantIdKey);
    await _secureStorage.delete(key: _tenantNameKey);
    await _secureStorage.delete(key: _schoolNameKey);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_accessTokenKey);
        await prefs.remove(_refreshTokenKey);
        await prefs.remove(_schoolIdKey);
        await prefs.remove(_tenantIdKey);
        await prefs.remove(_tenantNameKey);
        await prefs.remove(_schoolNameKey);
      } catch (_) {}
    }
  }
}
