import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_image_flutter/core/api/image_generation_api.dart';
import 'package:gpt_image_flutter/core/models/generation_request.dart';
import 'package:gpt_image_flutter/core/models/settings_model.dart';

void main() {
  final runLiveGeneration = Platform.environment['RUN_LIVE_GENERATION'] == '1';
  final baseUrl = Platform.environment['TEST_BASE_URL'];
  final apiKey = Platform.environment['TEST_API_KEY'];
  final model = Platform.environment['TEST_MODEL'] ?? 'gpt-image-2';
  final prompt =
      Platform.environment['TEST_PROMPT'] ??
      'a clean light blue abstract icon on a white background';
  final timeoutSeconds =
      int.tryParse(Platform.environment['TEST_TIMEOUT_SECONDS'] ?? '') ??
      SettingsModel.defaultRequestTimeoutSeconds;

  test(
    'generates a real image with the provided URL and key',
    () async {
      final api = const ImageGenerationApi();
      final request = GenerationRequest(
        prompt: prompt,
        imagePaths: const [],
        sizePreset: SizePreset.square1k,
        customWidth: 1024,
        customHeight: 1024,
        quality: ImageQuality.auto,
        count: 1,
        apiProfileId: 'live',
      );
      final profile = ApiProfile(
        id: 'live',
        name: 'live',
        baseUrl: baseUrl!,
        apiKey: apiKey!,
        model: model,
      );

      final results = await api.generate(
        request,
        profile,
        timeoutSeconds: timeoutSeconds,
      );

      expect(results, isNotEmpty);

      final first = results.first;
      if (first.b64Json != null && first.b64Json!.isNotEmpty) {
        expect(base64Decode(first.b64Json!), isNotEmpty);
      } else if (first.imageUrl != null && first.imageUrl!.isNotEmpty) {
        final client = HttpClient();
        try {
          final response = await (await client.getUrl(
            Uri.parse(first.imageUrl!),
          )).close();
          expect(response.statusCode, 200);
          expect(response.headers.contentType?.mimeType, startsWith('image'));

          final bytes = <int>[];
          await for (final chunk in response) {
            bytes.addAll(chunk);
          }
          expect(bytes, isNotEmpty);
        } finally {
          client.close(force: true);
        }
      } else {
        fail('The API returned no usable image data.');
      }
    },
    skip: !runLiveGeneration
        ? 'Set RUN_LIVE_GENERATION=1, TEST_BASE_URL, TEST_API_KEY, and TEST_MODEL.'
        : false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
