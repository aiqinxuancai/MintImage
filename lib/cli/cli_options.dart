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
  ..addOption(
    'model',
    abbr: 'm',
    help: '仅本次请求使用的模型名；Base URL、Key 等仍继承所选配置，不修改已保存配置。环境变量 MINT_IMAGE_MODEL。',
  )
  ..addOption(
    'api-mode',
    allowed: ['images', 'images_async', 'responses'],
    help: 'API 协议，默认继承 MintImage 配置，未配置时为 images。',
  )
  ..addOption('size', defaultsTo: '1024x1024', help: '宽x高或 auto，具体支持范围由服务商决定。')
  ..addOption(
    'quality',
    allowed: ['auto', 'low', 'medium', 'high', 'xhigh', 'max'],
    defaultsTo: 'auto',
  )
  ..addOption(
    'format',
    allowed: ['png', 'jpeg', 'webp', 'gif', 'svg'],
    defaultsTo: 'png',
  )
  ..addOption(
    'complexity',
    allowed: ['low', 'medium', 'high'],
    help: 'GPT Image 2.6 规划复杂度；省略时使用服务端默认值。',
  )
  ..addOption('frame-count', help: 'GIF 帧数：2–64，默认 9；仅用于 --format gif。')
  ..addOption('svg-model', help: 'SVG 绘制模型 ID；省略时使用服务端默认值。')
  ..addOption(
    'svg-reasoning-effort',
    allowed: ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'],
    help: 'SVG 绘制模型推理强度，需同时指定 --svg-model。',
  )
  ..addOption('markup', help: '第一张参考图的透明 PNG 标注层；尺寸需一致。')
  ..addOption('safety-identifier', help: '可选匿名安全标识，最多 128 字符；默认继承配置。')
  ..addOption(
    'frame-duration-ms',
    help: 'GIF 每帧时长：20–2000 毫秒，默认 200；服务端按 10 毫秒取整。',
  )
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
  mint-image generate --model "其他模型" --prompt "提示词"
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
        ImageOutputFormat.gif => ext == '.gif',
        ImageOutputFormat.svg => ext == '.svg',
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
      safetyIdentifier:
          args['safety-identifier'] as String? ??
          savedProfile?.safetyIdentifier ??
          '',
      useStreaming: args.wasParsed('stream')
          ? args['stream'] as bool
          : savedProfile?.useStreaming ?? false,
    );
    if (format != ImageOutputFormat.gif &&
        (args.wasParsed('frame-count') ||
            args.wasParsed('frame-duration-ms'))) {
      throw const CliException('invalid_arguments', '帧数和帧时长仅适用于 --format gif。');
    }
    final svgModel = args['svg-model'] as String?;
    if ((svgModel != null || args.wasParsed('svg-reasoning-effort')) &&
        (format != ImageOutputFormat.svg ||
            svgModel == null ||
            svgModel.trim().isEmpty)) {
      throw const CliException(
        'invalid_arguments',
        'SVG 参数需要 --format svg 和非空 --svg-model。',
      );
    }
    if ((profile.resolvedSafetyIdentifier?.length ?? 0) > 128) {
      throw const CliException('invalid_arguments', '安全标识最多 128 个字符。');
    }
    final markup = args['markup'] as String?;
    if (markup != null &&
        (markup.trim().isEmpty || !await File(markup).exists())) {
      throw const CliException('invalid_input', '标注图不存在，请检查 --markup 路径。');
    }
    final request = GenerationRequest(
      svgOptions: svgModel == null
          ? null
          : SvgOptions(
              model: svgModel.trim(),
              reasoningEffort: SvgReasoningEffort.fromApiValue(
                args['svg-reasoning-effort'] as String?,
              ),
            ),
      markupPath: markup == null ? null : File(markup).absolute.path,
      prompt: prompt,
      imagePaths: imagePaths,
      sizePreset: size == 'auto' ? SizePreset.auto : SizePreset.custom,
      customWidth: width ?? 1024,
      customHeight: height ?? 1024,
      quality: ImageQuality.fromApiValue(args['quality'] as String),
      outputFormat: format,
      complexity: ImageComplexity.fromApiValue(args['complexity'] as String?),
      frameCount: _positiveInteger(args, 'frame-count', fallback: 9),
      frameDurationMs: _positiveInteger(
        args,
        'frame-duration-ms',
        fallback: 200,
      ),
      count: 1,
      apiProfileId: profile.id,
    );
    final validation = request.validate(
      usesResponsesApi: mode == ImageGenerationApiMode.responses,
    );
    if (validation != null) throw CliException('invalid_arguments', validation);
    return CliOptions(
      profile: profile,
      request: request,
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
