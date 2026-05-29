import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/generation_result.dart';

class StoredImageResult {
  const StoredImageResult({required this.localPath, required this.imageUrl});

  final String? localPath;
  final String? imageUrl;
}

class ImageStorageService {
  const ImageStorageService();

  Future<StoredImageResult> storeResult(
    String recordId,
    GenerationResult result, {
    String fileExtension = 'png',
  }) async {
    final outputDirectory = await _ensureOutputDirectory();

    if (result.b64Json != null && result.b64Json!.isNotEmpty) {
      final bytes = base64Decode(result.b64Json!);
      final file = File(
        p.join(outputDirectory.path, '$recordId.$fileExtension'),
      );
      await file.writeAsBytes(bytes, flush: true);

      return StoredImageResult(localPath: file.path, imageUrl: result.imageUrl);
    }

    if (result.imageUrl != null && result.imageUrl!.isNotEmpty) {
      final localPath = await _downloadFromUrl(
        outputDirectory: outputDirectory,
        recordId: recordId,
        imageUrl: result.imageUrl!,
      );

      return StoredImageResult(
        localPath: localPath,
        imageUrl: localPath == null ? result.imageUrl : null,
      );
    }

    return StoredImageResult(localPath: null, imageUrl: result.imageUrl);
  }

  Future<Directory> _ensureOutputDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDirectory = Directory(
      p.join(directory.path, 'generated_images'),
    );
    await outputDirectory.create(recursive: true);
    return outputDirectory;
  }

  Future<String?> _downloadFromUrl({
    required Directory outputDirectory,
    required String recordId,
    required String imageUrl,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      final extension = _resolveExtension(
        imageUrl,
        response.headers.contentType,
      );
      final file = File(p.join(outputDirectory.path, '$recordId.$extension'));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  String _resolveExtension(String imageUrl, ContentType? contentType) {
    final uri = Uri.tryParse(imageUrl);
    final path = uri?.path ?? imageUrl;
    final parsedExtension = p.extension(path).replaceFirst('.', '').trim();
    if (parsedExtension.isNotEmpty && parsedExtension.length <= 5) {
      return parsedExtension;
    }

    return switch (contentType?.mimeType.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'png',
    };
  }
}
