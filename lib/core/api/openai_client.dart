import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/settings_model.dart';
import 'api_request_logger.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class OpenAiClient {
  OpenAiClient(
    ApiProfile profile, {
    required int timeoutSeconds,
    ApiRequestLogger? requestLogService,
  }) : _requestLogService = requestLogService,
       _dio = Dio(
         BaseOptions(
           baseUrl: profile.normalizedBaseUrl,
           connectTimeout: Duration(seconds: timeoutSeconds),
           sendTimeout: Duration(seconds: timeoutSeconds),
           receiveTimeout: Duration(seconds: timeoutSeconds),
           headers: {
             'Authorization': 'Bearer ${profile.apiKey.trim()}',
             'Accept': 'application/json',
           },
         ),
       );

  final Dio _dio;
  final ApiRequestLogger? _requestLogService;

  void close() => _dio.close(force: true);

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final title = 'POST $path';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '请求体:\n${_prettyJson(body)}',
      ),
    );

    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(response.data)}',
        ),
      );
      return _parseJsonResponse(response, title);
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message, statusCode: error.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Object?>(path, cancelToken: cancelToken);
      return _parseJsonResponse(response, 'GET $path');
    } on DioException catch (error) {
      throw ApiException(
        extractErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// 流式请求，支持 Responses API 和 Images API 两种格式。
  ///
  /// [isImagesApi] 为 true 时解析 Image API 的 partial/completed 事件，
  /// 返回格式与 Images API 非流式响应一致 `{data: [{b64_json: ...}]}`。
  /// 为 false 时（Responses API）解析 `response.completed` / `response.output_item.done`，
  /// 返回格式 `{output: [...]}` 与 `parseResponsesImageResults` 兼容。
  Future<Map<String, dynamic>> postJsonStreaming(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
    bool isImagesApi = false,
  }) async {
    final streamBody = Map<String, dynamic>.from(body)..['stream'] = true;
    if (isImagesApi) {
      // partial_images: 0 = 只接收最终图片，不要中间帧
      streamBody['partial_images'] = 0;
    }

    final stopwatch = Stopwatch()..start();
    final title = 'POST $path (stream)';

    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '请求体:\n${_prettyJson(streamBody)}',
      ),
    );

    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: streamBody,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );

      final result = await _readStreamingResult(
        response.data,
        isImagesApi: isImagesApi,
      );
      stopwatch.stop();

      if (isImagesApi) {
        final data = result['data'];
        final receivedImage = data is List && data.isNotEmpty;
        unawaited(
          _requestLogService?.logResponse(
            title,
            '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
            '状态码: ${response.statusCode ?? 'unknown'}\n'
            '流式响应，Images API，收到最终图片: $receivedImage',
          ),
        );
      } else {
        final output = result['output'];
        final outputCount = output is List ? output.length : 0;
        unawaited(
          _requestLogService?.logResponse(
            title,
            '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
            '状态码: ${response.statusCode ?? 'unknown'}\n'
            '流式响应，Responses API，收到 $outputCount 个图片结果',
          ),
        );
      }

      return result;
    } on DioException catch (error) {
      stopwatch.stop();
      final message = await _streamErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message, statusCode: error.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> postMultipartStreaming(
    String path,
    FormData formData, {
    CancelToken? cancelToken,
  }) async {
    formData.fields.addAll([
      const MapEntry('stream', 'true'),
      const MapEntry('partial_images', '0'),
    ]);

    final stopwatch = Stopwatch()..start();
    final title = 'POST $path (stream)';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '表单字段:\n${_prettyJson(_fieldsMap(formData))}\n'
        '上传文件:\n${_fileSummary(formData)}',
      ),
    );

    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: formData,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final result = await _readStreamingResult(
        response.data,
        isImagesApi: true,
      );
      stopwatch.stop();
      final data = result['data'];
      final receivedImage = data is List && data.isNotEmpty;
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '流式响应，Images API，收到最终图片: $receivedImage',
        ),
      );
      return result;
    } on DioException catch (error) {
      stopwatch.stop();
      final message = await _streamErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message, statusCode: error.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    FormData formData, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final title = 'POST $path';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '表单字段:\n${_prettyJson(_fieldsMap(formData))}\n'
        '上传文件:\n${_fileSummary(formData)}',
      ),
    );

    try {
      final response = await _dio.post<Object?>(
        path,
        data: formData,
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(response.data)}',
        ),
      );
      return _parseJsonResponse(response, title);
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message, statusCode: error.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> _readStreamingResult(
    ResponseBody? responseBody, {
    required bool isImagesApi,
  }) async {
    if (responseBody == null) {
      return isImagesApi ? {'data': []} : {'output': []};
    }

    String? lastImagesB64;
    final outputItems = <Map<String, dynamic>>[];
    Map<String, dynamic>? completedResponse;
    String? currentEventType;

    await for (final rawLine
        in responseBody.stream
            .map<List<int>>((chunk) => chunk)
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        currentEventType = null;
        continue;
      }

      if (line.startsWith('event:')) {
        currentEventType = line.substring('event:'.length).trim();
        continue;
      }

      if (!line.startsWith('data:')) {
        continue;
      }

      final dataStr = line.substring('data:'.length).trim();
      if (dataStr.isEmpty || dataStr == '[DONE]') {
        continue;
      }

      final Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(dataStr);
        if (decoded is! Map<String, dynamic>) continue;
        data = decoded;
      } on FormatException {
        continue;
      }
      final eventType = currentEventType ?? data['type'] as String?;
      if (eventType == 'error' ||
          eventType == 'response.failed' ||
          eventType == 'response.incomplete' ||
          data['error'] != null) {
        final response = data['response'];
        final detail = response is Map ? response : data;
        final error = detail['error'];
        final reason = error is Map ? error['message'] : error;
        throw ApiException(
          '流式请求失败：${reason ?? detail['message'] ?? detail['incomplete_details'] ?? eventType}',
        );
      }

      if (isImagesApi) {
        if (_isImageStreamResultEvent(eventType)) {
          final b64 = data['b64_json'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            lastImagesB64 = b64;
          }
        }
      } else if (eventType == 'response.completed') {
        final resp = data['response'];
        if (resp is Map) {
          completedResponse = Map<String, dynamic>.from(resp);
        }
      } else if (eventType == 'response.output_item.done') {
        final item = data['item'];
        if (item is Map) {
          outputItems.add(Map<String, dynamic>.from(item));
        }
      } else if (eventType == 'response.image_generation_call.partial_image') {
        final b64 = data['b64_json'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          outputItems.add({
            'type': 'image_generation_call',
            'result': {'b64_json': b64},
          });
        }
      }
    }

    if (isImagesApi) {
      return {
        'data': [
          if (lastImagesB64 != null) {'b64_json': lastImagesB64},
        ],
      };
    }

    return completedResponse ?? {'output': outputItems};
  }

  bool _isImageStreamResultEvent(String? eventType) {
    return eventType == 'image_generation.completed' ||
        eventType == 'image_generation.partial_image' ||
        eventType == 'image_edit.completed' ||
        eventType == 'image_edit.partial_image';
  }

  Future<String> _streamErrorMessage(DioException error) async {
    final body = error.response?.data;
    if (body is ResponseBody) {
      error.response!.data = await body.stream
          .map<List<int>>((chunk) => chunk)
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
    }
    return extractErrorMessage(error);
  }

  Map<String, dynamic> _parseJsonResponse(
    Response<Object?> response,
    String title,
  ) {
    Object? data = response.data;
    if (data == null) {
      return <String, dynamic>{};
    }
    // Some compatible providers send valid JSON with Content-Type: text/plain.
    // Keep the response untyped until both decoded maps and text are handled.
    if (data is String) {
      try {
        data = jsonDecode(data.trim());
      } on FormatException {
        throw _invalidJsonResponse(response, title);
      }
    }
    if (data is Map) {
      final result = Map<String, dynamic>.from(data);
      // Compatible providers sometimes return a failed request with HTTP 200.
      if (result['error'] != null || result['status'] == 'failed') {
        throw ApiException(
          extractErrorMessage(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          ),
          statusCode: response.statusCode,
        );
      }
      return result;
    }
    throw _invalidJsonResponse(response, title);
  }

  ApiException _invalidJsonResponse(Response<Object?> response, String title) {
    final contentType =
        response.headers.value(Headers.contentTypeHeader) ?? 'unknown';
    final message = _withStatusCode(
      '接口响应不是有效的 JSON 对象（Content-Type: $contentType），请检查 Base URL 或服务端返回格式。',
      response.statusCode,
    );
    unawaited(
      _requestLogService?.logError(
        title,
        '错误: $message\n响应体:\n${_summarizeData(response.data)}',
      ),
    );
    return ApiException(message, statusCode: response.statusCode);
  }

  static String extractErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    Object? responseData = error.response?.data;
    if (responseData is String) {
      try {
        responseData = jsonDecode(responseData);
      } on FormatException {
        // Preserve non-JSON HTTP errors for the existing text fallback below.
      }
    }
    String? apiMessage;

    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      final nestedError = map['error'];

      if (nestedError is Map && nestedError['message'] is String) {
        apiMessage = nestedError['message'] as String;
      } else if (nestedError is String && nestedError.trim().isNotEmpty) {
        apiMessage = nestedError.trim();
      }

      apiMessage ??= switch (map['message']) {
        String value => value,
        _ => null,
      };
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      apiMessage = responseData.trim();
    }

    if (apiMessage != null && apiMessage.isNotEmpty) {
      return _withStatusCode(apiMessage, statusCode);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请检查超时设置或稍后重试。';
      case DioExceptionType.connectionError:
        final cause = error.error?.toString() ?? error.message;
        return _withStatusCode(
          '网络连接失败，请检查网络或 Base URL。${cause == null ? '' : '\n$cause'}',
          statusCode,
        );
      case DioExceptionType.badCertificate:
        return _withStatusCode('证书校验失败，请检查 HTTPS 配置。', statusCode);
      case DioExceptionType.badResponse:
        return _withStatusCode('请求失败，请检查接口返回。', statusCode);
      case DioExceptionType.cancel:
        return '请求已取消。';
      case DioExceptionType.unknown:
        return _withStatusCode(
          error.message ?? error.error?.toString() ?? '请求失败，请稍后重试。',
          statusCode,
        );
    }
  }

  static String _withStatusCode(String message, int? statusCode) {
    if (statusCode == null) {
      return message;
    }

    return 'HTTP $statusCode：$message';
  }

  Map<String, dynamic> _fieldsMap(FormData formData) {
    return {for (final field in formData.fields) field.key: field.value};
  }

  String _fileSummary(FormData formData) {
    final files = formData.files
        .map((item) => '${item.key}: ${item.value.filename ?? 'unknown'}')
        .toList();
    return files.isEmpty ? '(无)' : files.join('\n');
  }

  String _summarizeData(Object? data) {
    if (data == null) {
      return '(空)';
    }

    if (data is String) {
      final text = data;
      try {
        data = jsonDecode(text);
      } on FormatException {
        return _truncate(text);
      }
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final payload = map['data'];
      if (payload is List) {
        map['data'] = {'count': payload.length};
      }
      return _prettyJson(map);
    }

    return _truncate(data.toString());
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
