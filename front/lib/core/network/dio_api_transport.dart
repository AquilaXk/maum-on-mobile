import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_transport.dart';
import 'multipart_body.dart';

class DioApiTransport implements ApiTransport {
  DioApiTransport(this._dio);

  factory DioApiTransport.fromConfig(ApiConfig config) {
    return DioApiTransport(
      Dio(
        BaseOptions(
          baseUrl: config.baseUrl.toString(),
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (_) => true,
        ),
      ),
    );
  }

  final Dio _dio;

  @override
  Future<ApiTransportResponse> send(ApiRequest request) async {
    try {
      final response = await _dio.request<Object?>(
        request.path,
        data: request.multipart == null
            ? request.body
            : _formDataFromMultipart(request.multipart!),
        queryParameters:
            request.queryParameters.isEmpty ? null : request.queryParameters,
        options: Options(
          method: _methodName(request.method),
          headers: request.headers,
        ),
      );

      return ApiTransportResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (error) {
      throw ApiTransportException(
        error.message ?? 'Network request failed.',
        error,
      );
    }
  }

  FormData _formDataFromMultipart(MultipartBody body) {
    final formData = FormData();

    formData.fields.addAll(body.fields.entries);
    for (final textPart in body.textParts) {
      formData.files.add(
        MapEntry(
          textPart.fieldName,
          MultipartFile.fromString(
            textPart.value,
            contentType: textPart.contentType == null
                ? null
                : DioMediaType.parse(textPart.contentType!),
          ),
        ),
      );
    }

    for (final file in body.files) {
      formData.files.add(
        MapEntry(
          file.fieldName,
          MultipartFile.fromBytes(file.bytes, filename: file.filename),
        ),
      );
    }

    return formData;
  }

  String _methodName(ApiMethod method) {
    return switch (method) {
      ApiMethod.get => 'GET',
      ApiMethod.post => 'POST',
      ApiMethod.put => 'PUT',
      ApiMethod.patch => 'PATCH',
      ApiMethod.delete => 'DELETE',
    };
  }
}
