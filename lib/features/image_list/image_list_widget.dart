import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/image_list_provider.dart';
import '../../shared/widgets/empty_state.dart';
import 'image_cell.dart';

class ImageListWidget extends ConsumerWidget {
  const ImageListWidget({
    super.key,
    required this.onReusePrompt,
    required this.onReuseEdit,
    required this.onRetryRecord,
    required this.onCancelRecord,
    required this.onDeleteRecord,
  });

  final ValueChanged<ImageRecord> onReusePrompt;
  final ValueChanged<ImageRecord> onReuseEdit;
  final ValueChanged<ImageRecord> onRetryRecord;
  final ValueChanged<String> onCancelRecord;
  final ValueChanged<ImageRecord> onDeleteRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(imageListProvider);

    if (records.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: () => ref.read(imageListProvider.notifier).reload(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _GridMetrics.fromContext(
            context,
            constraints.maxWidth,
          );
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              metrics.sidePadding,
              10,
              metrics.sidePadding,
              12,
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
                onReusePrompt: () => onReusePrompt(record),
                onReuseEdit: () => onReuseEdit(record),
                onRetry: () => onRetryRecord(record),
                onCancel: () => onCancelRecord(record.id),
                onDelete: () => onDeleteRecord(record),
              );
            },
          );
        },
      ),
    );
  }
}

class _GridMetrics {
  const _GridMetrics({
    required this.columnCount,
    required this.cellHeight,
    required this.imageHeight,
    required this.sidePadding,
    required this.gap,
  });

  final int columnCount;
  final double cellHeight;
  final double imageHeight;
  final double sidePadding;
  final double gap;

  static _GridMetrics fromContext(BuildContext context, double width) {
    final screen = MediaQuery.sizeOf(context);
    final isPhone = screen.shortestSide < 600;
    final sidePadding = isPhone ? 10.0 : 14.0;
    final gap = isPhone ? 8.0 : 10.0;
    final availableWidth = width - sidePadding * 2;
    final desktopColumnCount = (availableWidth / 206).floor();
    final columnCount = isPhone ? 2 : desktopColumnCount.clamp(2, 10).toInt();
    final imageHeight = isPhone ? 188.0 : 206.0;
    const footerHeight = 68.0;

    return _GridMetrics(
      columnCount: columnCount,
      cellHeight: imageHeight + footerHeight,
      imageHeight: imageHeight,
      sidePadding: sidePadding,
      gap: gap,
    );
  }
}
