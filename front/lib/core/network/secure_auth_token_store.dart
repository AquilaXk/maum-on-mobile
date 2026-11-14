import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_token_store.dart';

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';

  final FlutterSecureStorage _storage;
  bool _hasCachedAccessToken = false;
  String? _cachedAccessToken;
  bool _hasCachedRefreshToken = false;
  String? _cachedRefreshToken;

  @override
  Future<String?> readAccessToken() async {
    if (_hasCachedAccessToken) {
      return _cachedAccessToken;
    }
    final token = await _storage.read(key: _accessTokenKey);
    _cachedAccessToken = token;
    _hasCachedAccessToken = true;
    return token;
  }

  @override
  Future<String?> readRefreshToken() async {
    if (_hasCachedRefreshToken) {
      return _cachedRefreshToken;
    }
    final token = await _storage.read(key: _refreshTokenKey);
    _cachedRefreshToken = token;
    _hasCachedRefreshToken = true;
    return token;
  }

  @override
  Future<void> saveTokens(TokenPair tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
    _cachedAccessToken = tokens.accessToken;
    _hasCachedAccessToken = true;
    _cachedRefreshToken = tokens.refreshToken;
    _hasCachedRefreshToken = true;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    _cachedAccessToken = null;
    _hasCachedAccessToken = true;
    _cachedRefreshToken = null;
    _hasCachedRefreshToken = true;
  }
}
