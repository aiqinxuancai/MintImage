import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/models/settings_model.dart';
import 'cli_error.dart';

/// Reads the desktop application's existing preferences without Flutter or writes.
class CliSettingsStore {
  CliSettingsStore({
    required this.environment,
    String? operatingSystem,
    Future<String> Function(File)? readPlist,
  }) : operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _readPlist = readPlist ?? _convertPlistToJson;

  final Map<String, String> environment;
  final String operatingSystem;
  final Future<String> Function(File) _readPlist;

  List<String> get preferencePaths {
    if (operatingSystem == 'windows') {
      final appData = environment['APPDATA'];
      final userProfile = environment['USERPROFILE'];
      final root = appData?.isNotEmpty == true
          ? appData
          : userProfile?.isNotEmpty == true
          ? p.join(userProfile!, 'AppData', 'Roaming')
          : null;
      return root == null
          ? []
          : [p.join(root, 'com.aiqin', 'MintImage', 'shared_preferences.json')];
    }
    if (operatingSystem == 'macos') {
      final home = environment['HOME'];
      if (home == null || home.isEmpty) return [];
      const bundleId = 'com.aiqin.mintImage';
      return [
        p.join(
          home,
          'Library',
          'Containers',
          bundleId,
          'Data',
          'Library',
          'Preferences',
          '$bundleId.plist',
        ),
        p.join(home, 'Library', 'Preferences', '$bundleId.plist'),
      ];
    }
    return [];
  }

  Future<CliSavedSettings?> load({String? settingsFile}) async {
    final explicitPath =
        settingsFile ?? environment['MINT_IMAGE_SETTINGS_FILE'];
    if (explicitPath != null && explicitPath.trim().isEmpty) {
      throw const CliException('config_error', '配置文件路径不能为空。');
    }
    final candidates = explicitPath == null ? preferencePaths : [explicitPath];
    for (final path in candidates) {
      final file = File(path).absolute;
      try {
        final type = await FileSystemEntity.type(file.path);
        if (type == FileSystemEntityType.notFound && explicitPath == null) {
          continue;
        }
        final text = p.extension(file.path).toLowerCase() == '.plist'
            ? await _readPlist(file)
            : await file.readAsString(encoding: utf8);
        final preferences = jsonDecode(
          text.replaceFirst(RegExp(r'^\uFEFF'), ''),
        );
        if (preferences is! Map) {
          throw const FormatException();
        }
        final raw =
            preferences['flutter.${SettingsModel.storageKey}'] ??
            preferences[SettingsModel.storageKey] ??
            (preferences.containsKey('profiles') ? preferences : null);
        if (raw == null && explicitPath == null) continue;
        if (raw == null) {
          throw CliException(
            'config_error',
            '配置文件未包含 MintImage 生图设置：${file.path}',
          );
        }
        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is! Map || decoded['profiles'] is! List) {
          throw const FormatException();
        }
        final profiles = <ApiProfile>[];
        for (final value in decoded['profiles'] as List) {
          if (value is! Map ||
              value['id'] is! String ||
              (value['id'] as String).isEmpty) {
            throw const FormatException();
          }
          profiles.add(ApiProfile.fromJson(Map<String, dynamic>.from(value)));
        }
        final activeId = decoded['activeProfileId'];
        final active = profiles.where((profile) => profile.id == activeId);
        final timeout = decoded['requestTimeoutSeconds'];
        return CliSavedSettings(
          profiles: profiles,
          activeProfileId: active.isNotEmpty
              ? active.first.id
              : profiles.firstOrNull?.id,
          timeoutSeconds: timeout is int && timeout > 0
              ? timeout
              : SettingsModel.defaultRequestTimeoutSeconds,
          sourcePath: file.path,
        );
      } on CliException {
        rethrow;
      } on FileSystemException catch (error) {
        throw CliException(
          'config_error',
          '无法读取 MintImage 配置文件 ${file.path}：${error.osError?.message ?? error.message}',
        );
      } catch (_) {
        // A JSON/typing error may contain the original text, including keys.
        throw CliException('config_error', 'MintImage 配置文件格式无效：${file.path}');
      }
    }
    return null;
  }
}

class CliSavedSettings {
  const CliSavedSettings({
    required this.profiles,
    required this.activeProfileId,
    required this.timeoutSeconds,
    required this.sourcePath,
  });

  final List<ApiProfile> profiles;
  final String? activeProfileId;
  final int timeoutSeconds;
  final String sourcePath;

  ApiProfile? selectProfile(String? selector) {
    if (selector == null) {
      return profiles
          .where((profile) => profile.id == activeProfileId)
          .firstOrNull;
    }
    final value = selector.trim();
    if (value.isEmpty) {
      throw const CliException('invalid_arguments', '--profile 配置名称或 ID 不能为空。');
    }
    final ids = profiles.where((profile) => profile.id == value).toList();
    final matches = ids.isNotEmpty
        ? ids
        : profiles.where((profile) => profile.name == value).toList();
    if (matches.isEmpty) {
      throw const CliException(
        'config_error',
        '未找到指定的生图配置，请运行 mint-image profiles 查看可用的名称和 ID。',
      );
    }
    if (matches.length != 1) {
      throw const CliException(
        'config_error',
        '存在多个同名生图配置，请运行 mint-image profiles 并使用配置 ID 选择。',
      );
    }
    return matches.single;
  }

  Map<String, Object?> publicJson() {
    final secrets = profiles.map((profile) => profile.apiKey.trim()).toList();
    String safe(String value) => redactCliSecrets(value, secrets);
    return {
      'ok': true,
      'settings_file': safe(sourcePath),
      'active_profile_id': activeProfileId == null
          ? null
          : safe(activeProfileId!),
      'request_timeout_seconds': timeoutSeconds,
      'profiles': [
        for (final profile in profiles)
          {
            'id': safe(profile.id),
            'name': safe(profile.name),
            'base_url': safe(profile.baseUrl),
            'model': safe(profile.model),
            'api_mode': profile.apiMode.storageValue,
            'stream': profile.useStreaming,
            'is_active': profile.id == activeProfileId,
            'has_api_key': profile.apiKey.trim().isNotEmpty,
          },
      ],
    };
  }
}

Future<String> _convertPlistToJson(File file) async {
  if (!Platform.isMacOS) {
    throw const CliException('config_error', '读取 .plist 配置文件需要在 macOS 上运行。');
  }
  final process = await Process.start('/usr/bin/plutil', [
    '-convert',
    'json',
    '-o',
    '-',
    '--',
    file.path,
  ]);
  final output = utf8.decoder.bind(process.stdout).join();
  // Never forward a native tool's output: malformed plists can contain secrets.
  final errors = process.stderr.drain<void>();
  final code = await process.exitCode.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      process.kill();
      throw const CliException('config_error', '读取 macOS MintImage 配置文件超时。');
    },
  );
  final text = await output;
  await errors;
  if (code != 0) {
    throw CliException(
      'config_error',
      '无法解析 macOS 配置文件（退出码 $code）：${file.path}',
    );
  }
  return text;
}
