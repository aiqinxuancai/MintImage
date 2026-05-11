import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_image_flutter/core/api/image_edit_api.dart';
import 'package:gpt_image_flutter/core/models/generation_request.dart';
import 'package:gpt_image_flutter/core/models/settings_model.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ImageEditApi', () {
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

ApiProfile _profileFor(HttpServer server) {
  return ApiProfile(
    id: 'default',
    name: '默认',
    baseUrl: 'http://${server.address.host}:${server.port}',
    apiKey: 'test-key',
    model: 'gpt-image-2',
  );
}
