import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/dio_api_transport.dart';
import '../core/network/secure_auth_token_store.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../theme/app_theme.dart';
import 'app_routes.dart';

class MaumOnMobileApp extends StatefulWidget {
  const MaumOnMobileApp({
    this.authRepository,
    super.key,
  });

  final AuthRepository? authRepository;

  @override
  State<MaumOnMobileApp> createState() => _MaumOnMobileAppState();
}

class _MaumOnMobileAppState extends State<MaumOnMobileApp> {
  late final AuthController _authController = AuthController(
    authRepository: widget.authRepository ?? _buildDefaultAuthRepository(),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_authController.restoreSession);
  }

  @override
  void dispose() {
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
        animation: _authController,
        builder: (context, _) {
          final state = _authController.state;

          if (state.isRestoring) {
            return const _SessionRestoreScreen();
          }

          if (!state.isAuthenticated || state.member == null) {
            return AuthScreen(controller: _authController);
          }

          return HomeScreen(
            routeTitle: initialRoute.title,
            nickname: state.member!.nickname,
            onLogout: () {
              _authController.logout();
            },
          );
        },
      ),
    );
  }

  AuthRepository _buildDefaultAuthRepository() {
    const tokenStore = SecureAuthTokenStore();
    final transport = DioApiTransport.fromConfig(ApiConfig.fromEnvironment());
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
      tokenStore: tokenStore,
    );

    return ApiAuthRepository(
      apiClient: ApiClient(
        transport: transport,
        tokenStore: tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
      tokenStore: tokenStore,
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
