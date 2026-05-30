import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/api/prompt_optimization_api.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/features/input/bottom_input_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps prompt input and submit button at 40px', (tester) async {
    await _pumpInputBar(tester);

    final inputFinder = find.byKey(const Key('prompt-input'));
    final submitFinder = find.byKey(const Key('submit-generation-button'));
    final optimizeFinder = find.byKey(const Key('prompt-optimize-button'));

    expect(tester.getSize(inputFinder).height, moreOrLessEquals(40));
    expect(tester.getSize(submitFinder), const Size(40, 40));
    expect(
      tester.getRect(optimizeFinder).center.dy,
      moreOrLessEquals(tester.getRect(inputFinder).center.dy),
    );
  });

  testWidgets('shows clickable stop loading state while optimizing', (
    tester,
  ) async {
    final api = _BlockingPromptOptimizationApi();
    await _pumpInputBar(tester, promptOptimizationApi: api);

    await tester.enterText(find.byKey(const Key('prompt-input')), '一只白猫');
    await tester.tap(find.byKey(const Key('prompt-optimize-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('强化'));
    for (var i = 0; i < 20 && !api.started.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(api.started.isCompleted, isTrue);
    await tester.pump();

    expect(
      find.byKey(const Key('prompt-optimization-spinner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('prompt-optimization-stop-square')),
      findsOneWidget,
    );
    expect(find.byTooltip('停止优化'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prompt-optimize-button')));
    await api.cancelled.future;
    await tester.pump();

    expect(api.cancelled.isCompleted, isTrue);
    expect(find.byKey(const Key('prompt-optimization-spinner')), findsNothing);
    expect(find.byTooltip('优化提示词'), findsOneWidget);
  });
}

Future<void> _pumpInputBar(
  WidgetTester tester, {
  PromptOptimizationApi? promptOptimizationApi,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSettingsModelProvider.overrideWithValue(_settings),
        promptOptimizationApiProvider.overrideWithValue(
          promptOptimizationApi ?? const PromptOptimizationApi(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 420,
              child: BottomInputBar(onSubmit: (request) async {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _apiProfile = ApiProfile(
  id: 'api',
  name: 'API',
  baseUrl: 'https://api.openai.com',
  apiKey: 'test-key',
  model: 'gpt-image-2',
);

const _promptOptimizationProfile = PromptOptimizationProfile(
  id: 'optimizer',
  name: 'Optimizer',
  baseUrl: 'https://api.openai.com',
  apiKey: 'test-key',
  model: 'gpt-5.5',
  protocol: PromptOptimizationProtocol.openAiResponses,
);

const _settings = SettingsModel(
  profiles: [_apiProfile],
  activeProfileId: 'api',
  promptOptimizationProfiles: [_promptOptimizationProfile],
  activePromptOptimizationProfileId: 'optimizer',
);

class _BlockingPromptOptimizationApi extends PromptOptimizationApi {
  _BlockingPromptOptimizationApi();

  final Completer<void> started = Completer<void>();
  final Completer<void> cancelled = Completer<void>();
  final Completer<String> _response = Completer<String>();

  @override
  Future<String> optimize({
    required String prompt,
    required PromptOptimizationDirection direction,
    required PromptOptimizationProfile profile,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) {
    if (!started.isCompleted) {
      started.complete();
    }

    cancelToken?.whenCancel.then((_) {
      if (!cancelled.isCompleted) {
        cancelled.complete();
      }
      if (!_response.isCompleted) {
        _response.completeError(const ApiException('请求已取消。'));
      }
    });

    return _response.future;
  }
}
