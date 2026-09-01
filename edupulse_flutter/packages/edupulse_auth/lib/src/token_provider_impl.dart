import 'package:edupulse_network/edupulse_network.dart';
import 'domain/entities/session_token.dart';
import 'session_manager.dart';

typedef TokenRefreshCallback = Future<SessionToken> Function(
    String refreshToken);

class TokenProviderImpl implements AuthTokenProvider {
  final SessionManager _sessionManager;
  final TokenRefreshCallback _refreshCallback;

  static bool _isRefreshing = false;
  static Future<SessionToken>? _activeRefreshFuture;

  const TokenProviderImpl(this._sessionManager, this._refreshCallback);

  @override
  Future<String?> getAccessToken() {
    return _sessionManager.getAccessToken();
  }

  @override
  Future<String?> getRefreshToken() {
    return _sessionManager.getRefreshToken();
  }

  @override
  Future<String?> getSchoolId() {
    return _sessionManager.getSchoolId();
  }

  @override
  Future<void> refreshSession() async {
    if (_isRefreshing && _activeRefreshFuture != null) {
      await _activeRefreshFuture;
      return;
    }

    _isRefreshing = true;

    final refreshTask = Future(() async {
      final refreshTok = await getRefreshToken();
      if (refreshTok == null || refreshTok.isEmpty) {
        throw Exception('Refresh token is null or missing.');
      }

      try {
        final newToken = await _refreshCallback(refreshTok);
        await _sessionManager.saveSession(newToken);
        return newToken;
      } catch (e) {
        await _sessionManager.clearSession();
        rethrow;
      }
    });

    _activeRefreshFuture = refreshTask;

    try {
      await refreshTask;
    } finally {
      _isRefreshing = false;
      _activeRefreshFuture = null;
    }
  }
}
