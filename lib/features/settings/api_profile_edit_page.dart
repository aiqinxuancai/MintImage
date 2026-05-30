import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';

class ApiProfileEditPage extends ConsumerStatefulWidget {
  const ApiProfileEditPage({super.key, this.profile});

  final ApiProfile? profile;

  @override
  ConsumerState<ApiProfileEditPage> createState() => _ApiProfileEditPageState();
}

class _ApiProfileEditPageState extends ConsumerState<ApiProfileEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _obscureApiKey = true;
  late ImageGenerationApiMode _apiMode;

  ApiProfile? get _editingProfile => widget.profile;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final profile = _editingProfile;

    _nameController.text =
        profile?.name ?? '配置 ${settings.profiles.length + 1}';
    _apiMode = profile?.apiMode ?? ImageGenerationApiMode.images;
    _baseUrlController.text = profile?.baseUrl ?? 'https://api.openai.com';
    _apiKeyController.text = profile?.apiKey ?? '';
    _modelController.text = profile?.model ?? _apiMode.defaultModel;

    _nameController.addListener(_refresh);
    _baseUrlController.addListener(_refresh);
    _modelController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _baseUrlController.removeListener(_refresh);
    _modelController.removeListener(_refresh);
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewBaseUrl = _baseUrlController.text.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final finalUrl = previewBaseUrl.isEmpty
        ? 'https://example.com${_apiMode.generationPath}'
        : '$previewBaseUrl${_apiMode.generationPath}';

    return Scaffold(
      appBar: AppBar(title: Text(_editingProfile == null ? '新增配置' : '编辑配置')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppThemeTokens.canvas, AppThemeTokens.canvasTint],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: AppDecorations.card(radius: 30),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('连接信息', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '这里维护单组 Base URL、模型名、API Key 与生图 API。保存后可以直接在主页底部切换。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '名称'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(labelText: 'Base URL'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入 Base URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeTokens.surfaceSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '最终生成接口：$finalUrl',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppThemeTokens.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ImageGenerationApiMode>(
                      initialValue: _apiMode,
                      decoration: const InputDecoration(labelText: '生图 API'),
                      items: [
                        for (final mode in ImageGenerationApiMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label),
                          ),
                      ],
                      onChanged: (mode) {
                        if (mode == null) {
                          return;
                        }
                        setState(() {
                          final previousMode = _apiMode;
                          _apiMode = mode;
                          final model = _modelController.text.trim();
                          if (model.isEmpty ||
                              model == previousMode.defaultModel) {
                            _modelController.text = mode.defaultModel;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(labelText: '模型名'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入模型名';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(settingsProvider.notifier);
    final existing = _editingProfile;

    if (existing == null) {
      final created = await notifier.addProfile(
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
        apiMode: _apiMode,
      );
      await notifier.setActiveProfile(created.id);
    } else {
      await notifier.updateProfile(
        existing.copyWith(
          name: _nameController.text.trim(),
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          model: _modelController.text.trim(),
          apiMode: _apiMode,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
