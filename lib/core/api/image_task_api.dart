import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/generation_result.dart';
import 'openai_client.dart';

/// Parses an Images API `{data: [{b64_json | url}]}` response. Never returns
/// an empty list: a successful response without images is reported as
/// [MissingImageDataException] together with the (truncated) response body.
List<GenerationResult> parseImagesApiResults(Map<String, dynamic> response) {
  final payload = response['data'];
  final results = <GenerationResult>[
    if (payload is List)
      for (final item in payload)
        if (item is Map) ?_imageResult(Map<String, dynamic>.from(item)),
  ];
  if (results.isEmpty) {
    throw MissingImageDataException(
      '接口返回成功，但响应中没有图片数据，服务端可能已经计费。'
      '\n\n接口返回：\n${const JsonEncoder.withIndent('  ').convert(_redactLongStrings(response))}',
    );
  }
  return results;
}

GenerationResult? _imageResult(Map<String, dynamic> item) {
  final b64Json = switch (item['b64_json']) {
    final String value when value.isNotEmpty => value,
    _ => null,
  };
  final imageUrl = switch (item['url']) {
    final String value when value.isNotEmpty => value,
    _ => null,
  };
  if (b64Json == null && imageUrl == null) {
    return null;
  }
  return GenerationResult(
    b64Json: b64Json,
    imageUrl: imageUrl,
    rawResponseValue: b64Json ?? imageUrl,
  );
}

Object? _redactLongStrings(Object? value) {
  return switch (value) {
    String text when text.length > 200 =>
      '${text.substring(0, 200)}…（共 ${text.length} 字符）',
    Map map => {
      for (final entry in map.entries)
        '${entry.key}': _redactLongStrings(entry.value),
    },
    List list => [for (final item in list) _redactLongStrings(item)],
    _ => value,
  };
}

/// Accept immediate Images results or poll /v1/tasks when a task_id is returned.
Future<Map<String, dynamic>> requestImageResult({
  required OpenAiClient client,
  required Future<Map<String, dynamic>> Function() submit,
  required int timeoutSeconds,
  CancelToken? cancelToken,
}) async {
  final stopwatch = Stopwatch()..start();
  final timeout = Duration(seconds: timeoutSeconds);

  Future<T> withinDeadline<T>(Future<T> operation) {
    final remaining = timeout - stopwatch.elapsed;
    return operation.timeout(
      remaining > Duration.zero ? remaining : Duration.zero,
      onTimeout: () => throw const ApiException('图片请求或异步任务轮询超时。'),
    );
  }

  void checkCancellation() {
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException('请求已取消。');
    }
  }

  checkCancellation();
  var response = await withinDeadline(submit());
  String? taskId;
  while (true) {
    checkCancellation();
    final status = response['status']?.toString().toLowerCase();
    if (const ['failed', 'expired', 'canceled', 'cancelled'].contains(status)) {
      final error = response['error'];
      final detail = error is Map ? error['message'] : error;
      throw ApiException(
        '异步任务失败（$status）：${detail ?? response['message'] ?? '未知错误'}'
        '\n\n接口返回：\n${const JsonEncoder.withIndent('  ').convert(response)}',
      );
    }
    if (response['data'] is List) {
      return response;
    }
    if (status == 'completed') {
      throw MissingImageDataException(
        '接口响应缺少图片数据。'
        '\n\n接口返回：\n${const JsonEncoder.withIndent('  ').convert(response)}',
      );
    }
    final returnedTaskId = response['task_id'];
    if (taskId == null) {
      if (returnedTaskId is! String || returnedTaskId.trim().isEmpty) {
        throw ApiException(
          '接口响应缺少图片数据或有效的 task_id。'
          '\n\n接口返回：\n${const JsonEncoder.withIndent('  ').convert(response)}',
        );
      }
      taskId = returnedTaskId.trim();
    }

    await withinDeadline(
      Future.any<void>([
        Future<void>.delayed(const Duration(seconds: 3)),
        if (cancelToken != null)
          cancelToken.whenCancel.then<void>((_) {
            throw const ApiException('请求已取消。');
          }),
      ]),
    );
    checkCancellation();
    response = await withinDeadline(
      client.getJson(
        '/v1/tasks/${Uri.encodeComponent(taskId)}',
        cancelToken: cancelToken,
      ),
    );
  }
}
