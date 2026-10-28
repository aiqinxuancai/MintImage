import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:dio/dio.dart';

import '../core/api/image_edit_api.dart';
import '../core/api/image_generation_api.dart';
import 'cli_error.dart';
import 'cli_image_writer.dart';
import 'cli_options.dart';
import 'cli_settings_store.dart';

/// Runs without Flutter initialization or modifying application settings/history.
Future<int> runMintImageCli(
  List<String> arguments, {
  Map<String, String>? environment,
  Stream<List<int>>? input,
  StringSink? output,
  StringSink? errorOutput,
}) async {
  final env = environment ?? Platform.environment;
  final out = output ?? stdout;
  final err = errorOutput ?? stderr;
  final secrets = <String>[
    if (env['MINT_IMAGE_API_KEY'] != null) env['MINT_IMAGE_API_KEY']!.trim(),
    for (var i = 0; i < arguments.length; i++)
      if (arguments[i] == '--api-key' && i + 1 < arguments.length)
        arguments[i + 1].trim()
      else if (arguments[i].startsWith('--api-key='))
        arguments[i].substring('--api-key='.length).trim(),
  ];
  CliImageWriter? writer;
  try {
    final listProfiles = arguments.isNotEmpty && arguments.first == 'profiles';
    final parser = listProfiles ? createProfileListParser() : createCliParser();
    final raw =
        arguments.isNotEmpty && (arguments.first == 'generate' || listProfiles)
        ? arguments.sublist(1)
        : arguments;
    final ArgResults args;
    try {
      args = parser.parse(raw);
    } on FormatException catch (error) {
      throw CliException('invalid_arguments', error.message);
    }
    if (args.rest.isNotEmpty) {
      throw const CliException(
        'invalid_arguments',
        '不支持的命令或位置参数，请运行 mint-image --help。',
      );
    }
    if (arguments.isEmpty || args['help'] as bool) {
      out.write(listProfiles ? cliProfilesUsage(parser) : cliUsage(parser));
      return 0;
    }
    final useAppConfig = listProfiles || args['app-config'] as bool;
    if (!useAppConfig &&
        (args['profile'] != null || args['settings-file'] != null)) {
      throw const CliException(
        'invalid_arguments',
        '--no-app-config 不能与 --profile 或 --settings-file 同时使用。',
      );
    }
    final settings = useAppConfig
        ? await CliSettingsStore(
            environment: env,
          ).load(settingsFile: args['settings-file'] as String?)
        : null;
    if (settings != null) {
      secrets.addAll(settings.profiles.map((profile) => profile.apiKey.trim()));
    }
    if (listProfiles) {
      out.writeln(
        jsonEncode(
          settings?.publicJson() ??
              {
                'ok': true,
                'settings_file': null,
                'active_profile_id': null,
                'profiles': <Object>[],
                'message': '未找到已保存的 MintImage 生图配置。',
              },
        ),
      );
      return 0;
    }
    final selector = args['profile'] as String?;
    if (selector != null && settings == null) {
      throw const CliException(
        'config_error',
        '未找到 MintImage 配置，请先在桌面端保存生图配置，或使用 --settings-file 指定配置文件。',
      );
    }
    final savedProfile = settings?.selectProfile(selector);
    final options = await CliOptions.fromArguments(
      args,
      env,
      input ?? stdin,
      savedProfile: savedProfile,
      savedTimeoutSeconds: settings?.timeoutSeconds,
    );
    secrets.add(options.profile.apiKey);
    final imageWriter = CliImageWriter(options);
    writer = imageWriter;
    await imageWriter.prepare();
    final results = List<Map<String, Object?>?>.filled(options.count, null);
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < options.count) {
        // No await between claiming an index and incrementing it.
        final index = nextIndex++;
        results[index] = await _runTask(
          options,
          imageWriter,
          index + 1,
          secrets,
        );
        final result = results[index]!;
        if (result['ok'] == false) {
          err.writeln(
            jsonEncode({'index': index + 1, 'error': result['error']}),
          );
        }
      }
    }

    await Future.wait(
      List.generate(math.min(options.parallel, options.count), (_) => worker()),
    );
    final succeeded = results.where((result) => result!['ok'] == true).length;
    out.writeln(
      jsonEncode({
        'ok': succeeded == options.count,
        'requested': options.count,
        'succeeded': succeeded,
        'failed': options.count - succeeded,
        'results': results,
      }),
    );
    return succeeded == options.count ? 0 : 1;
  } catch (error) {
    final failure = describeCliError(error);
    final result = {'ok': false, 'error': failure.toJson(secrets)};
    out.writeln(jsonEncode(result));
    err.writeln(jsonEncode(result));
    return const [
          'invalid_arguments',
          'invalid_input',
          'config_error',
        ].contains(failure.type)
        ? 2
        : 1;
  } finally {
    writer?.close();
  }
}

Future<Map<String, Object?>> _runTask(
  CliOptions options,
  CliImageWriter writer,
  int index,
  List<String> secrets,
) async {
  final stopwatch = Stopwatch()..start();
  final cancelToken = CancelToken();
  final files = <String>[];
  try {
    final results =
        await (options.request.hasAttachments
                ? const ImageEditApi().edit(
                    options.request,
                    options.profile,
                    timeoutSeconds: options.timeoutSeconds,
                    cancelToken: cancelToken,
                  )
                : const ImageGenerationApi().generate(
                    options.request,
                    options.profile,
                    timeoutSeconds: options.timeoutSeconds,
                    cancelToken: cancelToken,
                  ))
            .timeout(
              Duration(seconds: options.timeoutSeconds),
              onTimeout: () {
                cancelToken.cancel('任务超时');
                throw TimeoutException(
                  '任务超时（超过 ${options.timeoutSeconds} 秒），已取消请求。',
                );
              },
            );
    if (results.isEmpty || results.any((result) => !result.hasImageData)) {
      throw const CliException('invalid_response', '接口返回成功，但没有可保存的图片数据。');
    }
    if (options.outputPath != null && results.length != 1) {
      throw const CliException(
        'invalid_response',
        '接口返回多张图片，无法保存到单个 --output 文件，请使用 --output-dir。',
      );
    }
    for (var i = 0; i < results.length; i++) {
      files.add(
        await writer.save(
          results[i],
          taskIndex: index,
          imageIndex: i + 1,
          cancelToken: cancelToken,
          remaining:
              Duration(seconds: options.timeoutSeconds) - stopwatch.elapsed,
        ),
      );
    }
    return {
      'index': index,
      'ok': true,
      'files': files,
      'elapsed_ms': stopwatch.elapsedMilliseconds,
    };
  } catch (error) {
    if (!cancelToken.isCancelled) cancelToken.cancel('任务失败');
    return {
      'index': index,
      'ok': false,
      'files': files,
      'error': describeCliError(error).toJson(secrets),
      'elapsed_ms': stopwatch.elapsedMilliseconds,
    };
  }
}
