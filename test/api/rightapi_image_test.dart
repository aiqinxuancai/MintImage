import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/image_edit_api.dart';
import 'package:mint_image/core/api/image_generation_api.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  test(
    'RightAPI generation preserves pixel size and polls for the image',
    () async {
      var polls = 0;
      await _withRightApiServer(
        (request) async {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer test-key',
          );
          if (request.method == 'POST') {
            expect(request.uri.path, '/v1/images/generations');
            final body =
                jsonDecode(await utf8.decoder.bind(request).join()) as Map;
            expect(body['async'], isTrue);
            expect(body['size'], '1536x1024');
            expect(body['quality'], 'medium');
            expect(body['output_format'], 'webp');
            expect(body.containsKey('imageSize'), isFalse);
            expect(body.containsKey('response_format'), isFalse);
            expect(body.containsKey('stream'), isFalse);
            await _respond(request, {
              'task_id': 'task_test',
              'status': 'processing',
            });
          } else {
            expect(request.uri.path, '/v1/tasks/task_test');
            polls++;
            await _respond(
              request,
              polls == 1
                  ? {
                      'task_id': 'task_test',
                      'status': 'in_progress',
                      'progress': 45,
                    }
                  : {
                      'data': [
                        {'url': 'https://example.com/generated.webp'},
                      ],
                    },
            );
          }
        },
        () async {
          final results = await const ImageGenerationApi().generate(
            _request(),
            _profile(useStreaming: true),
            responseFormat: 'url',
            timeoutSeconds: 30,
          );
          expect(results.single.imageUrl, 'https://example.com/generated.webp');
          expect(polls, 2);
        },
      );
    },
  );

  test(
    'RightAPI edits use the edits endpoint and retain image options',
    () async {
      final directory = await Directory.systemTemp.createTemp('rightapi-edit-');
      addTearDown(() => directory.delete(recursive: true));
      final first = await File(
        '${directory.path}/first.png',
      ).writeAsBytes([1, 2, 3]);
      final second = await File(
        '${directory.path}/second.png',
      ).writeAsBytes([4, 5, 6]);
      await _withRightApiServer(
        (request) async {
          if (request.method == 'POST') {
            expect(request.uri.path, '/v1/images/edits');
            expect(request.headers.contentType?.mimeType, 'application/json');
            final body =
                jsonDecode(await utf8.decoder.bind(request).join()) as Map;
            expect(body['async'], isTrue);
            expect(body['size'], '1536x1024');
            expect(body['quality'], 'medium');
            expect(body['output_format'], 'webp');
            expect(body['image'], [
              'data:image/png;base64,${base64Encode([1, 2, 3])}',
              'data:image/png;base64,${base64Encode([4, 5, 6])}',
            ]);
            expect(body.containsKey('imageSize'), isFalse);
            expect(body.containsKey('stream'), isFalse);
            expect(body.containsKey('response_format'), isFalse);
            await _respond(request, {
              'task_id': 'task_edit',
              'status': 'processing',
            });
          } else {
            expect(request.uri.path, '/v1/tasks/task_edit');
            await _respond(request, {
              'data': [
                {'url': 'https://example.com/edited.webp'},
              ],
            });
          }
        },
        () async {
          final results = await const ImageEditApi().edit(
            _request(imagePaths: [first.path, second.path]),
            _profile(
              baseUrl: 'http://www.rightapi.ai/draw/v1/',
              useStreaming: true,
            ),
            responseFormat: 'url',
            timeoutSeconds: 30,
          );
          expect(results.single.imageUrl, 'https://example.com/edited.webp');
        },
      );
    },
  );

  for (final status in ['failed', 'expired', 'canceled', 'cancelled']) {
    test('RightAPI stops on $status during submission', () async {
      await _withRightApiServer(
        (request) async {
          expect(request.method, 'POST');
          await request.drain<void>();
          await _respond(request, {
            'task_id': 'task_failed',
            'status': status,
            'error': 'upstream rejected the request',
          });
        },
        () async {
          await expectLater(
            const ImageGenerationApi().generate(
              _request(),
              _profile(),
              timeoutSeconds: 10,
            ),
            throwsA(
              isA<ApiException>().having(
                (error) => error.message,
                'message',
                contains('upstream rejected the request'),
              ),
            ),
          );
        },
      );
    });

    test('RightAPI stops on $status while polling', () async {
      await _withRightApiServer(
        (request) async {
          await request.drain<void>();
          await _respond(
            request,
            request.method == 'POST'
                ? {'task_id': 'task_failed', 'status': 'processing'}
                : {
                    'task_id': 'task_failed',
                    'status': status,
                    'error': {'message': 'generation stopped'},
                  },
          );
        },
        () async {
          await expectLater(
            const ImageGenerationApi().generate(
              _request(),
              _profile(),
              timeoutSeconds: 10,
            ),
            throwsA(
              isA<ApiException>().having(
                (error) => error.message,
                'message',
                contains('generation stopped'),
              ),
            ),
          );
        },
      );
    });
  }

  test('RightAPI also accepts an immediate Images response', () async {
    await _withRightApiServer(
      (request) async {
        expect(request.method, 'POST');
        await request.drain<void>();
        await _respond(request, {
          'data': [
            {'url': 'https://example.com/immediate.png'},
          ],
        });
      },
      () async {
        final results = await const ImageGenerationApi().generate(
          _request(),
          _profile(),
          timeoutSeconds: 10,
        );
        expect(results.single.imageUrl, 'https://example.com/immediate.png');
      },
    );
  });

  test('RightAPI enforces the overall timeout before the next poll', () async {
    var requests = 0;
    await _withRightApiServer(
      (request) async {
        requests++;
        await request.drain<void>();
        await _respond(request, {
          'task_id': 'task_slow',
          'status': 'processing',
        });
      },
      () async {
        final stopwatch = Stopwatch()..start();
        await expectLater(
          const ImageGenerationApi().generate(
            _request(),
            _profile(),
            timeoutSeconds: 1,
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('超时'),
            ),
          ),
        );
        expect(requests, 1);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );
  });

  test('RightAPI cancellation interrupts the polling delay', () async {
    final cancelToken = CancelToken();
    await _withRightApiServer(
      (request) async {
        expect(request.method, 'POST');
        await request.drain<void>();
        await _respond(request, {
          'task_id': 'task_cancel',
          'status': 'processing',
        });
        Timer(const Duration(milliseconds: 100), () => cancelToken.cancel());
      },
      () async {
        final stopwatch = Stopwatch()..start();
        await expectLater(
          const ImageGenerationApi().generate(
            _request(),
            _profile(),
            timeoutSeconds: 10,
            cancelToken: cancelToken,
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('取消'),
            ),
          ),
        );
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      },
    );
  });
}

