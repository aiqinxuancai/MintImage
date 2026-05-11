import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/generation_request.dart';
import '../../core/models/image_record.dart';
import '../../core/providers/generation_provider.dart';
import '../../core/providers/image_list_provider.dart';
import '../../core/providers/settings_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hasApiKey = settings.activeProfile.apiKey.trim().isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GPT Image',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              hasApiKey ? '生成与改图工作台' : '先完成 API 配置即可开始使用',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded),
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
                            onReusePrompt: (prompt) {
                              _inputBarKey.currentState?.prefillPrompt(prompt);
                            },
                            onReuseEdit: (record) {
                              _inputBarKey.currentState?.prefillForEdit(record);
                            },
                            onRetryRecord: _retryRecord,
                            onCancelRecord: _cancelRecord,
                            onDeleteRecord: _deleteRecord,
                          ),
                        ),
                        BottomInputBar(
                          key: _inputBarKey,
                          onSubmit: _submitRequest,
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

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
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
