import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  test('initial settings use a 600 second timeout', () {
    final settings = SettingsModel.initial();

    expect(
      settings.requestTimeoutSeconds,
      SettingsModel.defaultRequestTimeoutSeconds,
    );
    expect(settings.responseFormat, isNull);
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
    );

    final decoded = SettingsModel.decode(settings.encode());

    expect(decoded.requestTimeoutSeconds, 900);
    expect(decoded.promptOptimizationProfiles, hasLength(1));
    expect(decoded.activePromptOptimizationProfile?.id, 'optimizer-1');
    expect(
      decoded.activePromptOptimizationProfile?.protocol,
      PromptOptimizationProtocol.openAiResponses,
    );
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
  });

  test('image API mode is persisted per profile', () {
    final settings = SettingsModel.initial();
    final profile = settings.activeProfile.copyWith(
      model: 'gpt-5.5',
      apiMode: ImageGenerationApiMode.responses,
    );
    final updated = settings.copyWith(profiles: [profile]);

    final decoded = SettingsModel.decode(updated.encode());

    expect(decoded.activeProfile.apiMode, ImageGenerationApiMode.responses);
    expect(decoded.activeProfile.generationEndpoint, contains('/v1/responses'));
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
