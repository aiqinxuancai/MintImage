import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/cli/cli_error.dart';
import 'package:mint_image/cli/cli_settings_store.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:path/path.dart' as p;

Map<String, Object?> _profile(String id, String name) => {
  'id': id,
  'name': name,
  'apiKey': '$id-secret',
  'baseUrl': 'https://example.com',
  'model': 'fixture-model',
};

String _preferences({String key = 'flutter.settings_model_v1'}) => jsonEncode({
  key: jsonEncode({
    'profiles': [_profile('saved', '桌面配置')],
    'activeProfileId': 'saved',
  }),
});

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mint-cli-settings-');
  });
  tearDown(() => directory.delete(recursive: true));

  test('Windows storage path agrees with desktop version resources', () {
    final store = CliSettingsStore(
      environment: {'APPDATA': directory.path},
      operatingSystem: 'windows',
    );
    expect(store.preferencePaths, [
      p.join(
        directory.path,
        'com.aiqin',
        'MintImage',
        'shared_preferences.json',
      ),
    ]);
  });

  test('Windows USERPROFILE fallback retains the desktop storage layout', () {
    final store = CliSettingsStore(
      environment: {'USERPROFILE': directory.path},
      operatingSystem: 'windows',
    );
    expect(
      store.preferencePaths.single,
      p.join(
        directory.path,
        'AppData',
        'Roaming',
        'com.aiqin',
        'MintImage',
        'shared_preferences.json',
      ),
    );
  });

  test(
    'macOS prefers sandboxed application preferences over legacy ones',
    () async {
      final reads = <String>[];
      final store = CliSettingsStore(
        environment: {'HOME': directory.path},
        operatingSystem: 'macos',
        readPlist: (file) async {
          reads.add(file.path);
          return _preferences();
        },
      );
      expect(
        store.preferencePaths.first,
        p.join(
          directory.path,
          'Library',
          'Containers',
          'com.aiqin.mintImage',
          'Data',
          'Library',
          'Preferences',
          'com.aiqin.mintImage.plist',
        ),
      );
      for (final path in store.preferencePaths) {
        await File(path).create(recursive: true);
      }
      final saved = await store.load();
      expect(saved!.selectProfile(null)!.name, '桌面配置');
      expect(reads, [store.preferencePaths.first]);
    },
  );

  test(
    'macOS finds non-sandboxed preferences when no container exists',
    () async {
      final store = CliSettingsStore(
        environment: {'HOME': directory.path},
        operatingSystem: 'macos',
        readPlist: (_) async => _preferences(),
      );
      final file = File(store.preferencePaths.last);
      await file.create(recursive: true);
      expect((await store.load())!.sourcePath, file.absolute.path);
    },
  );

  test(
    'a missing native settings key permits trying the next macOS location',
    () async {
      var reads = 0;
      final store = CliSettingsStore(
        environment: {'HOME': directory.path},
        operatingSystem: 'macos',
        readPlist: (_) async => ++reads == 1 ? '{}' : _preferences(),
      );
      for (final path in store.preferencePaths) {
        await File(path).create(recursive: true);
      }
      expect(
        (await store.load())!.sourcePath,
        File(store.preferencePaths.last).absolute.path,
      );
      expect(reads, 2);
    },
  );

  for (final key in [
    'flutter.${SettingsModel.storageKey}',
    SettingsModel.storageKey,
  ]) {
    test('reads preferences with key $key', () async {
      final file = File(p.join(directory.path, 'settings.json'));
      await file.writeAsString(_preferences(key: key));
      final saved = await CliSettingsStore(
        environment: {},
      ).load(settingsFile: file.path);
      expect(saved!.profiles.single.apiKey, 'saved-secret');
    });
  }

  test(
    'reads an explicitly selected raw SettingsModel JSON document',
    () async {
      final file = File(p.join(directory.path, 'settings.json'));
      await file.writeAsString(
        jsonEncode({
          'profiles': [_profile('saved', '原始配置')],
        }),
      );
      final saved = await CliSettingsStore(
        environment: {},
      ).load(settingsFile: file.path);
      expect(saved!.selectProfile(null)!.name, '原始配置');
    },
  );

  test(
    'empty profile lists are valid and invalid active ID uses first profile',
    () async {
      final file = File(p.join(directory.path, 'settings.json'));
      final store = CliSettingsStore(environment: {});
      await file.writeAsString(jsonEncode({'profiles': []}));
      final empty = await store.load(settingsFile: file.path);
      expect(empty!.profiles, isEmpty);
      expect(empty.selectProfile(null), isNull);
      await file.writeAsString(
        jsonEncode({
          'profiles': [_profile('first', '首个')],
          'activeProfileId': 'deleted',
        }),
      );
      expect(
        (await store.load(settingsFile: file.path))!.activeProfileId,
        'first',
      );
    },
  );

  test('ID selection wins over an unrelated matching display name', () {
    final saved = CliSavedSettings(
      profiles: [
        ApiProfile.fromJson(_profile('id-one', 'name-one')),
        ApiProfile.fromJson(_profile('id-two', 'id-one')),
      ],
      activeProfileId: 'id-two',
      timeoutSeconds: 600,
      sourcePath: 'fixture',
    );
    expect(saved.selectProfile('id-one')!.id, 'id-one');
  });

  for (final value in [
    'secret-json malformed',
    '[]',
    '{}',
    '{"profiles":[{}]}',
  ]) {
    test('invalid settings give sanitized config errors: $value', () async {
      final file = File(p.join(directory.path, 'bad.json'));
      await file.writeAsString(value);
      await expectLater(
        CliSettingsStore(environment: {}).load(settingsFile: file.path),
        throwsA(
          isA<CliException>()
              .having((e) => e.type, 'type', 'config_error')
              .having(
                (e) => e.message,
                'message',
                isNot(contains('secret-json')),
              ),
        ),
      );
    });
  }
}
