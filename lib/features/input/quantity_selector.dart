import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme.dart';

class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.count,
    required this.onSelected,
  });

  final int count;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQuantityModal(context),
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
            Icon(Icons.layers_rounded, size: 13, color: AppThemeTokens.primaryStrong),
            const SizedBox(width: 4),
            Text(
              '$count',
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

  Future<void> _showQuantityModal(BuildContext context) async {
    final ctrl = TextEditingController(text: count.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _QuantityDialog(controller: ctrl, initial: count),
    );
    ctrl.dispose();
    if (result != null) onSelected(result);
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.controller, required this.initial});

  final TextEditingController controller;
  final int initial;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    final v = int.tryParse(widget.controller.text.trim());
    if (v != null && v >= 1 && v <= 16) {
      setState(() => _value = v);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('生成数量'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _MaxValueFormatter(16),
            ],
            decoration: const InputDecoration(
              hintText: '1 - 16',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickPicks(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildQuickPicks() {
    const picks = [1, 2, 4, 8, 16];
    return Row(
      children: picks.map((n) {
        final active = _value == n;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: n != 16 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                widget.controller.text = '$n';
                widget.controller.selection = TextSelection.collapsed(
                  offset: '$n'.length,
                );
                setState(() => _value = n);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MaxValueFormatter extends TextInputFormatter {
  _MaxValueFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final v = int.tryParse(newValue.text);
    if (v == null || v < 1) return oldValue;
    if (v > max) {
      return TextEditingValue(
        text: '$max',
        selection: TextSelection.collapsed(offset: '$max'.length),
      );
    }
    return newValue;
  }
}
