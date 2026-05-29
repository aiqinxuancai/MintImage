import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/generation_request.dart';
import '../../core/models/image_record.dart';
import '../../core/providers/generation_provider.dart';
import '../../core/providers/image_list_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/update_check_provider.dart';
import '../../core/version/app_version.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../image_list/image_list_widget.dart';
import '../input/bottom_input_bar.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey<BottomInputBarState> _inputBarKey =
      GlobalKey<BottomInputBarState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _selectionMode = false;
  Set<String> _selectedRecordIds = const <String>{};
  bool _favoriteOnly = false;
  bool _searchExpanded = false;
  String _searchQuery = '';
  int _attachmentCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final updateState = ref.watch(updateCheckProvider);
    final hasApiKey = settings.activeProfile.apiKey.trim().isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MintImage',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (updateState.hasUpdate) ...[
                  const SizedBox(width: 8),
                  _NewVersionBadge(onTap: () => _handleUpdateTap(updateState)),
                ],
              ],
            ),
            Text(
              hasApiKey ? '生成与改图工作台' : '先完成 API 配置即可开始使用',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (_selectionMode && _selectedRecordIds.isNotEmpty)
            IconButton(
              tooltip: '删除选中图像',
              onPressed: _confirmDeleteSelectedRecords,
              icon: const Icon(Icons.delete_rounded),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _selectionMode
                ? IconButton(
                    tooltip: '取消选择',
                    onPressed: _exitSelectionMode,
                    icon: const Icon(Icons.close_rounded),
                  )
                : TextButton(
                    onPressed: _enterSelectionMode,
                    child: const Text('选择'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: IconButton(
              tooltip: _favoriteOnly ? '显示全部' : '只看收藏',
              onPressed: _toggleFavoriteFilter,
              color: _favoriteOnly ? Colors.orange.shade700 : null,
              icon: Icon(
                _favoriteOnly ? Icons.star_rounded : Icons.star_border_rounded,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: IconButton(
              tooltip: _searchExpanded ? '关闭搜索' : '搜索提示词',
              onPressed: _toggleSearchPanel,
              color: _searchExpanded ? Colors.blue.shade600 : null,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: '设置',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_searchExpanded ? 52 : 0),
          child: ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: _searchExpanded ? 52 : 0,
              padding: EdgeInsets.fromLTRB(12, 0, 12, _searchExpanded ? 8 : 0),
              alignment: Alignment.topCenter,
              child: _searchExpanded
                  ? TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _handleSearchChanged,
                      minLines: 1,
                      maxLines: 1,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '搜索 Prompt',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清空搜索',
                                onPressed: _clearSearchQuery,
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppThemeTokens.canvas, AppThemeTokens.canvasTint],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -60,
              right: -40,
              child: _BackgroundOrb(
                size: 220,
                colors: [Color(0x444FC3F7), Color(0x114FC3F7)],
              ),
            ),
            const Positioned(
              top: 120,
              left: -70,
              child: _BackgroundOrb(
                size: 180,
                colors: [Color(0x2281D1F0), Color(0x0081D1F0)],
              ),
            ),
            const Positioned(
              bottom: 90,
              right: -50,
              child: _BackgroundOrb(
                size: 200,
                colors: [Color(0x2281D1F0), Color(0x0081D1F0)],
              ),
            ),
            Positioned.fill(
              child: hasApiKey
                  ? Column(
                      children: [
                        Expanded(
                          child: ImageListWidget(
                            onReusePrompt: (record) {
                              _inputBarKey.currentState?.prefillFromRecord(
                                record,
                              );
                            },
                            onReuseEdit: (record) {
                              _inputBarKey.currentState?.prefillForEdit(record);
                            },
                            onRetryRecord: _retryRecord,
                            onCancelRecord: _cancelRecord,
                            onDeleteRecord: _deleteRecord,
                            onToggleFavorite: _toggleRecordFavorite,
                            currentAttachmentCount: _attachmentCount,
                            onAppendRecordToAttachments:
                                _appendRecordToAttachments,
                            selectionMode: _selectionMode,
                            selectedRecordIds: _selectedRecordIds,
                            onToggleSelection: _toggleRecordSelection,
                            onSelectRecord: _selectRecord,
                            favoriteOnly: _favoriteOnly,
                            searchQuery: _searchQuery,
                          ),
                        ),
                        BottomInputBar(
                          key: _inputBarKey,
                          onSubmit: _submitRequest,
                          onAttachmentCountChanged: (count) {
                            if (mounted) {
                              setState(() {
                                _attachmentCount = count;
                              });
                            }
                          },
                        ),
                      ],
                    )
                  : EmptyState(
                      title: '请先设置 API Key',
                      description:
                          '先在设置页补充 Base URL、模型名和 Key，然后就可以从底部输入框直接开始生成。',
                      actionLabel: '前往设置',
                      onAction: _openSettings,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest(GenerationRequest request) async {
    await ref.read(generationProvider.notifier).submit(request);
  }

  Future<void> _retryRecord(ImageRecord record) async {
    await ref.read(generationProvider.notifier).retryRecord(record);
  }

  void _cancelRecord(String recordId) {
    ref.read(generationProvider.notifier).cancel(recordId);
  }

  Future<void> _deleteRecord(ImageRecord record) async {
    if (record.isInProgress) {
      await ref.read(generationProvider.notifier).deleteRecord(record.id);
      return;
    }

    await ref.read(imageListProvider.notifier).removeRecord(record.id);
  }

  Future<void> _toggleRecordFavorite(ImageRecord record) async {
    await ref.read(imageListProvider.notifier).toggleFavorite(record.id);
  }

  Future<void> _appendRecordToAttachments(ImageRecord record) async {
    final added = await _inputBarKey.currentState?.appendImageFromRecord(
      record,
    );
    if (added != true || !mounted) {
      return;
    }

    final count =
        _inputBarKey.currentState?.attachmentCount ?? _attachmentCount;
    setState(() {
      _attachmentCount = count;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已添加到附件$count。')));
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedRecordIds = const <String>{};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedRecordIds = const <String>{};
    });
  }

  void _toggleRecordSelection(String recordId) {
    if (!_selectionMode) {
      return;
    }

    final selected = {..._selectedRecordIds};
    if (!selected.add(recordId)) {
      selected.remove(recordId);
    }
    setState(() {
      _selectedRecordIds = selected;
    });
  }

  void _selectRecord(String recordId) {
    if (!_selectionMode || _selectedRecordIds.contains(recordId)) {
      return;
    }

    setState(() {
      _selectedRecordIds = {..._selectedRecordIds, recordId};
    });
  }

  void _toggleFavoriteFilter() {
    setState(() {
      _selectionMode = false;
      _selectedRecordIds = const <String>{};
      _favoriteOnly = !_favoriteOnly;
    });
  }

  void _toggleSearchPanel() {
    if (_searchExpanded) {
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _selectionMode = false;
        _selectedRecordIds = const <String>{};
        _searchExpanded = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _selectionMode = false;
      _selectedRecordIds = const <String>{};
      _searchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearchQuery() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _confirmDeleteSelectedRecords() async {
    final selectedCount = _selectedRecordIds.length;
    if (selectedCount == 0) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除图像'),
          content: Text('确认删除这 $selectedCount 个图像？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final selectedIds = {..._selectedRecordIds};
    final records = ref
        .read(imageListProvider)
        .where((record) => selectedIds.contains(record.id))
        .toList();

    _exitSelectionMode();

    for (final record in records) {
      await _deleteRecord(record);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  Future<void> _handleUpdateTap(UpdateCheckState updateState) async {
    if (!updateState.hasUpdate) {
      return;
    }

    if (Platform.isIOS) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('发现新版本'),
            content: Text(
              '有新的版本 ${updateState.latestVersion ?? ''}，请前往 ${AppVersion.repositoryUrl} 下载。',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
      return;
    }

    var launched = false;
    try {
      final uri = Uri.parse(updateState.releaseUrl);
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开下载页：${updateState.releaseUrl}')),
      );
    }
  }
}

class _NewVersionBadge extends StatelessWidget {
  const _NewVersionBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE4F6EE),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF93D7B5)),
        ),
        child: Text(
          'New',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF177245),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
