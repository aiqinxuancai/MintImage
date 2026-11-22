import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import '../services/markup_validation.dart';
import 'api_request_logger.dart';
import 'image_task_api.dart';
import 'openai_client.dart';
import 'openrouter_image_api.dart';
import 'responses_image_api.dart';

class ImageEditApi {
  const ImageEditApi({this.requestLogService});

  final ApiRequestLogger? requestLogService;

  Future<List<GenerationResult>> edit(
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
    if (request.imagePaths.isEmpty) {
      throw const ApiException('图生图请求缺少附件。');
    }
    if ((profile.resolvedSafetyIdentifier?.length ?? 0) > 128) {
      throw const ApiException('安全标识最多 128 个字符。');
    }
    if (profile.isOpenRouterImages) {
      final error = validateOpenRouterImageRequest(request);
      if (error != null) throw ApiException(error);
    }
    if (request.markupPath != null) {
      final error = await validateMarkupAttachment(
        request.imagePaths.first,
        request.markupPath!,
      );
      if (error != null) throw ApiException(error);
    }

    final client = OpenAiClient(
      profile,
      timeoutSeconds: timeoutSeconds,
      requestLogService: requestLogService,
    );

    try {
      return await _edit(
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

  Future<List<GenerationResult>> _edit(
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
        inputImages: [
          for (final path in request.imagePaths)
            {
              'type': 'input_image',
              'image_url': await imagePathToDataUrl(path),
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
    if (profile.isOpenRouterImages) {
      return requestOpenRouterImages(
        client,
        request,
        profile,
        cancelToken: cancelToken,
      );
    }

    final useAsync = profile.apiMode == ImageGenerationApiMode.imagesAsync;
    if (useAsync) {
      final body = <String, dynamic>{
        'model': profile.model,
        'prompt': request.prompt,
        'n': 1,
        'quality': request.quality.apiValue,
        'output_format': request.outputFormat.apiValue,
        if (profile.resolvedSafetyIdentifier != null)
          'safety_identifier': profile.resolvedSafetyIdentifier,
        if (request.markupPath != null)
          'markup': {
            'image_url': await imagePathToDataUrl(request.markupPath!),
          },
        if (request.complexity != null)
          'complexity': request.complexity!.apiValue,
        'async': true,
        'image': [
          for (final path in request.imagePaths) await imagePathToDataUrl(path),
        ],
      };
      if (request.apiSize != null) {
        body['size'] = request.apiSize;
      }
      final response = await requestImageResult(
        client: client,
        submit: () =>
            client.postJson('/v1/images/edits', body, cancelToken: cancelToken),
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
      return parseImagesApiResults(response);
    }

    final formData = FormData();

    final fields = <MapEntry<String, String>>[
      MapEntry('model', profile.model),
      MapEntry('prompt', request.prompt),
      MapEntry('n', '1'),
      MapEntry('quality', request.quality.apiValue),
      MapEntry('output_format', request.outputFormat.apiValue),
      if (profile.resolvedSafetyIdentifier != null)
        MapEntry('safety_identifier', profile.resolvedSafetyIdentifier!),
      if (request.complexity != null)
        MapEntry('complexity', request.complexity!.apiValue),
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
    if (request.markupPath != null) {
      formData.files.add(
        MapEntry(
          'markup',
          await MultipartFile.fromFile(
            request.markupPath!,
            filename: p.basename(request.markupPath!),
            contentType: DioMediaType('image', 'png'),
          ),
        ),
      );
    }

    for (final path in request.imagePaths) {
      formData.files.add(
        MapEntry(
          'image[]',
          await MultipartFile.fromFile(path, filename: p.basename(path)),
        ),
      );
    }

    final response = await requestImageResult(
      client: client,
      timeoutSeconds: timeoutSeconds,
      cancelToken: cancelToken,
      submit: () => profile.useStreaming
          ? client.postMultipartStreaming(
              '/v1/images/edits',
              formData,
              cancelToken: cancelToken,
            )
          : client.postMultipart(
              '/v1/images/edits',
              formData,
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
