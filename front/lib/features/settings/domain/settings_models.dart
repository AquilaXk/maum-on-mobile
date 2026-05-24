class MemberSettings {
  const MemberSettings({
    required this.id,
    required this.email,
    required this.nickname,
    required this.randomReceiveAllowed,
    required this.socialAccount,
  });

  factory MemberSettings.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected member settings object.');
    }

    final map = _stringKeyedMap(json);
    return MemberSettings(
      id: _readInt(map, 'id'),
      email: map['email']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '',
      randomReceiveAllowed: _readBool(map, 'randomReceiveAllowed'),
      socialAccount: _readBool(map, 'socialAccount'),
    );
  }

  final int id;
  final String email;
  final String nickname;
  final bool randomReceiveAllowed;
  final bool socialAccount;

  MemberSettings copyWith({
    String? email,
    String? nickname,
    bool? randomReceiveAllowed,
    bool? socialAccount,
  }) {
    return MemberSettings(
      id: id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      randomReceiveAllowed:
          randomReceiveAllowed ?? this.randomReceiveAllowed,
      socialAccount: socialAccount ?? this.socialAccount,
    );
  }
}

class PasswordChangeDraft {
  const PasswordChangeDraft({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  Map<String, Object?> toJson() {
    return {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
  }
}

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }

  return value?.toString().toLowerCase() == 'true';
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}
