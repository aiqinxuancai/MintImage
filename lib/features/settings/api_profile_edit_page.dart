import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/openai_client.dart';
import '../../core/models/settings_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';
import 'model_name_field.dart';

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
  bool _fetchingModels = false;
  bool _useStreaming = false;
  CancelToken? _modelListCancelToken;
  List<String> _modelOptions = const [];
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
    _useStreaming = profile?.useStreaming ?? false;
    _baseUrlController.text = profile?.baseUrl ?? 'https://api.openai.com';
    _apiKeyController.text = profile?.apiKey ?? '';
    _modelController.text = profile?.model ?? _apiMode.defaultModel;

    _nameController.addListener(_refresh);
    _baseUrlController.addListener(_refresh);
    _modelController.addListener(_refresh);
  }

  @override
  void dispose() {
    _modelListCancelToken?.cancel();
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
    final previewProfile = ApiProfile(
      id: 'preview',
      name: '',
      baseUrl: _baseUrlController.text.trim().isEmpty
          ? 'https://example.com'
          : _baseUrlController.text,
      apiKey: '',
      model: _modelController.text,
      apiMode: _apiMode,
    );
    final finalUrl = previewProfile.generationEndpoint;

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
                          _modelOptions = const [];
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('流式请求'),
                      subtitle: const Text('启用后发送 stream: true，可降低超时风险'),
                      value: _useStreaming,
                      onChanged: (v) => setState(() => _useStreaming = v),
                    ),
                    const SizedBox(height: 14),
                    ModelNameField(
                      controller: _modelController,
                      modelOptions: _modelOptions,
                      fetching: _fetchingModels,
                      onFetchModels: _fetchModels,
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
        useStreaming: _useStreaming,
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
          useStreaming: _useStreaming,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _fetchModels() async {
    if (_fetchingModels) {
      return;
    }

    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (baseUrl.isEmpty) {
      _showMessage('请输入 Base URL 后再获取模型列表。');
      return;
    }
    if (apiKey.isEmpty) {
      _showMessage('请输入 API Key 后再获取模型列表。');
      return;
    }

    final cancelToken = CancelToken();
    _modelListCancelToken = cancelToken;
    setState(() {
      _fetchingModels = true;
    });

    try {
      final models = await ref
          .read(modelListApiProvider)
          .fetchImageGenerationModels(
            profile: ApiProfile(
              id: _editingProfile?.id ?? 'model-list-preview',
              name: _nameController.text.trim().isEmpty
                  ? '配置'
                  : _nameController.text.trim(),
              baseUrl: baseUrl,
              apiKey: apiKey,
              model: _modelController.text.trim().isEmpty
                  ? _apiMode.defaultModel
                  : _modelController.text.trim(),
              apiMode: _apiMode,
            ),
            timeoutSeconds: ref.read(settingsProvider).requestTimeoutSeconds,
            cancelToken: cancelToken,
          );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }

      setState(() {
        _modelOptions = models;
        if (_modelController.text.trim().isEmpty && models.isNotEmpty) {
          _modelController.text = models.first;
        }
      });
      _showMessage('已获取 ${models.length} 个模型。');
    } on ApiException catch (error) {
      if (mounted && !cancelToken.isCancelled) {
        _showMessage('获取模型列表失败：${error.message}');
      }
    } catch (error) {
      if (mounted && !cancelToken.isCancelled) {
        _showMessage('获取模型列表失败：$error');
      }
    } finally {
      if (mounted && identical(_modelListCancelToken, cancelToken)) {
        setState(() {
          _fetchingModels = false;
          _modelListCancelToken = null;
        });
      }
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
