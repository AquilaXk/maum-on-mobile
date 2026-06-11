import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/api_error.dart';
import '../core/network/auth_token_store.dart';
import '../core/network/dio_api_transport.dart';
import '../core/network/secure_auth_token_store.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/deeplink/external_login.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/consultation/application/consultation_controller.dart';
import '../features/consultation/data/consultation_repository.dart';
import '../features/consultation/presentation/consultation_screen.dart';
import '../features/diary/application/diary_controller.dart';
import '../features/diary/data/diary_image_repository.dart';
import '../features/diary/data/diary_repository.dart';
import '../features/diary/presentation/diary_image_picker.dart';
import '../features/diary/presentation/diary_screen.dart';
import '../features/draft_recovery/data/draft_recovery_repository.dart';
import '../features/home/application/home_controller.dart';
import '../features/home/data/home_repository.dart';
import '../features/home/home_screen.dart';
import '../features/letter/application/letter_controller.dart';
import '../features/letter/data/letter_repository.dart';
import '../features/letter/domain/letter_models.dart';
import '../features/letter/presentation/letter_screen.dart';
import '../features/legal/domain/legal_disclosures.dart';
import '../features/moderation/data/content_moderation_repository.dart';
import '../features/notification/application/notification_controller.dart';
import '../features/notification/data/notification_repository.dart';
import '../features/notification/data/push_notification_permission_client.dart';
import '../features/notification/domain/notification_models.dart';
import '../features/notification/presentation/notification_report_screen.dart';
import '../features/operations/application/operations_controller.dart';
import '../features/operations/data/operations_repository.dart';
import '../features/operations/domain/operations_models.dart';
import '../features/operations/presentation/operations_screen.dart';
import '../features/report/application/report_controller.dart';
import '../features/report/data/report_repository.dart';
import '../features/report/domain/report_models.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/story/application/story_controller.dart';
import '../features/story/data/story_repository.dart';
import '../features/story/domain/story_models.dart';
import '../features/story/presentation/story_screen.dart';
import '../theme/app_theme.dart';
import 'authenticated_app_shell.dart';
import 'app_routes.dart';

class MaumOnMobileApp extends StatefulWidget {
  const MaumOnMobileApp({
    this.authRepository,
    this.externalLoginLauncher,
    this.externalLoginConfig,
    this.deepLinkSource,
    this.homeRepository,
    this.consultationRepository,
    this.notificationRepository,
    this.pushNotificationPermissionClient,
    this.reportRepository,
    this.operationsRepository,
    this.settingsRepository,
    this.diaryRepository,
    this.diaryImageRepository,
    this.diaryImagePicker,
    this.draftRecoveryRepository,
    this.contentModerationRepository,
    this.storyRepository,
    this.onStoryReportTarget,
    this.letterRepository,
    this.onLetterReportTarget,
    this.listenForDeepLinks = true,
    super.key,
  });

  final AuthRepository? authRepository;
  final ExternalLoginLauncher? externalLoginLauncher;
  final ExternalLoginConfig? externalLoginConfig;
  final ExternalLoginDeepLinkSource? deepLinkSource;
  final HomeRepository? homeRepository;
  final ConsultationRepository? consultationRepository;
  final NotificationRepository? notificationRepository;
  final PushNotificationPermissionClient? pushNotificationPermissionClient;
  final ReportRepository? reportRepository;
  final OperationsRepository? operationsRepository;
  final SettingsRepository? settingsRepository;
  final DiaryRepository? diaryRepository;
  final DiaryImageRepository? diaryImageRepository;
  final DiaryImagePicker? diaryImagePicker;
  final DraftRecoveryRepository? draftRecoveryRepository;
  final ContentModerationRepository? contentModerationRepository;
  final StoryRepository? storyRepository;
  final ValueChanged<StoryReportTarget>? onStoryReportTarget;
  final LetterRepository? letterRepository;
  final ValueChanged<LetterReportTarget>? onLetterReportTarget;
  final bool listenForDeepLinks;

  @override
  State<MaumOnMobileApp> createState() => _MaumOnMobileAppState();
}

