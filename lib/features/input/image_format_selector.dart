import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../shared/theme.dart';

class ImageFormatSelector extends StatelessWidget {
  const ImageFormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onSelected,
  });

  final ImageOutputFormat selectedFormat;
  final ValueChanged<ImageOutputFormat> onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
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
            Icon(
              Icons.image_rounded,
              size: 13,
              color: AppThemeTokens.primaryStrong,
            ),
            const SizedBox(width: 4),
            Text(
              selectedFormat.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppThemeTokens.primaryStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ImageOutputFormat.values.map((format) {
              final active = format == selectedFormat;
              return ListTile(
                leading: Icon(
                  active ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: active ? AppThemeTokens.primary : Colors.grey,
                ),
                title: Text(format.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onSelected(format);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
