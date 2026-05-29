import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/image_list_provider.dart';
import '../../shared/widgets/empty_state.dart';
import 'image_cell.dart';

class ImageListWidget extends ConsumerStatefulWidget {
  const ImageListWidget({
    super.key,
    required this.onReusePrompt,
    required this.onReuseEdit,
    required this.onRetryRecord,
    required this.onCancelRecord,
    required this.onDeleteRecord,
    required this.onToggleFavorite,
    required this.currentAttachmentCount,
    required this.onAppendRecordToAttachments,
    required this.selectionMode,
    required this.selectedRecordIds,
    required this.onToggleSelection,
    required this.onSelectRecord,
    required this.favoriteOnly,
    required this.searchQuery,
  });

  final ValueChanged<ImageRecord> onReusePrompt;
  final ValueChanged<ImageRecord> onReuseEdit;
  final ValueChanged<ImageRecord> onRetryRecord;
  final ValueChanged<String> onCancelRecord;
  final ValueChanged<ImageRecord> onDeleteRecord;
  final ValueChanged<ImageRecord> onToggleFavorite;
  final int currentAttachmentCount;
  final ValueChanged<ImageRecord> onAppendRecordToAttachments;
  final bool selectionMode;
  final Set<String> selectedRecordIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onSelectRecord;
  final bool favoriteOnly;
  final String searchQuery;

  @override
  ConsumerState<ImageListWidget> createState() => _ImageListWidgetState();
}

class _ImageListWidgetState extends ConsumerState<ImageListWidget> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _dragSelectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ImageListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectionMode && oldWidget.selectionMode) {
      _dragSelectedIds.clear();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = ref.watch(imageListProvider);
    final records = _filteredRecords(allRecords);

    if (allRecords.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(imageListProvider.notifier).reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
          children: const [
            SizedBox(height: 48),
            EmptyState(
              title: '还没有生成记录',
              description: '输入提示词并点击发送后，新的生成任务会立即出现在这里。',
            ),
          ],
        ),
      );
    }

    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(imageListProvider.notifier).reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
          children: [
            const SizedBox(height: 48),
            EmptyState(
              title: widget.favoriteOnly ? '没有收藏记录' : '没有匹配结果',
              description: widget.favoriteOnly
                  ? '长按图像卡片并收藏后，可以在这里快速筛选。'
                  : '换一个提示词关键词再试试。',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(imageListProvider.notifier).reload(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _GridMetrics.fromContext(
            context,
            constraints.maxWidth,
          );
          final grid = GridView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              metrics.sidePadding,
              metrics.topPadding,
              metrics.sidePadding,
              metrics.bottomPadding,
            ),
            itemCount: records.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: metrics.columnCount,
              crossAxisSpacing: metrics.gap,
              mainAxisSpacing: metrics.gap,
              mainAxisExtent: metrics.cellHeight,
            ),
            itemBuilder: (context, index) {
              final record = records[index];
              return ImageCell(
                record: record,
                imageHeight: metrics.imageHeight,
                onReusePrompt: () => widget.onReusePrompt(record),
                onReuseEdit: () => widget.onReuseEdit(record),
                onRetry: () => widget.onRetryRecord(record),
                onCancel: () => widget.onCancelRecord(record.id),
                onDelete: () => widget.onDeleteRecord(record),
                onToggleFavorite: () => widget.onToggleFavorite(record),
                currentAttachmentCount: widget.currentAttachmentCount,
                onAppendCurrentImageToAttachments: () =>
                    widget.onAppendRecordToAttachments(record),
                selectionMode: widget.selectionMode,
                selected: widget.selectedRecordIds.contains(record.id),
                onSelectionToggle: () => widget.onToggleSelection(record.id),
              );
            },
          );

          if (!widget.selectionMode) {
            return grid;
          }

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _dragSelectedIds.clear(),
            onPointerMove: (event) {
              _selectAtPosition(event.localPosition, metrics, records);
            },
            onPointerUp: (_) => _dragSelectedIds.clear(),
            onPointerCancel: (_) => _dragSelectedIds.clear(),
            child: grid,
          );
        },
      ),
    );
  }

  List<ImageRecord> _filteredRecords(List<ImageRecord> records) {
    final query = widget.searchQuery.trim().toLowerCase();
    return records
        .where((record) {
          if (widget.favoriteOnly && !record.isFavorite) {
            return false;
          }
          if (query.isNotEmpty &&
              !record.prompt.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _selectAtPosition(
    Offset localPosition,
    _GridMetrics metrics,
    List<ImageRecord> records,
  ) {
    final index = _indexAtPosition(localPosition, metrics, records.length);
    if (index == null) {
      return;
    }

    final recordId = records[index].id;
    if (_dragSelectedIds.add(recordId)) {
      widget.onSelectRecord(recordId);
    }
  }

  int? _indexAtPosition(
    Offset localPosition,
    _GridMetrics metrics,
    int recordCount,
  ) {
    final x = localPosition.dx - metrics.sidePadding;
    final y = localPosition.dy + _scrollController.offset - metrics.topPadding;

    if (x < 0 || y < 0) {
      return null;
    }

    final columnStride = metrics.cellWidth + metrics.gap;
    final rowStride = metrics.cellHeight + metrics.gap;
    final column = x ~/ columnStride;
    final row = y ~/ rowStride;

    if (column < 0 || column >= metrics.columnCount) {
      return null;
    }

    final xInCell = x - column * columnStride;
    final yInCell = y - row * rowStride;
    if (xInCell > metrics.cellWidth || yInCell > metrics.cellHeight) {
      return null;
    }

    final index = row * metrics.columnCount + column;
    if (index < 0 || index >= recordCount) {
      return null;
    }

    return index;
  }
}

class _GridMetrics {
  const _GridMetrics({
    required this.columnCount,
    required this.cellWidth,
    required this.cellHeight,
    required this.imageHeight,
    required this.sidePadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.gap,
  });

  final int columnCount;
  final double cellWidth;
  final double cellHeight;
  final double imageHeight;
  final double sidePadding;
  final double topPadding;
  final double bottomPadding;
  final double gap;

  static _GridMetrics fromContext(BuildContext context, double width) {
    final screen = MediaQuery.sizeOf(context);
    final isPhone = screen.shortestSide < 600;
    final sidePadding = isPhone ? 10.0 : 14.0;
    const topPadding = 10.0;
    const bottomPadding = 12.0;
    final gap = isPhone ? 8.0 : 10.0;
    final availableWidth = width - sidePadding * 2;
    final desktopColumnCount = (availableWidth / 206).floor();
    final columnCount = isPhone ? 2 : desktopColumnCount.clamp(2, 10).toInt();
    final cellWidth = (availableWidth - gap * (columnCount - 1)) / columnCount;
    final imageHeight = isPhone ? 188.0 : 206.0;
    const footerHeight = 68.0;

    return _GridMetrics(
      columnCount: columnCount,
      cellWidth: cellWidth,
      cellHeight: imageHeight + footerHeight,
      imageHeight: imageHeight,
      sidePadding: sidePadding,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      gap: gap,
    );
  }
}