class _MaumOnMobileAppState extends State<MaumOnMobileApp>
    with WidgetsBindingObserver {
  late final ApiConfig _apiConfig = ApiConfig.fromEnvironment();
  late final SecureAuthTokenStore _tokenStore = const SecureAuthTokenStore();
  late final AuthTokenRefreshCoordinator _tokenRefreshCoordinator =
      AuthTokenRefreshCoordinator();
  late final DioApiTransport _apiTransport = DioApiTransport.fromConfig(
    _apiConfig,
  );
  late final AuthController _authController = AuthController(
    authRepository: widget.authRepository ?? _buildDefaultAuthRepository(),
  );
  late final ExternalLoginController _externalLoginController =
      ExternalLoginController(
    authController: _authController,
    launcher: widget.externalLoginLauncher ?? const UrlExternalLoginLauncher(),
    config: widget.externalLoginConfig ??
        ExternalLoginConfig(apiBaseUrl: _apiConfig.baseUrl),
  );
  late final PushNotificationPermissionClient _pushNotificationClient =
      widget.pushNotificationPermissionClient ??
          MethodChannelPushNotificationPermissionClient();
  StreamSubscription<Uri>? _deepLinkSubscription;
  StreamSubscription<NotificationTapPayload>? _pushTapSubscription;
  HomeController? _homeController;
  int? _homeMemberId;
  ConsultationController? _consultationController;
  int? _consultationMemberId;
  NotificationController? _notificationController;
  int? _notificationMemberId;
  ReportController? _reportController;
  int? _reportMemberId;
  OperationsController? _operationsController;
  int? _operationsMemberId;
  SettingsController? _settingsController;
  int? _settingsMemberId;
  DiaryController? _diaryController;
  int? _diaryMemberId;
  StoryController? _storyController;
  int? _storyMemberId;
  LetterController? _letterController;
  int? _letterMemberId;
  bool _openLetterComposer = false;
  bool _notificationBootstrapRequested = false;
  String? _authenticatedSessionKey;
  Future<void>? _authenticatedInvalidationFuture;
  bool _pushTokenUnregisterRequested = false;
  ReportTarget? _pendingReportTarget;
  NotificationTapPayload? _pendingNotificationTap;
  int? _pendingLetterId;
  int? _pendingStoryId;
  int? _pendingOperationsReportId;
  String? _pendingNotificationNotice;
  AuthenticatedRoute _route = AuthenticatedRoute.home;
  late final DraftRecoveryRepository _draftRecoveryRepository =
      widget.draftRecoveryRepository ??
          const StorageDraftRecoveryRepository(
            storage: SecureDraftRecoveryStorage(),
          );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_authController.restoreSession);
    if (widget.listenForDeepLinks) {
      Future<void>.microtask(_bindDeepLinks);
    }
    Future<void>.microtask(_bindPushNotifications);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSubscription?.cancel();
    _pushTapSubscription?.cancel();
    _externalLoginController.dispose();
    _authController.dispose();
    _disposeHomeController();
    _disposeConsultationController();
    _disposeNotificationController();
    _disposeReportController();
    _disposeOperationsController();
    _disposeSettingsController();
    _disposeDiaryController();
    _disposeStoryController();
    _disposeLetterController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _notificationController?.handleLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maum On',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: ThemeMode.system,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      home: PopScope<void>(
        canPop: _route == AuthenticatedRoute.home,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _route == AuthenticatedRoute.home) {
            return;
          }

          _returnHome();
        },
        child: AnimatedBuilder(
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
              _disposeAuthenticatedControllers(
                unregisterPushToken: _authenticatedSessionKey != null,
              );
              _authenticatedSessionKey = null;
              _route = AuthenticatedRoute.home;
              return AuthScreen(
                controller: _authController,
                externalLoginController: _externalLoginController,
              );
            }

            _syncAuthenticatedSession(state);
            _applyPendingNotificationTap();
            return KeyedSubtree(
              key: ValueKey(
                'authenticated-${state.member!.id}-${state.sessionRevision}',
              ),
              child: AuthenticatedAppShell(
                currentRoute: _route,
                onRouteSelected: _selectPrimaryRoute,
                child: _buildAuthenticatedRoute(
                  memberId: state.member!.id,
                  email: state.member!.email,
                  nickname: state.member!.nickname,
                  role: state.member!.role,
                  status: state.member!.status,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthenticatedRoute({
    required int memberId,
    required String email,
    required String nickname,
    required String role,
    required String status,
  }) {
    return switch (_route) {
      AuthenticatedRoute.diary => DiaryScreen(
          controller: _diaryControllerFor(memberId),
          imagePicker:
              widget.diaryImagePicker ?? const PlatformDiaryImagePicker(),
          onBack: _returnHome,
        ),
      AuthenticatedRoute.consultation => ConsultationScreen(
          controller: _consultationControllerFor(memberId),
          onBack: _returnHome,
        ),
      AuthenticatedRoute.notifications => _buildNotificationRoute(memberId),
      AuthenticatedRoute.operations => role == 'ADMIN'
          ? OperationsScreen(
              controller: _operationsControllerForPendingTarget(memberId),
              onBack: _returnHome,
              adminProfile: OperationsAdminProfile(
                id: memberId,
                email: email,
                nickname: nickname,
                role: role,
                status: status,
              ),
              onOpenSettings: () => _openRoute(AuthenticatedRoute.settings),
              onLogout: _logout,
            )
          : _buildHomeRoute(
              memberId: memberId,
              nickname: nickname,
              isAdmin: false,
            ),
      AuthenticatedRoute.settings => SettingsScreen(
          controller: _settingsControllerFor(memberId),
          supportContactInfo: _supportContactInfo(),
          onBack: _returnHome,
        ),
      AuthenticatedRoute.letter => _buildLetterRoute(memberId),
      AuthenticatedRoute.story => _buildStoryRoute(memberId),
      AuthenticatedRoute.home => _buildHomeRoute(
          memberId: memberId,
          nickname: nickname,
          isAdmin: role == 'ADMIN',
          onOpenOperations: role == 'ADMIN'
              ? () => _openRoute(AuthenticatedRoute.operations)
              : null,
        ),
    };
  }

  Widget _buildHomeRoute({
    required int memberId,
    required String nickname,
    required bool isAdmin,
    VoidCallback? onOpenOperations,
  }) {
    final homeController = _homeControllerFor(memberId);
    final notificationController = _homeNotificationControllerFor(memberId);

    Widget buildHome({
      required int unreadCount,
      required bool hasLiveConnection,
    }) {
      return HomeScreen(
        nickname: nickname,
        homeController: homeController,
        onRefresh: notificationController == null
            ? homeController.load
            : () => _refreshHomeDashboard(
                  homeController,
                  notificationController,
                ),
        onWriteDiary: () => _openRoute(AuthenticatedRoute.diary),
        onWriteLetter: () {
          setState(() {
            _openLetterComposer = true;
            _route = AuthenticatedRoute.letter;
          });
        },
        onViewStory: () => _openRoute(AuthenticatedRoute.story),
        onOpenConsultation: () => _openRoute(AuthenticatedRoute.consultation),
        onOpenNotifications: () => _openRoute(AuthenticatedRoute.notifications),
        onOpenSettings: () => _openRoute(AuthenticatedRoute.settings),
        unreadNotificationCount: unreadCount,
        hasLiveNotificationConnection: hasLiveConnection,
        isAdmin: isAdmin,
        onOpenOperations: onOpenOperations,
        onLogout: _logout,
      );
    }

    if (notificationController == null) {
      return buildHome(unreadCount: 0, hasLiveConnection: false);
    }

    return AnimatedBuilder(
      animation: notificationController,
      builder: (context, _) {
        final notificationState = notificationController.state;
        return buildHome(
          unreadCount: notificationState.unreadCount,
          hasLiveConnection: notificationState.connectionState ==
              NotificationConnectionState.connected,
        );
      },
    );
  }

  NotificationController? _homeNotificationControllerFor(int memberId) {
    final shouldBootstrap =
        !kDebugMode || widget.notificationRepository != null;
    if (!shouldBootstrap && _notificationController == null) {
      return null;
    }

    final controller = _notificationControllerFor(memberId);
    if (shouldBootstrap && !_notificationBootstrapRequested) {
      _notificationBootstrapRequested = true;
      unawaited(controller.load(silent: true));
      if (_shouldSyncPushPermission) {
        unawaited(controller.syncPushPermissionStatus());
      }
      unawaited(controller.connect());
    }
    return controller;
  }

  bool get _shouldSyncPushPermission {
    return !kDebugMode || widget.pushNotificationPermissionClient != null;
  }

  Future<void> _refreshHomeDashboard(
    HomeController homeController,
    NotificationController notificationController,
  ) async {
    await Future.wait([
      homeController.load(),
      notificationController.load(silent: true),
      if (_shouldSyncPushPermission)
        notificationController.syncPushPermissionStatus(),
    ]);
    if (notificationController.state.connectionState !=
        NotificationConnectionState.connected) {
      unawaited(notificationController.connect());
    }
  }

  Widget _buildNotificationRoute(int memberId) {
    final notificationController = _notificationControllerFor(memberId);
    final pendingNotice = _pendingNotificationNotice;
    if (pendingNotice != null) {
      notificationController.showNotice(pendingNotice);
      _pendingNotificationNotice = null;
    }
    final reportController = _reportControllerFor(memberId);
    final pendingTarget = _pendingReportTarget;
    if (pendingTarget != null) {
      reportController.selectTarget(pendingTarget);
      _pendingReportTarget = null;
    }

    return NotificationReportScreen(
      notificationController: notificationController,
      reportController: reportController,
      onOpenNotification: _openNotificationItem,
      closeNotificationStreamOnDispose: false,
      onBack: _returnHome,
    );
  }

  void _logout() {
    _disposeAuthenticatedControllers(unregisterPushToken: true);
    _pendingNotificationTap = null;
    _pendingReportTarget = null;
    _pendingLetterId = null;
    _pendingStoryId = null;
    _pendingOperationsReportId = null;
    _pendingNotificationNotice = null;
    _route = AuthenticatedRoute.home;
    _authenticatedSessionKey = null;
    unawaited(_authController.logout());
  }

  void _syncAuthenticatedSession(AuthState state) {
    final member = state.member;
    if (member == null) {
      return;
    }

    final sessionKey = '${member.id}:${state.sessionRevision}';
    if (_authenticatedSessionKey == sessionKey) {
      return;
    }

    final hadAuthenticatedSession = _authenticatedSessionKey != null;
    _disposeAuthenticatedControllers(
      unregisterPushToken: hadAuthenticatedSession,
    );
    _openLetterComposer = false;
    _pendingReportTarget = null;
    _pendingLetterId = null;
    _pendingStoryId = null;
    _pendingOperationsReportId = null;
    _pendingNotificationNotice = null;
    _route = AuthenticatedRoute.home;
    _authenticatedSessionKey = sessionKey;
    _pushTokenUnregisterRequested = false;
  }

  Future<void> _handleApiSessionInvalidated(
    ApiClientException exception,
  ) {
    return _invalidateAuthenticatedSession(exception.message);
  }

  void _handleControllerSessionInvalidated() {
    unawaited(_invalidateAuthenticatedSession('다시 로그인해 주세요.'));
  }

  void _handleOperationsSessionInvalidated(String message) {
    unawaited(_invalidateAuthenticatedSession(message));
  }

  Future<void> _invalidateAuthenticatedSession(String message) {
    final currentInvalidation = _authenticatedInvalidationFuture;
    if (currentInvalidation != null) {
      return currentInvalidation;
    }

    final nextInvalidation = _runAuthenticatedSessionInvalidation(message);
    _authenticatedInvalidationFuture = nextInvalidation;
    return nextInvalidation.whenComplete(() {
      if (identical(_authenticatedInvalidationFuture, nextInvalidation)) {
        _authenticatedInvalidationFuture = null;
      }
    });
  }

  Future<void> _runAuthenticatedSessionInvalidation(String message) async {
    _disposeAuthenticatedControllers(unregisterPushToken: true);
    _pendingNotificationTap = null;
    _pendingReportTarget = null;
    _pendingLetterId = null;
    _pendingStoryId = null;
    _pendingOperationsReportId = null;
    _pendingNotificationNotice = null;
    _openLetterComposer = false;
    _route = AuthenticatedRoute.home;
    _authenticatedSessionKey = null;
    await _authController.invalidateSession(message: message);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleWithdrawn() async {
    _disposeAuthenticatedControllers(unregisterPushToken: true);
    _pendingNotificationTap = null;
    _pendingReportTarget = null;
    _pendingLetterId = null;
    _pendingStoryId = null;
    _pendingOperationsReportId = null;
    _pendingNotificationNotice = null;
    _openLetterComposer = false;
    _route = AuthenticatedRoute.home;
    _authenticatedSessionKey = null;
    await _authController.clearSession();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildLetterRoute(int memberId) {
    final letterController = _letterControllerFor(memberId);
    final startsInCompose = _openLetterComposer;
    final initialLetterId = _pendingLetterId;
    _openLetterComposer = false;
    _pendingLetterId = null;

    return LetterScreen(
      controller: letterController,
      initiallyCompose: startsInCompose,
      initialLetterId: initialLetterId,
      onOpenRandomReceiveSettings: () =>
          _openRoute(AuthenticatedRoute.settings),
      onBack: _returnHome,
    );
  }

  Widget _buildStoryRoute(int memberId) {
    final storyController = _storyControllerFor(memberId);
    final initialStoryId = _pendingStoryId;
    _pendingStoryId = null;

    return StoryScreen(
      controller: storyController,
      initialStoryId: initialStoryId,
      onBack: _returnHome,
    );
  }

  void _openRoute(AuthenticatedRoute route) {
    setState(() {
      _route = route;
    });
  }

  void _selectPrimaryRoute(AuthenticatedRoute route) {
    setState(() {
      _openLetterComposer = false;
      _pendingReportTarget = null;
      _pendingLetterId = null;
      _pendingStoryId = null;
      _pendingOperationsReportId = null;
      _pendingNotificationNotice = null;
      _route = route;
    });
  }

  void _returnHome() {
    setState(() {
      _openLetterComposer = false;
      _pendingReportTarget = null;
      _pendingLetterId = null;
      _pendingStoryId = null;
      _pendingOperationsReportId = null;
      _pendingNotificationNotice = null;
      _route = AuthenticatedRoute.home;
    });
  }

  void _disposeAuthenticatedControllers({bool unregisterPushToken = false}) {
    _disposeHomeController();
    _disposeConsultationController();
    _disposeNotificationController(unregisterPushToken: unregisterPushToken);
    _disposeReportController();
    _disposeOperationsController();
    _disposeSettingsController();
    _disposeDiaryController();
    _disposeStoryController();
    _disposeLetterController();
  }

  HomeController _homeControllerFor(int memberId) {
    final currentController = _homeController;
    if (currentController != null && _homeMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _homeMemberId = memberId;
    return _homeController = HomeController(
      homeRepository: widget.homeRepository ?? _buildDefaultHomeRepository(),
      draftRepository: _draftRecoveryRepository,
      currentMemberId: memberId,
    );
  }

  void _disposeHomeController() {
    _homeController?.dispose();
    _homeController = null;
    _homeMemberId = null;
  }

  ConsultationController _consultationControllerFor(int memberId) {
    final currentController = _consultationController;
    if (currentController != null && _consultationMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _consultationMemberId = memberId;
    final controller = ConsultationController(
      repository: widget.consultationRepository ??
          _buildDefaultConsultationRepository(),
      currentMemberId: memberId,
      draftRepository: _draftRecoveryRepository,
      onUnauthorized: _handleControllerSessionInvalidated,
    );
    unawaited(controller.restoreDraft());
    return _consultationController = controller;
  }

  void _disposeConsultationController() {
    _consultationController?.dispose();
    _consultationController = null;
    _consultationMemberId = null;
  }

  NotificationController _notificationControllerFor(int memberId) {
    final currentController = _notificationController;
    if (currentController != null && _notificationMemberId == memberId) {
      return currentController;
    }

    _disposeNotificationController(unregisterPushToken: true);
    _notificationMemberId = memberId;
    return _notificationController = NotificationController(
      repository: widget.notificationRepository ??
          _buildDefaultNotificationRepository(),
      pushPermissionClient: _pushNotificationClient,
      onUnauthorized: _handleControllerSessionInvalidated,
    );
  }

  void _disposeNotificationController({bool unregisterPushToken = false}) {
    final controller = _notificationController;
    if (unregisterPushToken && !_pushTokenUnregisterRequested) {
      _pushTokenUnregisterRequested = true;
      if (controller != null) {
        unawaited(controller.unregisterRegisteredDeviceToken());
      } else {
        unawaited(_unregisterCurrentPushToken());
      }
    }
    controller?.dispose();
    _notificationController = null;
    _notificationMemberId = null;
    _notificationBootstrapRequested = false;
  }

  Future<void> _unregisterCurrentPushToken() async {
    try {
      final token =
          (await _pushNotificationClient.getPermissionStatus()).token?.trim();
      if (token == null || token.isEmpty) {
        return;
      }
      await (widget.notificationRepository ??
              _buildDefaultNotificationRepository())
          .unregisterDeviceToken(token);
    } on Object {
      // 세션 폐기 중 푸시 해제 실패는 서버 측 토큰 폐기 또는 다음 로그인 동기화로 보정한다.
    }
  }

  ReportController _reportControllerFor(int memberId) {
    final currentController = _reportController;
    if (currentController != null && _reportMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _reportMemberId = memberId;
    return _reportController = ReportController(
      repository: widget.reportRepository ?? _buildDefaultReportRepository(),
      moderationRepository: widget.contentModerationRepository ??
          _buildDefaultContentModerationRepository(),
      onUnauthorized: _handleControllerSessionInvalidated,
    );
  }

  void _disposeReportController() {
    _reportController?.dispose();
    _reportController = null;
    _reportMemberId = null;
  }

  OperationsController _operationsControllerFor(int memberId) {
    final currentController = _operationsController;
    if (currentController != null && _operationsMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _operationsMemberId = memberId;
    return _operationsController = OperationsController(
      reportRepository:
          widget.reportRepository ?? _buildDefaultReportRepository(),
      operationsRepository:
          widget.operationsRepository ?? _buildDefaultOperationsRepository(),
      systemEnvironment: _operationsSystemEnvironment(),
      onUnauthorized: _handleOperationsSessionInvalidated,
    );
  }

  OperationsController _operationsControllerForPendingTarget(int memberId) {
    final controller = _operationsControllerFor(memberId);
    final reportId = _pendingOperationsReportId;
    if (reportId != null) {
      _pendingOperationsReportId = null;
      unawaited(controller.openReportById(reportId));
    }
    return controller;
  }

  void _disposeOperationsController() {
    _operationsController?.dispose();
    _operationsController = null;
    _operationsMemberId = null;
  }

  SettingsController _settingsControllerFor(int memberId) {
    final currentController = _settingsController;
    if (currentController != null && _settingsMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _settingsMemberId = memberId;
    return _settingsController = SettingsController(
      repository:
          widget.settingsRepository ?? _buildDefaultSettingsRepository(),
      onUnauthorized: _handleControllerSessionInvalidated,
      onWithdrawn: _handleWithdrawn,
    );
  }

  void _disposeSettingsController() {
    _settingsController?.dispose();
    _settingsController = null;
    _settingsMemberId = null;
  }

  DiaryController _diaryControllerFor(int memberId) {
    final currentController = _diaryController;
    if (currentController != null && _diaryMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _diaryMemberId = memberId;
    final controller = DiaryController(
      diaryRepository: widget.diaryRepository ?? _buildDefaultDiaryRepository(),
      imageRepository:
          widget.diaryImageRepository ?? _buildDefaultDiaryImageRepository(),
      moderationRepository: widget.contentModerationRepository ??
          _buildDefaultContentModerationRepository(),
      currentMemberId: memberId,
      draftRepository: _draftRecoveryRepository,
      onUnauthorized: _handleControllerSessionInvalidated,
    );
    unawaited(controller.restoreDraft());
    return _diaryController = controller;
  }

  void _disposeDiaryController() {
    _diaryController?.dispose();
    _diaryController = null;
    _diaryMemberId = null;
  }

  StoryController _storyControllerFor(int memberId) {
    final currentController = _storyController;
    if (currentController != null && _storyMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _storyMemberId = memberId;
    final controller = StoryController(
      storyRepository: widget.storyRepository ?? _buildDefaultStoryRepository(),
      currentMemberId: memberId,
      draftRepository: _draftRecoveryRepository,
      moderationRepository: widget.contentModerationRepository ??
          _buildDefaultContentModerationRepository(),
      onUnauthorized: _handleControllerSessionInvalidated,
      onReportTargetSelected: _handleStoryReportTarget,
    );
    unawaited(controller.restoreDraft());
    return _storyController = controller;
  }

  void _disposeStoryController() {
    _storyController?.dispose();
    _storyController = null;
    _storyMemberId = null;
  }

  LetterController _letterControllerFor(int memberId) {
    final currentController = _letterController;
    if (currentController != null && _letterMemberId == memberId) {
      return currentController;
    }

    currentController?.dispose();
    _letterMemberId = memberId;
    final controller = LetterController(
      letterRepository:
          widget.letterRepository ?? _buildDefaultLetterRepository(),
      moderationRepository: widget.contentModerationRepository ??
          _buildDefaultContentModerationRepository(),
      currentMemberId: memberId,
      draftRepository: _draftRecoveryRepository,
      onUnauthorized: _handleControllerSessionInvalidated,
      onReportTargetSelected: _handleLetterReportTarget,
    );
    unawaited(controller.restoreDraft());
    return _letterController = controller;
  }

  void _disposeLetterController() {
    _letterController?.dispose();
    _letterController = null;
    _letterMemberId = null;
  }

  AuthRepository _buildDefaultAuthRepository() {
    return ApiAuthRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
      tokenStore: _tokenStore,
    );
  }

  HomeRepository _buildDefaultHomeRepository() {
    return ApiHomeRepository(
      apiClient: _sessionApiClient(),
    );
  }

  DiaryRepository _buildDefaultDiaryRepository() {
    return ApiDiaryRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  DiaryImageRepository _buildDefaultDiaryImageRepository() {
    return ApiDiaryImageRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  LetterRepository _buildDefaultLetterRepository() {
    return ApiLetterRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  ConsultationRepository _buildDefaultConsultationRepository() {
    return ApiConsultationRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
      streamClient: HttpConsultationStreamClient(
        apiConfig: _apiConfig,
        tokenStore: _tokenStore,
        tokenRefresher: _tokenRefresher(),
        tokenRefreshCoordinator: _tokenRefreshCoordinator,
      ),
    );
  }

  NotificationRepository _buildDefaultNotificationRepository() {
    return ApiNotificationRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
      streamClient: DioNotificationStreamClient(apiConfig: _apiConfig),
    );
  }

  ReportRepository _buildDefaultReportRepository() {
    return ApiReportRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  OperationsRepository _buildDefaultOperationsRepository() {
    return ApiOperationsRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  OperationsSystemEnvironment _operationsSystemEnvironment() {
    return OperationsSystemEnvironment(
      apiEndpoint: _apiConfig.baseUrl.toString(),
      appVersion: const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '0.1.0',
      ),
      buildNumber: const String.fromEnvironment(
        'APP_BUILD_NUMBER',
        defaultValue: '1',
      ),
      platform: _platformLabel(defaultTargetPlatform),
      observabilityToolUrl: const String.fromEnvironment(
        'OBSERVABILITY_TOOL_URL',
        defaultValue: '',
      ),
    );
  }

  SupportContactInfo _supportContactInfo() {
    return SupportContactInfo(
      supportEmail: LegalDisclosures.supportEmail,
      privacyEmail: LegalDisclosures.privacyEmail,
      supportUrl: LegalDisclosures.supportUrl,
      incidentNoticeUrl: LegalDisclosures.incidentNoticeUrl,
      appVersion: const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '0.1.0',
      ),
      buildNumber: const String.fromEnvironment(
        'APP_BUILD_NUMBER',
        defaultValue: '1',
      ),
      platform: _platformLabel(defaultTargetPlatform),
    );
  }

  ContentModerationRepository _buildDefaultContentModerationRepository() {
    return ApiContentModerationRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  SettingsRepository _buildDefaultSettingsRepository() {
    return ApiSettingsRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  StoryRepository _buildDefaultStoryRepository() {
    return ApiStoryRepository(
      apiClient: _sessionApiClient(tokenRefresher: _tokenRefresher()),
    );
  }

  AuthSessionTokenRefresher _tokenRefresher() {
    return AuthSessionTokenRefresher(
      authRepository: ApiAuthRepository(
        apiClient: _rawApiClient(),
        tokenStore: _tokenStore,
      ),
    );
  }

  ApiClient _sessionApiClient({AuthTokenRefresher? tokenRefresher}) {
    return ApiClient(
      transport: _apiTransport,
      tokenStore: _tokenStore,
      tokenRefresher: tokenRefresher,
      tokenRefreshCoordinator: _tokenRefreshCoordinator,
      onSessionInvalidated: _handleApiSessionInvalidated,
    );
  }

  ApiClient _rawApiClient() {
    return ApiClient(
      transport: _apiTransport,
      tokenStore: _tokenStore,
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

  Future<void> _bindPushNotifications() async {
    _pushTapSubscription = _pushNotificationClient.notificationTaps.listen(
      _handleNotificationTap,
    );

    final initialPayload =
        await _pushNotificationClient.takeInitialNotificationTap();
    if (initialPayload != null) {
      _handleNotificationTap(initialPayload);
    }
  }

  void _handleNotificationTap(NotificationTapPayload payload) {
    if (!_authController.state.isAuthenticated ||
        _authController.state.member == null ||
        _authenticatedSessionKey == null) {
      _pendingNotificationTap = payload;
      return;
    }

    setState(() {
      _applyNotificationTap(payload);
    });
  }

  void _applyPendingNotificationTap() {
    final payload = _pendingNotificationTap;
    if (payload == null) {
      return;
    }

    _pendingNotificationTap = null;
    _applyNotificationTap(payload);
  }

  void _applyNotificationTap(NotificationTapPayload payload) {
    _openLetterComposer = false;
    _pendingReportTarget = null;
    _pendingLetterId = null;
    _pendingStoryId = null;
    _pendingOperationsReportId = null;
    _pendingNotificationNotice = null;
    _route = switch (payload.destination) {
      NotificationTapDestination.diary => AuthenticatedRoute.diary,
      NotificationTapDestination.story => _storyRouteFor(payload),
      NotificationTapDestination.letter => _letterRouteFor(payload),
      NotificationTapDestination.consultation =>
        AuthenticatedRoute.consultation,
      NotificationTapDestination.operations => _operationsRouteFor(payload),
      NotificationTapDestination.settings => AuthenticatedRoute.settings,
      NotificationTapDestination.notifications =>
        AuthenticatedRoute.notifications,
    };
  }

  AuthenticatedRoute _letterRouteFor(NotificationTapPayload payload) {
    final letterId = payload.letterId;
    if (letterId == null || letterId <= 0) {
      _pendingNotificationNotice = '편지를 바로 열 수 없어 알림 목록에 머뭅니다.';
      return AuthenticatedRoute.notifications;
    }

    _pendingLetterId = letterId;
    return AuthenticatedRoute.letter;
  }

  AuthenticatedRoute _storyRouteFor(NotificationTapPayload payload) {
    final storyId = payload.storyId;
    if (storyId == null || storyId <= 0) {
      if (payload.hasTargetReference) {
        _pendingNotificationNotice = '스토리를 바로 열 수 없어 알림 목록에 머뭅니다.';
        return AuthenticatedRoute.notifications;
      }
      return AuthenticatedRoute.story;
    }

    _pendingStoryId = storyId;
    return AuthenticatedRoute.story;
  }

  AuthenticatedRoute _operationsRouteFor(NotificationTapPayload payload) {
    final reportId = payload.reportId;
    if (reportId == null || reportId <= 0) {
      _pendingNotificationNotice = '운영 항목을 바로 열 수 없어 알림 목록에 머뭅니다.';
      return AuthenticatedRoute.notifications;
    }

    _pendingOperationsReportId = reportId;
    return AuthenticatedRoute.operations;
  }

  void _openNotificationItem(NotificationItem notification) {
    setState(() {
      _applyNotificationTap(notification.tapPayload);
    });
  }

  void _handleStoryReportTarget(StoryReportTarget target) {
    widget.onStoryReportTarget?.call(target);
    _openReportTarget(
      ReportTarget.fromRaw(
        targetType: target.targetType,
        targetId: target.targetId,
        label: target.label,
      ),
    );
  }

  void _handleLetterReportTarget(LetterReportTarget target) {
    widget.onLetterReportTarget?.call(target);
    _openReportTarget(
      ReportTarget.fromRaw(
        targetType: target.targetType,
        targetId: target.targetId,
        label: target.label,
      ),
    );
  }

  void _openReportTarget(ReportTarget target) {
    setState(() {
      _pendingReportTarget = target;
      _route = AuthenticatedRoute.notifications;
    });
  }
}

String _platformLabel(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
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
