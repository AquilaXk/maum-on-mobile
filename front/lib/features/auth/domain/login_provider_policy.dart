import 'package:flutter/foundation.dart';

enum LoginProvider {
  naver,
  kakao,
  facebook,
  google,
  apple,
}

class LoginProviderPolicy {
  const LoginProviderPolicy._();

  static const allProviders = [
    LoginProvider.naver,
    LoginProvider.kakao,
    LoginProvider.facebook,
    LoginProvider.google,
    LoginProvider.apple,
  ];

  static const _enabledProviderIds = String.fromEnvironment(
    'LOGIN_PROVIDER_IDS',
    defaultValue: '',
  );

  static List<LoginProvider> providersFor(
    TargetPlatform _, {
    String enabledProviderIds = _enabledProviderIds,
  }) {
    final enabledIds = enabledProviderIds
        .split(',')
        .map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (enabledIds.isEmpty) {
      return const [];
    }

    return [
      for (final provider in allProviders)
        if (enabledIds.contains(provider.providerId)) provider,
    ];
  }

  static bool showsReviewEmailGuidance(TargetPlatform platform) {
    return false;
  }
}

extension LoginProviderPresentation on LoginProvider {
  String get buttonKey {
    return switch (this) {
      LoginProvider.naver => 'external-login-naver-button',
      LoginProvider.kakao => 'external-login-kakao-button',
      LoginProvider.facebook => 'external-login-facebook-button',
      LoginProvider.google => 'external-login-google-button',
      LoginProvider.apple => 'external-login-apple-button',
    };
  }

  String get providerId {
    return switch (this) {
      LoginProvider.naver => 'naver',
      LoginProvider.kakao => 'kakao',
      LoginProvider.facebook => 'facebook',
      LoginProvider.google => 'google',
      LoginProvider.apple => 'apple',
    };
  }

  String get label {
    return switch (this) {
      LoginProvider.naver => '네이버로 계속하기',
      LoginProvider.kakao => '카카오로 계속하기',
      LoginProvider.facebook => 'Facebook으로 계속하기',
      LoginProvider.google => 'Google로 계속하기',
      LoginProvider.apple => 'Apple로 계속하기',
    };
  }
}
