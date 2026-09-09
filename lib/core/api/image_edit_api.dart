import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import '../services/request_log_service.dart';
import 'openai_client.dart';
import 'responses_image_api.dart';

class ImageEditApi {
  const ImageEditApi({this.requestLogService});

  final RequestLogService? requestLogService;

  Future<List<GenerationResult>> edit(
    GenerationRequest request,
    ApiProfile profile, {
    String? responseFormat,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    if (request.imagePaths.isEmpty) {
      throw const ApiException('图生图请求缺少附件。');
    }

    final client = OpenAiClient(
      profile,
      timeoutSeconds: timeoutSeconds,
      requestLogService: requestLogService,
    );

    if (profile.apiMode == ImageGenerationApiMode.responses) {
      final body = buildResponsesImageBody(
        request: request,
        profile: profile,
        input: [
          {
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': request.prompt},
              for (final path in request.imagePaths)
                {
                  'type': 'input_image',
                  'image_url': await imagePathToDataUrl(path),
                },
            ],
          },
        ],
        action: 'edit',
      );
      final response = profile.useStreaming
          ? await client.postJsonStreaming(
              '/v1/responses',
              body,
              cancelToken: cancelToken,
            )
          : await client.postJson(
              '/v1/responses',
              body,
              cancelToken: cancelToken,
            );
      return parseResponsesImageResults(response);
    }

    if (_isRightApiDraw(profile)) {
      final body = <String, dynamic>{
        'model': profile.model,
        'prompt': request.prompt,
        'n': 1,
        'async': true,
        'image': [
          for (final path in request.imagePaths) await imagePathToDataUrl(path),
        ],
      };
      if (_isGptImage25Family(profile.model)) {
        body['imageSize'] = _rightApiImageSize(request);
      } else if (request.apiSize != null) {
        body['size'] = request.apiSize;
      }
      final submitted = await client.postJson(
        '/v1/images/generations',
        body,
        cancelToken: cancelToken,
      );
      return _pollRightApi(client, submitted, timeoutSeconds, cancelToken);
    }

    final formData = FormData();

    final fields = <MapEntry<String, String>>[
      MapEntry('model', profile.model),
      MapEntry('prompt', request.prompt),
      MapEntry('n', '1'),
      MapEntry('quality', request.quality.apiValue),
      MapEntry('output_format', request.outputFormat.apiValue),
    ];
    if (request.apiSize != null) {
      fields.add(MapEntry('size', request.apiSize!));
    }
    if (responseFormat != null &&
        responseFormat.trim().isNotEmpty &&
        !_isGptImage2Family(profile.model)) {
      fields.add(MapEntry('response_format', responseFormat));
    }
    formData.fields.addAll(fields);

    for (final path in request.imagePaths) {
      formData.files.add(
        MapEntry(
          'image[]',
          await MultipartFile.fromFile(path, filename: p.basename(path)),
        ),
      );
    }

    final response = profile.useStreaming
        ? await client.postMultipartStreaming(
            '/v1/images/edits',
            formData,
            cancelToken: cancelToken,
          )
        : await client.postMultipart(
            '/v1/images/edits',
            formData,
            cancelToken: cancelToken,
          );

    return _parseResults(response);
  }

  bool _isGptImage2Family(String model) {
    final value = model.trim().toLowerCase();
    return value == 'gpt-image-2' || value.startsWith('gpt-image-2.5-');
  }

  bool _isRightApiDraw(ApiProfile profile) {
    final uri = Uri.tryParse(profile.normalizedBaseUrl);
    return uri != null &&
        uri.host.toLowerCase() == 'www.rightapi.ai' &&
        uri.path.toLowerCase().endsWith('/draw');
  }

  bool _isGptImage25Family(String model) {
    return model.trim().toLowerCase().startsWith('gpt-image-2.5-');
  }

  String _rightApiImageSize(GenerationRequest request) {
    final longestEdge = request.resolvedWidth > request.resolvedHeight
        ? request.resolvedWidth
        : request.resolvedHeight;
    if (longestEdge <= 1024) return '1K';
    if (longestEdge <= 2048) return '2K';
    return '4K';
  }

  Future<List<GenerationResult>> _pollRightApi(
    OpenAiClient client,
    Map<String, dynamic> submitted,
    int timeoutSeconds,
    CancelToken? cancelToken,
  ) async {
    final taskId = submitted['task_id'];
    if (taskId is! String || taskId.trim().isEmpty) {
      if (submitted['data'] is List) return _parseResults(submitted);
      throw const ApiException('RightAPI 异步提交未返回 task_id。');
    }
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final task = await client.getJson(
        'https://www.rightapi.ai/v1/tasks/${Uri.encodeComponent(taskId)}',
        cancelToken: cancelToken,
      );
      if (task['data'] is List) return _parseResults(task);
      final status = task['status']?.toString().toLowerCase();
      if (status == 'completed') return _parseResults(task);
      if (status == 'failed' || status == 'cancelled') {
        final error = task['error'];
        if (error is Map && error['message'] is String) {
          throw ApiException('RightAPI 任务失败：${error['message']}');
        }
        throw const ApiException('RightAPI 任务失败。');
      }
    }
    throw const ApiException('RightAPI 异步任务轮询超时。');
  }

  List<GenerationResult> _parseResults(Map<String, dynamic> response) {
    final payload = response['data'];
    if (payload is! List) {
      throw const ApiException('接口响应缺少图片数据。');
    }

    return payload.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final rawResponseValue =
          map['b64_json'] as String? ?? map['url'] as String?;
      return GenerationResult(
        b64Json: map['b64_json'] as String?,
        imageUrl: map['url'] as String?,
        rawResponseValue: rawResponseValue,
      );
    }).toList();
  }
}
