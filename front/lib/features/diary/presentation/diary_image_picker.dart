import 'package:file_picker/file_picker.dart';

import '../domain/diary_models.dart';

abstract interface class DiaryImagePicker {
  Future<DiaryImageAttachment?> pickImage();
}

class FilePickerDiaryImagePicker implements DiaryImagePicker {
  const FilePickerDiaryImagePicker();

  @override
  Future<DiaryImageAttachment?> pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      return null;
    }

    return DiaryImageAttachment(
      filename: file.name,
      bytes: bytes,
    );
  }
}
