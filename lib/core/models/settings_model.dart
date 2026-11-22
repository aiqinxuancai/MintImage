import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'generation_request.dart';

const _uuid = Uuid();

enum ImageGenerationApiMode {
  images('images', 'Images API (/v1/images)', 'Images API', 'gpt-image-2'),
  imagesAsync('images_async', 'Images API（异步任务）', 'Images 异步', 'gpt-image-2'),
  responses(
    'responses',
    'Responses API (/v1/responses)',
    'Responses API',
    'gpt-5.5',
  );

  const ImageGenerationApiMode(
    this.storageValue,
    this.label,
    this.shortLabel,
    this.defaultModel,
  );

  final String storageValue;
  final String label;
  final String shortLabel;
  final String defaultModel;

  String get generationPath {
    return switch (this) {
      ImageGenerationApiMode.images ||
      ImageGenerationApiMode.imagesAsync => '/v1/images/generations',
      ImageGenerationApiMode.responses => '/v1/responses',
    };
  }

  static ImageGenerationApiMode fromStorageValue(Object? rawValue) {
    final value = rawValue is String ? rawValue : '';
    return ImageGenerationApiMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => ImageGenerationApiMode.images,
    );
  }
}

enum ResponsesReasoningEffort {
  defaultValue,
  none,
  minimal,
  low,
  medium,
  high,
  xhigh,
  max;

  String get value => this == defaultValue ? 'default' : name;

  static ResponsesReasoningEffort parse(Object? value) =>
      values.firstWhere((e) => e.value == value, orElse: () => defaultValue);
}

class ApiProfile {
  const ApiProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.apiMode = ImageGenerationApiMode.images,
    this.useStreaming = false,
    this.includeSizeInPrompt = false,
    this.reasoningEffort = ResponsesReasoningEffort.defaultValue,
    this.safetyIdentifier = '',
  });

  factory ApiProfile.initial() {
    final apiMode = ImageGenerationApiMode.fromStorageValue(
      const String.fromEnvironment('API_MODE', defaultValue: 'images'),
    );
    const configuredModel = String.fromEnvironment('MODEL');
    return ApiProfile(
      id: _uuid.v4(),
      name: '默认',
      baseUrl: const String.fromEnvironment(
        'BASE_URL',
        defaultValue: 'https://api.openai.com',
      ),
      apiKey: const String.fromEnvironment('API_KEY'),
      model: configuredModel.isEmpty ? apiMode.defaultModel : configuredModel,
      apiMode: apiMode,
    );
  }

  factory ApiProfile.fromJson(Map<String, dynamic> json) {
    var apiMode = ImageGenerationApiMode.fromStorageValue(json['apiMode']);
    var baseUrl = json['baseUrl'] as String? ?? 'https://api.openai.com';
    if (apiMode == ImageGenerationApiMode.images) {
      final legacyUrl = _legacyRightApiBaseUrl(baseUrl);
      if (legacyUrl != null) {
        // Migrate old profiles to the explicit protocol, keeping URL cleanup
        // separate from request dispatch. New hosts need no provider detection.
        apiMode = ImageGenerationApiMode.imagesAsync;
        baseUrl = legacyUrl;
      }
    }
    return ApiProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '默认',
      baseUrl: baseUrl,
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? apiMode.defaultModel,
      apiMode: apiMode,
      includeSizeInPrompt: json['includeSizeInPrompt'] == true,
      useStreaming: json['useStreaming'] as bool? ?? false,
      reasoningEffort: ResponsesReasoningEffort.parse(json['reasoningEffort']),
      safetyIdentifier: json['safetyIdentifier'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final ImageGenerationApiMode apiMode;
  final bool useStreaming;
  final bool includeSizeInPrompt;
  final ResponsesReasoningEffort reasoningEffort;
  final String safetyIdentifier;

  String? get resolvedSafetyIdentifier {
    final value = safetyIdentifier.trim();
    return value.isEmpty ? null : value;
  }

  /// OpenRouter's unified Image API: one JSON endpoint for generation and
  /// edits, with no async tasks or multipart uploads.
  bool get isOpenRouterImages {
    if (apiMode == ImageGenerationApiMode.responses) return false;
    final uri = Uri.tryParse(baseUrl.trim());
    return uri?.host.toLowerCase() == 'openrouter.ai';
  }

  String get normalizedBaseUrl {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (isOpenRouterImages &&
        const ['', '/api', '/api/v1', '/api/v1/images'].contains(uri!.path)) {
      return uri.replace(path: '/api').toString();
    }
    if (apiMode != ImageGenerationApiMode.responses &&
        normalized.endsWith('/v1')) {
      return normalized.substring(0, normalized.length - 3);
    }
    return normalized;
  }

  static String? _legacyRightApiBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !const [
          'rightapi.ai',
          'www.rightapi.ai',
        ].contains(uri.host.toLowerCase())) {
      return null;
    }
    if (const [
      '',
      '/v1',
      '/draw',
      '/draw/v1',
    ].contains(uri.path.toLowerCase())) {
      return uri
          .replace(host: 'rightapi.ai', path: '')
          .toString()
          .replaceAll(RegExp(r'/+$'), '');
    }
    return normalized;
  }

  String get generationPath {
    if (isOpenRouterImages && Uri.tryParse(normalizedBaseUrl)?.path == '/api') {
      return '/v1/images';
    }
    return apiMode.generationPath;
  }

  String get generationEndpoint => '$normalizedBaseUrl$generationPath';

  String get editEndpoint {
    if (isOpenRouterImages) return generationEndpoint;
    return switch (apiMode) {
      ImageGenerationApiMode.images || ImageGenerationApiMode.imagesAsync =>
        '$normalizedBaseUrl/v1/images/edits',
      ImageGenerationApiMode.responses => '$normalizedBaseUrl/v1/responses',
    };
  }

  ApiProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    ImageGenerationApiMode? apiMode,
    bool? useStreaming,
    bool? includeSizeInPrompt,
    ResponsesReasoningEffort? reasoningEffort,
    String? safetyIdentifier,
  }) {
    return ApiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      apiMode: apiMode ?? this.apiMode,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      includeSizeInPrompt: includeSizeInPrompt ?? this.includeSizeInPrompt,
      useStreaming: useStreaming ?? this.useStreaming,
      safetyIdentifier: safetyIdentifier ?? this.safetyIdentifier,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'apiMode': apiMode.storageValue,
      if (reasoningEffort != ResponsesReasoningEffort.defaultValue)
        'reasoningEffort': reasoningEffort.value,
      if (includeSizeInPrompt) 'includeSizeInPrompt': true,
      'useStreaming': useStreaming,
      'safetyIdentifier': safetyIdentifier,
    };
  }
}

