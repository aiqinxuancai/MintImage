import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import 'api_request_logger.dart';
import 'image_task_api.dart';
import 'openai_client.dart';
import 'openrouter_image_api.dart';
import 'responses_image_api.dart';

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
    final validation = request.validate(
      usesResponsesApi: profile.apiMode == ImageGenerationApiMode.responses,
    );
    if (validation != null) throw ApiException(validation);
    if (profile.resolvedSafetyIdentifier != null &&
        profile.resolvedSafetyIdentifier!.length > 128) {
      throw const ApiException('安全标识最多 128 个字符。');
    }
    if (request.markupPath != null) {
      throw const ApiException('标注引导需要通过图生图接口提交。');
    }
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
    if (profile.isOpenRouterImages) {
      return requestOpenRouterImages(
        client,
        request,
        profile,
        cancelToken: cancelToken,
      );
    }

    final body = <String, dynamic>{
      'model': profile.model,
      'prompt': request.prompt,
      'n': 1,
      'quality': request.quality.apiValue,
      'output_format': request.outputFormat.apiValue,
      if (profile.resolvedSafetyIdentifier != null)
        'safety_identifier': profile.resolvedSafetyIdentifier,
      if (request.outputFormat == ImageOutputFormat.svg &&
          request.svgOptions != null)
        'svg': request.svgOptions!.toJson(),
      if (request.complexity != null)
        'complexity': request.complexity!.apiValue,
      if (request.outputFormat == ImageOutputFormat.gif) ...{
        'frame_count': request.frameCount,
        'frame_duration_ms': request.frameDurationMs,
      },
    };
    final useAsync = profile.apiMode == ImageGenerationApiMode.imagesAsync;
    if (useAsync) {
      body['async'] = true;
    }
    if (request.apiSize != null) {
      body['size'] = request.apiSize;
    }
    if (responseFormat != null && responseFormat.trim().isNotEmpty) {
      // GPT Image models omit this legacy field; task APIs return URLs.
      if (!_isGptImage2Family(profile.model) && !useAsync) {
        body['response_format'] = responseFormat;
      }
    }

    final response = await requestImageResult(
      client: client,
      timeoutSeconds: timeoutSeconds,
      cancelToken: cancelToken,
      submit: () =>
          profile.useStreaming &&
              !useAsync &&
              !request.outputFormat.requiresImagesGeneration
          ? client.postJsonStreaming(
              profile.generationPath,
              body,
              cancelToken: cancelToken,
              isImagesApi: true,
            )
          : client.postJson(
              profile.generationPath,
              body,
              cancelToken: cancelToken,
            ),
    );

    return parseImagesApiResults(response);
  }

  bool _isGptImage2Family(String model) {
    final value = model.trim().toLowerCase().split('/').last;
    return RegExp(r'^gpt-image-2(?:\.\d+)?(?:-|$)').hasMatch(value);
  }
}
