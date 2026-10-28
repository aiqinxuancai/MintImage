import 'package:dio/dio.dart';

import 'openai_client.dart';

/// RightAPI returns a task ID first, then an Images response from /v1/tasks.
Future<Map<String, dynamic>> submitRightApiImageTask({
  required OpenAiClient client,
  required String path,
  required Map<String, dynamic> body,
  required int timeoutSeconds,
  CancelToken? cancelToken,
}) async {
  final stopwatch = Stopwatch()..start();
  final timeout = Duration(seconds: timeoutSeconds);

  Future<T> withinDeadline<T>(Future<T> operation) {
    final remaining = timeout - stopwatch.elapsed;
    return operation.timeout(
      remaining > Duration.zero ? remaining : Duration.zero,
      onTimeout: () => throw const ApiException('RightAPI 异步任务轮询超时。'),
    );
  }

  void checkCancellation() {
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException('请求已取消。');
    }
  }

  checkCancellation();
  var response = await withinDeadline(
    client.postJson(path, {...body, 'async': true}, cancelToken: cancelToken),
  );
  String? taskId;
  while (true) {
    checkCancellation();
    final status = response['status']?.toString().toLowerCase();
    if (const ['failed', 'expired', 'canceled', 'cancelled'].contains(status)) {
      final error = response['error'];
      final detail = error is Map ? error['message'] : error;
      throw ApiException(
        'RightAPI 任务失败（$status）：${detail ?? response['message'] ?? '未知错误'}',
      );
    }
    if (response['data'] is List) {
      return response;
    }
    if (status == 'completed') {
      throw const ApiException('接口响应缺少图片数据。');
    }
    final returnedTaskId = response['task_id'];
    if (taskId == null) {
      if (returnedTaskId is! String || returnedTaskId.trim().isEmpty) {
        throw const ApiException('RightAPI 异步提交未返回 task_id。');
      }
      taskId = returnedTaskId;
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
