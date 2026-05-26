import 'package:flutter/foundation.dart';

enum LoginProvider {
  kakao,
}

class LoginProviderPolicy {
  const LoginProviderPolicy._();

  static List<LoginProvider> providersFor(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      return const [];
    }
    return const [LoginProvider.kakao];
  }

  static bool showsReviewEmailGuidance(TargetPlatform platform) {
    return platform == TargetPlatform.iOS;
  }
}

extension LoginProviderPresentation on LoginProvider {
  String get buttonKey {
    return switch (this) {
      LoginProvider.kakao => 'external-login-kakao-button',
    };
  }

  String get providerId {
    return switch (this) {
      LoginProvider.kakao => 'kakao',
    };
  }

  String get label {
    return switch (this) {
      LoginProvider.kakao => '카카오로 계속하기',
    };
  }
}
