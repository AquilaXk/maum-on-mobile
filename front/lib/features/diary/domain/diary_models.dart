import 'dart:convert';

enum DiaryCategory {
  love(label: '연애'),
  friend(label: '친구'),
  career(label: '진로'),
  family(label: '가족'),
  work(label: '직장'),
  daily(label: '일상'),
  etc(label: '기타');

  const DiaryCategory({required this.label});

  final String label;

  static DiaryCategory fromApiValue(Object? value) {
    final text = value?.toString();
    for (final category in DiaryCategory.values) {
      if (category.label == text) {
        return category;
      }
    }

    return DiaryCategory.etc;
  }
}

enum DiaryImageSource {
  camera(label: '카메라'),
  gallery(label: '앨범');

  const DiaryImageSource({required this.label});

  final String label;
}

class DiaryImageAttachment {
  const DiaryImageAttachment({
    required this.filename,
    required this.bytes,
    this.source = DiaryImageSource.gallery,
    this.contentType = 'image/jpeg',
    int? originalByteSize,
    this.width,
    this.height,
    this.wasCompressed = false,
  }) : _originalByteSize = originalByteSize;

  final String filename;
  final List<int> bytes;
  final DiaryImageSource source;
  final String contentType;
  final int? _originalByteSize;
  final int? width;
  final int? height;
  final bool wasCompressed;

  int get originalByteSize => _originalByteSize ?? bytes.length;

  int get byteSize => bytes.length;
}

enum DiaryContentBlockType {
  text,
  image;

  static DiaryContentBlockType fromValue(Object? value) {
    return DiaryContentBlockType.values.firstWhere(
      (type) => type.name == value?.toString(),
      orElse: () => DiaryContentBlockType.text,
    );
  }
}

enum DiaryImageBlockUploadStatus {
  pending(label: '업로드 대기'),
  uploading(label: '업로드 중'),
  uploaded(label: '업로드 완료'),
  failed(label: '업로드 실패');

  const DiaryImageBlockUploadStatus({required this.label});

  final String label;

  static DiaryImageBlockUploadStatus fromValue(Object? value) {
    return DiaryImageBlockUploadStatus.values.firstWhere(
      (status) => status.name == value?.toString(),
      orElse: () => DiaryImageBlockUploadStatus.pending,
    );
  }
}

