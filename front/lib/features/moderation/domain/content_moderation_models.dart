import '../../../core/network/api_error.dart';

enum ContentModerationTarget {
  story(apiValue: 'STORY'),
  comment(apiValue: 'COMMENT'),
  diary(apiValue: 'DIARY'),
  letter(apiValue: 'LETTER'),
  report(apiValue: 'REPORT'),
  consultation(apiValue: 'CONSULTATION');

  const ContentModerationTarget({required this.apiValue});

  final String apiValue;
}

enum ContentModerationRiskLevel {
  low(apiValue: 'LOW'),
  high(apiValue: 'HIGH');

  const ContentModerationRiskLevel({required this.apiValue});

  final String apiValue;

  static ContentModerationRiskLevel fromApiValue(String value) {
    return switch (value) {
      'LOW' => ContentModerationRiskLevel.low,
      'HIGH' => ContentModerationRiskLevel.high,
      _ => ContentModerationRiskLevel.high,
    };
  }
}

enum ContentModerationCategory {
  profanity(apiValue: 'PROFANITY'),
  selfHarm(apiValue: 'SELF_HARM'),
  violence(apiValue: 'VIOLENCE'),
  abuse(apiValue: 'ABUSE'),
  personalInfo(apiValue: 'PERSONAL_INFO'),
  spam(apiValue: 'SPAM'),
  inappropriate(apiValue: 'INAPPROPRIATE');

  const ContentModerationCategory({required this.apiValue});

  final String apiValue;

  static ContentModerationCategory fromApiValue(String value) {
    return switch (value) {
      'PROFANITY' => ContentModerationCategory.profanity,
      'SELF_HARM' => ContentModerationCategory.selfHarm,
      'VIOLENCE' => ContentModerationCategory.violence,
      'ABUSE' => ContentModerationCategory.abuse,
      'PERSONAL_INFO' => ContentModerationCategory.personalInfo,
      'SPAM' => ContentModerationCategory.spam,
      'INAPPROPRIATE' => ContentModerationCategory.inappropriate,
      _ => ContentModerationCategory.inappropriate,
    };
  }
}

class ContentModerationRequest {
  const ContentModerationRequest({
    required this.targetType,
    required this.text,
  });

  final ContentModerationTarget targetType;
  final String text;

  Map<String, Object?> toJson() {
    return {
      'targetType': targetType.apiValue,
      'text': text,
    };
  }
}

class ContentModerationResult {
  const ContentModerationResult({
    required this.allowed,
    required this.riskLevel,
    required this.message,
    required this.categories,
  });

  final bool allowed;
  final ContentModerationRiskLevel riskLevel;
  final String message;
  final List<ContentModerationCategory> categories;

  factory ContentModerationResult.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected content moderation result object.');
    }

    final map = json.map((key, value) => MapEntry(key.toString(), value));
    final categories = map['categories'] is List
        ? (map['categories'] as List)
            .map((value) => ContentModerationCategory.fromApiValue(
                  value.toString(),
                ))
            .toList(growable: false)
        : const <ContentModerationCategory>[];

    return ContentModerationResult(
      allowed: map['allowed'] == true,
      riskLevel: ContentModerationRiskLevel.fromApiValue(
        map['riskLevel']?.toString() ?? 'HIGH',
      ),
      message: map['message']?.toString() ?? '입력 내용을 확인해 주세요.',
      categories: categories,
    );
  }
}

enum ContentModerationFeedbackStatus {
  policyBlocked,
  networkError,
  modelUnavailable,
}

class ContentModerationFeedback {
  const ContentModerationFeedback({
    required this.targetType,
    required this.status,
    required this.riskLevel,
    required this.categories,
    required this.title,
    required this.message,
    required this.guidanceItems,
    this.primaryActionLabel = '수정 후 다시 검수',
    this.dismissActionLabel = '취소',
  });

