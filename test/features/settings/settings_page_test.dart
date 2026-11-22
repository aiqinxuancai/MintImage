import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/core/providers/settings_provider.dart';
import 'package:mint_image/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Responses settings follow the selected image protocol', (
    tester,
  ) async {
    await _pumpSettingsPage(tester, const Size(1280, 1000));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('image-api')),
        matching: find.byTooltip('编辑'),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.text('将尺寸和宽高比加入提示词');
    final effort = find.text('思考等级');
    expect(toggle, findsNothing);
    expect(effort, findsNothing);
    for (final mode in [
      ImageGenerationApiMode.responses,
      ImageGenerationApiMode.imagesAsync,
    ]) {
      await tester.tap(
        find.byType(DropdownButtonFormField<ImageGenerationApiMode>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(mode.label).last);
      await tester.pumpAndSettle();
      final expected = mode == ImageGenerationApiMode.responses
          ? findsOneWidget
          : findsNothing;
      expect(toggle, expected);
      expect(effort, expected);
    }
  });

  testWidgets('compact layout stacks sections in a single column', (
    tester,
  ) async {
    await _pumpSettingsPage(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('数据备份与恢复'), 300);
    final request = tester.getTopLeft(find.text('请求'));
    final backup = tester.getTopLeft(find.text('数据备份与恢复'));
    expect(backup.dx, request.dx);
    expect(backup.dy, greaterThan(request.dy));
    // Swipe-to-delete is used on compact screens instead of inline buttons.
    expect(find.byTooltip('删除'), findsNothing);
  });

  testWidgets('wide layout places API and data sections side by side', (
    tester,
  ) async {
    await _pumpSettingsPage(tester, const Size(1280, 900));

    expect(tester.takeException(), isNull);
    final imageApi = tester.getTopLeft(find.text('生图 API'));
    final backup = tester.getTopLeft(find.text('数据备份与恢复'));
    expect(backup.dx, greaterThan(imageApi.dx + 300));
    expect((backup.dy - imageApi.dy).abs(), lessThan(40));

    // Two image profiles share a row in the grid.
    final first = tester.getTopLeft(find.byKey(const ValueKey('image-api')));
    final second = tester.getTopLeft(find.byKey(const ValueKey('image-api-2')));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
  });

  testWidgets('tapping a profile card makes it active', (tester) async {
    final container = await _pumpSettingsPage(tester, const Size(1280, 900));

    await tester.tap(find.text('备用'));
    await tester.pump();

    expect(container.read(settingsProvider).activeProfileId, 'api-2');
  });

  testWidgets('wide layout deletes a profile after confirmation', (
    tester,
  ) async {
    final container = await _pumpSettingsPage(tester, const Size(1280, 900));

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('image-api-2')),
        matching: find.byTooltip('删除'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('确定删除「备用」吗？此操作无法撤销。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).profiles.map((p) => p.id), ['api']);
  });

  testWidgets('shows empty state when no prompt optimization profile', (
    tester,
  ) async {
    await _pumpSettingsPage(
      tester,
      const Size(390, 844),
      settings: const SettingsModel(
        profiles: [_apiProfile],
        activeProfileId: 'api',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('还没有提示词优化 API。添加后，首页输入框右侧会启用提示词优化。'), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpSettingsPage(
  WidgetTester tester,
  Size size, {
  SettingsModel settings = _settings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSettingsModelProvider.overrideWithValue(settings),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pump();

  return ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
}

const _apiProfile = ApiProfile(
  id: 'api',
  name: '默认',
  baseUrl: 'https://api.openai.com',
  apiKey: 'test-key',
  model: 'gpt-image-2',
);

const _settings = SettingsModel(
  profiles: [
    _apiProfile,
    ApiProfile(
      id: 'api-2',
      name: '备用',
      baseUrl: 'https://example.com/v1',
      apiKey: 'test-key-2',
      model: 'gpt-image-2',
      apiMode: ImageGenerationApiMode.responses,
    ),
  ],
  activeProfileId: 'api',
  promptOptimizationProfiles: [
    PromptOptimizationProfile(
      id: 'optimizer',
      name: 'Optimizer',
      baseUrl: 'https://api.openai.com',
      apiKey: 'test-key',
      model: 'gpt-5.5',
      protocol: PromptOptimizationProtocol.openAiResponses,
    ),
  ],
  activePromptOptimizationProfileId: 'optimizer',
);
