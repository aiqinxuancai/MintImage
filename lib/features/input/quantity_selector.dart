import 'package:flutter/material.dart';

import 'selector_button.dart';

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
    return SelectorButton<int>(
      icon: Icons.layers_rounded,
      label: '$count',
      values: List<int>.generate(16, (index) => index + 1),
      selectedValue: count,
      onSelected: onSelected,
      itemLabelBuilder: (value) => value.toString(),
    );
  }
}
