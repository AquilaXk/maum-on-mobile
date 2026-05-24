import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/dio_api_transport.dart';
import '../core/network/secure_auth_token_store.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/deeplink/external_login.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/home/application/home_controller.dart';
import '../features/home/data/home_repository.dart';
import '../features/home/home_screen.dart';
import '../theme/app_theme.dart';
import 'app_routes.dart';

class MaumOnMobileApp extends StatefulWidget {
  const MaumOnMobileApp({
    this.authRepository,
    this.externalLoginLauncher,
    this.externalLoginConfig,
    this.deepLinkSource,
    this.homeRepository,
    this.listenForDeepLinks = true,
    super.key,
  });

  final AuthRepository? authRepository;
  final ExternalLoginLauncher? externalLoginLauncher;
  final ExternalLoginConfig? externalLoginConfig;
  final ExternalLoginDeepLinkSource? deepLinkSource;
  final HomeRepository? homeRepository;
  final bool listenForDeepLinks;

  @override
  State<MaumOnMobileApp> createState() => _MaumOnMobileAppState();
}

class _MaumOnMobileAppState extends State<MaumOnMobileApp> {
  late final ApiConfig _apiConfig = ApiConfig.fromEnvironment();
  late final SecureAuthTokenStore _tokenStore = const SecureAuthTokenStore();
  late final DioApiTransport _apiTransport = DioApiTransport.fromConfig(
    _apiConfig,
  );
  late final AuthController _authController = AuthController(
    authRepository: widget.authRepository ?? _buildDefaultAuthRepository(),
  );
  late final HomeController _homeController = HomeController(
    homeRepository: widget.homeRepository ?? _buildDefaultHomeRepository(),
  );
  late final ExternalLoginController _externalLoginController =
      ExternalLoginController(
    authController: _authController,
    launcher: widget.externalLoginLauncher ?? const UrlExternalLoginLauncher(),
    config: widget.externalLoginConfig ??
        ExternalLoginConfig(apiBaseUrl: _apiConfig.baseUrl),
  );
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_authController.restoreSession);
    if (widget.listenForDeepLinks) {
      Future<void>.microtask(_bindDeepLinks);
    }
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    _externalLoginController.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute = getInitialRoute();

    return MaterialApp(
      title: 'Maum On',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: Listenable.merge([
          _authController,
          _externalLoginController,
        ]),
        builder: (context, _) {
          final state = _authController.state;

          if (state.isRestoring) {
            return const _SessionRestoreScreen();
          }

          if (!state.isAuthenticated || state.member == null) {
            return AuthScreen(
              controller: _authController,
              externalLoginController: _externalLoginController,
            );
          }

          return HomeScreen(
            routeTitle: initialRoute.title,
            nickname: state.member!.nickname,
            homeController: _homeController,
            onLogout: () {
              _authController.logout();
            },
          );
        },
      ),
    );
  }

  AuthRepository _buildDefaultAuthRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiAuthRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
      tokenStore: _tokenStore,
    );
  }

  HomeRepository _buildDefaultHomeRepository() {
    return ApiHomeRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
      ),
    );
  }

  Future<void> _bindDeepLinks() async {
    final source =
        widget.deepLinkSource ?? AppLinksExternalLoginDeepLinkSource();
    final initialUri = await source.getInitialUri();
    if (initialUri != null) {
      await _externalLoginController.handleIncomingUri(initialUri);
    }

    _deepLinkSubscription = source.uriStream.listen(
      _externalLoginController.handleIncomingUri,
    );
  }
}

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
