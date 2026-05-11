import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_image_flutter/core/models/settings_model.dart';

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
    final settings = SettingsModel.initial().copyWith(
      requestTimeoutSeconds: 900,
    );

    final decoded = SettingsModel.decode(settings.encode());

    expect(decoded.requestTimeoutSeconds, 900);
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
