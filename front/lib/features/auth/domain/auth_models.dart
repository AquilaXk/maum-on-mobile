class AuthMember {
  const AuthMember({
    required this.id,
    required this.email,
    required this.nickname,
    required this.role,
    required this.status,
  });

  factory AuthMember.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected auth member object.');
    }

    final map = _stringKeyedMap(json);
    return AuthMember(
      id: _readInt(map, 'id'),
      email: map['email']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }

  final int id;
  final String email;
  final String nickname;
  final String role;
  final String status;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.member,
    this.refreshToken,
  });

  factory AuthSession.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected auth session object.');
    }

    final map = _stringKeyedMap(json);
    return AuthSession(
      accessToken: map['accessToken']?.toString() ?? '',
      tokenType: map['tokenType']?.toString() ?? 'Bearer',
      expiresInSeconds: _readInt(map, 'expiresInSeconds'),
      refreshToken: map['refreshToken']?.toString(),
      member: AuthMember.fromJson(map['member']),
    );
  }

  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;
  final String? refreshToken;
  final AuthMember member;
}

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  Map<String, Object?> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class SignupRequest {
  const SignupRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  Map<String, Object?> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
    };
  }
}

class PasswordResetRequest {
  const PasswordResetRequest({
    required this.email,
  });

  final String email;

  Map<String, Object?> toJson() {
    return {
      'email': email,
    };
  }
}

class PasswordResetConfirmRequest {
  const PasswordResetConfirmRequest({
    required this.token,
    required this.newPassword,
  });

  final String token;
  final String newPassword;

  Map<String, Object?> toJson() {
    return {
      'token': token,
      'newPassword': newPassword,
    };
  }
}

class OidcSessionRequest {
  const OidcSessionRequest({
    required this.provider,
    required this.code,
    required this.state,
  });

  final String provider;
  final String code;
  final String state;

  Map<String, Object?> toJson() {
    return {
      'code': code,
      'state': state,
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

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}
