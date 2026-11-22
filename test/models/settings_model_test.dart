import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  test('settings retain GIF timing, SVG format and complexity', () {
    final settings = SettingsModel.initial().copyWith(
      lastOutputFormat: ImageOutputFormat.gif,
      lastFrameCount: 16,
      lastFrameDurationMs: 120,
      lastComplexity: ImageComplexity.medium,
    );
    final restored = SettingsModel.decode(settings.encode());
    expect(restored.lastOutputFormat, ImageOutputFormat.gif);
    expect(restored.lastFrameCount, 16);
    expect(restored.lastFrameDurationMs, 120);
    expect(restored.lastComplexity, ImageComplexity.medium);
    final svg = restored.copyWith(
      lastOutputFormat: ImageOutputFormat.svg,
      clearLastComplexity: true,
    );
    final restoredSvg = SettingsModel.decode(svg.encode());
    expect(restoredSvg.lastOutputFormat, ImageOutputFormat.svg);
    expect(restoredSvg.lastComplexity, isNull);
  });
  test('initial settings use a 600 second timeout', () {
    final settings = SettingsModel.initial();

    expect(
      settings.requestTimeoutSeconds,
      SettingsModel.defaultRequestTimeoutSeconds,
    );
    expect(settings.responseFormat, isNull);
    expect(settings.lastSizePreset, SizePreset.auto);
    expect(settings.lastCustomWidth, 0);
    expect(settings.lastCustomHeight, 0);
    expect(settings.lastQuality, ImageQuality.auto);
    expect(settings.lastOutputFormat, ImageOutputFormat.png);
  });

  test('settings round-trip preserves request timeout', () {
    final optimizer = PromptOptimizationProfile(
      id: 'optimizer-1',
      name: '优化',
      baseUrl: 'https://right.codes/codex/v1',
      apiKey: 'key',
      model: 'gpt-5.5',
      protocol: PromptOptimizationProtocol.openAiResponses,
    );
    final settings = SettingsModel.initial().copyWith(
      requestTimeoutSeconds: 900,
      promptOptimizationProfiles: [optimizer],
      activePromptOptimizationProfileId: optimizer.id,
      lastSizePreset: SizePreset.wide2k,
      lastCustomWidth: 2560,
      lastCustomHeight: 1440,
      lastQuality: ImageQuality.high,
      lastOutputFormat: ImageOutputFormat.webp,
    );

    final decoded = SettingsModel.decode(settings.encode());

    expect(decoded.requestTimeoutSeconds, 900);
    expect(decoded.promptOptimizationProfiles, hasLength(1));
    expect(decoded.activePromptOptimizationProfile?.id, 'optimizer-1');
    expect(
      decoded.activePromptOptimizationProfile?.protocol,
      PromptOptimizationProtocol.openAiResponses,
    );
    expect(decoded.lastSizePreset, SizePreset.wide2k);
    expect(decoded.lastCustomWidth, 2560);
    expect(decoded.lastCustomHeight, 1440);
    expect(decoded.lastQuality, ImageQuality.high);
    expect(decoded.lastOutputFormat, ImageOutputFormat.webp);
  });

  test('settings round-trip preserves WebDAV backup config', () {
    final settings = SettingsModel.initial().copyWith(
      webDavBackupConfig: const WebDavBackupConfig(
        baseUrl: 'https://example.com/dav',
        username: 'user',
        password: 'pass',
        remoteDirectory: 'MintImage/backups',
      ),
    );

    final decoded = SettingsModel.decode(settings.encode());

    expect(decoded.webDavBackupConfig?.baseUrl, 'https://example.com/dav');
    expect(decoded.webDavBackupConfig?.username, 'user');
    expect(decoded.webDavBackupConfig?.password, 'pass');
    expect(decoded.webDavBackupConfig?.remoteDirectory, 'MintImage/backups');
  });

  test('legacy settings default to no prompt optimization profiles', () {
    final decoded = SettingsModel.fromJson({
      'profiles': [
        {
          'id': '1',
          'name': '默认',
          'baseUrl': 'https://api.openai.com',
          'apiKey': 'key',
          'model': 'gpt-image-2',
        },
      ],
      'activeProfileId': '1',
      'requestTimeoutSeconds': 600,
    });

    expect(decoded.promptOptimizationProfiles, isEmpty);
    expect(decoded.activePromptOptimizationProfile, isNull);
    expect(decoded.activeProfile.apiMode, ImageGenerationApiMode.images);
    expect(decoded.lastSizePreset, SizePreset.auto);
    expect(decoded.lastQuality, ImageQuality.auto);
    expect(decoded.lastOutputFormat, ImageOutputFormat.png);
  });

  test('image API mode is persisted per profile', () {
    final settings = SettingsModel.initial();
    final profile = settings.activeProfile.copyWith(
      model: 'gpt-5.5',
      apiMode: ImageGenerationApiMode.responses,
    );
    final updated = settings.copyWith(
      profiles: [
        profile.copyWith(
          reasoningEffort: ResponsesReasoningEffort.high,
          includeSizeInPrompt: true,
        ),
      ],
    );

    final decoded = SettingsModel.decode(updated.encode());

    expect(decoded.activeProfile.apiMode, ImageGenerationApiMode.responses);
    expect(
      decoded.activeProfile.reasoningEffort,
      ResponsesReasoningEffort.high,
    );
    expect(decoded.activeProfile.includeSizeInPrompt, isTrue);
    expect(decoded.activeProfile.generationEndpoint, contains('/v1/responses'));
  });

  for (final baseUrl in [
    'https://rightapi.ai',
    ' https://rightapi.ai/v1/ ',
    'https://www.rightapi.ai/',
    'https://www.rightapi.ai/draw',
    'https://rightapi.ai/draw/v1/',
  ]) {
    test('RightAPI image endpoints normalize $baseUrl to the site root', () {
      final profile = ApiProfile.fromJson(
        ApiProfile.initial().copyWith(baseUrl: baseUrl).toJson(),
      );
      expect(profile.apiMode, ImageGenerationApiMode.imagesAsync);
      expect(profile.normalizedBaseUrl, 'https://rightapi.ai');
      expect(
        profile.generationEndpoint,
        'https://rightapi.ai/v1/images/generations',
      );
      expect(profile.editEndpoint, 'https://rightapi.ai/v1/images/edits');
    });
  }

  for (final baseUrl in [
    'https://openrouter.ai',
    'https://openrouter.ai/api',
    'https://openrouter.ai/api/v1/',
    ' https://openrouter.ai/api/v1/images/ ',
  ]) {
    test('OpenRouter image endpoint resolves $baseUrl', () {
      final profile = ApiProfile.initial().copyWith(baseUrl: baseUrl);
      expect(profile.normalizedBaseUrl, 'https://openrouter.ai/api');
      expect(profile.generationPath, '/v1/images');
      expect(profile.generationEndpoint, 'https://openrouter.ai/api/v1/images');
    });
  }

  test('OpenRouter route requires the exact host and Images protocol', () {
    final profile = ApiProfile.initial().copyWith(
      baseUrl: 'https://openrouter.ai.example.com/api/v1',
    );
    expect(profile.generationPath, '/v1/images/generations');
    final responses = profile.copyWith(
      baseUrl: 'https://openrouter.ai/api',
      apiMode: ImageGenerationApiMode.responses,
    );
    expect(
      responses.generationEndpoint,
      'https://openrouter.ai/api/v1/responses',
    );
  });

  test('RightAPI normalization preserves Responses channel paths', () {
    final profile = ApiProfile.initial().copyWith(
      baseUrl: 'https://rightapi.ai/codex/v1/',
      apiMode: ImageGenerationApiMode.responses,
    );
    expect(profile.apiMode, ImageGenerationApiMode.responses);
    expect(profile.normalizedBaseUrl, 'https://rightapi.ai/codex/v1');
  });

  test('legacy migration requires the exact former host', () {
    final profile = ApiProfile.fromJson(
      ApiProfile.initial()
          .copyWith(baseUrl: 'https://rightapi.ai.example.com/draw/')
          .toJson(),
    );
    expect(profile.apiMode, ImageGenerationApiMode.images);
    expect(profile.normalizedBaseUrl, 'https://rightapi.ai.example.com/draw');
  });

  for (final baseUrl in [
    'https://api.site',
    'https://another.example/gateway',
  ]) {
    test('async Images protocol persists independently of $baseUrl', () {
      final profile = ApiProfile.initial().copyWith(
        baseUrl: '$baseUrl/v1/',
        apiMode: ImageGenerationApiMode.imagesAsync,
      );
      final decoded = ApiProfile.fromJson(profile.toJson());
      expect(decoded.apiMode, ImageGenerationApiMode.imagesAsync);
      expect(decoded.normalizedBaseUrl, baseUrl);
      expect(decoded.generationEndpoint, '$baseUrl/v1/images/generations');
      expect(decoded.editEndpoint, '$baseUrl/v1/images/edits');
    });
  }

  test('migrated async profiles retain the protocol after a domain change', () {
    final profile = ApiProfile.fromJson(
      ApiProfile.initial().copyWith(baseUrl: 'https://rightapi.ai').toJson(),
    ).copyWith(baseUrl: 'https://api.site');
    final decoded = ApiProfile.fromJson(profile.toJson());
    expect(decoded.apiMode, ImageGenerationApiMode.imagesAsync);
    expect(decoded.normalizedBaseUrl, 'https://api.site');
  });

  test('legacy b64_json responseFormat is normalized to null', () {
    final decoded = SettingsModel.fromJson({
      'profiles': [
        {
          'id': '1',
          'name': '默认',
          'baseUrl': 'https://api.openai.com',
          'apiKey': 'key',
          'model': 'gpt-image-2',
        },
      ],
      'activeProfileId': '1',
      'responseFormat': 'b64_json',
      'requestTimeoutSeconds': 600,
    });

    expect(decoded.responseFormat, isNull);
  });
}
