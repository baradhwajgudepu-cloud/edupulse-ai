import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future.value(_data[key]);
    }
    if (invocation.memberName == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value != null) {
        _data[key] = value;
      } else {
        _data.remove(key);
      }
      return Future.value();
    }
    if (invocation.memberName == #delete) {
      final key = invocation.namedArguments[#key] as String;
      _data.remove(key);
      return Future.value();
    }
    if (invocation.memberName == #readAll) {
      return Future.value(Map<String, String>.from(_data));
    }
    if (invocation.memberName == #deleteAll) {
      _data.clear();
      return Future.value();
    }
    if (invocation.memberName == #containsKey) {
      final key = invocation.namedArguments[#key] as String;
      return Future.value(_data.containsKey(key));
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('TokenStorage Tests', () {
    late FakeSecureStorage secureStorage;
    late TokenStorage tokenStorage;

    setUp(() {
      secureStorage = FakeSecureStorage();
      tokenStorage = TokenStorage(secureStorage);
    });

    test('should save and retrieve tokens correctly', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
      );

      expect(await tokenStorage.getAccessToken(), 'access_123');
      expect(await tokenStorage.getRefreshToken(), 'refresh_123');
    });

    test('should clear stored tokens successfully', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
      );

      await tokenStorage.clearTokens();

      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });
  });

  group('SessionManager Tests', () {
    late FakeSecureStorage secureStorage;
    late TokenStorage tokenStorage;
    late SessionManager sessionManager;

    setUp(() {
      secureStorage = FakeSecureStorage();
      tokenStorage = TokenStorage(secureStorage);
      sessionManager = SessionManager(tokenStorage: tokenStorage);
    });

    test('should report false for hasSession when storage is empty', () async {
      expect(await sessionManager.hasSession(), isFalse);
    });

    test('should report true for hasSession when tokens are saved', () async {
      const token = SessionToken(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
        tokenType: 'bearer',
      );

      await sessionManager.saveSession(token);

      expect(await sessionManager.hasSession(), isTrue);
      expect(await sessionManager.getAccessToken(), 'access_123');
      expect(await sessionManager.getRefreshToken(), 'refresh_123');
    });

    test('should clear session successfully', () async {
      const token = SessionToken(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
        tokenType: 'bearer',
      );

      await sessionManager.saveSession(token);
      await sessionManager.clearSession();

      expect(await sessionManager.hasSession(), isFalse);
      expect(await sessionManager.getAccessToken(), isNull);
      expect(await sessionManager.getRefreshToken(), isNull);
    });
  });
}
