import '../domain/notification_models.dart';

abstract interface class NotificationStreamClient {
  Stream<NotificationStreamEvent> connect(String ticket);
}

abstract interface class ManagedNotificationStreamClient
    implements NotificationStreamClient {
  void close({bool force = true});
}
