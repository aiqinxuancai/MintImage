import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import '../services/request_log_service.dart';
import 'openai_client.dart';

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
    final formData = FormData();

    final fields = <MapEntry<String, String>>[
      MapEntry('model', profile.model),
      MapEntry('prompt', request.prompt),
      MapEntry('n', '1'),
      MapEntry('quality', request.quality.apiValue),
    ];
    if (request.apiSize != null) {
      fields.add(MapEntry('size', request.apiSize!));
    }
    if (responseFormat != null && responseFormat.trim().isNotEmpty) {
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

    final response = await client.postMultipart(
      '/v1/images/edits',
      formData,
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
