import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class PickedAttachment {
  const PickedAttachment({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;

  static Future<PickedAttachment?> fromExistingPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }
    return PickedAttachment(
      path: file.path,
      name: p.basename(file.path),
      sizeBytes: await file.length(),
    );
  }
}

class AttachmentPickerService {
  AttachmentPickerService() : _imagePicker = ImagePicker();

  final ImagePicker _imagePicker;

  Future<List<PickedAttachment>> pickImages() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final files = await _imagePicker.pickMultiImage();
      return Future.wait(
        files.map((file) async {
          return PickedAttachment(
            path: file.path,
            name: p.basename(file.path),
            sizeBytes: await file.length(),
          );
        }),
      );
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );

    if (result == null) {
      return const [];
    }

    return result.files
        .where((file) => file.path != null)
        .map(
          (file) => PickedAttachment(
            path: file.path!,
            name: file.name,
            sizeBytes: file.size,
          ),
        )
        .toList();
  }
}
