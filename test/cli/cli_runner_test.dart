import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/cli/cli_runner.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:path/path.dart' as p;

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN1cAAAAASUVORK5CYII=';
const _key = 'fixture-secret-key';

void main() {
  late Directory directory;
  late HttpServer server;
  late Future<void> Function(HttpRequest) respond;
  late List<String> paths;
  late List<String?> authorization;
  late Map<String, String> environment;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mint-cli-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    paths = [];
    authorization = [];
    respond = (request) async => _json(request, {
      'data': [
        {'b64_json': _pngBase64},
      ],
    });
    server.listen((request) async {
      paths.add(request.uri.path);
      authorization.add(request.headers.value(HttpHeaders.authorizationHeader));
      try {
        await respond(request);
      } on SocketException {
        // A timeout test deliberately closes the client's socket.
      } on HttpException {
        // A timeout test deliberately closes the client's socket.
      }
    });
    environment = {
      'MINT_IMAGE_API_KEY': _key,
      'MINT_IMAGE_BASE_URL': 'http://${server.address.host}:${server.port}',
    };
  });

  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  Future<_Result> run(
    List<String> arguments, {
    Map<String, String>? env,
    String? input,
  }) => _run(
    [
      ...arguments,
      if (arguments.firstOrNull != 'profiles' &&
          !arguments.contains('--output') &&
          !arguments.contains('--output-dir')) ...[
        '--output-dir',
        directory.path,
      ],
    ],
    env ?? environment,
    input: input,
  );

  Map<String, Object?> savedProfile(
    String id,
    String name, {
    String key = 'saved-profile-secret',
    String model = 'saved-image-model',
    String apiMode = 'images',
    bool stream = false,
  }) => {
    'id': id,
    'name': name,
    'apiKey': key,
    'baseUrl': environment['MINT_IMAGE_BASE_URL'],
    'model': model,
    'apiMode': apiMode,
    'useStreaming': stream,
  };

  Future<File> writeSettings(
    List<Map<String, Object?>> profiles, {
    String? activeId,
    int timeout = 600,
    String? path,
  }) async {
    final file = File(path ?? p.join(directory.path, 'preferences.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'flutter.${SettingsModel.storageKey}': jsonEncode({
          'profiles': profiles,
          'activeProfileId': activeId ?? profiles.firstOrNull?['id'],
          'requestTimeoutSeconds': timeout,
          'promptOptimizationProfiles': [
            {'apiKey': 'optimizer-secret-not-for-cli'},
          ],
          'webDavBackupConfig': {'password': 'webdav-secret-not-for-cli'},
        }),
      }),
    );
    return file;
  }

  test('help exits successfully without configuration or a request', () async {
    final result = await _run(['--help'], {});
    expect(result.code, 0);
    expect(result.output, contains('--parallel'));
    expect(result.error, isEmpty);
    expect(paths, isEmpty);
  });

  test(
    'profiles lists public fields and active state without any secrets',
    () async {
      final settings = await writeSettings([
        savedProfile('first', '默认配置', key: 'first-saved-secret'),
        savedProfile(
          'second',
          '备用配置',
          key: 'second-saved-secret',
          model: 'model-b',
        ),
        savedProfile('empty', '尚未配置密钥', key: ''),
      ], activeId: 'second');
      final result = await run(
        ['profiles'],
        env: {'MINT_IMAGE_SETTINGS_FILE': settings.path},
      );
      expect(result.code, 0);
      expect(result.error, isEmpty);
      expect(result.json['active_profile_id'], 'second');
      final profiles = result.json['profiles'] as List;
      expect(profiles.length, 3);
      expect(profiles[0]['name'], '默认配置');
      expect(profiles[1]['base_url'], environment['MINT_IMAGE_BASE_URL']);
      expect(profiles[1]['model'], 'model-b');
      expect(profiles[1]['api_mode'], 'images');
      expect(profiles[1]['is_active'], isTrue);
      expect(profiles[2]['has_api_key'], isFalse);
      for (final secret in [
        'first-saved-secret',
        'second-saved-secret',
        'optimizer-secret-not-for-cli',
        'webdav-secret-not-for-cli',
      ]) {
        expect(result.output, isNot(contains(secret)));
      }
      expect(
        profiles.every(
          (item) => !item.containsKey('apiKey') && !item.containsKey('api_key'),
        ),
        isTrue,
      );
      expect(paths, isEmpty);
    },
  );

  test('profiles without saved settings returns an empty list', () async {
    final result = await run(['profiles'], env: {});
    expect(result.code, 0);
    expect(result.json['profiles'], isEmpty);
    expect(result.json['active_profile_id'], isNull);
    expect(paths, isEmpty);
  });

  test('profiles help succeeds without opening a settings file', () async {
    final result = await _run(
      ['profiles', '--help'],
      {'MINT_IMAGE_SETTINGS_FILE': p.join(directory.path, 'missing.json')},
    );
    expect(result.code, 0);
    expect(result.output, contains('mint-image profiles'));
    expect(result.error, isEmpty);
    expect(paths, isEmpty);
  });

  test(
    'an explicitly missing settings file is an actionable config error',
    () async {
      final result = await run([
        'profiles',
        '--settings-file',
        p.join(directory.path, 'missing.json'),
      ], env: {});
      expect(result.code, 2);
      expect(result.json['error']['type'], 'config_error');
      expect(result.error, contains('missing.json'));
      expect(paths, isEmpty);
    },
  );

  test('command settings-file overrides its environment variable', () async {
    final settings = await writeSettings([savedProfile('saved', '指定文件')]);
    final result = await run(
      ['profiles', '--settings-file', settings.path],
      env: {'MINT_IMAGE_SETTINGS_FILE': p.join(directory.path, 'missing.json')},
    );
    expect(result.code, 0);
    expect(result.json['profiles'][0]['name'], '指定文件');
    expect(paths, isEmpty);
  });

  test(
    'generation uses the current saved profile without connection flags',
    () async {
      final settings = await writeSettings([
        savedProfile(
          'first',
          '默认配置',
          key: 'first-saved-secret',
          model: 'model-a',
        ),
        savedProfile(
          'second',
          '当前配置',
          key: 'second-saved-secret',
          model: 'model-b',
        ),
      ], activeId: 'second');
      respond = (request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['model'], 'model-b');
        await _json(request, {
          'data': [
            {'b64_json': _pngBase64},
          ],
        });
      };
      final result = await run(
        ['generate', '--prompt', 'cat'],
        env: {'MINT_IMAGE_SETTINGS_FILE': settings.path},
      );
      expect(result.code, 0);
      expect(authorization, ['Bearer second-saved-secret']);
      expect(paths, ['/v1/images/generations']);
    },
  );

  test(
    'discovers the desktop native preference file automatically',
    () async {
      final home = p.join(directory.path, 'home');
      final appData = p.join(directory.path, 'roaming');
      final path = Platform.isWindows
          ? p.join(appData, 'com.aiqin', 'MintImage', 'shared_preferences.json')
          : p.join(
              home,
              'Library',
              'Containers',
              'com.aiqin.mintImage',
              'Data',
              'Library',
              'Preferences',
              'com.aiqin.mintImage.plist',
            );
      final settings = await writeSettings([
        savedProfile('native', '桌面配置'),
      ], path: path);
      if (Platform.isMacOS) {
        final converted = await Process.run('/usr/bin/plutil', [
          '-convert',
          'binary1',
          '--',
          settings.path,
        ]);
        expect(converted.exitCode, 0);
      }
      final before = await settings.readAsBytes();
      final env = {'APPDATA': appData, 'HOME': home};
      final listing = await run(['profiles'], env: env);
      final results = await Future.wait([
        run(['--prompt', 'cat'], env: env),
        run(['--prompt', 'dog'], env: env),
      ]);
      expect(listing.code, 0);
      expect(listing.json['profiles'][0]['name'], '桌面配置');
      expect(results.map((result) => result.code), [0, 0]);
      expect(authorization, [
        'Bearer saved-profile-secret',
        'Bearer saved-profile-secret',
      ]);
      expect(await settings.readAsBytes(), before);
    },
    skip: !Platform.isWindows && !Platform.isMacOS,
  );

  for (final selector in ['备用 配置', 'second']) {
    test('selects a saved profile by name or ID: $selector', () async {
      final settings = await writeSettings([
        savedProfile('first', '当前配置', key: 'current-secret'),
        savedProfile('second', '备用 配置', key: 'selected-secret'),
      ]);
      final result = await run([
        '--prompt',
        'cat',
        '--profile',
        selector,
        '--settings-file',
        settings.path,
      ], env: {});
      expect(result.code, 0);
      expect(authorization, ['Bearer selected-secret']);
    });
  }

  test(
    'explicit connection options override environment and saved profile',
    () async {
      final settings = await writeSettings([savedProfile('saved', '已保存')]);
      respond = (request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['model'], 'command-model');
        await _json(request, {
          'data': [
            {'b64_json': _pngBase64},
          ],
        });
      };
      final result = await run(
        [
          '--prompt',
          'cat',
          '--api-key',
          'command-secret',
          '--model',
          'command-model',
          '--base-url',
          environment['MINT_IMAGE_BASE_URL']!,
        ],
        env: {
          'MINT_IMAGE_SETTINGS_FILE': settings.path,
          'MINT_IMAGE_API_KEY': 'environment-secret',
          'MINT_IMAGE_BASE_URL': 'http://127.0.0.1:1',
          'MINT_IMAGE_MODEL': 'environment-model',
        },
      );
      expect(result.code, 0);
      expect(authorization, ['Bearer command-secret']);
    },
  );

  test('environment connection options override the saved profile', () async {
    final settings = await writeSettings([savedProfile('saved', '已保存')]);
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['model'], 'environment-model');
      await _json(request, {
        'data': [
          {'b64_json': _pngBase64},
        ],
      });
    };
    final result = await run(
      ['--prompt', 'cat'],
      env: {
        ...environment,
        'MINT_IMAGE_SETTINGS_FILE': settings.path,
        'MINT_IMAGE_MODEL': 'environment-model',
      },
    );
    expect(result.code, 0);
    expect(authorization, ['Bearer $_key']);
  });

  test('inherits saved Responses protocol and stream setting', () async {
    final settings = await writeSettings([
      savedProfile('saved', 'Responses 配置', apiMode: 'responses', stream: true),
    ]);
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['stream'], isTrue);
      expect(body['model'], 'saved-image-model');
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'type': 'response.completed',
          'response': {
            'output': [
              {'type': 'image_generation_call', 'result': _pngBase64},
            ],
          },
        })}\n\n',
      );
      await request.response.close();
    };
    final result = await run(
      ['--prompt', 'cat'],
      env: {'MINT_IMAGE_SETTINGS_FILE': settings.path},
    );
    expect(result.code, 0);
    expect(paths, ['/v1/responses']);
  });

  test('explicit mode and --no-stream override the saved options', () async {
    final settings = await writeSettings([
      savedProfile('saved', 'Responses 配置', apiMode: 'responses', stream: true),
    ]);
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body.containsKey('stream'), isFalse);
      await _json(request, {
        'data': [
          {'b64_json': _pngBase64},
        ],
      });
    };
    final result = await run(
      ['--prompt', 'cat', '--api-mode', 'images', '--no-stream'],
      env: {'MINT_IMAGE_SETTINGS_FILE': settings.path},
    );
    expect(result.code, 0);
    expect(paths, ['/v1/images/generations']);
  });

  test('inherits the saved global timeout', () async {
    final settings = await writeSettings([
      savedProfile('saved', '短超时'),
    ], timeout: 1);
    respond = (request) async {
      await request.drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      await _json(request, {
        'data': [
          {'b64_json': _pngBase64},
        ],
      });
    };
    final result = await run(
      ['--prompt', 'cat'],
      env: {'MINT_IMAGE_SETTINGS_FILE': settings.path},
    );
    expect(result.code, 1);
    expect(result.error, contains('超时'));
  });

  test(
    'unknown or ambiguous profiles fail before submitting a request',
    () async {
      final settings = await writeSettings([
        savedProfile('first', '同名配置'),
        savedProfile('second', '同名配置'),
      ]);
      for (final selector in ['missing', '同名配置']) {
        final result = await run([
          '--prompt',
          'cat',
          '--profile',
          selector,
          '--settings-file',
          settings.path,
        ], env: {});
        expect(result.code, 2);
        expect(result.json['error']['type'], 'config_error');
        expect(result.error, contains('mint-image profiles'));
        expect(paths, isEmpty);
      }
    },
  );

  test(
    'a requested profile cannot silently fall back when no store exists',
    () async {
      final result = await run([
        '--prompt',
        'cat',
        '--profile',
        'missing',
      ], env: {});
      expect(result.code, 2);
      expect(result.json['error']['type'], 'config_error');
      expect(paths, isEmpty);
    },
  );

  test(
    'corrupt settings report the file without exposing its contents',
    () async {
      final file = File(p.join(directory.path, 'broken.json'));
      await file.writeAsString('{"apiKey":"corrupt-secret" broken');
      final result = await run([
        'profiles',
        '--settings-file',
        file.path,
      ], env: {});
      expect(result.code, 2);
      expect(result.error, contains('broken.json'));
      expect(result.output, isNot(contains('corrupt-secret')));
      expect(result.error, isNot(contains('corrupt-secret')));
      expect(paths, isEmpty);
    },
  );

  test(
    '--no-app-config skips stored settings and preserves independent use',
    () async {
      final result = await run(
        ['--prompt', 'cat', '--no-app-config'],
        env: {
          ...environment,
          'MINT_IMAGE_SETTINGS_FILE': p.join(directory.path, 'missing.json'),
        },
      );
      expect(result.code, 0);
      expect(authorization, ['Bearer $_key']);
    },
  );

  test('provider errors redact saved profile keys', () async {
    final settings = await writeSettings([savedProfile('saved', '已保存')]);
    respond = (request) async => _json(request, {
      'error': 'Invalid key saved-profile-secret',
    }, status: 401);
    final result = await run(
      ['--prompt', 'cat'],
      env: {'MINT_IMAGE_SETTINGS_FILE': settings.path},
    );
    expect(result.code, 1);
    expect(result.output, isNot(contains('saved-profile-secret')));
    expect(result.error, contains('[REDACTED]'));
  });

  for (final conflicting in [
    ['--profile', 'some-name'],
    ['--settings-file', 'settings.json'],
  ]) {
    test(
      'disabled app configuration rejects conflicting selectors: $conflicting',
      () async {
        final result = await run([
          '--prompt',
          'cat',
          '--no-app-config',
          ...conflicting,
        ]);
        expect(result.code, 2);
        expect(result.json['error']['type'], 'invalid_arguments');
        expect(paths, isEmpty);
      },
    );
  }

  test('generates from text/plain JSON with normalized /v1 URL', () async {
    Map<String, dynamic>? body;
    respond = (request) async {
      body = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.headers.contentType = ContentType.text;
      request.response.write(
        jsonEncode({
          'data': [
            {'b64_json': _pngBase64},
          ],
        }),
      );
      await request.response.close();
    };
    final result = await run([
      'generate',
      '--prompt',
      '中文提示词：薄荷色的猫',
      '--base-url',
      '${environment['MINT_IMAGE_BASE_URL']}/v1/',
      '--size',
      '1536x1024',
    ]);
    expect(result.code, 0);
    expect(result.error, isEmpty);
    expect(paths, ['/v1/images/generations']);
    expect(authorization, ['Bearer $_key']);
    expect(body!['model'], 'gpt-image-2');
    expect(body!['size'], '1536x1024');
    expect(body!['prompt'], '中文提示词：薄荷色的猫');
    expect(body!.containsKey('stream'), isFalse);
    final file = File(result.json['results'][0]['files'][0] as String);
    expect(p.isAbsolute(file.path), isTrue);
    expect(await file.readAsBytes(), base64Decode(_pngBase64));
  });

  test('bounded workers overlap and finish all tasks', () async {
    var active = 0;
    var maximumActive = 0;
    respond = (request) async {
      await request.drain<void>();
      active++;
      if (active > maximumActive) maximumActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      active--;
      await _json(request, {
        'data': [
          {'b64_json': _pngBase64},
        ],
      });
    };
    final result = await run([
      '--prompt',
      'cat',
      '--count',
      '5',
      '--parallel',
      '2',
    ]);
    expect(result.code, 0);
    expect(maximumActive, 2);
    expect(paths.length, 5);
    expect(result.json['succeeded'], 5);
    final results = result.json['results'] as List;
    expect(results.map((item) => item['index']), [1, 2, 3, 4, 5]);
    expect(results.expand((item) => item['files']).toSet().length, 5);
  });

  test('independent invocations safely share an output directory', () async {
    final results = await Future.wait([
      run(['--prompt', 'cat']),
      run(['--prompt', 'dog']),
    ]);
    expect(results.map((result) => result.code), [0, 0]);
    final paths = results
        .map((result) => result.json['results'][0]['files'][0] as String)
        .toSet();
    expect(paths.length, 2);
    for (final path in paths) {
      expect(await File(path).readAsBytes(), base64Decode(_pngBase64));
    }
  });

  test('multipart editing uploads every reference image', () async {
    final image = File(p.join(directory.path, '参考图, one.png'));
    await image.writeAsBytes(base64Decode(_pngBase64));
    String? body;
    respond = (request) async {
      expect(request.headers.contentType!.mimeType, 'multipart/form-data');
      body = latin1.decode(
        await request.fold<List<int>>([], (a, b) => a..addAll(b)),
      );
      await _json(request, {
        'data': [
          {'b64_json': _pngBase64},
        ],
      });
    };
    final result = await run([
      '--prompt',
      'make it green',
      '--image',
      image.path,
      '--image',
      image.path,
    ]);
    expect(result.code, 0);
    expect(paths, ['/v1/images/edits']);
    expect('name="image[]"'.allMatches(body!).length, 2);
    expect(body, contains('make it green'));
  });

  test('Responses API uses the shared image tool protocol', () async {
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['model'], 'fixture-responses-model');
      expect(body['tools'][0]['type'], 'image_generation');
      expect(body['tools'][0].containsKey('size'), isFalse);
      await _json(request, {
        'output': [
          {'type': 'image_generation_call', 'result': _pngBase64},
        ],
      });
    };
    final result = await run([
      '--prompt',
      'cat',
      '--api-mode',
      'responses',
      '--model',
      'fixture-responses-model',
      '--size',
      'auto',
    ]);
    expect(result.code, 0);
    expect(paths, ['/v1/responses']);
  });

  test(
    'downloads a returned URL without leaking the API authorization',
    () async {
      respond = (request) async {
        if (request.uri.path == '/image.png') {
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(base64Decode(_pngBase64));
          await request.response.close();
        } else {
          await _json(request, {
            'data': [
              {'url': '${environment['MINT_IMAGE_BASE_URL']}/image.png'},
            ],
          });
        }
      };
      final result = await run(['--prompt', 'cat']);
      expect(result.code, 0);
      expect(paths, ['/v1/images/generations', '/image.png']);
      expect(authorization, ['Bearer $_key', null]);
    },
  );

  test('HTTP failure keeps status and reason and redacts the key', () async {
    respond = (request) async => _json(request, {
      'error': {'message': 'Invalid API key: $_key'},
    }, status: 401);
    final result = await run(['--prompt', 'cat']);
    expect(result.code, 1);
    expect(result.output, isNot(contains(_key)));
    expect(result.error, isNot(contains(_key)));
    final error = result.json['results'][0]['error'] as Map;
    expect(error['http_status'], 401);
    expect(error['message'], contains('Invalid API key: [REDACTED]'));
    expect(jsonDecode(result.error)['index'], 1);
  });

  test('HTTP 200 error payload preserves the provider failure', () async {
    respond = (request) async => _json(request, {
      'error': {'message': 'Model permission denied'},
    });
    final result = await run(['--prompt', 'cat']);
    expect(result.code, 1);
    expect(result.error, contains('Model permission denied'));
  });

  test('streaming HTTP failures preserve status and provider reason', () async {
    respond = (request) async => _json(request, {
      'error': {'message': 'Streaming permission denied'},
    }, status: 403);
    final result = await run(['--prompt', 'cat', '--stream']);
    expect(result.code, 1);
    expect(result.error, contains('Streaming permission denied'));
    expect(result.json['results'][0]['error']['http_status'], 403);
  });

  for (final mode in ['images', 'responses']) {
    test('streaming $mode error events preserve the cause', () async {
      respond = (request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'event: error\ndata: ${jsonEncode({
            'error': {'message': 'Upstream rendering failed'},
          })}\n\n',
        );
        await request.response.close();
      };
      final result = await run([
        '--prompt',
        'cat',
        '--stream',
        '--api-mode',
        mode,
      ]);
      expect(result.code, 1);
      expect(result.error, contains('Upstream rendering failed'));
    });
  }

  test('streaming completion saves the final image', () async {
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['stream'], isTrue);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      request.response.write(
        'event: image_generation.completed\ndata: ${jsonEncode({'b64_json': _pngBase64})}\n\n',
      );
      await request.response.close();
    };
    final result = await run(['--prompt', 'cat', '--stream']);
    expect(result.code, 0);
    expect(result.error, isEmpty);
  });

  test('a Responses failure event keeps the nested upstream cause', () async {
    respond = (request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'type': 'response.failed',
          'response': {
            'error': {'message': 'Rendering capacity exhausted'},
          },
        })}\n\n',
      );
      await request.response.close();
    };
    final result = await run([
      '--prompt',
      'cat',
      '--stream',
      '--api-mode',
      'responses',
    ]);
    expect(result.code, 1);
    expect(result.error, contains('Rendering capacity exhausted'));
  });

  test('batch partial failure keeps successes and returns failure', () async {
    var received = 0;
    respond = (request) async {
      received++;
      if (received == 2) {
        await _json(request, {'error': 'Quota exhausted'}, status: 429);
      } else {
        await _json(request, {
          'data': [
            {'b64_json': _pngBase64},
          ],
        });
      }
    };
    final result = await run([
      '--prompt',
      'cat',
      '--count',
      '3',
      '--parallel',
      '2',
    ]);
    expect(result.code, 1);
    expect(result.json['succeeded'], 2);
    expect(result.json['failed'], 1);
    expect(result.error, contains('Quota exhausted'));
    expect(const LineSplitter().convert(result.error).length, 1);
  });

  for (final payload in [
    {'data': []},
    {
      'data': [{}],
    },
    {
      'data': [
        {'b64_json': 'invalid base64!'},
      ],
    },
    {
      'data': [
        {'b64_json': base64Encode(utf8.encode('<html>error</html>'))},
      ],
    },
  ]) {
    test('rejects missing or invalid image content: $payload', () async {
      respond = (request) async => _json(request, payload);
      final result = await run(['--prompt', 'cat']);
      expect(result.code, 1);
      expect(result.json['results'][0]['error']['type'], 'invalid_response');
      expect(await directory.list().toList(), isEmpty);
    });
  }

  test(
    'download HTTP failure reports download status and provider reason',
    () async {
      respond = (request) async {
        if (request.uri.path == '/image.png') {
          await _json(request, {'error': 'Image expired'}, status: 403);
        } else {
          await _json(request, {
            'data': [
              {'url': '${environment['MINT_IMAGE_BASE_URL']}/image.png'},
            ],
          });
        }
      };
      final result = await run(['--prompt', 'cat']);
      expect(result.code, 1);
      expect(result.json['results'][0]['error']['http_status'], 403);
      expect(result.error, contains('Image expired'));
    },
  );

  test('timeout cancels the request and exits within the limit', () async {
    respond = (request) async {
      await request.drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      await _json(request, {
        'data': [
          {'b64_json': _pngBase64},
        ],
      });
    };
    final stopwatch = Stopwatch()..start();
    final result = await run(['--prompt', 'cat', '--timeout', '1']);
    expect(result.code, 1);
    expect(result.error, contains('超时'));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('the same task deadline includes image downloads', () async {
    respond = (request) async {
      await request.drain<void>();
      if (request.uri.path == '/slow.png') {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        request.response.add(base64Decode(_pngBase64));
        await request.response.close();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _json(request, {
          'data': [
            {'url': '${environment['MINT_IMAGE_BASE_URL']}/slow.png'},
          ],
        });
      }
    };
    final result = await run(['--prompt', 'cat', '--timeout', '1']);
    expect(result.code, 1);
    expect(result.error, contains('超时'));
    expect(await directory.list().toList(), isEmpty);
  });

  test('connection failures preserve the system socket error', () async {
    final unused = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = unused.port;
    await unused.close(force: true);
    final result = await run([
      '--prompt',
      'cat',
      '--base-url',
      'http://127.0.0.1:$port',
      '--timeout',
      '5',
    ]);
    expect(result.code, 1);
    expect(result.error, contains('SocketException'));
    expect(result.error, contains('127.0.0.1'));
  });

  test('prompt can be read as UTF-8 from stdin or a file', () async {
    final prompts = <String>[];
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      prompts.add(body['prompt'] as String);
      await _json(request, {
        'data': [
          {'b64_json': _pngBase64},
        ],
      });
    };
    final prompt = File(p.join(directory.path, 'prompt.txt'));
    await prompt.writeAsString('\uFEFF第一行\n第二行');
    final fileResult = await run(['--prompt-file', prompt.path]);
    final stdinResult = await run(['--prompt-file', '-'], input: '另一只猫\n绿色背景');
    expect([fileResult.code, stdinResult.code], [0, 0]);
    expect(prompts, ['第一行\n第二行', '另一只猫\n绿色背景']);
  });

  test('explicit output path is exclusive and never overwrites', () async {
    final target = File(p.join(directory.path, 'output.png'));
    final first = await run(['--prompt', 'cat', '--output', target.path]);
    final second = await run(['--prompt', 'dog', '--output', target.path]);
    expect(first.code, 0);
    expect(second.code, 2);
    expect(second.error, contains('已存在'));
    expect(await target.readAsBytes(), base64Decode(_pngBase64));
    expect(paths.length, 1);
  });

  test(
    'concurrent writers cannot overwrite the same explicit output',
    () async {
      final target = File(p.join(directory.path, 'shared.png'));
      respond = (request) async {
        await request.drain<void>();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _json(request, {
          'data': [
            {'b64_json': _pngBase64},
          ],
        });
      };
      final results = await Future.wait([
        run(['--prompt', 'cat', '--output', target.path]),
        run(['--prompt', 'dog', '--output', target.path]),
      ]);
      expect(results.where((result) => result.code == 0).length, 1);
      expect(results.where((result) => result.code != 0).length, 1);
      expect(await target.readAsBytes(), base64Decode(_pngBase64));
    },
  );

  test('output directory failure occurs before a paid request', () async {
    final file = File(p.join(directory.path, 'file'));
    await file.writeAsString('do not overwrite');
    final result = await run(['--prompt', 'cat', '--output-dir', file.path]);
    expect(result.code, 1);
    expect(result.json['error']['type'], 'io_error');
    expect(paths, isEmpty);
    expect(await file.readAsString(), 'do not overwrite');
  });

  for (final args in [
    ['--prompt', 'cat', '--count', '0'],
    ['--prompt', 'cat', '--parallel', '-1'],
    ['--prompt', 'cat', '--timeout', 'none'],
    ['--prompt', 'cat', '--size', '0x1024'],
    ['--prompt', 'cat', '--quality', 'unknown'],
    ['--prompt', 'cat', '--unknown'],
    ['--prompt', 'cat', '--api-mode', 'unknown'],
    ['--prompt', 'cat', '--base-url', 'ftp://localhost'],
    ['--prompt', 'cat', '--base-url', 'https://user:password@example.com'],
    ['--prompt', 'cat', '--prompt-file', '-'],
    ['--prompt', ''],
  ]) {
    test('invalid arguments fail before contacting the API: $args', () async {
      final result = await run(args);
      expect(result.code, 2);
      expect(result.json['ok'], isFalse);
      expect(result.error, isNotEmpty);
      expect(paths, isEmpty);
    });
  }

  test('missing API key gives a clear input error', () async {
    final result = await run(['--prompt', 'cat'], env: {});
    expect(result.code, 2);
    expect(result.error, contains('MINT_IMAGE_API_KEY'));
    expect(paths, isEmpty);
  });

  test(
    'missing reference and prompt files give concrete input errors',
    () async {
      final missing = p.join(directory.path, 'missing.png');
      for (final args in [
        ['--prompt', 'cat', '--image', missing],
        ['--prompt-file', missing],
      ]) {
        final result = await run(args);
        expect(result.code, 2);
        expect(result.error, contains('missing.png'));
        expect(paths, isEmpty);
      }
    },
  );
}

