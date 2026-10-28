import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import 'api_request_logger.dart';
import 'openai_client.dart';
import 'responses_image_api.dart';
import 'rightapi_image_api.dart';

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
    if (request.imagePaths.isEmpty) {
      throw const ApiException('图生图请求缺少附件。');
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

    if (profile.usesRightApiImages) {
      final body = <String, dynamic>{
        'model': profile.model,
        'prompt': request.prompt,
        'n': 1,
        'quality': request.quality.apiValue,
        'output_format': request.outputFormat.apiValue,
        'image': [
          for (final path in request.imagePaths) await imagePathToDataUrl(path),
        ],
      };
      if (request.apiSize != null) {
        body['size'] = request.apiSize;
      }
      final response = await submitRightApiImageTask(
        client: client,
        path: '/v1/images/edits',
        body: body,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
      return _parseResults(response);
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
