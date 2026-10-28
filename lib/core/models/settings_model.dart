import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'generation_request.dart';

const _uuid = Uuid();

enum ImageGenerationApiMode {
  images('images', 'Images API (/v1/images)', 'Images API', 'gpt-image-2'),
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
      ImageGenerationApiMode.images => '/v1/images/generations',
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

class ApiProfile {
  const ApiProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.apiMode = ImageGenerationApiMode.images,
    this.useStreaming = false,
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
    final apiMode = ImageGenerationApiMode.fromStorageValue(json['apiMode']);
    return ApiProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '默认',
      baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? apiMode.defaultModel,
      apiMode: apiMode,
      useStreaming: json['useStreaming'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final ImageGenerationApiMode apiMode;
  final bool useStreaming;

  bool get usesRightApiImages {
    final host = Uri.tryParse(baseUrl.trim())?.host.toLowerCase();
    return apiMode == ImageGenerationApiMode.images &&
        (host == 'rightapi.ai' || host == 'www.rightapi.ai');
  }

  String get normalizedBaseUrl {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (usesRightApiImages) {
      final uri = Uri.parse(normalized);
      if (const [
        '',
        '/v1',
        '/draw',
        '/draw/v1',
      ].contains(uri.path.toLowerCase())) {
        // Current image endpoints live at the site root, including task lookup.
        return uri
            .replace(host: 'rightapi.ai', path: '')
            .toString()
            .replaceAll(RegExp(r'/+$'), '');
      }
    }
    return normalized;
  }

  String get generationEndpoint =>
      '$normalizedBaseUrl${apiMode.generationPath}';

  String get editEndpoint {
    return switch (apiMode) {
      ImageGenerationApiMode.images => '$normalizedBaseUrl/v1/images/edits',
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
  }) {
    return ApiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      apiMode: apiMode ?? this.apiMode,
      useStreaming: useStreaming ?? this.useStreaming,
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
      'useStreaming': useStreaming,
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
      lastOutputFormat: _normalizeImageOutputFormat(json['lastOutputFormat']),
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
      lastOutputFormat: lastOutputFormat ?? this.lastOutputFormat,
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