enum PromptOptimizationProtocol {
  openAiChatCompletions('openai_chat_completions'),
  openAiResponses('openai_responses'),
  claudeMessages('claude_messages'),
  geminiGenerateContent('gemini_generate_content');

  const PromptOptimizationProtocol(this.storageValue);

  final String storageValue;

  String get label {
    return switch (this) {
      PromptOptimizationProtocol.openAiChatCompletions =>
        'OpenAI Chat Completions',
      PromptOptimizationProtocol.openAiResponses => 'OpenAI Responses',
      PromptOptimizationProtocol.claudeMessages => 'Claude Messages',
      PromptOptimizationProtocol.geminiGenerateContent => 'Gemini',
    };
  }

  String get defaultBaseUrl {
    return switch (this) {
      PromptOptimizationProtocol.openAiChatCompletions ||
      PromptOptimizationProtocol.openAiResponses => 'https://api.openai.com',
      PromptOptimizationProtocol.claudeMessages => 'https://right.codes/claude',
      PromptOptimizationProtocol.geminiGenerateContent =>
        'https://right.codes/gemini',
    };
  }

  String get defaultModel {
    return switch (this) {
      PromptOptimizationProtocol.openAiChatCompletions ||
      PromptOptimizationProtocol.openAiResponses => 'gpt-5.5',
      PromptOptimizationProtocol.claudeMessages => 'claude-sonnet-4-6',
      PromptOptimizationProtocol.geminiGenerateContent => 'gemini-2.5-flash',
    };
  }

  static PromptOptimizationProtocol fromStorageValue(Object? rawValue) {
    final value = rawValue is String ? rawValue : '';
    return PromptOptimizationProtocol.values.firstWhere(
      (protocol) => protocol.storageValue == value,
      orElse: () => PromptOptimizationProtocol.openAiResponses,
    );
  }
}

