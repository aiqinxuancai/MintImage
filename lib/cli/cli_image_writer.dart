import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/api/openai_client.dart';
import '../core/models/generation_result.dart';
import 'cli_error.dart';
import 'cli_options.dart';

class CliImageWriter {
  CliImageWriter(this.options)
    : _downloader = Dio(
        BaseOptions(
          connectTimeout: Duration(seconds: options.timeoutSeconds),
          receiveTimeout: Duration(seconds: options.timeoutSeconds),
        ),
      );

  final CliOptions options;
  // Never attach API authorization to a provider's image/CDN URL.
  final Dio _downloader;
  final String _runId = const Uuid().v4();

  Future<void> prepare() async {
    final directory = Directory(options.outputDirectory);
    await directory.create(recursive: true);
    // Fail before submitting a paid request if the destination is not writable.
    final probe = File(p.join(directory.path, '.mint-image-$_runId.tmp'));
    await probe.create(exclusive: true);
    try {
      await probe.writeAsBytes([0], flush: true);
    } finally {
      await probe.delete();
    }
  }

  Future<String> save(
    GenerationResult result, {
    required int taskIndex,
    required int imageIndex,
    required CancelToken cancelToken,
    required Duration remaining,
  }) async {
    final List<int> bytes;
    if (result.b64Json?.trim().isNotEmpty == true) {
      try {
        final raw = result.b64Json!.trim();
        bytes = raw.startsWith('data:')
            ? UriData.parse(raw).contentAsBytes()
            : base64Decode(raw);
      } on FormatException {
        throw const CliException('invalid_response', '接口返回的图片 Base64 数据无效。');
      }
    } else if (result.imageUrl?.trim().isNotEmpty == true) {
      final uri = Uri.tryParse(result.imageUrl!.trim());
      if (uri == null ||
          !const ['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const CliException('invalid_response', '接口返回的图片下载地址无效。');
      }
      if (remaining <= Duration.zero) {
        throw TimeoutException('任务超时，未能下载图片。');
      }
      final response = await _downloader
          .get<List<int>>(
            uri.toString(),
            options: Options(
              responseType: ResponseType.bytes,
              validateStatus: (_) => true,
            ),
            cancelToken: cancelToken,
          )
          .timeout(
            remaining,
            onTimeout: () {
              cancelToken.cancel('图片下载超时');
              throw TimeoutException('任务超时，图片下载未完成。');
            },
          );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        final errorResponse = Response<Object?>(
          requestOptions: response.requestOptions,
          statusCode: response.statusCode,
          data: utf8.decode(response.data ?? [], allowMalformed: true),
        );
        throw CliException(
          'download_error',
          '图片下载失败：${OpenAiClient.extractErrorMessage(DioException(requestOptions: response.requestOptions, response: errorResponse))}',
          httpStatus: response.statusCode,
        );
      }
      bytes = response.data ?? [];
    } else {
      throw const CliException(
        'invalid_response',
        '接口返回成功，但没有图片 Base64 或 URL。',
      );
    }
    final extension = _imageExtension(bytes);
    if (extension == null) {
      throw const CliException(
        'invalid_response',
        '返回内容不是有效的 PNG/JPEG/WebP 图片（可能是空数据或错误页面）。',
      );
    }
    if (options.outputPath != null &&
        extension != options.request.outputFormat.fileExtension) {
      throw CliException(
        'invalid_response',
        '接口实际返回 $extension，与 --output 请求的 ${options.request.outputFormat.apiValue} 格式不一致。',
      );
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    final file = File(
      options.outputPath ??
          p.join(
            options.outputDirectory,
            'mint-$_runId-$taskIndex-$imageIndex.$extension',
          ),
    );
    // Atomic exclusive creation also prevents concurrent processes overwriting.
    await file.create(exclusive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      await file.delete();
      rethrow;
    }
    return file.absolute.path;
  }

  void close() => _downloader.close(force: true);
}

String? _imageExtension(List<int> bytes) {
  if (bytes.length >= 8 &&
      _matches(bytes, [137, 80, 78, 71, 13, 10, 26, 10], 0)) {
    return 'png';
  }
  if (bytes.length >= 3 && _matches(bytes, [255, 216, 255], 0)) {
    return 'jpeg';
  }
  if (bytes.length >= 12 &&
      _matches(bytes, [82, 73, 70, 70], 0) &&
      _matches(bytes, [87, 69, 66, 80], 8)) {
    return 'webp';
  }
  return null;
}

bool _matches(List<int> bytes, List<int> expected, int offset) {
  for (var i = 0; i < expected.length; i++) {
    if (bytes[offset + i] != expected[i]) return false;
  }
  return true;
}
