import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/features/image_list/image_cell.dart';
import 'package:mint_image/features/image_list/image_preview_page.dart';
import 'package:mint_image/shared/widgets/record_svg_image.dart';
import 'package:photo_view/photo_view_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays animated GIF in the list and full screen preview', (
    tester,
  ) async {
    final file = File('test/fixtures/animation.gif').absolute;
    final record = _record.copyWith(
      status: ImageRecordStatus.done,
      outputFormat: 'gif',
      resultImagePath: file.path,
    );
    await _pumpImageCell(tester, record);
    final imageFinder = find.descendant(
      of: find.byType(ImageCell),
      matching: find.byType(RawImage),
    );
    for (
      var attempt = 0;
      attempt < 100 && tester.widget<RawImage>(imageFinder).image == null;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    final first = await _pixel(
      tester.widget<RawImage>(imageFinder).image!,
      tester,
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 220)),
    );
    await tester.pump(const Duration(milliseconds: 220));
    final second = await _pixel(
      tester.widget<RawImage>(imageFinder).image!,
      tester,
    );
    expect(second, isNot(first));

    await tester.tapAt(
      tester.getTopLeft(find.byType(ImageCell)) + const Offset(120, 90),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ImagePreviewPage), findsOneWidget);
    final previewImage = find.descendant(
      of: find.byType(ImagePreviewPage),
      matching: find.byType(RawImage),
    );
    for (
      var attempt = 0;
      attempt < 100 &&
          (previewImage.evaluate().isEmpty ||
              tester.widget<RawImage>(previewImage).image == null);
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(previewImage, findsOneWidget);
    final previewFirst = await _pixel(
      tester.widget<RawImage>(previewImage).image!,
      tester,
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 220)),
    );
    await tester.pump(const Duration(milliseconds: 220));
    final previewSecond = await _pixel(
      tester.widget<RawImage>(previewImage).image!,
      tester,
    );
    expect(previewSecond, isNot(previewFirst));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders SVG in the list and opens a vector zoom preview', (
    tester,
  ) async {
    final file = File('test/fixtures/generated.svg').absolute;
    final record = _record.copyWith(
      status: ImageRecordStatus.done,
      outputFormat: 'svg',
      resultImagePath: file.path,
    );
    await _pumpImageCell(tester, record);
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
    expect(find.byType(RecordSvgImage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tapAt(
      tester.getTopLeft(find.byType(ImageCell)) + const Offset(120, 90),
    );
    await tester.pump();
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    final gallery = tester.widget<PhotoViewGallery>(
      find.byType(PhotoViewGallery),
    );
    final options = gallery.builder!(
      tester.element(find.byType(PhotoViewGallery)),
      0,
    );
    expect(options.child, isA<RecordSvgImage>());
    expect(options.childSize, const Size(240, 120));
    expect(find.text('实际尺寸240x120'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows error details when tapping failed status pill', (
    tester,
  ) async {
    await _pumpImageCell(
      tester,
      _record.copyWith(errorMessage: '接口返回 429：额度不足'),
    );

    await tester.tap(find.text('失败'));
    await tester.pumpAndSettle();

    expect(find.text('失败原因'), findsOneWidget);
    expect(find.text('接口返回 429：额度不足'), findsOneWidget);
  });

  testWidgets('long error responses can be read and the dialog closed', (
    tester,
  ) async {
    final message =
        'HTTP 429：请求失败。\n\n接口返回：\n'
        '${List.generate(200, (index) => '错误详情 $index').join('\n')}';
    await _pumpImageCell(tester, _record.copyWith(errorMessage: message));
    await tester.tap(find.text('失败'));
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    final scrollView = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(scrollView, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('shows regenerate action for completed records', (tester) async {
    var regenerated = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onRegenerate: () {
        regenerated = true;
      },
    );

    await tester.longPress(find.byType(ImageCell));
    await tester.pumpAndSettle();

    expect(find.text('再生成一张'), findsOneWidget);
    await tester.tap(find.text('再生成一张'));
    await tester.pumpAndSettle();

    expect(regenerated, isTrue);
  });

  testWidgets('right click opens actions without opening the image preview', (
    tester,
  ) async {
    var regenerated = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: const ['missing-preview-image.png'],
        clearErrorMessage: true,
      ),
      onRegenerate: () {
        regenerated = true;
      },
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(ImageCell)) + const Offset(120, 90),
      kind: ui.PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(ImagePreviewPage), findsNothing);
    expect(find.text('复用提示词'), findsOneWidget);
    expect(find.text('再生成一张'), findsOneWidget);
    expect(find.text('以此改图'), findsOneWidget);
    expect(find.text('收藏到...'), findsOneWidget);
    expect(find.text('删除这条记录'), findsOneWidget);

    await tester.tap(find.text('再生成一张'));
    await tester.pumpAndSettle();

    expect(regenerated, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('shows append attachment action when record has a local image', (
    tester,
  ) async {
    var appended = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: [File('pubspec.yaml').absolute.path],
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onAppendCurrentImageToAttachments: () {
        appended = true;
      },
    );

    await tester.longPress(find.byType(ImageCell));
    await tester.pumpAndSettle();

    expect(find.text('将此图添加到附件1'), findsOneWidget);
    await tester.tap(find.text('将此图添加到附件1'));
    await tester.pumpAndSettle();

    expect(appended, isTrue);
  });

  testWidgets('opens preview through preview navigation callback', (
    tester,
  ) async {
    var navigatedThroughCallback = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: const ['missing-preview-image.png'],
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onPreviewNavigation: (navigate) async {
        navigatedThroughCallback = true;
        await navigate();
      },
    );

    final cellTopLeft = tester.getTopLeft(find.byType(ImageCell));
    await tester.tapAt(cellTopLeft + const Offset(120, 90));
    await tester.pumpAndSettle();

    expect(navigatedThroughCallback, isTrue);
    expect(find.byType(ImagePreviewPage), findsOneWidget);
  });
}

Future<List<int>> _pixel(ui.Image image, WidgetTester tester) async {
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return bytes!.buffer.asUint8List().take(4).toList();
}

Future<void> _pumpImageCell(
  WidgetTester tester,
  ImageRecord record, {
  VoidCallback? onRegenerate,
  VoidCallback? onAppendCurrentImageToAttachments,
  Future<void> Function(Future<void> Function() navigate)? onPreviewNavigation,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSettingsModelProvider.overrideWithValue(_settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 300,
              child: ImageCell(
                record: record,
                imageHeight: 180,
                onReusePrompt: () {},
                onReuseEdit: () {},
                onRegenerate: onRegenerate ?? () {},
                onRetry: () {},
                onCancel: () {},
                onDelete: () {},
                onToggleFavorite: () {},
                onPreviewNavigation:
                    onPreviewNavigation ?? (navigate) => navigate(),
                selectionMode: false,
                selected: false,
                onSelectionToggle: () {},
                currentAttachmentCount: 0,
                onAppendCurrentImageToAttachments:
                    onAppendCurrentImageToAttachments ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _settings = SettingsModel(
  profiles: [_apiProfile],
  activeProfileId: 'api',
);

const _apiProfile = ApiProfile(
  id: 'api',
  name: 'API',
  baseUrl: 'https://api.openai.com',
  apiKey: 'test-key',
  model: 'gpt-image-2',
);

final _record = ImageRecord(
  id: 'record-error',
  prompt: '一张城市夜景',
  apiProfileId: 'api',
  sourceImagePath: null,
  sourceImagePaths: const [],
  resultImagePath: null,
  resultImageUrl: null,
  resultB64: null,
  width: 1024,
  height: 1024,
  quality: 'medium',
  outputFormat: 'png',
  model: 'gpt-image-2',
  status: ImageRecordStatus.error,
  errorMessage: null,
  rawApiResponseValue: null,
  createdAt: DateTime(2026, 5, 30, 12),
  durationMs: 1200,
  usedSingleImageFallback: false,
  isFavorite: false,
);
