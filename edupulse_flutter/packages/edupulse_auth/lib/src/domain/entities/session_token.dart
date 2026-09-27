import 'dart:convert';
import 'package:equatable/equatable.dart';

class SessionToken extends Equatable {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const SessionToken({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  /// Extracts the authoritative tenant_id embedded within the JWT access token.
  String? get tenantId {
    try {
      final parts = accessToken.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;
      final tid = payload['tenant_id'];
      if (tid is String && tid.isNotEmpty && tid != 'None') {
        return tid;
      }
    } catch (_) {}
    return null;
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, tokenType];
}
