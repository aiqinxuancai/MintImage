import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import 'openai_client.dart';
import 'responses_image_api.dart';

/// OpenRouter silently drops fields it does not know, so reject options that
/// would otherwise be lost before a paid request is sent.
String? validateOpenRouterImageRequest(GenerationRequest request) {
  if (request.outputFormat == ImageOutputFormat.gif) {
    return 'OpenRouter 图像接口不支持 GIF 输出，请选择 PNG / JPEG / WEBP。';
  }
  if (request.markupPath != null) {
    return 'OpenRouter 图像接口不支持标注引导（markup），请移除标注图后重试。';
  }
  if (request.svgOptions != null) {
    return 'OpenRouter 图像接口不支持自定义 SVG 绘制模型，请关闭该选项。';
  }
  if (request.imagePaths.length > 16) {
    return 'OpenRouter 最多支持 16 张参考图。';
  }
  return null;
}

/// Builds a `POST /api/v1/images` body; edits add `input_references`.
Future<Map<String, dynamic>> buildOpenRouterImageBody(
  GenerationRequest request,
  ApiProfile profile,
) async {
  final user = profile.resolvedSafetyIdentifier;
  return {
    'model': profile.model,
    'prompt': request.prompt,
    'n': 1,
    'quality': request.quality.apiValue,
    'output_format': request.outputFormat.apiValue,
    'size': ?request.apiSize,
    // OpenRouter's abuse-detection ID; it hashes it before forwarding.
    'user': ?user,
    // Provider-specific fields only pass through `provider.options`.
    if (request.complexity != null)
      'provider': {
        'options': {
          'openai': {'complexity': request.complexity!.apiValue},
        },
      },
    if (request.imagePaths.isNotEmpty)
      'input_references': [
        for (final path in request.imagePaths)
          {
            'type': 'image_url',
            'image_url': {'url': await imagePathToDataUrl(path)},
          },
      ],
  };
}

Future<List<GenerationResult>> requestOpenRouterImages(
  OpenAiClient client,
  GenerationRequest request,
  ApiProfile profile, {
  CancelToken? cancelToken,
}) async {
  final validation = validateOpenRouterImageRequest(request);
  if (validation != null) throw ApiException(validation);
  final body = await buildOpenRouterImageBody(request, profile);
  final response = profile.useStreaming
      ? await client.postJsonStreaming(
          profile.generationPath,
          body,
          cancelToken: cancelToken,
          isImagesApi: true,
        )
      : await client.postJson(
          profile.generationPath,
          body,
          cancelToken: cancelToken,
        );
  final payload = response['data'];
  final results = [
    if (payload is List)
      for (final item in payload)
        if (item is Map && item['b64_json'] is String)
          GenerationResult(
            b64Json: item['b64_json'] as String,
            rawResponseValue: item['b64_json'] as String,
          ),
  ];
  if (results.isEmpty) {
    throw const MissingImageDataException('接口返回成功，但响应中没有图片数据，服务端可能已经计费。');
  }
  return results;
}
