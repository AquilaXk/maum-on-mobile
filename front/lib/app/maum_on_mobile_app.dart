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
import '../features/consultation/application/consultation_controller.dart';
import '../features/consultation/data/consultation_repository.dart';
import '../features/consultation/presentation/consultation_screen.dart';
import '../features/diary/application/diary_controller.dart';
import '../features/diary/data/diary_repository.dart';
import '../features/diary/presentation/diary_image_picker.dart';
import '../features/diary/presentation/diary_screen.dart';
import '../features/home/application/home_controller.dart';
import '../features/home/data/home_repository.dart';
import '../features/home/home_screen.dart';
import '../features/letter/application/letter_controller.dart';
import '../features/letter/data/letter_repository.dart';
import '../features/letter/domain/letter_models.dart';
import '../features/letter/presentation/letter_screen.dart';
import '../features/notification/application/notification_controller.dart';
import '../features/notification/data/notification_repository.dart';
import '../features/notification/presentation/notification_report_screen.dart';
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
    this.reportRepository,
    this.settingsRepository,
    this.diaryRepository,
    this.diaryImagePicker,
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
  final ReportRepository? reportRepository;
  final SettingsRepository? settingsRepository;
  final DiaryRepository? diaryRepository;
  final DiaryImagePicker? diaryImagePicker;
  final StoryRepository? storyRepository;
  final ValueChanged<StoryReportTarget>? onStoryReportTarget;
  final LetterRepository? letterRepository;
  final ValueChanged<LetterReportTarget>? onLetterReportTarget;
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
  late final ExternalLoginController _externalLoginController =
      ExternalLoginController(
    authController: _authController,
    launcher: widget.externalLoginLauncher ?? const UrlExternalLoginLauncher(),
    config: widget.externalLoginConfig ??
        ExternalLoginConfig(apiBaseUrl: _apiConfig.baseUrl),
  );
  StreamSubscription<Uri>? _deepLinkSubscription;
  HomeController? _homeController;
  int? _homeMemberId;
  ConsultationController? _consultationController;
  int? _consultationMemberId;
  NotificationController? _notificationController;
  int? _notificationMemberId;
  ReportController? _reportController;
  int? _reportMemberId;
  SettingsController? _settingsController;
  int? _settingsMemberId;
  DiaryController? _diaryController;
  int? _diaryMemberId;
  StoryController? _storyController;
  int? _storyMemberId;
  LetterController? _letterController;
  int? _letterMemberId;
  bool _openLetterComposer = false;
  ReportTarget? _pendingReportTarget;
  _AuthenticatedDestination _destination = _AuthenticatedDestination.home;

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
    _disposeHomeController();
    _disposeConsultationController();
    _disposeNotificationController();
    _disposeReportController();
    _disposeSettingsController();
    _disposeDiaryController();
    _disposeStoryController();
    _disposeLetterController();
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
            _disposeHomeController();
            _disposeConsultationController();
            _disposeNotificationController();
            _disposeReportController();
            _disposeSettingsController();
            _disposeDiaryController();
            _disposeStoryController();
            _disposeLetterController();
            _destination = _AuthenticatedDestination.home;
            return AuthScreen(
              controller: _authController,
              externalLoginController: _externalLoginController,
            );
          }

          if (_destination == _AuthenticatedDestination.diary) {
            return DiaryScreen(
              controller: _diaryControllerFor(state.member!.id),
              imagePicker:
                  widget.diaryImagePicker ?? const FilePickerDiaryImagePicker(),
              onBack: () {
                setState(() {
                  _destination = _AuthenticatedDestination.home;
                });
              },
            );
          }

          if (_destination == _AuthenticatedDestination.consultation) {
            return ConsultationScreen(
              controller: _consultationControllerFor(state.member!.id),
              onBack: () {
                setState(() {
                  _destination = _AuthenticatedDestination.home;
                });
              },
            );
          }

          if (_destination == _AuthenticatedDestination.notifications) {
            final reportController = _reportControllerFor(state.member!.id);
            final pendingTarget = _pendingReportTarget;
            if (pendingTarget != null) {
              reportController.selectTarget(pendingTarget);
              _pendingReportTarget = null;
            }

            return NotificationReportScreen(
              notificationController:
                  _notificationControllerFor(state.member!.id),
              reportController: reportController,
              onBack: () {
                setState(() {
                  _destination = _AuthenticatedDestination.home;
                });
              },
            );
          }

          if (_destination == _AuthenticatedDestination.settings) {
            return SettingsScreen(
              controller: _settingsControllerFor(state.member!.id),
              onBack: () {
                setState(() {
                  _destination = _AuthenticatedDestination.home;
                });
              },
            );
          }

          if (_destination == _AuthenticatedDestination.letter) {
            final letterController = _letterControllerFor(state.member!.id);
            final startsInCompose = _openLetterComposer;
            _openLetterComposer = false;

            return LetterScreen(
              controller: letterController,
              initiallyCompose: startsInCompose,
              onBack: () {
                setState(() {
                  _destination = _AuthenticatedDestination.home;
                });
              },
            );
          }

          if (_destination == _AuthenticatedDestination.story) {
            return StoryScreen(
              controller: _storyControllerFor(state.member!.id),
              onBack: () {
                setState(() {
                  _destination = _AuthenticatedDestination.home;
                });
              },
            );
          }

          final homeController = _homeControllerFor(state.member!.id);
          return HomeScreen(
            routeTitle: initialRoute.title,
            nickname: state.member!.nickname,
            homeController: homeController,
            onWriteDiary: () {
              setState(() {
                _destination = _AuthenticatedDestination.diary;
              });
            },
            onWriteLetter: () {
              setState(() {
                _openLetterComposer = true;
                _destination = _AuthenticatedDestination.letter;
              });
            },
            onViewStory: () {
              setState(() {
                _destination = _AuthenticatedDestination.story;
              });
            },
            onOpenConsultation: () {
              setState(() {
                _destination = _AuthenticatedDestination.consultation;
              });
            },
            onOpenNotifications: () {
              setState(() {
                _destination = _AuthenticatedDestination.notifications;
              });
            },
            onOpenSettings: () {
              setState(() {
                _destination = _AuthenticatedDestination.settings;
              });
            },
            onLogout: () {
              _disposeHomeController();
              _disposeConsultationController();
              _disposeNotificationController();
              _disposeReportController();
              _disposeSettingsController();
              _disposeDiaryController();
              _disposeStoryController();
              _disposeLetterController();
              _destination = _AuthenticatedDestination.home;
              _authController.logout();
            },
          );
        },
      ),
    );
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
    return _consultationController = ConsultationController(
      repository: widget.consultationRepository ??
          _buildDefaultConsultationRepository(),
      onUnauthorized: () {
        _authController.logout();
      },
    );
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

    currentController?.dispose();
    _notificationMemberId = memberId;
    return _notificationController = NotificationController(
      repository:
          widget.notificationRepository ?? _buildDefaultNotificationRepository(),
      onUnauthorized: () {
        _authController.logout();
      },
    );
  }

  void _disposeNotificationController() {
    _notificationController?.dispose();
    _notificationController = null;
    _notificationMemberId = null;
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
      onUnauthorized: () {
        _authController.logout();
      },
    );
  }

  void _disposeReportController() {
    _reportController?.dispose();
    _reportController = null;
    _reportMemberId = null;
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
      onUnauthorized: () {
        _authController.logout();
      },
      onWithdrawn: _authController.clearSession,
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
    return _diaryController = DiaryController(
      diaryRepository: widget.diaryRepository ?? _buildDefaultDiaryRepository(),
      onUnauthorized: () {
        _authController.logout();
      },
    );
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
    return _storyController = StoryController(
      storyRepository: widget.storyRepository ?? _buildDefaultStoryRepository(),
      currentMemberId: memberId,
      onUnauthorized: () {
        _authController.logout();
      },
      onReportTargetSelected: _handleStoryReportTarget,
    );
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
    return _letterController = LetterController(
      letterRepository:
          widget.letterRepository ?? _buildDefaultLetterRepository(),
      onUnauthorized: () {
        _authController.logout();
      },
      onReportTargetSelected: _handleLetterReportTarget,
    );
  }

  void _disposeLetterController() {
    _letterController?.dispose();
    _letterController = null;
    _letterMemberId = null;
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

  DiaryRepository _buildDefaultDiaryRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiDiaryRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
    );
  }

  LetterRepository _buildDefaultLetterRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiLetterRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
    );
  }

  ConsultationRepository _buildDefaultConsultationRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiConsultationRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
      streamClient: DioConsultationStreamClient(
        apiConfig: _apiConfig,
        tokenStore: _tokenStore,
      ),
    );
  }

  NotificationRepository _buildDefaultNotificationRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiNotificationRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
      streamClient: DioNotificationStreamClient(apiConfig: _apiConfig),
    );
  }

  ReportRepository _buildDefaultReportRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiReportRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
    );
  }

  SettingsRepository _buildDefaultSettingsRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiSettingsRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
      ),
    );
  }

  StoryRepository _buildDefaultStoryRepository() {
    final refreshRepository = ApiAuthRepository(
      apiClient: ApiClient(transport: _apiTransport, tokenStore: _tokenStore),
      tokenStore: _tokenStore,
    );

    return ApiStoryRepository(
      apiClient: ApiClient(
        transport: _apiTransport,
        tokenStore: _tokenStore,
        tokenRefresher: AuthSessionTokenRefresher(
          authRepository: refreshRepository,
        ),
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
      _destination = _AuthenticatedDestination.notifications;
    });
  }
}

enum _AuthenticatedDestination {
  home,
  consultation,
  notifications,
  settings,
  diary,
  letter,
  story,
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
