import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import 'api_request_logger.dart';
import 'openai_client.dart';
import 'responses_image_api.dart';
import 'rightapi_image_api.dart';

class ImageGenerationApi {
  const ImageGenerationApi({this.requestLogService});

  final ApiRequestLogger? requestLogService;

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

    try {
      return await _generate(
        client,
        request,
        profile,
        responseFormat: responseFormat,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
    } finally {
      client.close();
    }
  }

  Future<List<GenerationResult>> _generate(
    OpenAiClient client,
    GenerationRequest request,
    ApiProfile profile, {
    String? responseFormat,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
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
      // GPT Image models omit this legacy field; RightAPI returns URLs.
      if (!_isGptImage2Family(profile.model) && !profile.usesRightApiImages) {
        body['response_format'] = responseFormat;
      }
    }

    if (profile.usesRightApiImages) {
      final response = await submitRightApiImageTask(
        client: client,
        path: '/v1/images/generations',
        body: body,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
      return _parseResults(response);
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

  bool _isGptImage2Family(String model) {
    final value = model.trim().toLowerCase();
    return value == 'gpt-image-2' ||
        value == 'gpt-image-2.5' ||
        value.startsWith('gpt-image-2.5-');
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
