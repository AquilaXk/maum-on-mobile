class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

abstract interface class AuthTokenStore {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> saveTokens(TokenPair tokens);

  Future<void> clear();
}

abstract interface class AuthTokenRefresher {
  Future<TokenPair?> refresh(String refreshToken);
}

class MemoryAuthTokenStore implements AuthTokenStore {
  MemoryAuthTokenStore({
    TokenPair? initialTokens,
  }) : _tokens = initialTokens;

  TokenPair? _tokens;

  @override
  Future<String?> readAccessToken() async => _tokens?.accessToken;

  @override
  Future<String?> readRefreshToken() async => _tokens?.refreshToken;

  @override
  Future<void> saveTokens(TokenPair tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}
