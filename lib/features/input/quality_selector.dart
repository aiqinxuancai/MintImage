import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import 'selector_button.dart';

class QualitySelector extends StatelessWidget {
  const QualitySelector({
    super.key,
    required this.selectedQuality,
    required this.onSelected,
  });

  final ImageQuality selectedQuality;
  final ValueChanged<ImageQuality> onSelected;

  @override
  Widget build(BuildContext context) {
    return SelectorButton<ImageQuality>(
      icon: Icons.auto_awesome_rounded,
      label: selectedQuality.label,
      values: ImageQuality.values,
      selectedValue: selectedQuality,
      onSelected: onSelected,
      itemLabelBuilder: (value) => value.label,
    );
  }
}
