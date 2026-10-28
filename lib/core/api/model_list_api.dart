import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/settings_model.dart';
import 'api_request_logger.dart';
import 'openai_client.dart';

class ModelListApi {
  const ModelListApi({this.requestLogService});

  final ApiRequestLogger? requestLogService;

  Future<List<String>> fetchImageGenerationModels({
    required ApiProfile profile,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final apiKey = profile.apiKey.trim();
    if (apiKey.isEmpty) {
      throw const ApiException('API Key 为空，无法获取模型列表。');
    }

    final response = await _getJson(
      url: _appendVersionPath(profile.normalizedBaseUrl, 'v1', ['models']),
      headers: _bearerHeaders(apiKey),
      timeoutSeconds: timeoutSeconds,
      cancelToken: cancelToken,
    );
    return _parseModels(response);
  }

  Future<List<String>> fetchPromptOptimizationModels({
    required PromptOptimizationProfile profile,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final apiKey = profile.apiKey.trim();
    if (apiKey.isEmpty) {
      throw const ApiException('API Key 为空，无法获取模型列表。');
    }

    final request = switch (profile.protocol) {
      PromptOptimizationProtocol.openAiChatCompletions ||
      PromptOptimizationProtocol.openAiResponses => _ModelListRequest(
        url: _appendVersionPath(profile.normalizedBaseUrl, 'v1', ['models']),
        headers: _bearerHeaders(apiKey),
        stripModelPrefix: false,
        requiredMethod: null,
      ),
      PromptOptimizationProtocol.claudeMessages => _ModelListRequest(
        url: _appendVersionPath(profile.normalizedBaseUrl, 'v1', ['models']),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Accept': 'application/json',
        },
        stripModelPrefix: false,
        requiredMethod: null,
      ),
      PromptOptimizationProtocol.geminiGenerateContent => _ModelListRequest(
        url: _appendVersionPath(profile.normalizedBaseUrl, 'v1beta', [
          'models',
        ]),
        headers: {'x-goog-api-key': apiKey, 'Accept': 'application/json'},
        stripModelPrefix: true,
        requiredMethod: 'generateContent',
      ),
    };

    final response = await _getJson(
      url: request.url,
      headers: request.headers,
      timeoutSeconds: timeoutSeconds,
      cancelToken: cancelToken,
    );
    return _parseModels(
      response,
      stripModelPrefix: request.stripModelPrefix,
      requiredMethod: request.requiredMethod,
    );
  }

  Future<Map<String, dynamic>> _getJson({
    required String url,
    required Map<String, String> headers,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: timeoutSeconds),
        receiveTimeout: Duration(seconds: timeoutSeconds),
        headers: headers,
      ),
    );
    final stopwatch = Stopwatch()..start();
    final title = 'GET $url';
    unawaited(
      requestLogService?.logRequest(
        title,
        '请求地址: $url\n'
        '超时: $timeoutSeconds 秒',
      ),
    );

    try {
      final response = await dio.get<Object?>(
        url,
        options: Options(responseType: ResponseType.json),
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      final data = response.data;
      final normalized = switch (data) {
        Map value => Map<String, dynamic>.from(value),
        List value => <String, dynamic>{'data': value},
        _ => <String, dynamic>{},
      };
      unawaited(
        requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(normalized)}',
        ),
      );
      return normalized;
    } on DioException catch (error) {
      stopwatch.stop();
      final message = OpenAiClient.extractErrorMessage(error);
      unawaited(
        requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message);
    }
  }

  List<String> _parseModels(
    Map<String, dynamic> response, {
    bool stripModelPrefix = false,
    String? requiredMethod,
  }) {
    final models = <String>{};
    _collectModels(
      response['data'],
      models,
      stripModelPrefix: stripModelPrefix,
      requiredMethod: requiredMethod,
    );
    _collectModels(
      response['models'],
      models,
      stripModelPrefix: stripModelPrefix,
      requiredMethod: requiredMethod,
    );

    final sorted = models.toList()..sort();
    if (sorted.isEmpty) {
      throw const ApiException('模型列表为空。');
    }
    return sorted;
  }

  void _collectModels(
    Object? payload,
    Set<String> output, {
    required bool stripModelPrefix,
    required String? requiredMethod,
  }) {
    if (payload is! List) {
      return;
    }

    for (final item in payload) {
      if (item is String) {
        _addModel(output, item, stripModelPrefix: stripModelPrefix);
        continue;
      }
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      if (!_supportsRequiredMethod(map, requiredMethod)) {
        continue;
      }
      final rawName = switch (map['id']) {
        String value => value,
        _ => switch (map['name']) {
          String value => value,
          _ => '',
        },
      };
      _addModel(output, rawName, stripModelPrefix: stripModelPrefix);
    }
  }

  bool _supportsRequiredMethod(
    Map<String, dynamic> map,
    String? requiredMethod,
  ) {
    if (requiredMethod == null) {
      return true;
    }

    final methods = map['supportedGenerationMethods'];
    if (methods is! List) {
      return true;
    }
    return methods.contains(requiredMethod);
  }

  void _addModel(
    Set<String> output,
    String rawName, {
    required bool stripModelPrefix,
  }) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final model = stripModelPrefix && trimmed.startsWith('models/')
        ? trimmed.substring('models/'.length)
        : trimmed;
    if (model.trim().isNotEmpty) {
      output.add(model);
    }
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
    List<String> segments,
  ) {
    final normalizedBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedSegments = [
      if (!normalizedBaseUrl.endsWith('/$version')) version,
      ...segments,
    ];
    return '$normalizedBaseUrl/${normalizedSegments.join('/')}';
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

class _ModelListRequest {
  const _ModelListRequest({
    required this.url,
    required this.headers,
    required this.stripModelPrefix,
    required this.requiredMethod,
  });

  final String url;
  final Map<String, String> headers;
  final bool stripModelPrefix;
  final String? requiredMethod;
}