Future<void> _json(HttpRequest request, Object body, {int status = 200}) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

class _Result {
  const _Result(this.code, this.output, this.error);
  final int code;
  final String output;
  final String error;
  Map<String, dynamic> get json => jsonDecode(output) as Map<String, dynamic>;
}

Future<_Result> _run(
  List<String> arguments,
  Map<String, String> environment, {
  String? input,
}) async {
  // The same fixture suite validates the core and the actual packaged process.
  final binary = Platform.environment['MINT_IMAGE_CLI_BINARY'];
  if (binary == null || binary.isEmpty) {
    final output = StringBuffer();
    final error = StringBuffer();
    final code = await runMintImageCli(
      arguments,
      environment: environment,
      input: Stream.value(utf8.encode(input ?? '')),
      output: output,
      errorOutput: error,
    );
    return _Result(code, output.toString(), error.toString());
  }
  final childEnvironment = {...Platform.environment}
    ..removeWhere(
      (key, _) =>
          key.startsWith('MINT_IMAGE_') ||
          const ['APPDATA', 'USERPROFILE', 'HOME'].contains(key.toUpperCase()),
    )
    ..addAll(environment);
  final process = await Process.start(
    p.absolute(binary),
    arguments,
    workingDirectory: File(binary).absolute.parent.path,
    environment: childEnvironment,
    includeParentEnvironment: false,
  );
  final output = utf8.decoder.bind(process.stdout).join();
  final error = utf8.decoder.bind(process.stderr).join();
  if (input != null) process.stdin.add(utf8.encode(input));
  await process.stdin.close();
  final code = await process.exitCode.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      process.kill();
      throw TimeoutException('CLI did not exit within 10 seconds');
    },
  );
  return _Result(code, await output, await error);
}
