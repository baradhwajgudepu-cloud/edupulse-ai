abstract class AuthTokenProvider {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> refreshSession();
}
