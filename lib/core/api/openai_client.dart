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

/// The server accepted the request (and may already have billed it), but the
/// response contained no usable image. Retrying with different inputs would
/// bill again, so callers must not treat this as a request-shape failure.
class MissingImageDataException extends ApiException {
  const MissingImageDataException(super.message, {super.statusCode});
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

    final diagnostics = _StreamDiagnostics();
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
        response,
        title,
        isImagesApi: isImagesApi,
        diagnostics: diagnostics,
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
            '流式响应，Images API，收到最终图片: $receivedImage\n'
            '${diagnostics.summary()}',
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
            '流式响应，Responses API，收到 $outputCount 个图片结果\n'
            '${diagnostics.summary()}',
          ),
        );
      }

      return result;
    } on ApiException catch (error) {
      stopwatch.stop();
      _logStreamFailure(title, stopwatch, error);
      rethrow;
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

    final diagnostics = _StreamDiagnostics();
    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: formData,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final result = await _readStreamingResult(
        response,
        title,
        isImagesApi: true,
        diagnostics: diagnostics,
      );
      stopwatch.stop();
      final data = result['data'];
      final receivedImage = data is List && data.isNotEmpty;
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '流式响应，Images API，收到最终图片: $receivedImage\n'
          '${diagnostics.summary()}',
        ),
      );
      return result;
    } on ApiException catch (error) {
      stopwatch.stop();
      _logStreamFailure(title, stopwatch, error);
      rethrow;
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
    Response<ResponseBody> response,
    String title, {
    required bool isImagesApi,
    required _StreamDiagnostics diagnostics,
  }) async {
    final responseBody = response.data;
    if (responseBody == null) {
      if (isImagesApi) {
        throw _missingStreamImage(response, diagnostics);
      }
      return {'output': []};
    }

    Map<String, dynamic>? finalImage;
    Map<String, dynamic>? partialImage;
    final outputItems = <Map<String, dynamic>>[];
    Map<String, dynamic>? completedResponse;
    String? currentEventType;
    final dataLines = <String>[];
    bool? isEventStream;
    final jsonBody = StringBuffer();
    // Lines that are not SSE fields; some relays mix a plain JSON body into
    // an event stream (e.g. keep-alive comments followed by the final JSON).
    final strayLines = StringBuffer();

    Map<String, dynamic>? handleEvent(
      String? eventName,
      Map<String, dynamic> data,
    ) {
      // Relays often rename the SSE `event:` field (e.g. `message`) while
      // keeping the OpenAI event type in the JSON, so check both.
      final dataType = data['type'];
      final types = <String>{?eventName, if (dataType is String) dataType};
      diagnostics.recordEvent(types, data);

      if (types.any(_isStreamFailureEvent) || data['error'] != null) {
        final response = data['response'];
        final detail = response is Map ? response : data;
        final error = detail['error'];
        final reason = error is Map ? error['message'] : error;
        throw ApiException(
          _withResponseBody(
            '流式请求失败：${reason ?? detail['message'] ?? detail['incomplete_details'] ?? types.join('/')}',
            data,
          ),
        );
      }

      if (isImagesApi) {
        if (data['task_id'] != null) {
          return data;
        }
        // A complete Images response inside one event. Empty lists are
        // progress events, not the final result, so keep reading.
        final payload = data['data'];
        if (payload is List && payload.any(_hasImageItem)) {
          return data;
        }
        final image = _imageItem(data);
        if (image != null) {
          if (types.any((type) => type.endsWith('partial_image'))) {
            partialImage = image;
          } else {
            finalImage = image;
          }
        }
      } else if (types.contains('response.completed')) {
        final resp = data['response'];
        if (resp is Map) {
          completedResponse = Map<String, dynamic>.from(resp);
        }
      } else if (types.contains('response.output_item.done')) {
        final item = data['item'];
        if (item is Map) {
          outputItems.add(Map<String, dynamic>.from(item));
        }
      } else if (types.contains(
        'response.image_generation_call.partial_image',
      )) {
        final b64 = data['b64_json'];
        if (b64 is String && b64.isNotEmpty) {
          outputItems.add({
            'type': 'image_generation_call',
            'result': {'b64_json': b64},
          });
        }
      }
      return null;
    }

    Map<String, dynamic>? dispatch() {
      final eventName = currentEventType;
      currentEventType = null;
      if (dataLines.isEmpty) {
        return null;
      }
      final lines = List<String>.of(dataLines);
      dataLines.clear();
      for (final data in _decodeSseData(lines, diagnostics)) {
        final result = handleEvent(eventName, data);
        if (result != null) {
          return result;
        }
      }
      return null;
    }

    try {
      await for (final rawLine
          in responseBody.stream
              .map<List<int>>((chunk) {
                diagnostics.bytes += chunk.length;
                return chunk;
              })
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final line = rawLine.trim();
        if (isEventStream == null && line.isNotEmpty) {
          isEventStream = line.startsWith(':') || _isSseFieldLine(line);
        }
        if (isEventStream == false) {
          jsonBody.writeln(rawLine);
          continue;
        }
        if (line.isEmpty) {
          final result = dispatch();
          if (result != null) return result;
          continue;
        }
        if (line.startsWith(':')) {
          continue;
        }
        if (line.startsWith('event:')) {
          // Tolerate servers that omit the blank line between events.
          if (dataLines.isNotEmpty) {
            final result = dispatch();
            if (result != null) return result;
          }
          currentEventType = line.substring('event:'.length).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          final value = line.substring('data:'.length).trim();
          if (value.isNotEmpty && value != '[DONE]') {
            dataLines.add(value);
          }
          continue;
        }
        if (!_isSseFieldLine(line)) {
          diagnostics.strayLines++;
          strayLines.writeln(rawLine);
        }
      }
    } on ApiException {
      rethrow;
    } on DioException {
      rethrow;
    } catch (error) {
      throw ApiException(
        '流式响应读取中断：$error\n\n${diagnostics.summary()}',
        statusCode: response.statusCode,
      );
    }

    if (isEventStream == false) {
      // Some Images providers return a JSON task even when stream was requested.
      return _parseJsonResponse(
        Response<Object?>(
          data: jsonBody.toString(),
          requestOptions: response.requestOptions,
          statusCode: response.statusCode,
          headers: response.headers,
        ),
        title,
      );
    }

    // The stream may end without a trailing blank line.
    final trailing = dispatch();
    if (trailing != null) return trailing;

    if (isImagesApi) {
      final image = finalImage ?? partialImage;
      if (image != null) {
        return {
          'data': [image],
        };
      }
      final fallback = _tryDecodeMap(strayLines.toString());
      if (fallback != null) {
        final payload = fallback['data'];
        if (fallback['task_id'] != null ||
            (payload is List && payload.any(_hasImageItem))) {
          return fallback;
        }
      }
      throw _missingStreamImage(response, diagnostics);
    }

    return completedResponse ?? {'output': outputItems};
  }

  MissingImageDataException _missingStreamImage(
    Response<ResponseBody> response,
    _StreamDiagnostics diagnostics,
  ) {
    return MissingImageDataException(
      _withStatusCode(
        '流式响应已结束，但没有解析到最终图片。服务端可能已经生成并计费，'
        '请先查看下方的流式诊断信息再决定是否重试。\n\n${diagnostics.summary()}',
        response.statusCode,
      ),
      statusCode: response.statusCode,
    );
  }

  void _logStreamFailure(
    String title,
    Stopwatch stopwatch,
    ApiException error,
  ) {
    unawaited(
      _requestLogService?.logError(
        title,
        '耗时: ${stopwatch.elapsedMilliseconds} ms\n错误: ${error.message}',
      ),
    );
  }

  static bool _isSseFieldLine(String line) {
    return const ['data:', 'event:', 'id:', 'retry:'].any(line.startsWith);
  }

  static bool _isStreamFailureEvent(String type) {
    return type == 'error' ||
        type == 'response.failed' ||
        type == 'response.incomplete' ||
        type.endsWith('.failed');
  }

  static bool _hasImageItem(Object? item) {
    return item is Map && _imageItem(Map<String, dynamic>.from(item)) != null;
  }

  /// Extracts `{b64_json, url}` from an Images stream event or result item.
  static Map<String, dynamic>? _imageItem(Map<String, dynamic> data) {
    final b64 = data['b64_json'];
    final url = data['url'];
    final hasB64 = b64 is String && b64.isNotEmpty;
    final hasUrl = url is String && url.isNotEmpty;
    if (!hasB64 && !hasUrl) {
      return null;
    }
    return {if (hasB64) 'b64_json': b64, if (hasUrl) 'url': url};
  }

  /// Decodes the `data:` lines of one SSE event. The spec joins multi-line
  /// data with `\n`; some relays instead split a long JSON line arbitrarily,
  /// and some omit the blank line between events, so try each in turn.
  static List<Map<String, dynamic>> _decodeSseData(
    List<String> lines,
    _StreamDiagnostics diagnostics,
  ) {
    final whole =
        _tryDecodeMap(lines.join('\n')) ??
        (lines.length > 1 ? _tryDecodeMap(lines.join()) : null);
    if (whole != null) {
      return [whole];
    }
    final events = <Map<String, dynamic>>[];
    if (lines.length > 1) {
      for (final line in lines) {
        final decoded = _tryDecodeMap(line);
        if (decoded != null) {
          events.add(decoded);
        } else {
          diagnostics.recordUnparsed(line);
        }
      }
    } else {
      diagnostics.recordUnparsed(lines.single);
    }
    return events;
  }

  static Map<String, dynamic>? _tryDecodeMap(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
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
      _withResponseBody(
        '接口响应不是有效的 JSON 对象（Content-Type: $contentType），请检查 Base URL 或服务端返回格式。',
        response.data,
      ),
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
    final rawResponseData = error.response?.data;
    Object? responseData = rawResponseData;
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
        final message = (nestedError['message'] as String).trim();
        if (message.isNotEmpty) {
          apiMessage = message;
        }
      } else if (nestedError is String && nestedError.trim().isNotEmpty) {
        apiMessage = nestedError.trim();
      }

      apiMessage ??= switch (map['message']) {
        String value when value.trim().isNotEmpty => value.trim(),
        _ => null,
      };
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      apiMessage = responseData.trim();
    }

    final cause = error.error?.toString() ?? error.message;
    final message =
        apiMessage ??
        switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout => '请求超时，请检查超时设置或稍后重试。',
          DioExceptionType.connectionError =>
            '网络连接失败，请检查网络或 Base URL。${cause == null ? '' : '\n$cause'}',
          DioExceptionType.badCertificate => '证书校验失败，请检查 HTTPS 配置。',
          DioExceptionType.badResponse =>
            rawResponseData == null ||
                    (rawResponseData is String &&
                        rawResponseData.trim().isEmpty)
                ? '请求失败，接口返回内容为空。'
                : '请求失败。',
          DioExceptionType.cancel => '请求已取消。',
          DioExceptionType.unknown =>
            error.message ?? error.error?.toString() ?? '请求失败，请稍后重试。',
        };
    return _withStatusCode(
      _withResponseBody(message, rawResponseData),
      statusCode,
    );
  }

  static String _withResponseBody(String message, Object? data) {
    if (data == null || (data is String && data.trim().isEmpty)) {
      return message;
    }

    if (data is String) {
      final text = data.trim();
      try {
        data = jsonDecode(text);
      } on FormatException {
        data = text;
      }
    }

    String body;
    if (data is String) {
      body = data;
    } else {
      try {
        body = const JsonEncoder.withIndent('  ').convert(data);
      } catch (_) {
        body = data.toString();
      }
    }
    if (body == message) {
      return message;
    }
    return '$message\n\n接口返回：\n$body';
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

/// Records what a streaming response contained, so a missing image can be
/// diagnosed from the request log instead of guessed at.
class _StreamDiagnostics {
  int bytes = 0;
  int strayLines = 0;
  int unparsed = 0;
  String? lastUnparsed;
  final Map<String, int> eventTypes = <String, int>{};
  final List<String> recentEvents = <String>[];

  void recordEvent(Set<String> types, Map<String, dynamic> data) {
    final key = types.isEmpty ? '(无类型)' : types.join(' / ');
    eventTypes.update(key, (count) => count + 1, ifAbsent: () => 1);
    recentEvents.add(_preview(data));
    if (recentEvents.length > 3) {
      recentEvents.removeAt(0);
    }
  }

  void recordUnparsed(String data) {
    unparsed++;
    lastUnparsed = _shorten(data, 300);
  }

  String summary() {
    final events = eventTypes.isEmpty
        ? '无'
        : eventTypes.entries
              .map((entry) => '${entry.key} ×${entry.value}')
              .join('，');
    final buffer = StringBuffer('流式诊断：接收 $bytes 字节，事件：$events');
    if (unparsed > 0) {
      buffer.write('\n无法解析的 data：$unparsed 条，最后一条：$lastUnparsed');
    }
    if (strayLines > 0) {
      buffer.write('\n非 SSE 字段行：$strayLines 行');
    }
    if (recentEvents.isNotEmpty) {
      buffer.write('\n最近事件（长字符串已截断）：\n${recentEvents.join('\n')}');
    }
    return buffer.toString();
  }

  static String _preview(Map<String, dynamic> data) {
    try {
      return jsonEncode(_redact(data));
    } catch (_) {
      return _shorten(data.toString(), 500);
    }
  }

  static Object? _redact(Object? value) {
    return switch (value) {
      String text => _shorten(text, 120),
      Map map => {
        for (final entry in map.entries) '${entry.key}': _redact(entry.value),
      },
      List list => [
        for (final item in list.take(5)) _redact(item),
        if (list.length > 5) '…共 ${list.length} 项',
      ],
      _ => value,
    };
  }

  static String _shorten(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}…（共 ${text.length} 字符）';
  }
}