class PromptOptimizationProfile {
  const PromptOptimizationProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.protocol,
  });

  factory PromptOptimizationProfile.fromJson(Map<String, dynamic> json) {
    final protocol = PromptOptimizationProtocol.fromStorageValue(
      json['protocol'],
    );
    return PromptOptimizationProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '提示词优化',
      baseUrl: json['baseUrl'] as String? ?? protocol.defaultBaseUrl,
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? protocol.defaultModel,
      protocol: protocol,
    );
  }

  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final PromptOptimizationProtocol protocol;

  String get normalizedBaseUrl => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  PromptOptimizationProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    PromptOptimizationProtocol? protocol,
  }) {
    return PromptOptimizationProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      protocol: protocol ?? this.protocol,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'protocol': protocol.storageValue,
    };
  }
}

class WebDavBackupConfig {
  const WebDavBackupConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.remoteDirectory,
  });

  factory WebDavBackupConfig.fromJson(Map<String, dynamic> json) {
    return WebDavBackupConfig(
      baseUrl: json['baseUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remoteDirectory:
          json['remoteDirectory'] as String? ?? 'MintImage/backups',
    );
  }

  final String baseUrl;
  final String username;
  final String password;
  final String remoteDirectory;

  bool get isConfigured {
    return baseUrl.trim().isNotEmpty && remoteDirectory.trim().isNotEmpty;
  }

  WebDavBackupConfig copyWith({
    String? baseUrl,
    String? username,
    String? password,
    String? remoteDirectory,
  }) {
    return WebDavBackupConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDirectory: remoteDirectory ?? this.remoteDirectory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'remoteDirectory': remoteDirectory,
    };
  }
}

class SettingsModel {
  static const String storageKey = 'settings_model_v1';
  static const int defaultRequestTimeoutSeconds = 600;

  const SettingsModel({
    required this.profiles,
    required this.activeProfileId,
    this.promptOptimizationProfiles = const [],
    this.activePromptOptimizationProfileId,
    this.responseFormat,
    this.requestTimeoutSeconds = defaultRequestTimeoutSeconds,
    this.lastSizePreset = SizePreset.auto,
    this.lastCustomWidth = 0,
    this.lastCustomHeight = 0,
    this.lastQuality = ImageQuality.auto,
    this.lastOutputFormat = ImageOutputFormat.png,
    this.lastFrameCount = 9,
    this.lastFrameDurationMs = 200,
    this.lastComplexity,
    this.lastSvgOptions,
    this.previewInfoCollapsed = false,
    this.webDavBackupConfig,
  });

