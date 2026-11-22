import '../../../core/network/api_config.dart';
import '../../../core/network/api_error.dart';
import '../domain/notification_models.dart';
import 'notification_stream_client.dart';

ManagedNotificationStreamClient createNotificationStreamClient({
  required ApiConfig apiConfig,
}) {
  return const WebNotificationStreamClient();
}

class WebNotificationStreamClient implements ManagedNotificationStreamClient {
  const WebNotificationStreamClient();

  @override
  void close({bool force = true}) {}

  @override
  Stream<NotificationStreamEvent> connect(String ticket) async* {
    throw const ApiClientException(
      kind: ApiErrorKind.unknown,
      message: '웹 환경에서는 실시간 알림 스트림을 지원하지 않습니다.',
    );
  }
}
