import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/openai_client.dart';
import '../../core/models/generation_request.dart';
import '../../core/models/image_record.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/attachment_picker_service.dart';
import '../../shared/theme.dart';
import 'attachment_preview_strip.dart';
import 'image_format_selector.dart';
import 'quality_selector.dart';
import 'quantity_selector.dart';
import 'size_selector.dart';

class BottomInputBar extends ConsumerStatefulWidget {
  const BottomInputBar({
    super.key,
    required this.onSubmit,
    this.onAttachmentCountChanged,
  });

  final Future<void> Function(GenerationRequest request) onSubmit;
  final ValueChanged<int>? onAttachmentCountChanged;

  @override
  ConsumerState<BottomInputBar> createState() => BottomInputBarState();
}

class BottomInputBarState extends ConsumerState<BottomInputBar> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();

  SizePreset _sizePreset = SizePreset.auto;
  ImageQuality _quality = ImageQuality.auto;
  ImageOutputFormat _outputFormat = ImageOutputFormat.png;
  int _count = 1;
  int _customWidth = 0;
  int _customHeight = 0;
  bool _submitting = false;
  List<PickedAttachment> _attachments = const [];

  int get attachmentCount => _attachments.length;

  @override
  void dispose() {
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
    await _prefillAttachments(record.sourceAttachmentPaths);
  }

  Future<void> prefillForEdit(ImageRecord record) async {
    prefillPrompt(record.prompt);
    if (!mounted) {
      return;
    }

    setState(() {
      _sizePreset = _matchingSizePreset(record.width, record.height);
      _customWidth = record.width;
      _customHeight = record.height;
      _count = 1;
    });

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final activeProfile = settings.activeProfile;
    final hasApiKey = activeProfile.apiKey.trim().isNotEmpty;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: AppDecorations.glass(radius: 28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Focus(
                              onKeyEvent: _handleKeyEvent,
                              child: TextField(
                                key: const Key('prompt-input'),
                                controller: _promptController,
                                focusNode: _promptFocusNode,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: _attachments.isEmpty
                                      ? '描述你想生成的画面'
                                      : '描述你想如何修改这些图片',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _SendButton(
                            key: const Key('submit-generation-button'),
                            enabled: hasApiKey,
                            onTap: _submit,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
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
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  QualitySelector(
                                    selectedQuality: _quality,
                                    onSelected: (quality) {
                                      setState(() {
                                        _quality = quality;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ImageFormatSelector(
                                    selectedFormat: _outputFormat,
                                    onSelected: (format) {
                                      setState(() {
                                        _outputFormat = format;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  QuantitySelector(
                                    count: _count,
                                    onSelected: (count) {
                                      setState(() {
                                        _count = count;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              tooltip: '添加图片',
                              onPressed: _submitting ? null : _pickAttachments,
                              icon: const Icon(
                                Icons.attach_file_rounded,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: AppThemeTokens.surfaceSoft,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!hasApiKey) ...[
                        const SizedBox(height: 8),
                        Text(
                          '当前配置缺少 API Key，发送按钮已禁用。',
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
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (!_isDesktopPlatform) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
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

  void _insertNewLine() {
    final value = _promptController.value;
    final selection = value.selection;
    final start = selection.start.clamp(0, value.text.length);
    final end = selection.end.clamp(0, value.text.length);
    final updatedText = value.text.replaceRange(start, end, '\n');

    _promptController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  Future<void> _pickAttachments() async {
    final picked = await ref.read(attachmentPickerServiceProvider).pickImages();
    if (!mounted || picked.isEmpty) {
      return;
    }

    final valid = <PickedAttachment>[];
    final oversized = <PickedAttachment>[];

    for (final item in picked) {
      if (item.sizeBytes > AttachmentPickerService.maxFileSizeBytes) {
        oversized.add(item);
      } else {
        valid.add(item);
      }
    }

    if (oversized.isNotEmpty) {
      _showMessage('已忽略 ${oversized.length} 张超过 25MB 的图片。');
    }

    if (valid.isEmpty) {
      return;
    }

    _setAttachments([..._attachments, ...valid]);
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final settings = ref.read(settingsProvider);
    final activeProfile = settings.activeProfile;
    final prompt = _promptController.text.trim();

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
          apiProfileId: settings.activeProfileId,
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

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
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(18),
              child: const Center(
                child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
