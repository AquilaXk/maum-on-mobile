enum ContentModerationTarget {
  story(apiValue: 'STORY'),
  comment(apiValue: 'COMMENT'),
  diary(apiValue: 'DIARY'),
  letter(apiValue: 'LETTER'),
  report(apiValue: 'REPORT');

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
  personalInfo(apiValue: 'PERSONAL_INFO'),
  spam(apiValue: 'SPAM'),
  inappropriate(apiValue: 'INAPPROPRIATE');

  const ContentModerationCategory({required this.apiValue});

  final String apiValue;

  static ContentModerationCategory fromApiValue(String value) {
    return switch (value) {
      'PROFANITY' => ContentModerationCategory.profanity,
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