class DiaryContentBlock {
  const DiaryContentBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.imageUrl,
    this.image,
    this.uploadStatus = DiaryImageBlockUploadStatus.pending,
    this.uploadProgress,
    this.errorMessage,
    this.filename,
    this.byteSize,
    this.source,
    this.contentType,
  });

  factory DiaryContentBlock.text({
    required String id,
    String text = '',
  }) {
    return DiaryContentBlock(
      id: id,
      type: DiaryContentBlockType.text,
      text: text,
    );
  }

  factory DiaryContentBlock.image({
    required String id,
    String? imageUrl,
    DiaryImageAttachment? image,
    DiaryImageBlockUploadStatus uploadStatus =
        DiaryImageBlockUploadStatus.pending,
    double? uploadProgress,
    String? errorMessage,
    String? filename,
    int? byteSize,
    DiaryImageSource? source,
    String? contentType,
  }) {
    return DiaryContentBlock(
      id: id,
      type: DiaryContentBlockType.image,
      imageUrl: imageUrl,
      image: image,
      uploadStatus: imageUrl == null
          ? uploadStatus
          : DiaryImageBlockUploadStatus.uploaded,
      uploadProgress: uploadProgress,
      errorMessage: errorMessage,
      filename: filename ?? image?.filename,
      byteSize: byteSize ?? image?.byteSize,
      source: source ?? image?.source,
      contentType: contentType ?? image?.contentType,
    );
  }

  factory DiaryContentBlock.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected diary content block object.');
    }

    final map = _stringKeyedMap(json);
    final type = DiaryContentBlockType.fromValue(map['type']);
    if (type == DiaryContentBlockType.text) {
      return DiaryContentBlock.text(
        id: _readBlockId(map['id']),
        text: map['text']?.toString() ?? '',
      );
    }

    final filename = _readNullableString(map['filename']);
    final uploadStatus =
        DiaryImageBlockUploadStatus.fromValue(map['uploadStatus']);
    return DiaryContentBlock.image(
      id: _readBlockId(map['id']),
      imageUrl: _readNullableString(map['imageUrl']),
      uploadStatus: _restoredImageStatus(
        imageUrl: _readNullableString(map['imageUrl']),
        status: uploadStatus,
      ),
      errorMessage: _restoredImageError(
        imageUrl: _readNullableString(map['imageUrl']),
        filename: filename,
        errorMessage: _readNullableString(map['errorMessage']),
      ),
      filename: filename,
      byteSize: _readNullableInt(map['byteSize']),
      source: _imageSourceFromValue(map['source']),
      contentType: _readNullableString(map['contentType']),
    );
  }

  final String id;
  final DiaryContentBlockType type;
  final String text;
  final String? imageUrl;
  final DiaryImageAttachment? image;
  final DiaryImageBlockUploadStatus uploadStatus;
  final double? uploadProgress;
  final String? errorMessage;
  final String? filename;
  final int? byteSize;
  final DiaryImageSource? source;
  final String? contentType;

  bool get isText => type == DiaryContentBlockType.text;

  bool get isImage => type == DiaryContentBlockType.image;

  bool get hasImage => image != null || imageUrl != null || filename != null;

  String get displayFilename => image?.filename ?? filename ?? '첨부 이미지';

  int? get displayByteSize => image?.byteSize ?? byteSize;

  DiaryImageSource? get displaySource => image?.source ?? source;

  DiaryContentBlock copyWith({
    String? id,
    DiaryContentBlockType? type,
    String? text,
    String? imageUrl,
    bool clearImageUrl = false,
    DiaryImageAttachment? image,
    bool clearImage = false,
    DiaryImageBlockUploadStatus? uploadStatus,
    double? uploadProgress,
    bool clearUploadProgress = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? filename,
    int? byteSize,
    DiaryImageSource? source,
    String? contentType,
  }) {
    return DiaryContentBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      image: clearImage ? null : image ?? this.image,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadProgress: clearUploadProgress
          ? null
          : uploadProgress ?? this.uploadProgress,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      filename: filename ?? this.filename,
      byteSize: byteSize ?? this.byteSize,
      source: source ?? this.source,
      contentType: contentType ?? this.contentType,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      if (isText) 'text': text,
      if (isImage) ...{
        'imageUrl': imageUrl,
        'uploadStatus': uploadStatus.name,
        'uploadProgress': uploadProgress,
        'errorMessage': errorMessage,
        'filename': displayFilename,
        'byteSize': displayByteSize,
        'source': displaySource?.name,
        'contentType': image?.contentType ?? contentType,
      },
    };
  }
}

class DiaryDraft {
  const DiaryDraft({
    required this.title,
    required this.content,
    required this.category,
    required this.isPrivate,
    this.imageUrl,
    this.image,
    this.contentBlocks = const [],
    this.moodScore,
    this.emotionTags,
    this.triggerTags,
  });

  final String title;
  final String content;
  final DiaryCategory category;
  final bool isPrivate;
  final String? imageUrl;
  final DiaryImageAttachment? image;
  final List<DiaryContentBlock> contentBlocks;
  final int? moodScore;
  final String? emotionTags;
  final String? triggerTags;
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.nickname,
    required this.imageUrl,
    required this.isPrivate,
    required this.createDate,
    required this.modifyDate,
    this.contentBlocks = const [],
    this.moodScore,
    this.emotionTags,
    this.triggerTags,
  });

  factory DiaryEntry.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected diary object.');
    }

    final map = _stringKeyedMap(json);
    final content = map['content']?.toString() ?? '';
    final imageUrl = _readNullableString(map['imageUrl']);
    final contentBlocks = _readContentBlocks(map['contentBlocks']);
    return DiaryEntry(
      id: _readInt(map, 'id'),
      title: map['title']?.toString() ?? '',
      content: content,
      category: DiaryCategory.fromApiValue(map['categoryName']),
      nickname: _readNickname(map['nickname']),
      imageUrl: imageUrl,
      isPrivate: map['isPrivate'] == true,
      createDate: map['createDate']?.toString() ?? '',
      modifyDate: map['modifyDate']?.toString() ?? '',
      contentBlocks: contentBlocks.isEmpty
          ? legacyDiaryContentBlocks(content: content, imageUrl: imageUrl)
          : contentBlocks,
      moodScore: _readNullableInt(map['moodScore']),
      emotionTags: _readNullableString(map['emotionTags']),
      triggerTags: _readNullableString(map['triggerTags']),
    );
  }

  final int id;
  final String title;
  final String content;
  final DiaryCategory category;
  final String nickname;
  final String? imageUrl;
  final bool isPrivate;
  final String createDate;
  final String modifyDate;
  final List<DiaryContentBlock> contentBlocks;
  final int? moodScore;
  final String? emotionTags;
  final String? triggerTags;

  String get dateKey => dateKeyFromDateTime(createDate);

  List<DiaryContentBlock> get readableContentBlocks {
    if (contentBlocks.isNotEmpty) {
      return contentBlocks;
    }

    return legacyDiaryContentBlocks(content: content, imageUrl: imageUrl);
  }

  DiaryEntry copyWith({
    String? title,
    String? content,
    DiaryCategory? category,
    String? nickname,
    String? imageUrl,
    bool clearImageUrl = false,
    bool? isPrivate,
    String? createDate,
    String? modifyDate,
    List<DiaryContentBlock>? contentBlocks,
    int? moodScore,
    bool clearMoodScore = false,
    String? emotionTags,
    bool clearEmotionTags = false,
    String? triggerTags,
    bool clearTriggerTags = false,
  }) {
    return DiaryEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      nickname: nickname ?? this.nickname,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      createDate: createDate ?? this.createDate,
      modifyDate: modifyDate ?? this.modifyDate,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      moodScore: clearMoodScore ? null : moodScore ?? this.moodScore,
      emotionTags: clearEmotionTags ? null : emotionTags ?? this.emotionTags,
      triggerTags: clearTriggerTags ? null : triggerTags ?? this.triggerTags,
    );
  }
}

