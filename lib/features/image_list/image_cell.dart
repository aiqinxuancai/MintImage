import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/generation_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/loading_image_cell.dart';
import 'image_preview_page.dart';

class ImageCell extends ConsumerWidget {
  const ImageCell({
    super.key,
    required this.record,
    required this.onReusePrompt,
    required this.onReuseEdit,
    required this.onRetry,
    required this.onCancel,
    required this.onDelete,
  });

  final ImageRecord record;
  final VoidCallback onReusePrompt;
  final VoidCallback onReuseEdit;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final imageSize = _thumbnailSize(context);
    final requestStartedAt = ref.watch(
      generationProvider.select((state) => state.requestStartedAts[record.id]),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _canPreview ? () => _openPreview(context) : null,
        child: Container(
          decoration: AppDecorations.card(radius: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: imageSize,
                  child: Hero(
                    tag: 'image-${record.id}',
                    child: _buildThumbnail(imageSize),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              record.prompt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppThemeTokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusWidget(context, theme),
                          IconButton(
                            tooltip: '更多',
                            onPressed: () => _showActions(context),
                            icon: const Icon(Icons.more_horiz_rounded),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _InfoChip(
                              icon: Icons.aspect_ratio_rounded,
                              label: record.sizeLabel,
                            ),
                            const SizedBox(width: 6),
                            _InfoChip(
                              icon: Icons.auto_awesome_rounded,
                              label: record.qualityLabel,
                            ),
                            const SizedBox(width: 6),
                            _InfoChip(
                              icon: Icons.api_rounded,
                              label: _apiProfileName(ref),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: AppThemeTokens.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildTimeLabel(theme, requestStartedAt),
                          ),
                        ],
                      ),
                      if (record.usedSingleImageFallback) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeTokens.warningSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 13,
                                color: AppThemeTokens.warningText,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '代理不支持多图，已退化为单图发送。',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppThemeTokens.warningText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canPreview {
    return record.resultImagePath != null ||
        record.resultImageUrl != null ||
        record.sourceImagePath != null;
  }

  double _thumbnailSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      return 80;
    }
    if (width >= 600) {
      return 72;
    }
    return 56;
  }

  Widget _buildThumbnail(double imageSize) {
    if (record.status == ImageRecordStatus.loading ||
        record.status == ImageRecordStatus.pending) {
      return LoadingImageCell(size: imageSize);
    }

    if (record.resultImagePath != null &&
        File(record.resultImagePath!).existsSync()) {
      return _ImageThumb(
        size: imageSize,
        child: Image.file(
          File(record.resultImagePath!),
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
        ),
      );
    }

    if (record.sourceImagePath != null &&
        File(record.sourceImagePath!).existsSync()) {
      return _ImageThumb(
        size: imageSize,
        child: Image.file(
          File(record.sourceImagePath!),
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
        ),
      );
    }

    if (record.resultImageUrl != null) {
      return _ImageThumb(
        size: imageSize,
        child: CachedNetworkImage(
          imageUrl: record.resultImageUrl!,
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
          placeholder: (context, url) => LoadingImageCell(size: imageSize),
          errorWidget: (context, url, error) =>
              _FallbackThumb(size: imageSize, icon: Icons.image_not_supported),
        ),
      );
    }

    return _FallbackThumb(size: imageSize, icon: Icons.broken_image_rounded);
  }

  Widget _buildStatusWidget(BuildContext context, ThemeData theme) {
    final isInfoTapEnabled =
        record.status == ImageRecordStatus.error &&
        record.errorMessage != null &&
        record.errorMessage!.isNotEmpty;

    final chip = _StatusChip(status: record.status);
    if (!isInfoTapEnabled) {
      return chip;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showErrorDetails(context),
      child: chip,
    );
  }

  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ImagePreviewPage(record: record)),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final canEdit = record.status == ImageRecordStatus.done;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('复用提示词'),
                onTap: () {
                  Navigator.of(context).pop();
                  onReusePrompt();
                },
              ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('以此改图'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onReuseEdit();
                  },
                ),
              if (record.status == ImageRecordStatus.loading ||
                  record.status == ImageRecordStatus.pending)
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('取消当前请求'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onCancel();
                  },
                ),
              if (record.status == ImageRecordStatus.error ||
                  record.status == ImageRecordStatus.cancelled)
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('重试本次请求'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onRetry();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_rounded),
                title: const Text('删除这条记录'),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showErrorDetails(BuildContext context) async {
    final message = record.errorMessage;
    if (message == null || message.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('信息'),
          content: SelectableText(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }

  Widget _buildTimeLabel(ThemeData theme, DateTime? requestStartedAt) {
    final style = theme.textTheme.bodySmall?.copyWith(
      color: AppThemeTokens.textSecondary,
    );

    if (record.status == ImageRecordStatus.loading &&
        requestStartedAt != null) {
      return StreamBuilder<int>(
        stream: Stream<int>.periodic(
          const Duration(seconds: 1),
          (tick) => tick,
        ),
        initialData: 0,
        builder: (context, snapshot) {
          return Text(
            '${_formatTime(record.createdAt)}  ·  已用 ${_elapsedSeconds(requestStartedAt)} 秒',
            style: style,
          );
        },
      );
    }

    return Text(_staticTimeLabel, style: style);
  }

  String get _staticTimeLabel {
    if (record.durationMs == null) {
      return _formatTime(record.createdAt);
    }

    return '${_formatTime(record.createdAt)}  ·  ${(record.durationMs! / 1000).toStringAsFixed(1)}s';
  }

  int _elapsedSeconds(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }

  String _apiProfileName(WidgetRef ref) {
    final profiles = ref.watch(settingsProvider).profiles;
    for (final p in profiles) {
      if (p.id == record.apiProfileId) return p.name;
    }
    return '未知';
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDecorations.softShadow,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppThemeTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppThemeTokens.primaryStrong),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppThemeTokens.primaryStrong,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ImageRecordStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color backgroundColor;
    late final Color foregroundColor;

    switch (status) {
      case ImageRecordStatus.pending:
      case ImageRecordStatus.loading:
        backgroundColor = AppThemeTokens.surfaceSoft;
        foregroundColor = AppThemeTokens.primaryStrong;
      case ImageRecordStatus.done:
        backgroundColor = const Color(0xFFE4F6EE);
        foregroundColor = const Color(0xFF177245);
      case ImageRecordStatus.error:
        backgroundColor = AppThemeTokens.dangerSurface;
        foregroundColor = AppThemeTokens.dangerText;
      case ImageRecordStatus.cancelled:
        backgroundColor = const Color(0xFFFFF0D8);
        foregroundColor = const Color(0xFF935E00);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({required this.size, required this.icon});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppThemeTokens.surfaceSoft,
      ),
      child: Icon(icon, color: AppThemeTokens.primary),
    );
  }
}
