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

  @override
  List<Object?> get props => [accessToken, refreshToken, tokenType];
}
