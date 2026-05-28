import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import '../services/request_log_service.dart';
import 'openai_client.dart';

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
    final body = <String, dynamic>{
      'model': profile.model,
      'prompt': request.prompt,
      'n': 1,
      'quality': request.quality.apiValue,
    };
    if (request.apiSize != null) {
      body['size'] = request.apiSize;
    }
    if (responseFormat != null && responseFormat.trim().isNotEmpty) {
      body['response_format'] = responseFormat;
    }

    final response = await client.postJson(
      '/v1/images/generations',
      body,
      cancelToken: cancelToken,
    );

    return _parseResults(response);
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
