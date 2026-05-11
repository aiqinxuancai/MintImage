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

  final ValueChanged<String> onReusePrompt;
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: records.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final record = records[index];
          return ImageCell(
            record: record,
            onReusePrompt: () => onReusePrompt(record.prompt),
            onReuseEdit: () => onReuseEdit(record),
            onRetry: () => onRetryRecord(record),
            onCancel: () => onCancelRecord(record.id),
            onDelete: () => onDeleteRecord(record),
          );
        },
      ),
    );
  }
}
