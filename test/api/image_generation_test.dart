import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/image_generation_api.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  group('ImageGenerationApi', () {
    test(
      'omits response_format by default and parses b64_json response',
      () async {
        final server = await _startServer((request) async {
          expect(request.method, 'POST');
          expect(request.uri.path, '/v1/images/generations');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer test-key',
          );

          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;

          expect(body['model'], 'gpt-image-2');
          expect(body['prompt'], 'a red apple on white background');
          expect(body['n'], 1);
          expect(body['size'], '1024x1024');
          expect(body['quality'], 'low');
          expect(body['output_format'], 'png');
          expect(body.containsKey('response_format'), isFalse);

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'created': 1715000000,
              'data': [
                {
                  'b64_json': base64Encode(<int>[1, 2, 3, 4]),
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final api = const ImageGenerationApi();
        final request = GenerationRequest(
          prompt: 'a red apple on white background',
          imagePaths: const [],
          sizePreset: SizePreset.square1k,
          customWidth: 1024,
          customHeight: 1024,
          quality: ImageQuality.low,
          count: 1,
          apiProfileId: 'default',
        );

        final results = await api.generate(
          request,
          _profileFor(server),
          timeoutSeconds: 600,
        );

        expect(results, hasLength(1));
        expect(results.single.b64Json, isNotEmpty);
        expect(results.single.imageUrl, isNull);
      },
    );

    test('throws ApiException when server returns auth error', () async {
      final server = await _startServer((request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': {'message': 'Invalid API key'},
          }),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final api = const ImageGenerationApi();
      final request = GenerationRequest(
        prompt: 'a red apple on white background',
        imagePaths: const [],
        sizePreset: SizePreset.square1k,
        customWidth: 1024,
        customHeight: 1024,
        quality: ImageQuality.low,
        count: 1,
        apiProfileId: 'default',
      );

      await expectLater(
        () => api.generate(request, _profileFor(server), timeoutSeconds: 600),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'HTTP 401：Invalid API key',
          ),
        ),
      );
    });

    test(
      'includes response_format and output_format when configured',
      () async {
        final server = await _startServer((request) async {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;

          expect(body['response_format'], 'url');
          expect(body['output_format'], 'jpeg');

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'created': 1715000000,
              'data': [
                {'url': 'https://example.com/image.png'},
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final api = const ImageGenerationApi();
        final request = GenerationRequest(
          prompt: 'a red apple on white background',
          imagePaths: const [],
          sizePreset: SizePreset.square1k,
          customWidth: 1024,
          customHeight: 1024,
          quality: ImageQuality.low,
          outputFormat: ImageOutputFormat.jpeg,
          count: 1,
          apiProfileId: 'default',
        );

        final results = await api.generate(
          request,
          _profileFor(server),
          responseFormat: 'url',
          timeoutSeconds: 600,
        );

        expect(results.single.imageUrl, 'https://example.com/image.png');
      },
    );

    test(
      'uses Responses API mode and parses image_generation_call result',
      () async {
        final responseImage = base64Encode(<int>[5, 4, 3, 2]);
        final server = await _startServer((request) async {
          expect(request.method, 'POST');
          expect(request.uri.path, '/v1/responses');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer test-key',
          );

          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;

          expect(body['model'], 'gpt-5.5');
          expect(body['input'], 'a red apple on white background');
          expect(body['tool_choice'], 'required');
          expect(body.containsKey('response_format'), isFalse);

          final tools = body['tools'] as List;
          final tool = tools.single as Map<String, dynamic>;
          expect(tool['type'], 'image_generation');
          expect(tool['action'], 'generate');
          expect(tool['size'], '1024x1024');
          expect(tool['quality'], 'low');
          expect(tool['output_format'], 'jpeg');

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'id': 'resp_123',
              'output': [
                {'type': 'message', 'content': []},
                {
                  'id': 'ig_123',
                  'type': 'image_generation_call',
                  'result': {'b64_json': responseImage},
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final api = const ImageGenerationApi();
        final request = GenerationRequest(
          prompt: 'a red apple on white background',
          imagePaths: const [],
          sizePreset: SizePreset.square1k,
          customWidth: 1024,
          customHeight: 1024,
          quality: ImageQuality.low,
          outputFormat: ImageOutputFormat.jpeg,
          count: 1,
          apiProfileId: 'default',
        );

        final results = await api.generate(
          request,
          _profileFor(
            server,
            model: 'gpt-5.5',
            apiMode: ImageGenerationApiMode.responses,
          ),
          responseFormat: 'url',
          timeoutSeconds: 600,
        );

        expect(results, hasLength(1));
        expect(results.single.b64Json, responseImage);
        expect(results.single.rawResponseValue, responseImage);
      },
    );
  });
}

Future<HttpServer> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      await handler(request);
    }),
  );
  return server;
}

ApiProfile _profileFor(
  HttpServer server, {
  String model = 'gpt-image-2',
  ImageGenerationApiMode apiMode = ImageGenerationApiMode.images,
}) {
  return ApiProfile(
    id: 'default',
    name: '默认',
    baseUrl: 'http://${server.address.host}:${server.port}',
    apiKey: 'test-key',
    model: model,
    apiMode: apiMode,
  );
}
