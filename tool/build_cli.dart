import 'dart:io';

/// Run from the repository root after `flutter pub get`.
Future<void> main() async {
  if (!File('bin/mint_image.dart').existsSync()) {
    stderr.writeln('请从项目根目录运行 dart run tool/build_cli.dart。');
    exit(2);
  }
  final process = await Process.start(Platform.resolvedExecutable, [
    'build',
    'cli',
    '--target=bin/mint_image.dart',
    '--output=build/cli',
  ], mode: ProcessStartMode.inheritStdio);
  final code = await process.exitCode;
  if (code != 0) exit(code);

  final suffix = Platform.isWindows ? '.exe' : '';
  final executable = await File(
    'build/cli/bundle/bin/mint_image$suffix',
  ).rename('build/cli/bundle/bin/mint-image$suffix');
  await File('docs/CLI.md').copy('build/cli/bundle/README.md');
  stdout.writeln('CLI: ${executable.absolute.path}');
}
