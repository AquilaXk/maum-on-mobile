import '../../../core/network/api_client.dart';
import '../../../core/network/multipart_body.dart';
import '../domain/diary_models.dart';

abstract interface class DiaryImageRepository {
  Future<UploadedDiaryImage> uploadImage(DiaryImageAttachment image);

  Future<void> deleteImage(String imageUrl);
}

class UploadedDiaryImage {
  const UploadedDiaryImage({
    required this.imageUrl,
    required this.originalFilename,
    required this.contentType,
    required this.byteSize,
    required this.status,
  });

  factory UploadedDiaryImage.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected uploaded image object.');
    }

    return UploadedDiaryImage(
      imageUrl: json['imageUrl']?.toString() ?? '',
      originalFilename: json['originalFilename']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      byteSize: _readInt(json['byteSize']),
      status: json['status']?.toString() ?? '',
    );
  }

  final String imageUrl;
  final String originalFilename;
  final String contentType;
  final int byteSize;
  final String status;
}

class ApiDiaryImageRepository implements DiaryImageRepository {
  const ApiDiaryImageRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UploadedDiaryImage> uploadImage(DiaryImageAttachment image) {
    return _apiClient.postMultipart<UploadedDiaryImage>(
      '/api/v1/images/upload',
      multipart: MultipartBody.image(
        MultipartFilePart(
          fieldName: 'image',
          filename: image.filename,
          bytes: image.bytes,
        ),
      ),
      parser: UploadedDiaryImage.fromJson,
    );
  }

  @override
  Future<void> deleteImage(String imageUrl) {
    return _apiClient.deleteVoid(
      '/api/v1/images',
      body: {'imageUrl': imageUrl},
    );
  }
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
