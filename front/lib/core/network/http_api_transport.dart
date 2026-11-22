import 'api_config.dart';
import 'api_transport.dart';
import 'http_api_transport_stub.dart'
    if (dart.library.io) 'http_api_transport_io.dart'
    if (dart.library.js_interop) 'http_api_transport_web.dart' as impl;
import 'http_transport_codec.dart';

class HttpApiTransport implements ApiTransport {
  HttpApiTransport({
    required ApiConfig config,
    Duration connectTimeout = defaultConnectTimeout,
    Duration requestTimeout = defaultRequestTimeout,
    int maxResponseBytes = defaultMaxResponseBytes,
  }) : _delegate = impl.createHttpApiTransport(
          config,
          connectTimeout: connectTimeout,
          requestTimeout: requestTimeout,
          maxResponseBytes: maxResponseBytes,
        );

  factory HttpApiTransport.fromConfig(ApiConfig config) {
    return HttpApiTransport(config: config);
  }

  final ManagedApiTransport _delegate;

  @override
  Future<ApiTransportResponse> send(ApiRequest request) {
    return _delegate.send(request);
  }

  void close({bool force = false}) {
    _delegate.close(force: force);
  }
}
