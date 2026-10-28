import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/openai_client.dart';
import '../../core/api/prompt_optimization_api.dart';
import '../../core/models/generation_request.dart';
import '../../core/models/image_record.dart';
import '../../core/models/settings_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/attachment_picker_service.dart';
import '../../core/services/image_clipboard_service.dart';
import '../../shared/theme.dart';
import 'attachment_preview_strip.dart';
import 'image_format_selector.dart';
import 'prompt_editor_page.dart';
import 'quality_selector.dart';
import 'quantity_selector.dart';
import 'size_selector.dart';
import '../settings/prompt_optimization_profile_edit_page.dart';

const double _primaryInputHeight = 40;
const double _promptOptimizeButtonSize = 28;

class BottomInputBar extends ConsumerStatefulWidget {
  const BottomInputBar({
    super.key,
    required this.onSubmit,
    this.onAttachmentCountChanged,
    this.maxHeight,
  });

  final Future<void> Function(GenerationRequest request) onSubmit;
  final ValueChanged<int>? onAttachmentCountChanged;
  final double? maxHeight;

  @override
  ConsumerState<BottomInputBar> createState() => BottomInputBarState();
}

class BottomInputBarState extends ConsumerState<BottomInputBar> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  final GlobalKey _promptAreaKey = GlobalKey();
  double? _promptHeight;

  SizePreset _sizePreset = SizePreset.auto;
  ImageQuality _quality = ImageQuality.auto;
  ImageOutputFormat _outputFormat = ImageOutputFormat.png;
  int _count = 1;
  int _customWidth = 0;
  int _customHeight = 0;
  bool _submitting = false;
  bool _optimizingPrompt = false;
  bool _pastingFromClipboard = false;
  CancelToken? _optimizationCancelToken;
  List<PickedAttachment> _attachments = const [];

  int get attachmentCount => _attachments.length;

  void unfocusPrompt() {
    if (!mounted) {
      return;
    }
    _promptFocusNode.unfocus(disposition: UnfocusDisposition.scope);
  }

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _sizePreset = settings.lastSizePreset;
    _customWidth = settings.lastCustomWidth;
    _customHeight = settings.lastCustomHeight;
    _quality = settings.lastQuality;
    _outputFormat = settings.lastOutputFormat;
  }

  @override
  void dispose() {
    _optimizationCancelToken?.cancel();
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  void prefillPrompt(String prompt) {
    if (!mounted) {
      return;
    }
    _promptController
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    _promptFocusNode.requestFocus();
    setState(() {});
  }

  Future<void> prefillFromRecord(ImageRecord record) async {
    prefillPrompt(record.prompt);
    _applyGenerationOptionsFromRecord(record);
    await _prefillAttachments(record.sourceAttachmentPaths);
  }

  Future<void> prefillForEdit(ImageRecord record) async {
    prefillPrompt(record.prompt);
    if (!mounted) {
      return;
    }

    _applyGenerationOptionsFromRecord(record);

    await _prefillAttachments(
      record.resultImagePath == null
          ? record.sourceAttachmentPaths
          : [record.resultImagePath!],
    );
  }

  Future<bool> appendImageFromRecord(ImageRecord record) async {
    final path = _attachmentPathForRecord(record);
    if (path == null) {
      _showMessage('这条记录没有可加入附件的本地图片。');
      return false;
    }

    final attachment = await PickedAttachment.fromExistingPath(path);
    if (!mounted) {
      return false;
    }
    if (attachment == null) {
      _showMessage('图片文件不存在，无法加入附件。');
      return false;
    }

    _setAttachments([..._attachments, attachment]);
    return true;
  }

  Future<void> _prefillAttachments(List<String> paths) async {
    final attachments = <PickedAttachment>[];
    for (final path in paths) {
      final attachment = await PickedAttachment.fromExistingPath(path);
      if (attachment != null) {
        attachments.add(attachment);
      }
    }

    if (!mounted) {
      return;
    }

    _setAttachments(attachments);
  }

  String? _attachmentPathForRecord(ImageRecord record) {
    final resultImagePath = record.resultImagePath;
    if (resultImagePath != null && File(resultImagePath).existsSync()) {
      return resultImagePath;
    }

    final sourceImagePath = record.sourceImagePath;
    if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
      return sourceImagePath;
    }

    for (final path in record.sourceAttachmentPaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    return null;
  }

  void _setAttachments(List<PickedAttachment> attachments) {
    if (!mounted) {
      return;
    }
    setState(() {
      _attachments = attachments;
    });
    widget.onAttachmentCountChanged?.call(_attachments.length);
  }

  SizePreset _matchingSizePreset(int width, int height) {
    if (width == 0 || height == 0) return SizePreset.auto;
    return SizePreset.values.firstWhere(
      (preset) =>
          preset != SizePreset.custom &&
          preset != SizePreset.auto &&
          preset.width == width &&
          preset.height == height,
      orElse: () => SizePreset.custom,
    );
  }

  void _applyGenerationOptionsFromRecord(ImageRecord record) {
    if (!mounted) {
      return;
    }

    setState(() {
      _sizePreset = _matchingSizePreset(record.width, record.height);
      _customWidth = record.width;
      _customHeight = record.height;
      _quality = ImageQuality.fromApiValue(record.quality);
      _outputFormat = ImageOutputFormat.fromApiValue(record.outputFormat);
      _count = 1;
    });
    _persistLastGenerationOptions();
  }

  void _persistLastGenerationOptions() {
    unawaited(
      ref
          .read(settingsProvider.notifier)
          .updateLastGenerationOptions(
            sizePreset: _sizePreset,
            customWidth: _customWidth,
            customHeight: _customHeight,
            quality: _quality,
            outputFormat: _outputFormat,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final activeProfile = settings.activeProfile;
    final hasApiKey = activeProfile.apiKey.trim().isNotEmpty;
    final otherProfiles = settings.profiles
        .where((profile) => profile.id != settings.activeProfileId)
        .toList();
    final canUseSendButton =
        !_optimizingPrompt && (hasApiKey || otherProfiles.isNotEmpty);
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            widget.maxHeight ??
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: AppDecorations.glass(radius: 22),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 28,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: _promptHeight == null
                                    ? null
                                    : IconButton(
                                        tooltip: '收起输入框',
                                        padding: EdgeInsets.zero,
                                        iconSize: 18,
                                        onPressed: () => setState(
                                          () => _promptHeight = null,
                                        ),
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                        ),
                                      ),
                              ),
                              Expanded(
                                child: Tooltip(
                                  message: '拖动调整输入框高度，双击收起',
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.resizeUpDown,
                                    child: GestureDetector(
                                      key: const Key('prompt-resize-handle'),
                                      behavior: HitTestBehavior.opaque,
                                      onVerticalDragUpdate: _resizePrompt,
                                      onDoubleTap: () =>
                                          setState(() => _promptHeight = null),
                                      child: Center(
                                        child: Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: AppThemeTokens.textSecondary
                                                .withValues(alpha: 0.45),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '全屏编辑提示词',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                iconSize: 18,
                                onPressed: _optimizingPrompt
                                    ? null
                                    : _openPromptEditor,
                                icon: const Icon(Icons.open_in_full_rounded),
                              ),
                            ],
                          ),
                        ),
                        if (_attachments.isNotEmpty) ...[
                          AttachmentPreviewStrip(
                            attachments: _attachments,
                            onRemove: (index) {
                              _setAttachments([
                                for (int i = 0; i < _attachments.length; i++)
                                  if (i != index) _attachments[i],
                              ]);
                            },
                          ),
                        ],
                        const SizedBox(height: 6),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: AnimatedBuilder(
                                  animation: _promptFocusNode,
                                  builder: (context, child) {
                                    final focused = _promptFocusNode.hasFocus;
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: focused
                                              ? AppThemeTokens.primary
                                              : AppThemeTokens.border,
                                          width: focused ? 1.4 : 1,
                                        ),
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: ConstrainedBox(
                                    key: _promptAreaKey,
                                    constraints: const BoxConstraints(
                                      minHeight: _primaryInputHeight,
                                    ),
                                    child: SizedBox(
                                      height: _promptHeight,
                                      child: Stack(
                                        alignment: Alignment.bottomLeft,
                                        children: [
                                          Focus(
                                            onKeyEvent: _handleKeyEvent,
                                            child: TextField(
                                              key: const Key('prompt-input'),
                                              controller: _promptController,
                                              focusNode: _promptFocusNode,
                                              selectAllOnFocus: false,
                                              readOnly: _optimizingPrompt,
                                              expands: _promptHeight != null,
                                              minLines: _promptHeight == null
                                                  ? 1
                                                  : null,
                                              maxLines: _promptHeight == null
                                                  ? 4
                                                  : null,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: AppThemeTokens
                                                        .textPrimary,
                                                    fontSize: 13,
                                                    height: 1.25,
                                                  ),
                                              textAlignVertical:
                                                  _promptHeight == null
                                                  ? TextAlignVertical.center
                                                  : TextAlignVertical.top,
                                              textInputAction:
                                                  TextInputAction.newline,
                                              keyboardType:
                                                  TextInputType.multiline,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                filled: false,
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                errorBorder: InputBorder.none,
                                                focusedErrorBorder:
                                                    InputBorder.none,
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight:
                                                          _primaryInputHeight,
                                                    ),
                                                hintText: _attachments.isEmpty
                                                    ? '描述你想生成的画面'
                                                    : '描述你想如何修改这些图片',
                                                hintStyle: theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: AppThemeTokens
                                                          .textSecondary
                                                          .withValues(
                                                            alpha: 0.82,
                                                          ),
                                                      fontSize: 13,
                                                      height: 1.25,
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.fromLTRB(
                                                      12,
                                                      15,
                                                      70,
                                                      7,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 5,
                                            bottom: 0,
                                            height: _primaryInputHeight,
                                            child: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _AttachmentInputButton(
                                                    enabled:
                                                        !_submitting &&
                                                        !_optimizingPrompt,
                                                    onTap: _pickAttachments,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _PromptOptimizeButton(
                                                    key: const Key(
                                                      'prompt-optimize-button',
                                                    ),
                                                    enabled: true,
                                                    loading: _optimizingPrompt,
                                                    onTap:
                                                        _handlePromptOptimizationTap,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              _SendButton(
                                key: const Key('submit-generation-button'),
                                enabled: canUseSendButton,
                                onTap: _submit,
                                onLongPress: _showApiProfileSendSheet,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              width: constraints.maxWidth,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizeSelector(
                                      currentWidth: _customWidth,
                                      currentHeight: _customHeight,
                                      onSizeSelected: (width, height) {
                                        setState(() {
                                          _sizePreset = _matchingSizePreset(
                                            width,
                                            height,
                                          );
                                          _customWidth = width;
                                          _customHeight = height;
                                        });
                                        _persistLastGenerationOptions();
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    QualitySelector(
                                      selectedQuality: _quality,
                                      onSelected: (quality) {
                                        setState(() {
                                          _quality = quality;
                                        });
                                        _persistLastGenerationOptions();
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    ImageFormatSelector(
                                      selectedFormat: _outputFormat,
                                      onSelected: (format) {
                                        setState(() {
                                          _outputFormat = format;
                                        });
                                        _persistLastGenerationOptions();
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    QuantitySelector(
                                      count: _count,
                                      onSelected: (count) {
                                        setState(() {
                                          _count = count;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    _ApiProfileSwitchButton(
                                      activeProfile: activeProfile,
                                      onTap: _showApiProfileSwitchSheet,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (!hasApiKey) ...[
                          const SizedBox(height: 6),
                          Text(
                            otherProfiles.isEmpty
                                ? '当前配置缺少 API Key，发送按钮已禁用。'
                                : '当前配置缺少 API Key，可长按发送切换其他配置。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resizePrompt(DragUpdateDetails details) {
    final renderBox =
        _promptAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = widget.maxHeight ?? viewportHeight;
    final historySpace = (viewportHeight * 0.2).clamp(80.0, 160.0);
    final chromeHeight = _attachments.isEmpty ? 100.0 : 164.0;
    final maxPromptHeight = (maxHeight - historySpace - chromeHeight).clamp(
      _primaryInputHeight,
      double.infinity,
    );
    setState(() {
      _promptHeight = (renderBox.size.height - details.delta.dy).clamp(
        _primaryInputHeight,
        maxPromptHeight,
      );
    });
  }

  Future<void> _openPromptEditor() async {
    unfocusPrompt();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PromptEditorPage(controller: _promptController),
      ),
    );
    if (mounted) _promptFocusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (_optimizingPrompt) {
      return KeyEventResult.handled;
    }

    if (!_isDesktopPlatform) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_isClipboardImagePasteShortcut(event)) {
      unawaited(_handlePasteShortcut());
      return KeyEventResult.handled;
    }

    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      _insertNewLine();
      return KeyEventResult.handled;
    }

    _submit();
    return KeyEventResult.handled;
  }

  bool get _isDesktopPlatform {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  bool get _supportsClipboardImagePaste {
    return !kIsWeb && (Platform.isWindows || Platform.isMacOS);
  }

  bool _isClipboardImagePasteShortcut(KeyDownEvent event) {
    if (!_supportsClipboardImagePaste ||
        event.logicalKey != LogicalKeyboardKey.keyV) {
      return false;
    }

    final keyboard = HardwareKeyboard.instance;
    return Platform.isMacOS
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
  }

  void _insertNewLine() {
    if (_optimizingPrompt) {
      return;
    }

    _insertTextAtSelection('\n');
  }

  void _insertTextAtSelection(String text) {
    if (_optimizingPrompt || text.isEmpty) {
      return;
    }

    final value = _promptController.value;
    final selection = value.selection;
    final start = selection.start.clamp(0, value.text.length);
    final end = selection.end.clamp(0, value.text.length);
    final updatedText = value.text.replaceRange(start, end, text);

    _promptController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<void> _handlePasteShortcut() async {
    if (_pastingFromClipboard || _optimizingPrompt) {
      return;
    }

    _pastingFromClipboard = true;
    try {
      final imagePath = await const ImageClipboardService()
          .readImageFileFromClipboard();
      if (!mounted) {
        return;
      }

      if (imagePath != null) {
        final attachment = await PickedAttachment.fromExistingPath(imagePath);
        if (!mounted) {
          return;
        }
        if (attachment == null) {
          _showMessage('剪贴板图片文件不存在，无法加入附件。');
          return;
        }
        _setAttachments([..._attachments, attachment]);
        return;
      }

      await _pasteTextFromClipboard();
    } on ImageClipboardException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } finally {
      _pastingFromClipboard = false;
    }
  }

  Future<void> _pasteTextFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) {
      return;
    }
    _insertTextAtSelection(data?.text ?? '');
  }

  Future<void> _pickAttachments() async {
    unfocusPrompt();
    try {
      final picked = await ref
          .read(attachmentPickerServiceProvider)
          .pickImages();
      if (!mounted) return;
      unfocusPrompt();
      if (picked.isNotEmpty) {
        _setAttachments([..._attachments, ...picked]);
      }
    } catch (error) {
      if (mounted) _showMessage('读取图片失败：$error');
    }
  }

  Future<void> _submit({String? apiProfileId}) async {
    if (_submitting || _optimizingPrompt) {
      return;
    }

    final settings = ref.read(settingsProvider);
    final selectedProfileId = apiProfileId ?? settings.activeProfileId;
    final activeProfile = settings.profileById(selectedProfileId);
    final prompt = _promptController.text.trim();

    if (activeProfile == null) {
      _showMessage('当前 API 配置不存在，请重新选择。');
      return;
    }

    if (activeProfile.apiKey.trim().isEmpty) {
      _showMessage('请先在设置中填写 API Key。');
      return;
    }

    if (prompt.isEmpty) {
      _showMessage('提示词不能为空。');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onSubmit(
        GenerationRequest(
          prompt: prompt,
          imagePaths: _attachments.map((item) => item.path).toList(),
          sizePreset: _sizePreset,
          customWidth: _customWidth,
          customHeight: _customHeight,
          quality: _quality,
          outputFormat: _outputFormat,
          count: _count,
          apiProfileId: selectedProfileId,
        ),
      );

      _promptController.clear();
      _setAttachments(const []);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _showApiProfileSendSheet() async {
    if (_submitting || _optimizingPrompt) {
      return;
    }

    final settings = ref.read(settingsProvider);
    final profiles = settings.profiles
        .where((profile) => profile.id != settings.activeProfileId)
        .toList();
    if (profiles.isEmpty) {
      _showMessage('没有其他生图 API 配置。');
      return;
    }

    unfocusPrompt();
    final selectedProfileId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '切换到API配置并发送',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final profile in profiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(ctx).pop(profile.id),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeTokens.surfaceSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppThemeTokens.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.hub_rounded,
                                size: 18,
                                color: AppThemeTokens.primaryStrong,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.name,
                                      style: Theme.of(ctx).textTheme.labelLarge
                                          ?.copyWith(
                                            color: AppThemeTokens.textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      profile.normalizedBaseUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(ctx).textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppThemeTokens.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                profile.apiKey.trim().isEmpty
                                    ? Icons.key_off_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 18,
                                color: profile.apiKey.trim().isEmpty
                                    ? AppThemeTokens.textSecondary
                                    : AppThemeTokens.primaryStrong,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    unfocusPrompt();
    if (selectedProfileId == null) {
      return;
    }

    await ref
        .read(settingsProvider.notifier)
        .setActiveProfile(selectedProfileId);
    if (!mounted) {
      return;
    }
    await _submit(apiProfileId: selectedProfileId);
  }

  Future<void> _showApiProfileSwitchSheet() async {
    if (_optimizingPrompt) {
      return;
    }

    final settings = ref.read(settingsProvider);
    unfocusPrompt();
    final selectedProfileId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '切换生图 API',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                for (final profile in settings.profiles)
                  ListTile(
                    leading: Icon(
                      profile.id == settings.activeProfileId
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: profile.id == settings.activeProfileId
                          ? AppThemeTokens.primary
                          : AppThemeTokens.textSecondary,
                    ),
                    title: Text(profile.name),
                    subtitle: Text(
                      profile.normalizedBaseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: profile.apiKey.trim().isEmpty
                        ? const Icon(Icons.key_off_rounded, size: 18)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(profile.id),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    unfocusPrompt();
    if (selectedProfileId == null) {
      return;
    }

    await ref
        .read(settingsProvider.notifier)
        .setActiveProfile(selectedProfileId);

    unfocusPrompt();
  }

  Future<void> _handlePromptOptimizationTap() async {
    if (_optimizingPrompt) {
      final cancelToken = _optimizationCancelToken;
      cancelToken?.cancel('cancelled by user');
      setState(() {
        _optimizingPrompt = false;
        _optimizationCancelToken = null;
      });
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showMessage('提示词不能为空。');
      return;
    }

    final settings = ref.read(settingsProvider);
    final profile = settings.activePromptOptimizationProfile;
    if (profile == null) {
      unfocusPrompt();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PromptOptimizationProfileEditPage(),
        ),
      );
      if (mounted) {
        unfocusPrompt();
      }
      return;
    }

    if (profile.apiKey.trim().isEmpty) {
      _showMessage('当前提示词优化配置缺少 API Key。');
      return;
    }

    final direction = await _showPromptOptimizationDirectionSheet();
    if (direction == null || !mounted) {
      return;
    }

    await _optimizePrompt(
      originalPrompt: prompt,
      direction: direction,
      profileId: profile.id,
    );
  }

  Future<PromptOptimizationDirection?>
  _showPromptOptimizationDirectionSheet() async {
    unfocusPrompt();
    final direction = await showModalBottomSheet<PromptOptimizationDirection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '优化方向',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final direction in PromptOptimizationDirection.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(direction),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeTokens.surfaceSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppThemeTokens.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: AppThemeTokens.primaryStrong,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      direction.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: AppThemeTokens.textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      direction.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppThemeTokens.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (mounted) {
      unfocusPrompt();
    }
    return direction;
  }

  Future<void> _optimizePrompt({
    required String originalPrompt,
    required PromptOptimizationDirection direction,
    required String profileId,
  }) async {
    final settings = ref.read(settingsProvider);
    final profile = settings.promptOptimizationProfileById(profileId);
    if (profile == null) {
      _showMessage('提示词优化配置已不存在。');
      return;
    }

    final cancelToken = CancelToken();
    _optimizationCancelToken = cancelToken;
    _promptFocusNode.unfocus();
    setState(() {
      _optimizingPrompt = true;
    });

    try {
      final optimized = await ref
          .read(promptOptimizationApiProvider)
          .optimize(
            prompt: originalPrompt,
            direction: direction,
            profile: profile,
            timeoutSeconds: settings.requestTimeoutSeconds,
            cancelToken: cancelToken,
          );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }

      _promptController.value = TextEditingValue(
        text: optimized,
        selection: TextSelection.collapsed(offset: optimized.length),
      );
    } on ApiException catch (error) {
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted && identical(_optimizationCancelToken, cancelToken)) {
        setState(() {
          _optimizingPrompt = false;
          _optimizationCancelToken = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PromptOptimizeButton extends StatefulWidget {
  const _PromptOptimizeButton({
    super.key,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_PromptOptimizeButton> createState() => _PromptOptimizeButtonState();
}

class _PromptOptimizeButtonState extends State<_PromptOptimizeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.loading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PromptOptimizeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _controller.repeat();
    } else if (!widget.loading && oldWidget.loading) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled || widget.loading;
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFC857), Color(0xFFFF6B6B), Color(0xFF3B82F6)],
    );
    final iconWidget = ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
    final loadingWidget = SizedBox.square(
      dimension: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                key: const Key('prompt-optimization-spinner'),
                value: 0.72,
                strokeWidth: 2.4,
                strokeCap: StrokeCap.round,
                backgroundColor: AppThemeTokens.primarySoft.withValues(
                  alpha: 0.35,
                ),
                color: AppThemeTokens.primaryStrong,
              ),
            ),
          ),
          Container(
            key: const Key('prompt-optimization-stop-square'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppThemeTokens.primaryStrong,
              borderRadius: BorderRadius.circular(1.8),
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: widget.loading ? '停止优化' : '优化提示词',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: active ? 1 : 0.38,
        child: SizedBox(
          width: _promptOptimizeButtonSize,
          height: _promptOptimizeButtonSize,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: active ? widget.onTap : null,
              borderRadius: BorderRadius.circular(8),
              child: Center(child: widget.loading ? loadingWidget : iconWidget),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentInputButton extends StatelessWidget {
  const _AttachmentInputButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '添加图片',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.38,
        child: SizedBox(
          width: _promptOptimizeButtonSize,
          height: _promptOptimizeButtonSize,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(8),
              child: const Center(
                child: Icon(
                  Icons.attach_file_rounded,
                  color: AppThemeTokens.primaryStrong,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApiProfileSwitchButton extends StatelessWidget {
  const _ApiProfileSwitchButton({
    required this.activeProfile,
    required this.onTap,
  });

  final ApiProfile activeProfile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '切换生图 API',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 90),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 28),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppThemeTokens.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppThemeTokens.border.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hub_rounded,
                  size: 13,
                  color: AppThemeTokens.primaryStrong,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    activeProfile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppThemeTokens.primaryStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.onLongPress,
  });

  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = enabled
        ? const [AppThemeTokens.primary, AppThemeTokens.primaryStrong]
        : const [Color(0xFFB9C7D4), Color(0xFFB9C7D4)];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: _primaryInputHeight,
          height: _primaryInputHeight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              onLongPress: enabled ? onLongPress : null,
              borderRadius: BorderRadius.circular(15),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
