import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../core/models/generation_request.dart';
import '../core/models/settings_model.dart';
import 'cli_error.dart';

ArgParser createProfileListParser() => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false, help: '显示帮助。')
  ..addOption('settings-file', help: '指定 MintImage 配置文件；默认自动查找桌面端配置。');

ArgParser createCliParser() => createProfileListParser()
  ..addOption('profile', help: '使用 MintImage 中保存的配置名称或 ID；默认使用当前配置。')
  ..addFlag(
    'app-config',
    defaultsTo: true,
    help: '读取 MintImage 配置；--no-app-config 可禁用。',
  )
  ..addOption('prompt', abbr: 'p', help: '提示词；与 --prompt-file 二选一。')
  ..addOption('prompt-file', help: 'UTF-8 提示词文件；- 表示从标准输入读取。')
  ..addMultiOption('image', splitCommas: false, help: '参考图路径，可重复；提供后使用图生图。')
  ..addOption('base-url', help: 'API 地址（可包含 /v1）。环境变量 MINT_IMAGE_BASE_URL。')
  ..addOption('api-key', help: 'API 密钥，建议改用环境变量 MINT_IMAGE_API_KEY。')
  ..addOption('model', help: '模型名。环境变量 MINT_IMAGE_MODEL。')
  ..addOption(
    'api-mode',
    allowed: ['images', 'responses'],
    help: 'API 协议，默认继承 MintImage 配置，未配置时为 images。',
  )
  ..addOption('size', defaultsTo: '1024x1024', help: '宽x高或 auto，具体支持范围由服务商决定。')
  ..addOption(
    'quality',
    allowed: ['auto', 'low', 'medium', 'high'],
    defaultsTo: 'auto',
  )
  ..addOption('format', allowed: ['png', 'jpeg', 'webp'], defaultsTo: 'png')
  ..addOption('count', defaultsTo: '1', help: '独立生成任务数（每次请求一张图）。')
  ..addOption('parallel', defaultsTo: '1', help: '同时执行的任务数。')
  ..addOption('timeout', help: '网络总超时秒数，默认继承 MintImage 设置或 600 秒。')
  ..addOption('output', abbr: 'o', help: '单张图片的目标路径；已存在时失败，防止覆盖。')
  ..addOption('output-dir', help: '输出目录，默认 ./mint-image-output；自动生成唯一文件名。')
  ..addFlag(
    'stream',
    defaultsTo: false,
    help: '流式 API 开关；默认继承 MintImage 配置，未配置时关闭。',
  );

String cliProfilesUsage(ArgParser parser) =>
    '''列出 MintImage 已保存的生图配置（不输出密钥）

用法:
  mint-image profiles [选项]

${parser.usage}
''';

String cliUsage(ArgParser parser) =>
    '''MintImage 命令行生图（不创建 UI，任务完成后退出）

用法:
  mint-image generate --prompt "提示词" [选项]
  mint-image generate --profile "配置名称" --prompt "提示词"
  mint-image profiles
  mint-image generate --prompt-file - --count 4 --parallel 2
  mint-image generate --prompt "修改说明" --image reference.png

${parser.usage}

配置优先级: 命令行 > MINT_IMAGE_* 环境变量 > MintImage 已保存配置 > 默认值。
不指定 --profile 时使用 MintImage 当前选中的生图配置。
默认 API: https://api.openai.com；Images 默认模型 gpt-image-2。
stdout: 一份 JSON 结果；stderr: 每个错误一行 JSON（帮助除外）。
退出码: 0 全部成功；1 运行失败（含部分失败）；2 参数或输入无效。
''';

class CliOptions {
  const CliOptions({
    required this.profile,
    required this.request,
    required this.count,
    required this.parallel,
    required this.timeoutSeconds,
    required this.outputDirectory,
    required this.outputPath,
  });

  final ApiProfile profile;
  final GenerationRequest request;
  final int count;
  final int parallel;
  final int timeoutSeconds;
  final String outputDirectory;
  final String? outputPath;

