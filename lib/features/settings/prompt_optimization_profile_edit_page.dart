import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/api/openai_client.dart';
import '../../core/api/prompt_optimization_api.dart';
import '../../core/models/settings_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';

class PromptOptimizationProfileEditPage extends ConsumerStatefulWidget {
  const PromptOptimizationProfileEditPage({super.key, this.profile});

  final PromptOptimizationProfile? profile;

  @override
  ConsumerState<PromptOptimizationProfileEditPage> createState() =>
      _PromptOptimizationProfileEditPageState();
}

class _PromptOptimizationProfileEditPageState
    extends ConsumerState<PromptOptimizationProfileEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _obscureApiKey = true;
  bool _testingConnection = false;
  CancelToken? _testCancelToken;
  late PromptOptimizationProtocol _protocol;

  PromptOptimizationProfile? get _editingProfile => widget.profile;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final profile = _editingProfile;

    _protocol = profile?.protocol ?? PromptOptimizationProtocol.openAiResponses;
    _nameController.text =
        profile?.name ??
        '优化配置 ${settings.promptOptimizationProfiles.length + 1}';
    _baseUrlController.text = profile?.baseUrl ?? _protocol.defaultBaseUrl;
    _apiKeyController.text = profile?.apiKey ?? '';
    _modelController.text = profile?.model ?? _protocol.defaultModel;

    _baseUrlController.addListener(_refresh);
    _modelController.addListener(_refresh);
  }

  @override
  void dispose() {
    _testCancelToken?.cancel();
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
    final finalUrl = _previewEndpoint();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingProfile == null ? '新增提示词优化 API' : '编辑提示词优化 API'),
      ),
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
                decoration: AppDecorations.card(radius: 24),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('连接信息', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '这里维护提示词优化专用的协议、Base URL、模型名与 API Key。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PromptOptimizationProtocol>(
                      initialValue: _protocol,
                      decoration: const InputDecoration(labelText: '协议类型'),
                      items: [
                        for (final protocol
                            in PromptOptimizationProtocol.values)
                          DropdownMenuItem(
                            value: protocol,
                            child: Text(protocol.label),
                          ),
                      ],
                      onChanged: (protocol) {
                        if (protocol == null) {
                          return;
                        }
                        setState(() {
                          final previousProtocol = _protocol;
                          _protocol = protocol;
                          final baseUrl = _baseUrlController.text.trim();
                          if (baseUrl.isEmpty ||
                              baseUrl == previousProtocol.defaultBaseUrl) {
                            _baseUrlController.text = protocol.defaultBaseUrl;
                          }
                          final model = _modelController.text.trim();
                          if (model.isEmpty ||
                              model == previousProtocol.defaultModel) {
                            _modelController.text = protocol.defaultModel;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppThemeTokens.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '最终请求接口：$finalUrl',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppThemeTokens.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _save, child: const Text('保存')),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _testingConnection ? null : _testConnection,
                icon: _testingConnection
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check_rounded),
                label: Text(_testingConnection ? '测试中...' : '测试连通性'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewEndpoint() {
    final baseUrl = _baseUrlController.text.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final resolvedBaseUrl = baseUrl.isEmpty ? 'https://example.com' : baseUrl;

    return switch (_protocol) {
      PromptOptimizationProtocol.openAiChatCompletions => _appendVersionPath(
        resolvedBaseUrl,
        'v1',
        ['chat', 'completions'],
      ),
      PromptOptimizationProtocol.openAiResponses => _appendVersionPath(
        resolvedBaseUrl,
        'v1',
        ['responses'],
      ),
      PromptOptimizationProtocol.claudeMessages => _appendVersionPath(
        resolvedBaseUrl,
        'v1',
        ['messages'],
      ),
      PromptOptimizationProtocol.geminiGenerateContent =>
        _appendVersionPath(resolvedBaseUrl, 'v1beta', [
          'models/${_modelController.text.trim().isEmpty ? '{model}' : _modelController.text.trim()}',
        ], suffix: ':generateContent'),
    };
  }

  String _appendVersionPath(
    String baseUrl,
    String version,
    List<String> segments, {
    String suffix = '',
  }) {
    final normalizedSegments = [
      if (!baseUrl.endsWith('/$version')) version,
      ...segments,
    ];
    return '$baseUrl/${normalizedSegments.join('/')}$suffix';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(settingsProvider.notifier);
    final existing = _editingProfile;

    if (existing == null) {
      final created = await notifier.addPromptOptimizationProfile(
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
        protocol: _protocol,
      );
      await notifier.setActivePromptOptimizationProfile(created.id);
    } else {
      await notifier.updatePromptOptimizationProfile(
        existing.copyWith(
          name: _nameController.text.trim(),
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          model: _modelController.text.trim(),
          protocol: _protocol,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showMessage('请输入 API Key 后再测试。');
      return;
    }

    final profile = PromptOptimizationProfile(
      id: _editingProfile?.id ?? 'connection-test',
      name: _nameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      apiKey: apiKey,
      model: _modelController.text.trim(),
      protocol: _protocol,
    );
    final cancelToken = CancelToken();
    _testCancelToken = cancelToken;
    setState(() {
      _testingConnection = true;
    });

    try {
      final result = await ref
          .read(promptOptimizationApiProvider)
          .optimize(
            prompt: '一只白猫坐在雨后的窗边',
            direction: PromptOptimizationDirection.strengthen,
            profile: profile,
            timeoutSeconds: ref.read(settingsProvider).requestTimeoutSeconds,
            cancelToken: cancelToken,
          );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('连通性测试成功'),
            content: Text(result, maxLines: 8, overflow: TextOverflow.ellipsis),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
    } on ApiException catch (error) {
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      _showMessage('连通性测试失败：${error.message}');
    } catch (error) {
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      _showMessage('连通性测试失败：$error');
    } finally {
      if (mounted && identical(_testCancelToken, cancelToken)) {
        setState(() {
          _testingConnection = false;
          _testCancelToken = null;
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
