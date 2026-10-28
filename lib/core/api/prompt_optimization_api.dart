import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/settings_model.dart';
import 'api_request_logger.dart';
import 'openai_client.dart';

enum PromptOptimizationDirection {
  strengthen('强化', '补足主体、构图、光影、材质和细节，让提示词更稳定。'),
  edgeExplore('探索边界', '识别当前方向，在合规范围内增强冲击力和张力。'),
  strengthenToEnglish('强化后转为英文', '先强化画面表达，再转写为自然英文提示词。'),
  classicalChinese('转为文言文', '保留画面意图，转为凝练的文言风格表达。'),
  poetic('诗意强化', '强化画面感，并加入更具诗性的氛围与意象。');

  const PromptOptimizationDirection(this.label, this.description);

  final String label;
  final String description;
}

class PromptOptimizationApi {
  const PromptOptimizationApi({this.requestLogService});

  final ApiRequestLogger? requestLogService;

  Future<String> optimize({
    required String prompt,
    required PromptOptimizationDirection direction,
    required PromptOptimizationProfile profile,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final apiKey = profile.apiKey.trim();
    if (apiKey.isEmpty) {
      throw const ApiException('提示词优化 API Key 为空。');
    }

    final request = _buildRequest(
      profile: profile,
      direction: direction,
      prompt: prompt,
    );
    final response = await _postJson(
      url: request.url,
      headers: request.headers,
      body: request.body,
      streamResponse: request.streamResponse,
      timeoutSeconds: timeoutSeconds,
      cancelToken: cancelToken,
    );
    final optimized = _parseTextResponse(response, profile.protocol).trim();
    if (optimized.isEmpty) {
      throw const ApiException('提示词优化接口没有返回有效文本。');
    }
    return _stripCodeFence(optimized);
  }

  _PromptOptimizationRequest _buildRequest({
    required PromptOptimizationProfile profile,
    required PromptOptimizationDirection direction,
    required String prompt,
  }) {
    final systemPrompt = _systemPrompt(direction);
    final userPrompt = _userPrompt(direction: direction, prompt: prompt);

    return switch (profile.protocol) {
      PromptOptimizationProtocol.openAiChatCompletions => _openAiChatRequest(
        profile,
        systemPrompt,
        userPrompt,
      ),
      PromptOptimizationProtocol.openAiResponses => _openAiResponsesRequest(
        profile,
        systemPrompt,
        userPrompt,
      ),
      PromptOptimizationProtocol.claudeMessages => _claudeRequest(
        profile,
        systemPrompt,
        userPrompt,
      ),
      PromptOptimizationProtocol.geminiGenerateContent => _geminiRequest(
        profile,
        systemPrompt,
        userPrompt,
      ),
    };
  }

  _PromptOptimizationRequest _openAiChatRequest(
    PromptOptimizationProfile profile,
    String systemPrompt,
    String userPrompt,
  ) {
    return _PromptOptimizationRequest(
      url: _appendVersionPath(profile.normalizedBaseUrl, 'v1', [
        'chat',
        'completions',
      ]),
      headers: _bearerHeaders(profile.apiKey),
      body: {
        'model': profile.model.trim(),
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
      },
    );
  }

  _PromptOptimizationRequest _openAiResponsesRequest(
    PromptOptimizationProfile profile,
    String systemPrompt,
    String userPrompt,
  ) {
    return _PromptOptimizationRequest(
      url: _appendVersionPath(profile.normalizedBaseUrl, 'v1', ['responses']),
      headers: _bearerHeaders(profile.apiKey),
      body: {
        'model': profile.model.trim(),
        'input': [
          {
            'type': 'message',
            'role': 'system',
            'content': [
              {'type': 'input_text', 'text': systemPrompt},
            ],
          },
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': userPrompt},
            ],
          },
        ],
        'temperature': 0.7,
        'stream': true,
      },
      streamResponse: true,
    );
  }

  _PromptOptimizationRequest _claudeRequest(
    PromptOptimizationProfile profile,
    String systemPrompt,
    String userPrompt,
  ) {
    return _PromptOptimizationRequest(
      url: _appendVersionPath(profile.normalizedBaseUrl, 'v1', ['messages']),
      headers: {
        'x-api-key': profile.apiKey.trim(),
        'anthropic-version': '2023-06-01',
        'Accept': 'application/json',
      },
      body: {
        'model': profile.model.trim(),
        'max_tokens': 1200,
        'stream': true,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '$systemPrompt\n\n$userPrompt',
                'cache_control': {'type': 'ephemeral'},
              },
            ],
          },
        ],
        'temperature': 0.7,
      },
      streamResponse: true,
    );
  }

  _PromptOptimizationRequest _geminiRequest(
    PromptOptimizationProfile profile,
    String systemPrompt,
    String userPrompt,
  ) {
    final model = profile.model.trim();
    final modelPath = model.startsWith('models/')
        ? model
        : 'models/${Uri.encodeComponent(model)}';
    return _PromptOptimizationRequest(
      url: _appendVersionPath(profile.normalizedBaseUrl, 'v1beta', [
        modelPath,
      ], suffix: ':generateContent'),
      headers: {
        'x-goog-api-key': profile.apiKey.trim(),
        'Accept': 'application/json',
      },
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$systemPrompt\n\n$userPrompt'},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.7},
      },
    );
  }

  Future<Map<String, dynamic>> _postJson({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required bool streamResponse,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: timeoutSeconds),
        sendTimeout: Duration(seconds: timeoutSeconds),
        receiveTimeout: Duration(seconds: timeoutSeconds),
        headers: headers,
      ),
    );
    final stopwatch = Stopwatch()..start();
    final title = 'POST $url';
    unawaited(
      requestLogService?.logRequest(
        title,
        '请求地址: $url\n'
        '超时: $timeoutSeconds 秒\n'
        '请求体:\n${_prettyJson(body)}',
      ),
    );

    try {
      final response = streamResponse
          ? await dio.post<ResponseBody>(
              url,
              data: body,
              options: Options(
                contentType: Headers.jsonContentType,
                responseType: ResponseType.stream,
              ),
              cancelToken: cancelToken,
            )
          : await dio.post<Map<String, dynamic>>(
              url,
              data: body,
              options: Options(contentType: Headers.jsonContentType),
              cancelToken: cancelToken,
            );
      stopwatch.stop();
      final Map<String, dynamic> responseData;
      if (streamResponse) {
        responseData = await _readStreamingResponse(
          response.data as ResponseBody?,
        );
      } else {
        responseData =
            response.data as Map<String, dynamic>? ?? <String, dynamic>{};
      }
      unawaited(
        requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(responseData)}',
        ),
      );
      return responseData;
    } on DioException catch (error) {
      stopwatch.stop();
      final responseData = await _decodeResponseData(error.response?.data);
      final message = _extractErrorMessage(error, responseData);
      unawaited(
        requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(responseData)}',
        ),
      );
      throw ApiException(message);
    }
  }

  Future<Object?> _decodeResponseData(Object? data) async {
    if (data is! ResponseBody) {
      return data;
    }

    final text = await data.stream
        .map<List<int>>((chunk) => chunk)
        .transform(utf8.decoder)
        .join();
    if (text.trim().isEmpty) {
      return text;
    }

    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  String _extractErrorMessage(DioException error, Object? responseData) {
    if (responseData is ResponseBody) {
      return OpenAiClient.extractErrorMessage(error);
    }

    final statusCode = error.response?.statusCode;
    String? apiMessage;
    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      final nestedError = map['error'];
      if (nestedError is Map && nestedError['message'] is String) {
        apiMessage = nestedError['message'] as String;
      }
      apiMessage ??= switch (map['message']) {
        String value => value,
        _ => null,
      };
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      apiMessage = responseData.trim();
    }

    if (apiMessage != null && apiMessage.trim().isNotEmpty) {
      return statusCode == null ? apiMessage : 'HTTP $statusCode：$apiMessage';
    }
    return OpenAiClient.extractErrorMessage(error);
  }

  Future<Map<String, dynamic>> _readStreamingResponse(
    ResponseBody? responseBody,
  ) async {
    if (responseBody == null) {
      return <String, dynamic>{};
    }

    final textBuffer = StringBuffer();
    Map<String, dynamic>? completedResponse;
    await for (final line
        in responseBody.stream
            .map<List<int>>((chunk) => chunk)
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) {
        continue;
      }

      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') {
        continue;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        continue;
      }
      final event = Map<String, dynamic>.from(decoded);
      final delta = event['delta'];
      if (delta is String) {
        textBuffer.write(delta);
      } else if (delta is Map && delta['text'] is String) {
        textBuffer.write(delta['text'] as String);
      }

      final response = event['response'];
      if (response is Map) {
        completedResponse = Map<String, dynamic>.from(response);
      }
    }

    if (textBuffer.isNotEmpty) {
      return {'output_text': textBuffer.toString()};
    }
    return completedResponse ?? <String, dynamic>{};
  }

  String _parseTextResponse(
    Map<String, dynamic> response,
    PromptOptimizationProtocol protocol,
  ) {
    final outputText = response['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText;
    }

    return switch (protocol) {
      PromptOptimizationProtocol.openAiChatCompletions => _parseOpenAiChat(
        response,
      ),
      PromptOptimizationProtocol.openAiResponses => _parseOpenAiResponses(
        response,
      ),
      PromptOptimizationProtocol.claudeMessages => _parseClaude(response),
      PromptOptimizationProtocol.geminiGenerateContent => _parseGemini(
        response,
      ),
    };
  }

  String _parseOpenAiChat(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          final content = message['content'];
          final parsed = _extractContentText(content);
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      }
    }
    throw const ApiException('OpenAI Chat 响应缺少文本内容。');
  }

  String _parseOpenAiResponses(Map<String, dynamic> response) {
    final outputText = response['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText;
    }

    final output = response['output'];
    if (output is List) {
      final buffer = StringBuffer();
      for (final item in output) {
        if (item is! Map) {
          continue;
        }
        final content = item['content'];
        final text = _extractContentText(content);
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.write('\n');
          }
          buffer.write(text);
        }
      }
      if (buffer.isNotEmpty) {
        return buffer.toString();
      }
    }

    throw const ApiException('OpenAI Responses 响应缺少文本内容。');
  }

  String _parseClaude(Map<String, dynamic> response) {
    final content = response['content'];
    final parsed = _extractContentText(content);
    if (parsed.isNotEmpty) {
      return parsed;
    }
    throw const ApiException('Claude 响应缺少文本内容。');
  }

  String _parseGemini(Map<String, dynamic> response) {
    final candidates = response['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map) {
        final content = first['content'];
        if (content is Map) {
          final parsed = _extractContentText(content['parts']);
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      }
    }
    throw const ApiException('Gemini 响应缺少文本内容。');
  }

  String _extractContentText(Object? content) {
    if (content is String) {
      return content.trim();
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is String) {
          if (buffer.isNotEmpty) {
            buffer.write('\n');
          }
          buffer.write(item);
          continue;
        }
        if (item is! Map) {
          continue;
        }
        final text = switch (item['text']) {
          String value => value,
          _ => switch (item['content']) {
            String value => value,
            _ => null,
          },
        };
        if (text == null || text.trim().isEmpty) {
          continue;
        }
        if (buffer.isNotEmpty) {
          buffer.write('\n');
        }
        buffer.write(text.trim());
      }
      return buffer.toString().trim();
    }

    return '';
  }

  String _systemPrompt(PromptOptimizationDirection direction) {
    final styleInstruction = switch (direction) {
      PromptOptimizationDirection.strengthen => '强化主体、构图、镜头语言、光影、色彩、材质、环境和细节。',
      PromptOptimizationDirection.edgeExplore =>
        '识别原提示词的创作方向，在合法合规、安全表达范围内提升戏剧张力、风格辨识度和视觉冲击力。',
      PromptOptimizationDirection.strengthenToEnglish =>
        '先强化画面表达，再转写为自然、专业、可直接用于图像生成模型的英文提示词。',
      PromptOptimizationDirection.classicalChinese =>
        '保持原始画面意图，转写为凝练、古雅、可读性好的文言风格中文提示词。',
      PromptOptimizationDirection.poetic => '强化画面细节，同时加入诗意意象、氛围层次和更细腻的审美描述。',
    };

    return '你是专业的图像生成提示词优化器。'
        '你的任务是根据用户的原始提示词输出一段更适合图像生成的提示词。'
        '$styleInstruction'
        '不要添加违法、露骨色情、仇恨、暴力伤害或规避安全规则的内容。'
        '只输出优化后的提示词正文，不要解释、不要标题、不要 Markdown。';
  }

  String _userPrompt({
    required PromptOptimizationDirection direction,
    required String prompt,
  }) {
    return '优化方向：${direction.label}\n'
        '原始提示词：\n$prompt\n\n'
        '请直接返回优化后的提示词。';
  }

  Map<String, String> _bearerHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer ${apiKey.trim()}',
      'Accept': 'application/json',
    };
  }

  String _appendVersionPath(
    String baseUrl,
    String version,
    List<String> segments, {
    String suffix = '',
  }) {
    final normalizedBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedSegments = [
      if (!normalizedBaseUrl.endsWith('/$version')) version,
      ...segments,
    ];
    return '$normalizedBaseUrl/${normalizedSegments.join('/')}$suffix';
  }

  String _stripCodeFence(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) {
      return trimmed;
    }

    final withoutOpening = trimmed.replaceFirst(RegExp(r'^```\w*\s*'), '');
    return withoutOpening.replaceFirst(RegExp(r'\s*```$'), '').trim();
  }

  String _summarizeData(Object? data) {
    if (data == null) {
      return '(空)';
    }
    return _truncate(_prettyJson(data));
  }

  String _prettyJson(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return _truncate(value.toString());
    }
  }

  String _truncate(String text, [int maxLength = 5000]) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}

class _PromptOptimizationRequest {
  const _PromptOptimizationRequest({
    required this.url,
    required this.headers,
    required this.body,
    this.streamResponse = false,
  });

  final String url;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
  final bool streamResponse;
}