class DiaryFetchRequest {
  const DiaryFetchRequest({
    required this.page,
    required this.size,
  });

  final int page;
  final int size;

  @override
  bool operator ==(Object other) {
    return other is DiaryFetchRequest &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(page, size);
}

String dateKeyFromDateTime(String dateTime) {
  if (dateTime.length >= 10) {
    return dateTime.substring(0, 10);
  }

  return '';
}

String monthKeyFromDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String dateKeyFromDate(DateTime date) {
  return '${monthKeyFromDate(date)}-${date.day.toString().padLeft(2, '0')}';
}

DateTime firstDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month);
}

DateTime addMonths(DateTime date, int delta) {
  return DateTime(date.year, date.month + delta);
}

List<DateTime> daysInMonth(DateTime month) {
  final firstDay = firstDayOfMonth(month);
  final nextMonth = addMonths(firstDay, 1);
  final count = nextMonth.difference(firstDay).inDays;

  return [
    for (var day = 1; day <= count; day += 1)
      DateTime(month.year, month.month, day),
  ];
}

List<DiaryContentBlock> legacyDiaryContentBlocks({
  required String content,
  String? imageUrl,
}) {
  return parseHtmlToDiaryContentBlocks(content: content, imageUrl: imageUrl);
}

List<DiaryContentBlock> parseHtmlToDiaryContentBlocks({
  required String content,
  String? imageUrl,
}) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) {
    return [
      DiaryContentBlock.text(id: 'text-0', text: ''),
      if (imageUrl != null)
        DiaryContentBlock.image(id: 'image-0', imageUrl: imageUrl),
    ];
  }

  final hasHtml = RegExp(r'<[^>]+>').hasMatch(trimmed);
  if (!hasHtml) {
    return [
      DiaryContentBlock.text(id: 'text-0', text: content),
      if (imageUrl != null)
        DiaryContentBlock.image(id: 'image-0', imageUrl: imageUrl),
    ];
  }

  final blocks = <DiaryContentBlock>[];
  var blockIndex = 0;
  final seenImageUrls = <String>{};

  final imgRegex = RegExp(
    r'''<img[^>]*src=["']([^"']+)["'][^>]*>''',
    caseSensitive: false,
  );
  var lastIndex = 0;

  for (final match in imgRegex.allMatches(trimmed)) {
    final textBefore = trimmed.substring(lastIndex, match.start);
    final cleanText = _stripHtmlTags(textBefore);
    if (cleanText.isNotEmpty) {
      blocks.add(DiaryContentBlock.text(
        id: 'text-${blockIndex++}',
        text: cleanText,
      ));
    }

    final imgSrc = match.group(1);
    final imgTag = match.group(0) ?? '';
    if (imgSrc != null && imgSrc.isNotEmpty) {
      seenImageUrls.add(imgSrc);
      final dataFilenameMatch = RegExp(
        r'''data-filename=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(imgTag);
      final altMatch = RegExp(
        r'''alt=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(imgTag);
      final filename = dataFilenameMatch?.group(1) ?? altMatch?.group(1);
      final sizeMatch = RegExp(
        r'''data-size=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(imgTag);

      blocks.add(DiaryContentBlock.image(
        id: 'image-${blockIndex++}',
        imageUrl: imgSrc,
        filename: filename,
        byteSize: int.tryParse(sizeMatch?.group(1) ?? ''),
      ));
    }

    lastIndex = match.end;
  }

  if (lastIndex < trimmed.length) {
    final textAfter = trimmed.substring(lastIndex);
    final cleanText = _stripHtmlTags(textAfter);
    if (cleanText.isNotEmpty) {
      blocks.add(DiaryContentBlock.text(
        id: 'text-${blockIndex++}',
        text: cleanText,
      ));
    }
  }

  if (imageUrl != null && !seenImageUrls.contains(imageUrl)) {
    blocks.add(DiaryContentBlock.image(
      id: 'image-${blockIndex++}',
      imageUrl: imageUrl,
    ));
  }

  return ensureDiaryTextBlock(blocks);
}

String _stripHtmlTags(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .trim();
}

String encodeDiaryContentBlocks(List<DiaryContentBlock> blocks) {
  return jsonEncode(blocks.map((block) => block.toJson()).toList());
}

List<DiaryContentBlock> decodeDiaryContentBlocks(
  String? encoded, {
  required String fallbackContent,
  String? fallbackImageUrl,
}) {
  final text = encoded?.trim() ?? '';
  if (text.isEmpty) {
    return legacyDiaryContentBlocks(
      content: fallbackContent,
      imageUrl: fallbackImageUrl,
    );
  }

  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) {
      return legacyDiaryContentBlocks(
        content: fallbackContent,
        imageUrl: fallbackImageUrl,
      );
    }

    final blocks = decoded
        .map(DiaryContentBlock.fromJson)
        .where((block) => block.isText || block.hasImage)
        .toList(growable: false);
    return ensureDiaryTextBlock(blocks);
  } on Object {
    return legacyDiaryContentBlocks(
      content: fallbackContent,
      imageUrl: fallbackImageUrl,
    );
  }
}

List<DiaryContentBlock> ensureDiaryTextBlock(List<DiaryContentBlock> blocks) {
  if (blocks.any((block) => block.isText)) {
    return List<DiaryContentBlock>.unmodifiable(blocks);
  }

  return List<DiaryContentBlock>.unmodifiable([
    DiaryContentBlock.text(id: 'text-0'),
    ...blocks,
  ]);
}

String plainDiaryContentFromBlocks(List<DiaryContentBlock> blocks) {
  return blocks
      .where((block) => block.isText)
      .map((block) => block.text.trim())
      .where((text) => text.isNotEmpty)
      .join('\n\n');
}

String? primaryDiaryImageUrlFromBlocks(List<DiaryContentBlock> blocks) {
  for (final block in blocks) {
    final imageUrl = block.imageUrl;
    if (block.isImage && imageUrl != null && imageUrl.trim().isNotEmpty) {
      return imageUrl;
    }
  }

  return null;
}

String _readNickname(Object? value) {
  final nickname = value?.toString().trim() ?? '';
  return nickname.isEmpty ? '익명' : nickname;
}

String? _readNullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String _readBlockId(Object? value) {
  final id = value?.toString().trim() ?? '';
  return id.isEmpty ? 'block-${DateTime.now().microsecondsSinceEpoch}' : id;
}

int? _readNullableInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

List<DiaryContentBlock> _readContentBlocks(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value.map(DiaryContentBlock.fromJson).toList(growable: false);
}

DiaryImageSource? _imageSourceFromValue(Object? value) {
  for (final source in DiaryImageSource.values) {
    if (source.name == value?.toString()) {
      return source;
    }
  }

  return null;
}

DiaryImageBlockUploadStatus _restoredImageStatus({
  required String? imageUrl,
  required DiaryImageBlockUploadStatus status,
}) {
  if (imageUrl != null) {
    return DiaryImageBlockUploadStatus.uploaded;
  }

  if (status == DiaryImageBlockUploadStatus.uploaded ||
      status == DiaryImageBlockUploadStatus.uploading ||
      status == DiaryImageBlockUploadStatus.pending) {
    return DiaryImageBlockUploadStatus.failed;
  }

  return status;
}

String? _restoredImageError({
  required String? imageUrl,
  required String? filename,
  required String? errorMessage,
}) {
  if (imageUrl != null) {
    return errorMessage;
  }

  if (filename == null) {
    return errorMessage;
  }

  return errorMessage ?? '이미지 파일을 다시 선택해 주세요.';
}
