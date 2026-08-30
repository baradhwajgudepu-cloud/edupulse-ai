class TokenResponseDto {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const TokenResponseDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory TokenResponseDto.fromJson(Map<String, dynamic> json) {
    return TokenResponseDto(
      accessToken: (json['access_token'] ?? json['accessToken'] ?? '').toString(),
      refreshToken: (json['refresh_token'] ?? json['refreshToken'] ?? '').toString(),
      tokenType: (json['token_type'] ?? json['tokenType'] ?? 'bearer').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
    };
  }
}
