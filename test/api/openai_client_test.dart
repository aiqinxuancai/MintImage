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
          'HTTP 401：Invalid API key',
        ),
      ),
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

    expect(OpenAiClient.extractErrorMessage(error), 'HTTP 504：Gateway timeout');
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

    expect(OpenAiClient.extractErrorMessage(error), 'HTTP 400：模型已停用，请选择其他模型');
  });
}

Future<HttpServer> _respondWithText(
  String body, {
  int statusCode = HttpStatus.ok,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      await request.drain<void>();
      request.response.statusCode = statusCode;
      request.response.headers.contentType = ContentType(
        'text',
        'plain',
        charset: 'utf-8',
      );
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