  factory SettingsModel.initial() {
    final defaultProfile = ApiProfile.initial();
    return SettingsModel(
      profiles: [defaultProfile],
      activeProfileId: defaultProfile.id,
      promptOptimizationProfiles: const [],
      activePromptOptimizationProfileId: null,
      responseFormat: null,
      requestTimeoutSeconds: defaultRequestTimeoutSeconds,
      lastSizePreset: SizePreset.auto,
      lastCustomWidth: 0,
      lastCustomHeight: 0,
      lastQuality: ImageQuality.auto,
      lastOutputFormat: ImageOutputFormat.png,
      webDavBackupConfig: null,
    );
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'];
    final profiles = rawProfiles is List
        ? rawProfiles
              .map(
                (item) =>
                    ApiProfile.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList()
        : <ApiProfile>[ApiProfile.initial()];
    final activeProfileId = json['activeProfileId'] as String?;

    final resolvedActiveProfileId =
        profiles.any((profile) => profile.id == activeProfileId)
        ? activeProfileId!
        : profiles.first.id;
    final rawPromptOptimizationProfiles = json['promptOptimizationProfiles'];
    final promptOptimizationProfiles = rawPromptOptimizationProfiles is List
        ? rawPromptOptimizationProfiles
              .map(
                (item) => PromptOptimizationProfile.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : <PromptOptimizationProfile>[];
    final activePromptOptimizationProfileId =
        json['activePromptOptimizationProfileId'] as String?;
    final resolvedActivePromptOptimizationProfileId =
        promptOptimizationProfiles.any(
          (profile) => profile.id == activePromptOptimizationProfileId,
        )
        ? activePromptOptimizationProfileId
        : promptOptimizationProfiles.isEmpty
        ? null
        : promptOptimizationProfiles.first.id;
    final lastSizePreset = _normalizeSizePreset(json['lastSizePreset']);

    return SettingsModel(
      profiles: profiles,
      activeProfileId: resolvedActiveProfileId,
      promptOptimizationProfiles: promptOptimizationProfiles,
      activePromptOptimizationProfileId:
          resolvedActivePromptOptimizationProfileId,
      responseFormat: _normalizeResponseFormat(json['responseFormat']),
      requestTimeoutSeconds: _normalizeRequestTimeoutSeconds(
        json['requestTimeoutSeconds'],
      ),
      lastSizePreset: lastSizePreset,
      lastCustomWidth: _normalizeDimension(
        json['lastCustomWidth'],
        fallback: _fallbackWidthForPreset(lastSizePreset),
      ),
      lastCustomHeight: _normalizeDimension(
        json['lastCustomHeight'],
        fallback: _fallbackHeightForPreset(lastSizePreset),
      ),
      lastQuality: _normalizeImageQuality(json['lastQuality']),
      lastSvgOptions: SvgOptions.fromJson(json['lastSvgOptions']),
      lastOutputFormat: _normalizeImageOutputFormat(json['lastOutputFormat']),
      lastFrameCount: (json['lastFrameCount'] as int? ?? 9).clamp(2, 64),
      lastFrameDurationMs: (json['lastFrameDurationMs'] as int? ?? 200).clamp(
        20,
        2000,
      ),
      lastComplexity: ImageComplexity.fromApiValue(
        json['lastComplexity'] as String?,
      ),
      previewInfoCollapsed: _normalizeBool(json['previewInfoCollapsed']),
      webDavBackupConfig: _normalizeWebDavBackupConfig(
        json['webDavBackupConfig'],
      ),
    );
  }

  final List<ApiProfile> profiles;
  final String activeProfileId;
  final List<PromptOptimizationProfile> promptOptimizationProfiles;
  final String? activePromptOptimizationProfileId;
  final String? responseFormat;
  final int requestTimeoutSeconds;
  final SizePreset lastSizePreset;
  final int lastCustomWidth;
  final int lastCustomHeight;
  final ImageQuality lastQuality;
  final ImageOutputFormat lastOutputFormat;
  final int lastFrameCount;
  final int lastFrameDurationMs;
  final ImageComplexity? lastComplexity;
  final SvgOptions? lastSvgOptions;
  final bool previewInfoCollapsed;
  final WebDavBackupConfig? webDavBackupConfig;

  ApiProfile get activeProfile {
    return profiles.firstWhere(
      (profile) => profile.id == activeProfileId,
      orElse: () => profiles.first,
    );
  }

  ApiProfile? profileById(String id) {
    for (final profile in profiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return null;
  }

  PromptOptimizationProfile? get activePromptOptimizationProfile {
    final activeId = activePromptOptimizationProfileId;
    if (activeId == null) {
      return promptOptimizationProfiles.isEmpty
          ? null
          : promptOptimizationProfiles.first;
    }

    for (final profile in promptOptimizationProfiles) {
      if (profile.id == activeId) {
        return profile;
      }
    }

    return promptOptimizationProfiles.isEmpty
        ? null
        : promptOptimizationProfiles.first;
  }

  PromptOptimizationProfile? promptOptimizationProfileById(String id) {
    for (final profile in promptOptimizationProfiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return null;
  }

  SettingsModel copyWith({
    List<ApiProfile>? profiles,
    String? activeProfileId,
    List<PromptOptimizationProfile>? promptOptimizationProfiles,
    String? activePromptOptimizationProfileId,
    bool clearActivePromptOptimizationProfileId = false,
    String? responseFormat,
    bool clearResponseFormat = false,
    int? requestTimeoutSeconds,
    SizePreset? lastSizePreset,
    int? lastCustomWidth,
    int? lastCustomHeight,
    ImageQuality? lastQuality,
    ImageOutputFormat? lastOutputFormat,
    int? lastFrameCount,
    int? lastFrameDurationMs,
    ImageComplexity? lastComplexity,
    bool clearLastComplexity = false,
    SvgOptions? lastSvgOptions,
    bool clearLastSvgOptions = false,
    bool? previewInfoCollapsed,
    WebDavBackupConfig? webDavBackupConfig,
    bool clearWebDavBackupConfig = false,
  }) {
    return SettingsModel(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      promptOptimizationProfiles:
          promptOptimizationProfiles ?? this.promptOptimizationProfiles,
      activePromptOptimizationProfileId: clearActivePromptOptimizationProfileId
          ? null
          : activePromptOptimizationProfileId ??
                this.activePromptOptimizationProfileId,
      responseFormat: clearResponseFormat
          ? null
          : responseFormat ?? this.responseFormat,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      lastSizePreset: lastSizePreset ?? this.lastSizePreset,
      lastCustomWidth: lastCustomWidth ?? this.lastCustomWidth,
      lastCustomHeight: lastCustomHeight ?? this.lastCustomHeight,
      lastQuality: lastQuality ?? this.lastQuality,
      lastSvgOptions: clearLastSvgOptions
          ? null
          : lastSvgOptions ?? this.lastSvgOptions,
      lastOutputFormat: lastOutputFormat ?? this.lastOutputFormat,
      lastFrameCount: lastFrameCount ?? this.lastFrameCount,
      lastFrameDurationMs: lastFrameDurationMs ?? this.lastFrameDurationMs,
      lastComplexity: clearLastComplexity
          ? null
          : lastComplexity ?? this.lastComplexity,
      previewInfoCollapsed: previewInfoCollapsed ?? this.previewInfoCollapsed,
      webDavBackupConfig: clearWebDavBackupConfig
          ? null
          : webDavBackupConfig ?? this.webDavBackupConfig,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'activeProfileId': activeProfileId,
      'promptOptimizationProfiles': promptOptimizationProfiles
          .map((profile) => profile.toJson())
          .toList(),
      'activePromptOptimizationProfileId': activePromptOptimizationProfileId,
      'responseFormat': responseFormat,
      'requestTimeoutSeconds': requestTimeoutSeconds,
      'lastSizePreset': lastSizePreset.storageKey,
      'lastCustomWidth': lastCustomWidth,
      'lastCustomHeight': lastCustomHeight,
      'lastQuality': lastQuality.apiValue,
      'lastOutputFormat': lastOutputFormat.apiValue,
      'lastFrameCount': lastFrameCount,
      'lastFrameDurationMs': lastFrameDurationMs,
      'lastComplexity': lastComplexity?.apiValue,
      'lastSvgOptions': lastSvgOptions?.toJson(),
      'previewInfoCollapsed': previewInfoCollapsed,
      'webDavBackupConfig': webDavBackupConfig?.toJson(),
    };
  }

  String encode() => jsonEncode(toJson());

  static SettingsModel decode(String raw) {
    return SettingsModel.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  static int _normalizeRequestTimeoutSeconds(Object? rawValue) {
    final parsed = switch (rawValue) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };

    if (parsed == null || parsed <= 0) {
      return defaultRequestTimeoutSeconds;
    }

    return parsed;
  }

  static String? _normalizeResponseFormat(Object? rawValue) {
    final value = switch (rawValue) {
      String text => text.trim(),
      _ => '',
    };

    if (value.isEmpty) {
      return null;
    }

    if (value == 'b64_json') {
      return null;
    }

    return value;
  }

  static SizePreset _normalizeSizePreset(Object? rawValue) {
    final value = rawValue is String ? rawValue : '';
    return SizePreset.values.firstWhere(
      (preset) => preset.storageKey == value,
      orElse: () => SizePreset.auto,
    );
  }

  static int _normalizeDimension(Object? rawValue, {required int fallback}) {
    final parsed = switch (rawValue) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };

    if (parsed == null || parsed < 0) {
      return fallback;
    }

    return parsed;
  }

  static ImageQuality _normalizeImageQuality(Object? rawValue) {
    final value = rawValue is String ? rawValue : '';
    return ImageQuality.values.firstWhere(
      (quality) => quality.apiValue == value,
      orElse: () => ImageQuality.auto,
    );
  }

  static ImageOutputFormat _normalizeImageOutputFormat(Object? rawValue) {
    final value = rawValue is String ? rawValue : '';
    return ImageOutputFormat.values.firstWhere(
      (format) => format.apiValue == value,
      orElse: () => ImageOutputFormat.png,
    );
  }

  static bool _normalizeBool(Object? rawValue, {bool fallback = false}) {
    return switch (rawValue) {
      bool value => value,
      String value => value == 'true',
      num value => value != 0,
      _ => fallback,
    };
  }

  static WebDavBackupConfig? _normalizeWebDavBackupConfig(Object? rawValue) {
    if (rawValue is! Map) {
      return null;
    }

    final config = WebDavBackupConfig.fromJson(
      Map<String, dynamic>.from(rawValue),
    );
    return config.isConfigured ? config : null;
  }

  static int _fallbackWidthForPreset(SizePreset preset) {
    return switch (preset) {
      SizePreset.auto => 0,
      SizePreset.custom => 1024,
      _ => preset.width,
    };
  }

  static int _fallbackHeightForPreset(SizePreset preset) {
    return switch (preset) {
      SizePreset.auto => 0,
      SizePreset.custom => 1024,
      _ => preset.height,
    };
  }
}
