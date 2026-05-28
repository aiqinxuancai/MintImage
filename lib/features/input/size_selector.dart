import 'package:flutter/material.dart';

import '../../shared/theme.dart';
import 'size_picker_modal.dart';

class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.currentWidth,
    required this.currentHeight,
    required this.onSizeSelected,
  });

  final int currentWidth;
  final int currentHeight;
  final void Function(int width, int height) onSizeSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showSizePickerModal(
          context,
          currentWidth: currentWidth,
          currentHeight: currentHeight,
        );
        if (result != null) {
          onSizeSelected(result.$1, result.$2);
        }
      },
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
            Icon(Icons.aspect_ratio_rounded, size: 13, color: AppThemeTokens.primaryStrong),
            const SizedBox(width: 4),
            Text(
              '$currentWidth×$currentHeight',
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
}
