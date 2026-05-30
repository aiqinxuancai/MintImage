import 'package:flutter/material.dart';

import '../../core/models/settings_model.dart';
import '../../shared/theme.dart';

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

    return Tooltip(
      message: '切换生图 API',
      child: GestureDetector(
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
                Icons.hub_rounded,
                size: 13,
                color: AppThemeTokens.primaryStrong,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  activeProfile.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeTokens.primaryStrong,
                  ),
                ),
              ),
            ],
          ),
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
            children: profiles.map((profile) {
              final active = profile.id == activeProfileId;
              return ListTile(
                leading: Icon(
                  active ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: active ? AppThemeTokens.primary : Colors.grey,
                ),
                title: Text(profile.name),
                subtitle: Text(
                  profile.normalizedBaseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onSelected(profile.id);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
