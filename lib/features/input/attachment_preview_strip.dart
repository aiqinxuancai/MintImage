import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/attachment_picker_service.dart';
import '../../shared/theme.dart';

class AttachmentPreviewStrip extends StatelessWidget {
  const AttachmentPreviewStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  final List<PickedAttachment> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppThemeTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (
                      int index = 0;
                      index < attachments.length;
                      index += 1
                    ) ...[
                      _AttachmentThumb(
                        attachment: attachments[index],
                        onRemove: () => onRemove(index),
                      ),
                      if (index != attachments.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已附加 ${attachments.length} 张参考图',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '发送后会自动切换为图生图',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment, required this.onRemove});

  final PickedAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(attachment.path),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 44,
                height: 44,
                color: AppThemeTokens.surfaceSoft,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 18,
                  color: AppThemeTokens.primary,
                ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            top: -5,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