Future<void> _withRightApiServer(
  Future<void> Function(HttpRequest) handler,
  Future<void> Function() action,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      try {
        await handler(request);
      } finally {
        await request.response.close();
      }
    }),
  );
  try {
    await HttpOverrides.runWithHttpOverrides(
      action,
      _RightApiProxy(server.port),
    );
  } finally {
    await server.close(force: true);
  }
}

class _RightApiProxy extends HttpOverrides {
  _RightApiProxy(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) => 'PROXY 127.0.0.1:$port';
  }
}

Future<void> _respond(HttpRequest request, Map<String, dynamic> body) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

ApiProfile _profile({
  String baseUrl = 'http://rightapi.ai',
  bool useStreaming = false,
}) {
  return ApiProfile(
    id: 'rightapi',
    name: 'RightAPI',
    baseUrl: baseUrl,
    apiKey: 'test-key',
    model: 'gpt-image-2.5-flare',
    useStreaming: useStreaming,
  );
}

GenerationRequest _request({List<String> imagePaths = const []}) {
  return GenerationRequest(
    prompt: 'a blue circle on white',
    imagePaths: imagePaths,
    sizePreset: SizePreset.posterLandscape,
    customWidth: 1536,
    customHeight: 1024,
    quality: ImageQuality.medium,
    outputFormat: ImageOutputFormat.webp,
    count: 1,
    apiProfileId: 'rightapi',
  );
}
