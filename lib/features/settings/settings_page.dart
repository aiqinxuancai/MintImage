import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/image_list_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/version/app_version.dart';
import '../../shared/theme.dart';
import '../logs/request_log_page.dart';
import 'api_profile_edit_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: '新增配置',
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppThemeTokens.canvas, AppThemeTokens.canvasTint],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            const _AppInfoCard(),
            const SizedBox(height: 12),
            _RequestTimeoutCard(
              timeoutSeconds: settings.requestTimeoutSeconds,
              onEdit: () => _editRequestTimeout(context, ref, settings),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.receipt_long_rounded,
              title: '请求日志',
              description: '查看当前进程记录的请求、响应和错误详情。',
              actionLabel: '查看日志',
              onAction: () => _openRequestLogs(context),
            ),
            const SizedBox(height: 12),
            for (final profile in settings.profiles) ...[
              Slidable(
                key: ValueKey(profile.id),
                endActionPane: settings.profiles.length <= 1
                    ? null
                    : ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) async {
                              await ref
                                  .read(settingsProvider.notifier)
                                  .deleteProfile(profile.id);
                            },
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            icon: Icons.delete_rounded,
                            label: '删除',
                          ),
                        ],
                      ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProfileCard(
                    profile: profile,
                    isActive: profile.id == settings.activeProfileId,
                    onTap: () async {
                      await ref
                          .read(settingsProvider.notifier)
                          .setActiveProfile(profile.id);
                    },
                    onEdit: () => _openEditor(context, profile: profile),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('清除历史记录'),
                      content: const Text('这会删除所有生成记录，但不会清除 API 配置。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('确认清除'),
                        ),
                      ],
                    );
                  },
                );

                if (confirmed != true || !context.mounted) {
                  return;
                }

                await ref.read(imageListProvider.notifier).clearHistory();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('历史记录已清空。')));
              },
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('清除历史记录'),
              style: FilledButton.styleFrom(
                backgroundColor: AppThemeTokens.dangerSurface,
                foregroundColor: AppThemeTokens.dangerText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {ApiProfile? profile}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApiProfileEditPage(profile: profile),
      ),
    );
  }

  Future<void> _editRequestTimeout(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) async {
    final controller = TextEditingController(
      text: settings.requestTimeoutSeconds.toString(),
    );

    final timeoutSeconds = await showDialog<int>(
      context: context,
      builder: (context) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('请求超时（秒）'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '超时时间',
                      suffixText: '秒',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '默认 600 秒。生成较慢时可以适当调高。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed == null || parsed <= 0) {
                      setState(() {
                        errorText = '请输入大于 0 的整数';
                      });
                      return;
                    }

                    Navigator.of(context).pop(parsed);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (timeoutSeconds == null) {
      return;
    }

    await ref
        .read(settingsProvider.notifier)
        .setRequestTimeoutSeconds(timeoutSeconds);
  }

  Future<void> _openRequestLogs(BuildContext context) async {
    if (_supportsDetachedLogWindow) {
      try {
        await Process.start(Platform.resolvedExecutable, const [
          '--log-window',
        ], mode: ProcessStartMode.detached);
        return;
      } catch (_) {
        // Fall back to in-app viewing when detached launch fails.
      }
    }

    if (!context.mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RequestLogPage()));
  }

  bool get _supportsDetachedLogWindow =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: 28),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppThemeTokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.info_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '关于 MintImage',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.sell_outlined,
            label: '版本',
            value: AppVersion.current,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.code_rounded,
            label: '开源地址',
            value: AppVersion.repositoryUrl,
            onTap: () => _openRepository(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openRepository(BuildContext context) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(AppVersion.repositoryUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开 GitHub 地址。')));
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(icon, size: 18, color: AppThemeTokens.primaryStrong),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppThemeTokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: onTap == null
                  ? AppThemeTokens.textPrimary
                  : AppThemeTokens.primaryStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: AppThemeTokens.primaryStrong,
          ),
        ],
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
  });

  final ApiProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tint = isActive ? AppThemeTokens.surfaceSoft : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: AppDecorations.card(radius: 28, color: tint),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppThemeTokens.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '使用中',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '编辑',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                profile.normalizedBaseUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppThemeTokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '模型：${profile.model}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestTimeoutCard extends StatelessWidget {
  const _RequestTimeoutCard({
    required this.timeoutSeconds,
    required this.onEdit,
  });

  final int timeoutSeconds;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: 28),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppThemeTokens.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timer_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('请求超时', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$timeoutSeconds 秒',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: onEdit, child: const Text('修改')),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: 28),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppThemeTokens.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
