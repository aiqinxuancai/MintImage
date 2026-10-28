import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/image_edit_api.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ImageEditApi', () {
    test(
      'uploads a reference image larger than 25 MB without truncating it',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'mint-large-edit-',
        );
        addTearDown(() => directory.delete(recursive: true));
        const imageSize = 26 * 1024 * 1024;
        final image = File(p.join(directory.path, 'large.png'));
        final file = await image.open(mode: FileMode.write);
        await file.writeFrom(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
          ),
        );
        await file.truncate(imageSize);
        await file.close();
        var receivedBytes = 0;
        var expectedBytes = 0;
        final server = await _startServer((request) async {
          expect(request.uri.path, '/v1/images/edits');
          expectedBytes = request.contentLength;
          receivedBytes = await request.fold<int>(
            0,
            (size, chunk) => size + chunk.length,
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': [
                {'url': 'https://example.com/large-edit.png'},
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        final results = await const ImageEditApi().edit(
          GenerationRequest(
            prompt: 'edit the full reference image',
            imagePaths: [image.path],
            sizePreset: SizePreset.square1k,
            customWidth: 1024,
            customHeight: 1024,
            quality: ImageQuality.auto,
            count: 1,
            apiProfileId: 'default',
          ),
          _profileFor(server),
          timeoutSeconds: 30,
        );
        expect(receivedBytes, expectedBytes);
        expect(receivedBytes, greaterThan(imageSize));
        expect(receivedBytes, lessThan(imageSize + 2048));
        expect(await image.length(), imageSize);
        expect(results.single.imageUrl, 'https://example.com/large-edit.png');
      },
    );

    test('uploads multiple image fields as multipart form-data', () async {
      final tempDir = await Directory.systemTemp.createTemp('gpt-edit-api');
      addTearDown(() => tempDir.delete(recursive: true));

      final first = await File(
        p.join(tempDir.path, 'first.png'),
      ).writeAsString('fake-png-a');
      final second = await File(
        p.join(tempDir.path, 'second.png'),
      ).writeAsString('fake-png-b');

      final server = await _startServer((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/v1/images/edits');
        expect(
          request.headers.contentType?.mimeType,
          contains('multipart/form-data'),
        );

        final bytes = await _collectBytes(request);
        final payload = utf8.decode(bytes, allowMalformed: true);

        expect(RegExp(r'name=\"image\[\]\"').allMatches(payload).length, 2);
        expect(payload, contains('name="prompt"'));
        expect(payload, contains('turn this into a watercolor poster'));
        expect(payload, contains('name="quality"'));
        expect(payload, contains('medium'));
        expect(payload, contains('name="output_format"'));
        expect(payload, contains('webp'));
        expect(payload, contains('name="size"'));
        expect(payload, contains('1536x1024'));

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'created': 1715000001,
            'data': [
              {
                'b64_json': base64Encode(<int>[9, 8, 7, 6]),
              },
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final api = const ImageEditApi();
      final request = GenerationRequest(
        prompt: 'turn this into a watercolor poster',
        imagePaths: [first.path, second.path],
        sizePreset: SizePreset.posterLandscape,
        customWidth: 1536,
        customHeight: 1024,
        quality: ImageQuality.medium,
        outputFormat: ImageOutputFormat.webp,
        count: 1,
        apiProfileId: 'default',
      );

      final results = await api.edit(
        request,
        _profileFor(server),
        timeoutSeconds: 600,
      );

      expect(results, hasLength(1));
      expect(results.single.b64Json, isNotNull);
    });

    test('omits response_format for edit requests by default', () async {
      final tempDir = await Directory.systemTemp.createTemp('gpt-edit-api');
      addTearDown(() => tempDir.delete(recursive: true));

      final first = await File(
        p.join(tempDir.path, 'first.png'),
      ).writeAsString('fake-png-a');

      final server = await _startServer((request) async {
        final bytes = await _collectBytes(request);
        final payload = utf8.decode(bytes, allowMalformed: true);

        expect(payload, isNot(contains('name="response_format"')));
        expect(payload, contains('name="output_format"'));
        expect(payload, contains('png'));

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'created': 1715000001,
            'data': [
              {'url': 'https://example.com/image.png'},
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final api = const ImageEditApi();
      final request = GenerationRequest(
        prompt: 'turn this into a watercolor poster',
        imagePaths: [first.path],
        sizePreset: SizePreset.posterLandscape,
        customWidth: 1536,
        customHeight: 1024,
        quality: ImageQuality.medium,
        count: 1,
        apiProfileId: 'default',
      );

      final results = await api.edit(
        request,
        _profileFor(server),
        timeoutSeconds: 600,
      );

      expect(results.single.imageUrl, 'https://example.com/image.png');
    });

    test(
      'streams Images API edit request and parses final image event',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('gpt-edit-api');
        addTearDown(() => tempDir.delete(recursive: true));

        final first = await File(
          p.join(tempDir.path, 'first.png'),
        ).writeAsString('fake-png-a');
        final finalImage = base64Encode(<int>[6, 6, 6, 6]);

        final server = await _startServer((request) async {
          expect(request.method, 'POST');
          expect(request.uri.path, '/v1/images/edits');
          expect(
            request.headers.contentType?.mimeType,
            contains('multipart/form-data'),
          );

          final bytes = await _collectBytes(request);
          final payload = utf8.decode(bytes, allowMalformed: true);
          expect(payload, contains('name="stream"'));
          expect(payload, contains('true'));
          expect(payload, contains('name="partial_images"'));
          expect(payload, contains('0'));

          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: ${jsonEncode({'type': 'image_edit.completed', 'b64_json': finalImage})}\n\n'
            'data: [DONE]\n\n',
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final api = const ImageEditApi();
        final request = GenerationRequest(
          prompt: 'turn this into a watercolor poster',
          imagePaths: [first.path],
          sizePreset: SizePreset.posterLandscape,
          customWidth: 1536,
          customHeight: 1024,
          quality: ImageQuality.medium,
          count: 1,
          apiProfileId: 'default',
        );

        final results = await api.edit(
          request,
          _profileFor(server, useStreaming: true),
          timeoutSeconds: 600,
        );

        expect(results.single.b64Json, finalImage);
      },
    );

    test('uses Responses API mode with input image data URLs', () async {
      final tempDir = await Directory.systemTemp.createTemp('gpt-edit-api');
      addTearDown(() => tempDir.delete(recursive: true));

      final first = await File(
        p.join(tempDir.path, 'first.png'),
      ).writeAsBytes(<int>[1, 2, 3, 4]);
      final responseImage = base64Encode(<int>[4, 3, 2, 1]);

      final server = await _startServer((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/v1/responses');
        expect(request.headers.contentType?.mimeType, 'application/json');

        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;

        expect(body['model'], 'gpt-5.5');
        expect(body['tool_choice'], 'required');

        final input = body['input'] as List;
        final message = input.single as Map<String, dynamic>;
        final content = message['content'] as List;
        expect(content.first, {
          'type': 'input_text',
          'text': 'turn this into a watercolor poster',
        });
        final imageContent = content[1] as Map<String, dynamic>;
        expect(imageContent['type'], 'input_image');
        expect(
          imageContent['image_url'],
          'data:image/png;base64,${base64Encode(<int>[1, 2, 3, 4])}',
        );

        final tools = body['tools'] as List;
        final tool = tools.single as Map<String, dynamic>;
        expect(tool['type'], 'image_generation');
        expect(tool['action'], 'edit');
        expect(tool['size'], '1536x1024');
        expect(tool['quality'], 'medium');
        expect(tool['output_format'], 'webp');

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'resp_123',
            'output': [
              {
                'id': 'ig_123',
                'type': 'image_generation_call',
                'result': responseImage,
              },
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final api = const ImageEditApi();
      final request = GenerationRequest(
        prompt: 'turn this into a watercolor poster',
        imagePaths: [first.path],
        sizePreset: SizePreset.posterLandscape,
        customWidth: 1536,
        customHeight: 1024,
        quality: ImageQuality.medium,
        outputFormat: ImageOutputFormat.webp,
        count: 1,
        apiProfileId: 'default',
      );

      final results = await api.edit(
        request,
        _profileFor(
          server,
          model: 'gpt-5.5',
          apiMode: ImageGenerationApiMode.responses,
        ),
        timeoutSeconds: 600,
      );

      expect(results.single.b64Json, responseImage);
    });
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

Future<List<int>> _collectBytes(HttpRequest request) async {
  final bytes = <int>[];
  await for (final chunk in request) {
    bytes.addAll(chunk);
  }
  return bytes;
}

ApiProfile _profileFor(
  HttpServer server, {
  String model = 'gpt-image-2',
  ImageGenerationApiMode apiMode = ImageGenerationApiMode.images,
  bool useStreaming = false,
}) {
  return ApiProfile(
    id: 'default',
    name: '默认',
    baseUrl: 'http://${server.address.host}:${server.port}',
    apiKey: 'test-key',
    model: model,
    apiMode: apiMode,
    useStreaming: useStreaming,
  );
}
