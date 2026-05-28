import 'package:flutter/material.dart';

import '../../core/models/settings_model.dart';
import 'selector_button.dart';

class ApiProfileSelector extends StatelessWidget {
  const ApiProfileSelector({
    super.key,
    required this.profiles,
    required this.activeProfileId,
    required this.onSelected,
  });

  final List<ApiProfile> profiles;
  final String activeProfileId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final activeProfile = profiles.firstWhere(
      (profile) => profile.id == activeProfileId,
      orElse: () => profiles.first,
    );

    return SelectorButton<String>(
      icon: Icons.hub_rounded,
      label: activeProfile.name,
      values: profiles.map((profile) => profile.id).toList(),
      selectedValue: activeProfileId,
      onSelected: onSelected,
      itemLabelBuilder: (value) {
        final profile = profiles.firstWhere((item) => item.id == value);
        return profile.name;
      },
    );
  }
}
