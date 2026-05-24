class MultipartBody {
  MultipartBody({
    Map<String, String> fields = const {},
    List<MultipartTextPart> textParts = const [],
    List<MultipartFilePart> files = const [],
  })  : fields = Map.unmodifiable(fields),
        textParts = List.unmodifiable(textParts),
        files = List.unmodifiable(files);

  factory MultipartBody.image(
    MultipartFilePart image, {
    Map<String, String> fields = const {},
  }) {
    return MultipartBody(fields: fields, files: [image]);
  }

  final Map<String, String> fields;
  final List<MultipartTextPart> textParts;
  final List<MultipartFilePart> files;
}

class MultipartTextPart {
  const MultipartTextPart({
    required this.fieldName,
    required this.value,
    this.contentType,
  });

  final String fieldName;
  final String value;
  final String? contentType;
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
