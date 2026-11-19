import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  test('postJson decodes a JSON image response served as text/plain', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(
      server.forEach((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType(
          'text',
          'plain',
          charset: 'utf-8',
        );
        request.response.write(
          jsonEncode({
            'created': 1793177865,
            'data': [
              {
                'b64_json': base64Encode([1, 2, 3]),
                'width': 1024,
                'height': 1024,
              },
            ],
          }),
        );
        await request.response.close();
      }),
    );
    final client = OpenAiClient(
      ApiProfile(
        id: 'test',
        name: 'test',
        baseUrl: 'http://${server.address.host}:${server.port}',
        apiKey: 'test-key',
        model: 'gpt-image-2',
      ),
      timeoutSeconds: 10,
    );

    final result = await client.postJson('/v1/images/generations', {
      'model': 'gpt-image-2',
    });
    expect(
      (result['data'] as List).single['b64_json'],
      base64Encode([1, 2, 3]),
    );
  });

  for (final method in ['GET', 'multipart']) {
    test('$method decodes JSON served as text/plain', () async {
      final server = await _respondWithText(
        jsonEncode({'task_id': 'task_test'}),
      );
      addTearDown(() => server.close(force: true));
      final client = _clientFor(server);
      final result = method == 'GET'
          ? await client.getJson('/v1/tasks/task_test')
          : await client.postMultipart(
              '/v1/images/edits',
              FormData.fromMap({'model': 'gpt-image-2'}),
            );
      expect(result['task_id'], 'task_test');
    });
  }

  for (final body in ['<!doctype html><html>Login</html>', '[1,2,3]']) {
    test(
      'rejects a non-object response with HTTP and content type details: $body',
      () async {
        final server = await _respondWithText(body);
        addTearDown(() => server.close(force: true));
        await expectLater(
          _clientFor(server).postJson('/v1/images/generations', {}),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('HTTP 200'),
                contains('JSON 对象'),
                contains('text/plain'),
                contains('接口返回：'),
              ),
            ),
          ),
        );
      },
    );
  }

  test('preserves an HTTP error returned as JSON text/plain', () async {
    final server = await _respondWithText(
      jsonEncode({
        'error': {'message': 'Invalid API key'},
      }),
      statusCode: HttpStatus.unauthorized,
    );
    addTearDown(() => server.close(force: true));
    await expectLater(
      _clientFor(server).postJson('/v1/images/generations', {}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          allOf(
            startsWith('HTTP 401：Invalid API key'),
            contains('"message": "Invalid API key"'),
          ),
        ),
      ),
    );
  });

  for (final method in [
    'GET',
    'POST',
    'multipart',
    'stream',
    'multipart stream',
  ]) {
    test('$method preserves the full HTTP 429 error response', () async {
      final body = {
        'error': {'code': 'rate_limit_exceeded'},
        'detail': '请求过于频繁，请稍后重试',
        'request_id': 'req_rate_limit_test',
        'retry_after': 60,
      };
      final server = await _respondWithText(
        jsonEncode(body),
        statusCode: HttpStatus.tooManyRequests,
        contentType: ContentType.json,
      );
      addTearDown(() => server.close(force: true));
      final client = _clientFor(server);
      addTearDown(client.close);
      final response = switch (method) {
        'GET' => client.getJson('/v1/tasks/test'),
        'POST' => client.postJson('/v1/images/generations', {}),
        'multipart' => client.postMultipart('/v1/images/edits', FormData()),
        'stream' => client.postJsonStreaming('/v1/images/generations', {}),
        _ => client.postMultipartStreaming('/v1/images/edits', FormData()),
      };

      await expectLater(
        response,
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having(
                (error) => error.message,
                'message',
                allOf(
                  startsWith('HTTP 429：'),
                  endsWith(const JsonEncoder.withIndent('  ').convert(body)),
                ),
              ),
        ),
      );
    });
  }

  group('Images API stream parsing', () {
    final image = base64Encode([7, 7, 7, 7]);
    String sse(Object data, {String? event}) =>
        '${event == null ? '' : 'event: $event\n'}data: ${jsonEncode(data)}\n\n';

    final cases = <String, String>{
      'event name differs from data type':
          '${sse({'type': 'image_edit.completed', 'b64_json': image}, event: 'message')}'
          'data: [DONE]\n\n',
      'event name only': sse({
        'b64_json': image,
      }, event: 'image_generation.completed'),
      'progress event with empty data before final image':
          sse({'type': 'image_edit.in_progress', 'data': <Object>[]}) +
          sse({'type': 'image_edit.completed', 'b64_json': image}),
      'complete Images response in one event': sse({
        'created': 1,
        'data': [
          {'b64_json': image},
        ],
      }),
      'final JSON split over several data lines':
          'event: image_edit.completed\n'
          'data: {"type":"image_edit.completed",\n'
          'data: "b64_json":"${image.substring(0, 3)}\n'
          'data: ${image.substring(3)}"}\n\n',
      'no blank line between events':
          'data: ${jsonEncode({'type': 'image_edit.in_progress'})}\n'
          'data: ${jsonEncode({'type': 'image_edit.completed', 'b64_json': image})}\n',
      'stream ends without trailing blank line':
          'event: image_edit.completed\ndata: ${jsonEncode({'b64_json': image})}',
      'keep-alive comments followed by a plain JSON body':
          ': keep-alive\n\n: keep-alive\n\n${jsonEncode({
            'data': [
              {'b64_json': image},
            ],
          })}\n',
    };

    for (final entry in cases.entries) {
      test('extracts the final image: ${entry.key}', () async {
        final server = await _respondWithText(
          entry.value,
          contentType: ContentType('text', 'event-stream'),
        );
        addTearDown(() => server.close(force: true));
        final client = _clientFor(server);
        addTearDown(client.close);

        final result = await client.postMultipartStreaming(
          '/v1/images/edits',
          FormData(),
        );
        expect((result['data'] as List).single['b64_json'], image);
      });
    }

    test('accepts a final image event that carries a URL', () async {
      final server = await _respondWithText(
        sse({
          'type': 'image_generation.completed',
          'url': 'https://cdn.example.com/a.png',
        }),
        contentType: ContentType('text', 'event-stream'),
      );
      addTearDown(() => server.close(force: true));
      final client = _clientFor(server);
      addTearDown(client.close);

      final result = await client.postJsonStreaming(
        '/v1/images/generations',
        {},
        isImagesApi: true,
      );
      expect(
        (result['data'] as List).single['url'],
        'https://cdn.example.com/a.png',
      );
    });

    test('prefers the completed image over partial images', () async {
      final partial = base64Encode([1]);
      final server = await _respondWithText(
        sse({'type': 'image_edit.completed', 'b64_json': image}) +
            sse({'type': 'image_edit.partial_image', 'b64_json': partial}),
        contentType: ContentType('text', 'event-stream'),
      );
      addTearDown(() => server.close(force: true));
      final client = _clientFor(server);
      addTearDown(client.close);

      final result = await client.postMultipartStreaming(
        '/v1/images/edits',
        FormData(),
      );
      expect((result['data'] as List).single['b64_json'], image);
    });

    test('reports what the stream contained when no image arrives', () async {
      final server = await _respondWithText(
        '${sse({'type': 'image_edit.in_progress', 'data': <Object>[]})}'
        'data: {"type":"image_edit.completed","b64_json":"${image.substring(0, 4)}\n\n',
        contentType: ContentType('text', 'event-stream'),
      );
      addTearDown(() => server.close(force: true));
      final client = _clientFor(server);
      addTearDown(client.close);

      await expectLater(
        client.postMultipartStreaming('/v1/images/edits', FormData()),
        throwsA(
          isA<MissingImageDataException>().having(
            (error) => error.message,
            'message',
            allOf(
              startsWith('HTTP 200：'),
              contains('没有解析到最终图片'),
              contains('image_edit.in_progress ×1'),
              contains('无法解析的 data：1 条'),
            ),
          ),
        ),
      );
    });
  });

  for (final body in [
    ['请求频率超限', '请等待 60 秒'],
    'Too many requests',
    '<html><body>429 Too Many Requests</body></html>',
  ]) {
    test('preserves a non-object HTTP error response: $body', () {
      final options = RequestOptions(path: '/v1/images/generations');
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 429,
          data: body,
        ),
      );
      final message = OpenAiClient.extractErrorMessage(error);
      expect(message, startsWith('HTTP 429：'));
      if (body is String) {
        expect(message, 'HTTP 429：$body');
      } else {
        expect(jsonDecode(message.split('接口返回：\n').last), body);
      }
    });
  }

  test('preserves provider metadata and long error details', () {
    final options = RequestOptions(path: '/v1/images/generations');
    final body = {
      'error': {
        'message': 'Quota exhausted',
        'code': 'insufficient_quota',
        'details': List.filled(1200, '完整错误详情').join(),
      },
      'request_id': 'req_quota_test',
    };
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: 429,
        data: jsonEncode(body),
      ),
    );

    final message = OpenAiClient.extractErrorMessage(error);
    expect(message, startsWith('HTTP 429：Quota exhausted'));
    expect(jsonDecode(message.split('接口返回：\n').last), body);
  });

  test('an empty nested message does not hide the provider message', () {
    final options = RequestOptions(path: '/v1/images/generations');
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: 429,
        data: {
          'error': {'message': '   '},
          'message': '请求频率超限',
        },
      ),
    );

    expect(
      OpenAiClient.extractErrorMessage(error),
      startsWith('HTTP 429：请求频率超限'),
    );
  });

  test('unknown Dio errors preserve the underlying cause', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/v1/images/generations'),
      error: const FormatException('Invalid response encoding'),
    );
    expect(
      OpenAiClient.extractErrorMessage(error),
      contains('Invalid response encoding'),
    );
  });

  test('extractErrorMessage includes HTTP status code when available', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/v1/images/generations'),
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/images/generations'),
        statusCode: 504,
        data: {
          'error': {'message': 'Gateway timeout'},
        },
      ),
    );

    expect(
      OpenAiClient.extractErrorMessage(error),
      allOf(
        startsWith('HTTP 504：Gateway timeout'),
        contains('"message": "Gateway timeout"'),
      ),
    );
  });

  test('extractErrorMessage preserves RightAPI string errors', () {
    final requestOptions = RequestOptions(path: '/v1/images/generations');
    final error = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 400,
        data: {'error': '模型已停用，请选择其他模型'},
      ),
    );

    expect(
      OpenAiClient.extractErrorMessage(error),
      allOf(
        startsWith('HTTP 400：模型已停用，请选择其他模型'),
        contains('"error": "模型已停用，请选择其他模型"'),
      ),
    );
  });
}

Future<HttpServer> _respondWithText(
  String body, {
  int statusCode = HttpStatus.ok,
  ContentType? contentType,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      await request.drain<void>();
      request.response.statusCode = statusCode;
      request.response.headers.contentType =
          contentType ?? ContentType('text', 'plain', charset: 'utf-8');
      request.response.write(body);
      await request.response.close();
    }),
  );
  return server;
}

OpenAiClient _clientFor(HttpServer server) {
  return OpenAiClient(
    ApiProfile(
      id: 'test',
      name: 'test',
      baseUrl: 'http://${server.address.host}:${server.port}',
      apiKey: 'test-key',
      model: 'gpt-image-2',
    ),
    timeoutSeconds: 10,
  );
}
