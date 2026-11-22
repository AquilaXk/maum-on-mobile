import 'api_config.dart';
import 'http_transport_codec.dart';

ManagedApiTransport createHttpApiTransport(
  ApiConfig config, {
  Duration connectTimeout = defaultConnectTimeout,
  Duration requestTimeout = defaultRequestTimeout,
  int maxResponseBytes = defaultMaxResponseBytes,
}) {
  throw UnsupportedError(
    'HttpApiTransport is not supported on this platform.',
  );
}
