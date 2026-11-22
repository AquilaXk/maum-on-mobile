import '../../../core/network/api_config.dart';
import 'notification_stream_client.dart';

ManagedNotificationStreamClient createNotificationStreamClient({
  required ApiConfig apiConfig,
}) {
  throw UnsupportedError(
    'HttpNotificationStreamClient is not supported on this platform.',
  );
}
