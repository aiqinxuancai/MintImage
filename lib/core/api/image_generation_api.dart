import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import '../services/request_log_service.dart';
import 'openai_client.dart';
import 'responses_image_api.dart';

class ImageGenerationApi {
  const ImageGenerationApi({this.requestLogService});

  final RequestLogService? requestLogService;

  Future<List<GenerationResult>> generate(
    GenerationRequest request,
    ApiProfile profile, {
    String? responseFormat,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final client = OpenAiClient(
      profile,
      timeoutSeconds: timeoutSeconds,
      requestLogService: requestLogService,
    );

    if (profile.apiMode == ImageGenerationApiMode.responses) {
      final body = buildResponsesImageBody(
        request: request,
        profile: profile,
        input: request.prompt,
        action: 'generate',
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

    final body = <String, dynamic>{
      'model': profile.model,
      'prompt': request.prompt,
      'n': 1,
      'quality': request.quality.apiValue,
      'output_format': request.outputFormat.apiValue,
    };
    if (request.apiSize != null) {
      body['size'] = request.apiSize;
    }
    if (responseFormat != null && responseFormat.trim().isNotEmpty) {
      // GPT Image 2/2.5 and RightAPI reject the legacy response_format field.
      if (!_isGptImage2Family(profile.model) && !_isRightApiDraw(profile)) {
        body['response_format'] = responseFormat;
      }
    }

    if (_isRightApiDraw(profile)) {
      if (_isGptImage25Family(profile.model)) {
        // RightAPI currently interprets `size` as an aspect-ratio token for
        // the 2.5 channels. Those channels require the separate imageSize
        // selector instead (1K/2K/4K).
        body.remove('size');
        body['imageSize'] = _rightApiImageSize(request);
      }
      body['async'] = true;
      return _submitAndPollRightApi(
        client,
        body,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
    }

    final response = profile.useStreaming
        ? await client.postJsonStreaming(
            '/v1/images/generations',
            body,
            cancelToken: cancelToken,
            isImagesApi: true,
          )
        : await client.postJson(
            '/v1/images/generations',
            body,
            cancelToken: cancelToken,
          );

    return _parseResults(response);
  }

  bool _isRightApiDraw(ApiProfile profile) {
    final uri = Uri.tryParse(profile.normalizedBaseUrl);
    return uri != null &&
        uri.host.toLowerCase() == 'www.rightapi.ai' &&
        uri.path.toLowerCase().endsWith('/draw');
  }

  bool _isGptImage2Family(String model) {
    final value = model.trim().toLowerCase();
    return value == 'gpt-image-2' || value.startsWith('gpt-image-2.5-');
  }

  bool _isGptImage25Family(String model) {
    return model.trim().toLowerCase().startsWith('gpt-image-2.5-');
  }

  String _rightApiImageSize(GenerationRequest request) {
    final longestEdge = request.resolvedWidth > request.resolvedHeight
        ? request.resolvedWidth
        : request.resolvedHeight;
    if (longestEdge <= 1024) {
      return '1K';
    }
    if (longestEdge <= 2048) {
      return '2K';
    }
    return '4K';
  }

  Future<List<GenerationResult>> _submitAndPollRightApi(
    OpenAiClient client,
    Map<String, dynamic> body, {
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final submitted = await client.postJson(
      '/v1/images/generations',
      body,
      cancelToken: cancelToken,
    );
    final taskId = submitted['task_id'];
    if (taskId is! String || taskId.trim().isEmpty) {
      // Some deployments return a synchronous Images response despite async=true.
      if (submitted['data'] is List) {
        return _parseResults(submitted);
      }
      throw const ApiException('RightAPI 异步提交未返回 task_id。');
    }

    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final task = await client.getJson(
        _rightApiTaskPath(taskId),
        cancelToken: cancelToken,
      );
      // RightAPI returns the final Images payload without a status field.
      if (task['data'] is List) {
        return _parseResults(task);
      }
      final status = task['status']?.toString().toLowerCase();
      if (status == 'completed') {
        return _parseResults(task);
      }
      if (status == 'failed' || status == 'cancelled') {
        throw ApiException(_rightApiTaskError(task));
      }
    }
    throw const ApiException('RightAPI 异步任务轮询超时。');
  }

  String _rightApiTaskPath(String taskId) {
    // OpenAiClient's base URL is /draw; task lookup is site-level, so use an
    // absolute URL understood by Dio.
    return 'https://www.rightapi.ai/v1/tasks/${Uri.encodeComponent(taskId)}';
  }

  String _rightApiTaskError(Map<String, dynamic> task) {
    final error = task['error'];
    if (error is Map && error['message'] is String) {
      return 'RightAPI 任务失败：${error['message']}';
    }
    return 'RightAPI 任务失败。';
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
