import 'dart:async';

import '../storage/secure_key_value_storage.dart';
import 'auth_token_store.dart';

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({
    SecureKeyValueStorage storage = const PlatformSecureKeyValueStorage(),
  }) : _storage = storage;

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';

  final SecureKeyValueStorage _storage;
  bool _hasCachedAccessToken = false;
  String? _cachedAccessToken;
  int _accessCacheEpoch = 0;
  bool _hasCachedRefreshToken = false;
  String? _cachedRefreshToken;
  int _refreshCacheEpoch = 0;
  Future<void> _mutationQueue = Future<void>.value();

  Future<void> _enqueueMutation(Future<void> Function() action) {
    final next = _mutationQueue.catchError((Object _, StackTrace __) {}).then(
      (_) => action(),
    );
    _mutationQueue = next.catchError((Object _, StackTrace __) {});
    return next;
  }

  @override
  Future<String?> readAccessToken() async {
    if (_hasCachedAccessToken) {
      return _cachedAccessToken;
    }
    final readEpoch = _accessCacheEpoch;
    final token = await _storage.read(_accessTokenKey);
    if (_accessCacheEpoch != readEpoch) {
      if (_hasCachedAccessToken) {
        return _cachedAccessToken;
      }
      return await _storage.read(_accessTokenKey);
    }
    if (!_hasCachedAccessToken) {
      _cachedAccessToken = token;
      _hasCachedAccessToken = true;
    }
    return token;
  }

  @override
  Future<String?> readRefreshToken() async {
    if (_hasCachedRefreshToken) {
      return _cachedRefreshToken;
    }
    final readEpoch = _refreshCacheEpoch;
    final token = await _storage.read(_refreshTokenKey);
    if (_refreshCacheEpoch != readEpoch) {
      if (_hasCachedRefreshToken) {
        return _cachedRefreshToken;
      }
      return await _storage.read(_refreshTokenKey);
    }
    if (!_hasCachedRefreshToken) {
      _cachedRefreshToken = token;
      _hasCachedRefreshToken = true;
    }
    return token;
  }

  @override
  Future<void> saveTokens(TokenPair tokens) {
    final accessEpoch = ++_accessCacheEpoch;
    final refreshEpoch = ++_refreshCacheEpoch;
    _cachedAccessToken = null;
    _hasCachedAccessToken = false;
    _cachedRefreshToken = null;
    _hasCachedRefreshToken = false;
    return _enqueueMutation(() async {
      await _storage.write(_accessTokenKey, tokens.accessToken);
      await _storage.write(_refreshTokenKey, tokens.refreshToken);
      if (_accessCacheEpoch == accessEpoch) {
        _accessCacheEpoch += 1;
        _cachedAccessToken = tokens.accessToken;
        _hasCachedAccessToken = true;
      }
      if (_refreshCacheEpoch == refreshEpoch) {
        _refreshCacheEpoch += 1;
        _cachedRefreshToken = tokens.refreshToken;
        _hasCachedRefreshToken = true;
      }
    });
  }

  @override
  Future<void> clear() {
    final accessEpoch = ++_accessCacheEpoch;
    final refreshEpoch = ++_refreshCacheEpoch;
    _cachedAccessToken = null;
    _hasCachedAccessToken = false;
    _cachedRefreshToken = null;
    _hasCachedRefreshToken = false;
    return _enqueueMutation(() async {
      await _storage.delete(_accessTokenKey);
      await _storage.delete(_refreshTokenKey);
      if (_accessCacheEpoch == accessEpoch) {
        _accessCacheEpoch += 1;
        _cachedAccessToken = null;
        _hasCachedAccessToken = true;
      }
      if (_refreshCacheEpoch == refreshEpoch) {
        _refreshCacheEpoch += 1;
        _cachedRefreshToken = null;
        _hasCachedRefreshToken = true;
      }
    });
  }
}
