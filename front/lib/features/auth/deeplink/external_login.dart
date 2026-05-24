import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/auth_controller.dart';
import '../domain/auth_models.dart';

class ExternalLoginConfig {
  const ExternalLoginConfig({
    required this.apiBaseUrl,
    this.scheme = 'maumon',
    this.host = 'auth',
    this.callbackPath = '/callback',
  });

  final Uri apiBaseUrl;
  final String scheme;
  final String host;
  final String callbackPath;

  Uri get redirectUri {
    return Uri(
      scheme: scheme,
      host: host,
      path: callbackPath,
    );
  }

  Uri authorizeUri({required String provider}) {
    final encodedProvider = Uri.encodeComponent(provider);
    final endpoint = apiBaseUrl.resolve(
      '/api/v1/auth/oidc/authorize/$encodedProvider',
    );

    return endpoint.replace(
      queryParameters: {
        'redirect_uri': redirectUri.toString(),
      },
    );
  }

  bool isCallbackUri(Uri uri) {
    return uri.scheme == scheme && uri.host == host && uri.path == callbackPath;
  }
}

class ExternalLoginState {
  const ExternalLoginState({
    this.isStarting = false,
    this.errorMessage,
  });

  final bool isStarting;
  final String? errorMessage;

  ExternalLoginState copyWith({
    bool? isStarting,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ExternalLoginState(
      isStarting: isStarting ?? this.isStarting,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

abstract interface class ExternalLoginLauncher {
  Future<bool> launch(Uri uri);
}

class UrlExternalLoginLauncher implements ExternalLoginLauncher {
  const UrlExternalLoginLauncher();

  @override
  Future<bool> launch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

abstract interface class ExternalLoginDeepLinkSource {
  Future<Uri?> getInitialUri();

  Stream<Uri> get uriStream;
}

class AppLinksExternalLoginDeepLinkSource implements ExternalLoginDeepLinkSource {
  AppLinksExternalLoginDeepLinkSource({
    AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialUri() {
    return _appLinks.getInitialLink();
  }

  @override
  Stream<Uri> get uriStream => _appLinks.uriLinkStream;
}

class ExternalLoginController extends ChangeNotifier {
  ExternalLoginController({
    required AuthController authController,
    required ExternalLoginLauncher launcher,
    required ExternalLoginConfig config,
  })  : _authController = authController,
        _launcher = launcher,
        _config = config;

  final AuthController _authController;
  final ExternalLoginLauncher _launcher;
  final ExternalLoginConfig _config;

  ExternalLoginState _state = const ExternalLoginState();

  ExternalLoginState get state => _state;

  Future<void> start({required String provider}) async {
    _setState(
      _state.copyWith(isStarting: true, clearErrorMessage: true),
    );

    final launched = await _launcher.launch(
      _config.authorizeUri(provider: provider),
    );

    _setState(
      _state.copyWith(
        isStarting: false,
        errorMessage: launched ? null : '외부 로그인을 시작할 수 없습니다.',
        clearErrorMessage: launched,
      ),
    );
  }

  Future<bool> handleIncomingUri(Uri uri) async {
    if (!_config.isCallbackUri(uri)) {
      return false;
    }

    final query = uri.queryParameters;
    final status = query['status'];
    final error = query['error'];

    if (status == 'cancelled' || status == 'canceled' || error == 'cancelled') {
      _setState(
        const ExternalLoginState(errorMessage: '외부 로그인이 취소되었습니다.'),
      );
      return true;
    }

    if (error != null && error.isNotEmpty) {
      _setState(
        ExternalLoginState(errorMessage: _messageFromError(query)),
      );
      return true;
    }

    if (status == 'success' || _hasCodeAndState(query)) {
      final session = _sessionFromCallback(query);
      if (session != null) {
        try {
          await _authController.completeExternalLogin(session);
          _setState(const ExternalLoginState());
        } on Object {
          _setState(
            const ExternalLoginState(
              errorMessage: '로그인 세션을 저장하지 못했습니다. 다시 시도해 주세요.',
            ),
          );
        }
        return true;
      }

      _setState(const ExternalLoginState());
      await _authController.restoreSession();

      if (!_authController.state.isAuthenticated) {
        _setState(
          const ExternalLoginState(
            errorMessage: '로그인 세션을 확인하지 못했습니다. 다시 시도해 주세요.',
          ),
        );
      }
      return true;
    }

    _setState(
      const ExternalLoginState(errorMessage: '외부 로그인 결과를 확인할 수 없습니다.'),
    );
    return true;
  }

  bool _hasCodeAndState(Map<String, String> query) {
    final code = query['code'];
    final state = query['state'];

    return code != null && code.isNotEmpty && state != null && state.isNotEmpty;
  }

  AuthSession? _sessionFromCallback(Map<String, String> query) {
    final accessToken = query['access_token'] ?? query['accessToken'];
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final memberId = int.tryParse(query['member_id'] ?? query['memberId'] ?? '');
    final email = query['email'];
    final nickname = query['nickname'];
    if (memberId == null || email == null || email.isEmpty || nickname == null) {
      return null;
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: query['refresh_token'] ?? query['refreshToken'],
      tokenType: query['token_type'] ?? query['tokenType'] ?? 'Bearer',
      expiresInSeconds: int.tryParse(
            query['expires_in'] ?? query['expiresInSeconds'] ?? '',
          ) ??
          0,
      member: AuthMember(
        id: memberId,
        email: email,
        nickname: nickname,
        role: query['role'] ?? 'USER',
        status: query['member_status'] ?? query['status'] ?? 'ACTIVE',
      ),
    );
  }

  String _messageFromError(Map<String, String> query) {
    final error = query['error'];
    if (error == 'state_mismatch') {
      return '로그인 요청이 만료되었습니다. 다시 시도해 주세요.';
    }

    final description = query['error_description'];
    if (description != null && description.isNotEmpty) {
      return description;
    }

    return '외부 로그인에 실패했습니다.';
  }

  void _setState(ExternalLoginState nextState) {
    _state = nextState;
    notifyListeners();
  }
}