  static Future<CliOptions> fromArguments(
    ArgResults args,
    Map<String, String> environment,
    Stream<List<int>> input, {
    ApiProfile? savedProfile,
    int? savedTimeoutSeconds,
  }) async {
    String configured(String flag, String variable, String fallback) =>
        (args[flag] as String? ?? environment[variable] ?? fallback).trim();

    final key = configured(
      'api-key',
      'MINT_IMAGE_API_KEY',
      savedProfile?.apiKey ?? '',
    );
    if (key.isEmpty) {
      throw const CliException(
        'invalid_arguments',
        '缺少 API Key，请先在 MintImage 中保存生图配置，或设置 MINT_IMAGE_API_KEY / --api-key。',
      );
    }
    if (key.contains(RegExp(r'[\r\n]'))) {
      throw const CliException('invalid_arguments', 'API Key 不能包含换行。');
    }
    final mode = ImageGenerationApiMode.fromStorageValue(
      args['api-mode'] ?? savedProfile?.apiMode.storageValue,
    );
    final model = configured(
      'model',
      'MINT_IMAGE_MODEL',
      savedProfile?.model ?? mode.defaultModel,
    );
    if (model.isEmpty) {
      throw const CliException('invalid_arguments', '模型名不能为空。');
    }
    var baseUrl = configured(
      'base-url',
      'MINT_IMAGE_BASE_URL',
      savedProfile?.baseUrl ?? 'https://api.openai.com',
    ).replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const CliException(
        'invalid_arguments',
        'Base URL 必须是 http(s) 地址，不能包含凭据、查询参数或片段。',
      );
    }
    // Shared API classes append /v1 themselves, including prefixed gateways.
    if (uri.path.endsWith('/v1')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 3);
    }
    final count = _positiveInteger(args, 'count');
    final parallel = _positiveInteger(args, 'parallel');
    final timeout = _positiveInteger(
      args,
      'timeout',
      fallback:
          savedTimeoutSeconds ?? SettingsModel.defaultRequestTimeoutSeconds,
    );
    final output = args['output'] as String?;
    final outputDir = args['output-dir'] as String?;
    if (output != null && (count != 1 || outputDir != null)) {
      throw const CliException(
        'invalid_arguments',
        '--output 仅适用于 --count 1，且不能与 --output-dir 同时使用。',
      );
    }
    if (output?.trim().isEmpty == true || outputDir?.trim().isEmpty == true) {
      throw const CliException('invalid_arguments', '输出路径不能为空。');
    }
    final format = ImageOutputFormat.fromApiValue(args['format'] as String);
    if (output != null) {
      final ext = p.extension(output).toLowerCase();
      final valid = switch (format) {
        ImageOutputFormat.png => ext == '.png',
        ImageOutputFormat.jpeg => ext == '.jpeg' || ext == '.jpg',
        ImageOutputFormat.webp => ext == '.webp',
      };
      if (!valid) {
        throw const CliException(
          'invalid_arguments',
          '--output 文件扩展名必须与 --format 一致（默认为 png）。',
        );
      }
      if (await FileSystemEntity.type(output, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const CliException('invalid_arguments', '--output 目标已存在，请选择新路径。');
      }
    }
    final size = args['size'] as String;
    final dimensions = RegExp(r'^([1-9]\d*)x([1-9]\d*)$').firstMatch(size);
    final width = dimensions == null
        ? null
        : int.tryParse(dimensions.group(1)!);
    final height = dimensions == null
        ? null
        : int.tryParse(dimensions.group(2)!);
    if (size != 'auto' && (width == null || height == null)) {
      throw const CliException(
        'invalid_arguments',
        '--size 必须是正整数像素尺寸（如 1024x1536）或 auto。',
      );
    }
    final promptArg = args['prompt'] as String?;
    final promptFile = args['prompt-file'] as String?;
    if ((promptArg == null) == (promptFile == null)) {
      throw const CliException(
        'invalid_arguments',
        '请提供 --prompt 或 --prompt-file，且只能提供其中一个。',
      );
    }
    String prompt;
    try {
      prompt =
          promptArg ??
          (promptFile == '-'
              ? await utf8.decoder.bind(input).join()
              : await File(promptFile!).readAsString(encoding: utf8));
    } on FileSystemException catch (error) {
      throw CliException('invalid_input', '读取提示词失败：$error');
    } on FormatException {
      throw const CliException('invalid_input', '提示词必须是有效的 UTF-8 文本。');
    }
    prompt = prompt.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (prompt.isEmpty) {
      throw const CliException('invalid_input', '提示词不能为空。');
    }
    final imagePaths = <String>[];
    for (final image in args['image'] as List<String>) {
      final file = File(image).absolute;
      try {
        final handle = await file.open();
        try {
          if (await handle.length() == 0) {
            throw CliException('invalid_input', '参考图为空：${file.path}');
          }
        } finally {
          await handle.close();
        }
      } on FileSystemException catch (error) {
        throw CliException('invalid_input', '无法读取参考图：$error');
      }
      imagePaths.add(file.path);
    }
    final profile = ApiProfile(
      id: savedProfile?.id ?? 'cli',
      name: savedProfile?.name ?? 'CLI',
      baseUrl: baseUrl,
      apiKey: key,
      model: model,
      apiMode: mode,
      useStreaming: args.wasParsed('stream')
          ? args['stream'] as bool
          : savedProfile?.useStreaming ?? false,
    );
    return CliOptions(
      profile: profile,
      request: GenerationRequest(
        prompt: prompt,
        imagePaths: imagePaths,
        sizePreset: size == 'auto' ? SizePreset.auto : SizePreset.custom,
        customWidth: width ?? 1024,
        customHeight: height ?? 1024,
        quality: ImageQuality.fromApiValue(args['quality'] as String),
        outputFormat: format,
        count: 1,
        apiProfileId: profile.id,
      ),
      count: count,
      parallel: parallel,
      timeoutSeconds: timeout,
      outputDirectory: Directory(
        output == null ? outputDir ?? 'mint-image-output' : p.dirname(output),
      ).absolute.path,
      outputPath: output == null ? null : File(output).absolute.path,
    );
  }
}

int _positiveInteger(ArgResults args, String name, {int? fallback}) {
  final raw = args[name] as String?;
  final value = raw == null ? fallback : int.tryParse(raw);
  if (value == null || value <= 0) {
    throw CliException('invalid_arguments', '--$name 必须是正整数。');
  }
  return value;
}
