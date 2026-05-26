import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';
import 'package:maum_on_mobile_front/features/letter/domain/letter_models.dart';
import 'package:maum_on_mobile_front/features/moderation/domain/content_moderation_models.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';
import 'package:maum_on_mobile_front/features/operations/domain/operations_models.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';
import 'package:maum_on_mobile_front/features/settings/domain/settings_models.dart';
import 'package:maum_on_mobile_front/features/story/domain/story_models.dart';

void main() {
  group('mobile API response snapshots', () {
    test('cover every mobile API area', () {
      final contract = _readContract();
      final areas = _snapshots(contract)
          .map((snapshot) => snapshot['area']?.toString())
          .toSet();

      expect(areas, {
        'auth',
        'home',
        'diary',
        'story',
        'letter',
        'consultation',
        'notification',
        'settings',
        'operations',
        'moderation',
        'report',
      });
    });

    test('parse success and error envelopes with Flutter models', () {
      final contract = _readContract();

      for (final snapshot in _snapshots(contract)) {
        final response = _map(snapshot['response'], 'snapshot response');
        final parser = snapshot['parser']?.toString() ?? 'raw';
        final envelope = ApiEnvelope<Object?>.fromJson(
          response,
          (json) => _parseSnapshot(parser, json),
        );

        if (response['success'] == true) {
          expect(
            envelope.data,
            isNotNull,
            reason:
                '${snapshot['id']} must remain parseable by Flutter model parser $parser.',
          );
        } else {
          expect(envelope.success, isFalse);
          expect(envelope.error, isA<ApiErrorBody>());
          expect(
            envelope.error?.fieldErrors,
            isA<List<ApiFieldError>>(),
            reason: '${snapshot['id']} must keep stable fieldErrors.',
          );
        }
      }
    });

    test('Flutter enum parsers match snapshot schema values', () {
      final enumValues = _map(
        _map(_readContract()['schema'], 'schema')['enumValues'],
        'enumValues',
      );

      _expectEnumValues(
        enumValues,
        'storyCategory',
        StoryCategory.values
            .map((value) => value.apiValue)
            .whereType<String>()
            .toList(),
      );
      _expectEnumValues(
        enumValues,
        'storyResolutionStatus',
        StoryResolutionStatus.values.map((value) => value.apiValue).toList(),
      );
      _expectEnumValues(
        enumValues,
        'letterStatus',
        LetterStatus.values.map((value) => value.apiValue).toList(),
      );
      _expectEnumValues(
        enumValues,
        'reportTargetType',
        ReportTargetType.values.map((value) => value.apiValue).toList(),
      );
      _expectEnumValues(
        enumValues,
        'reportReason',
        ReportReasonCode.values.map((value) => value.apiValue).toList(),
      );
      _expectEnumValues(
        enumValues,
        'notificationDevicePlatform',
        NotificationDevicePlatform.values
            .map((value) => value.apiValue)
            .toList(),
      );
      _expectEnumValues(
        enumValues,
        'moderationTarget',
        ContentModerationTarget.values.map((value) => value.apiValue).toList(),
      );
      _expectEnumValues(
        enumValues,
        'moderationRiskLevel',
        ContentModerationRiskLevel.values
            .map((value) => value.apiValue)
            .toList(),
      );
      _expectEnumValues(
        enumValues,
        'moderationCategory',
        ContentModerationCategory.values
            .map((value) => value.apiValue)
            .toList(),
      );
    });
  });
}

Map<String, Object?> _readContract() {
  final file = File('../contracts/mobile-api/response-snapshots.json');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing shared mobile API contract snapshot file: ${file.path}',
  );
  return _map(jsonDecode(file.readAsStringSync()), 'mobile API contract');
}

List<Map<String, Object?>> _snapshots(Map<String, Object?> contract) {
  final snapshots = contract['snapshots'];
  if (snapshots is! List) {
    throw const FormatException('Expected contract snapshots array.');
  }
  return snapshots
      .map((snapshot) => _map(snapshot, 'mobile API snapshot'))
      .toList(growable: false);
}

Object? _parseSnapshot(String parser, Object? json) {
  return switch (parser) {
    'auth.member' => AuthMember.fromJson(json),
    'auth.session' => AuthSession.fromJson(json),
    'home.stats' => HomeStats.fromJson(json),
    'story.page' => PageResponse<StorySummary>.fromJson(
        json,
        StorySummary.fromJson,
      ),
    'story.detail' => StoryDetail.fromJson(json),
    'story.commentsPage' => PageResponse<StoryComment>.fromJson(
        json,
        StoryComment.fromJson,
      ),
    'diary.page' => PageResponse<DiaryEntry>.fromJson(
        json,
        DiaryEntry.fromJson,
      ),
    'diary.detail' => DiaryEntry.fromJson(json),
    'letter.list' => LetterListPage.fromJson(json),
    'letter.detail' => LetterDetail.fromJson(json),
    'letter.stats' => LetterStats.fromJson(json),
    'consultation.chat' => ConsultationSendResult.fromJson(json),
    'consultation.history' => _list(json, 'consultation history')
        .map(ConsultationMessage.fromJson)
        .toList(growable: false),
    'notification.list' => _list(json, 'notification list')
        .map(NotificationItem.fromJson)
        .toList(growable: false),
    'notification.ticket' => NotificationSubscriptionTicket.fromJson(json),
    'notification.deviceToken' => NotificationDeviceTokenResult.fromJson(json),
    'settings.profile' => MemberSettings.fromJson(json),
    'settings.exportJob' => MemberDataExportJob.fromJson(json),
    'operations.dashboard' => OperationsDashboard.fromJson(json),
    'operations.metrics' => MobileApiMetricsSnapshot.fromJson(json),
    'moderation.review' => ContentModerationResult.fromJson(json),
    'report.adminList' => _list(json, 'admin report list')
        .map(AdminReportSummary.fromJson)
        .toList(growable: false),
    'raw' => json,
    _ => throw FormatException(
        'Unknown mobile API snapshot parser "$parser". '
        'Update front/test/contracts/mobile_api_contract_snapshot_test.dart.',
      ),
  };
}

void _expectEnumValues(
  Map<String, Object?> enumValues,
  String name,
  List<String> expected,
) {
  expect(
    _list(enumValues[name], name),
    expected,
    reason:
        'Update contracts/mobile-api/response-snapshots.json schema.enumValues.$name and matching Flutter parsers together.',
  );
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Expected $label object.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _list(Object? value, String label) {
  if (value is! List) {
    throw FormatException('Expected $label list.');
  }
  return value;
}
