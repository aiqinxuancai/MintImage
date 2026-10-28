import 'dart:convert';
import 'dart:io';

import 'package:mint_image/cli/cli_runner.dart';

/// This entrypoint has no Flutter imports and compiles to a console executable.
Future<void> main(List<String> arguments) async {
  stdout.encoding = utf8;
  stderr.encoding = utf8;
  final code = await runMintImageCli(arguments);
  await stdout.flush();
  await stderr.flush();
  // Do not keep an Agent waiting for HTTP keep-alive sockets or plugin services.
  exit(code);
}
