import 'package:flutter/foundation.dart';

enum LoginProvider {
  apple,
  kakao,
}

class LoginProviderPolicy {
  const LoginProviderPolicy._();

  static List<LoginProvider> providersFor(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      return const [LoginProvider.apple];
    }
    return const [LoginProvider.kakao];
  }

  static bool showsReviewEmailGuidance(TargetPlatform platform) {
    return false;
  }
}

extension LoginProviderPresentation on LoginProvider {
  String get buttonKey {
    return switch (this) {
      LoginProvider.apple => 'external-login-apple-button',
      LoginProvider.kakao => 'external-login-kakao-button',
    };
  }

  String get providerId {
    return switch (this) {
      LoginProvider.apple => 'apple',
      LoginProvider.kakao => 'kakao',
    };
  }

  String get label {
    return switch (this) {
      LoginProvider.apple => 'Apple로 계속하기',
      LoginProvider.kakao => '카카오로 계속하기',
    };
  }
}