  factory ContentModerationFeedback.blocked({
    required ContentModerationTarget targetType,
    required ContentModerationResult result,
  }) {
    return ContentModerationFeedback(
      targetType: targetType,
      status: ContentModerationFeedbackStatus.policyBlocked,
      riskLevel: result.riskLevel,
      categories: result.categories,
      title: '${targetType.displayLabel} 표현을 수정해 주세요.',
      message: '${result.message} 입력 내용은 그대로 유지됩니다. '
          '아래 안내를 보고 표현을 고친 뒤 다시 검수해 주세요.',
      guidanceItems: result.categories.guidanceItems(),
    );
  }

  factory ContentModerationFeedback.failure({
    required ContentModerationTarget targetType,
    required ApiClientException error,
  }) {
    final isNetwork = error.kind == ApiErrorKind.network;
    return ContentModerationFeedback(
      targetType: targetType,
      status: isNetwork
          ? ContentModerationFeedbackStatus.networkError
          : ContentModerationFeedbackStatus.modelUnavailable,
      riskLevel: ContentModerationRiskLevel.high,
      categories: const [],
      title: isNetwork ? '연결 후 다시 검수해 주세요.' : '검수 결과를 불러오지 못했습니다.',
      message: isNetwork
          ? '네트워크 연결을 확인해 주세요. 입력 내용은 그대로 유지됩니다.'
          : '검수 결과를 확인하지 못했습니다. 입력 내용은 그대로 유지됩니다. 잠시 후 다시 시도해 주세요.',
      guidanceItems: [
        if (isNetwork)
          '네트워크 연결 상태를 확인한 뒤 다시 검수해 주세요.'
        else
          '잠시 후 다시 검수해 주세요. 같은 문제가 반복되면 입력 내용은 유지한 채 나중에 다시 시도할 수 있습니다.',
      ],
    );
  }

  final ContentModerationTarget targetType;
  final ContentModerationFeedbackStatus status;
  final ContentModerationRiskLevel riskLevel;
  final List<ContentModerationCategory> categories;
  final String title;
  final String message;
  final List<String> guidanceItems;
  final String primaryActionLabel;
  final String dismissActionLabel;
}

extension ContentModerationTargetLabel on ContentModerationTarget {
  String get displayLabel {
    return switch (this) {
      ContentModerationTarget.story => '스토리',
      ContentModerationTarget.comment => '댓글',
      ContentModerationTarget.diary => '기록',
      ContentModerationTarget.letter => '편지',
      ContentModerationTarget.report => '신고 내용',
      ContentModerationTarget.consultation => 'AI 상담',
    };
  }
}

extension ContentModerationCategoryGuidance on List<ContentModerationCategory> {
  List<String> guidanceItems() {
    final items = map((category) => category.guidanceText)
        .toSet()
        .toList(growable: false);
    if (items.isEmpty) {
      return const ['상대가 불편하게 느낄 수 있는 표현을 구체적으로 순화해 주세요.'];
    }
    return items;
  }
}

extension on ContentModerationCategory {
  String get guidanceText {
    return switch (this) {
      ContentModerationCategory.profanity =>
        '비난, 욕설, 위협으로 읽힐 수 있는 표현을 부드럽게 바꿔 주세요.',
      ContentModerationCategory.selfHarm =>
        '자해나 극단적 선택을 부추기거나 구체화하는 표현은 도움 요청 중심으로 바꿔 주세요.',
      ContentModerationCategory.violence =>
        '폭력, 위협, 보복으로 읽힐 수 있는 표현은 안전 확보와 감정 설명 중심으로 바꿔 주세요.',
      ContentModerationCategory.abuse =>
        '학대, 착취, 가족 비하로 읽힐 수 있는 표현은 구체적인 도움 요청이나 상황 설명으로 바꿔 주세요.',
      ContentModerationCategory.personalInfo =>
        '전화번호, 이메일, 주소처럼 개인을 특정할 수 있는 표현을 지워 주세요.',
      ContentModerationCategory.spam => '광고, 반복 홍보, 외부 유도 표현을 줄여 주세요.',
      ContentModerationCategory.inappropriate =>
        '상대가 불편하거나 위험하다고 느낄 수 있는 표현을 구체적으로 순화해 주세요.',
    };
  }
}
