class MultipartBody {
  MultipartBody({
    Map<String, String> fields = const {},
    List<MultipartFilePart> files = const [],
  })  : fields = Map.unmodifiable(fields),
        files = List.unmodifiable(files);

  factory MultipartBody.image(
    MultipartFilePart image, {
    Map<String, String> fields = const {},
  }) {
    return MultipartBody(fields: fields, files: [image]);
  }

  final Map<String, String> fields;
  final List<MultipartFilePart> files;
}

class MultipartFilePart {
  MultipartFilePart({
    required this.fieldName,
    required this.filename,
    required List<int> bytes,
  }) : bytes = List.unmodifiable(bytes);

  final String fieldName;
  final String filename;
  final List<int> bytes;
}
