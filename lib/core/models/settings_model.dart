import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ApiProfile {
  const ApiProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  factory ApiProfile.initial() {
    return ApiProfile(
      id: _uuid.v4(),
      name: '默认',
      baseUrl: const String.fromEnvironment(
        'BASE_URL',
        defaultValue: 'https://api.openai.com',
      ),
      apiKey: const String.fromEnvironment('API_KEY'),
      model: const String.fromEnvironment('MODEL', defaultValue: 'gpt-image-2'),
    );
  }

  factory ApiProfile.fromJson(Map<String, dynamic> json) {
    return ApiProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '默认',
      baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? 'gpt-image-2',
    );
  }

  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;

  String get normalizedBaseUrl => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  String get generationEndpoint => '$normalizedBaseUrl/v1/images/generations';

  String get editEndpoint => '$normalizedBaseUrl/v1/images/edits';

  ApiProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return ApiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
    };
  }
}

class SettingsModel {
  static const int defaultRequestTimeoutSeconds = 600;

  const SettingsModel({
    required this.profiles,
    required this.activeProfileId,
    this.responseFormat,
    this.requestTimeoutSeconds = defaultRequestTimeoutSeconds,
  });

  factory SettingsModel.initial() {
    final defaultProfile = ApiProfile.initial();
    return SettingsModel(
      profiles: [defaultProfile],
      activeProfileId: defaultProfile.id,
      responseFormat: null,
      requestTimeoutSeconds: defaultRequestTimeoutSeconds,
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

    return SettingsModel(
      profiles: profiles,
      activeProfileId: resolvedActiveProfileId,
      responseFormat: _normalizeResponseFormat(json['responseFormat']),
      requestTimeoutSeconds: _normalizeRequestTimeoutSeconds(
        json['requestTimeoutSeconds'],
      ),
    );
  }

  final List<ApiProfile> profiles;
  final String activeProfileId;
  final String? responseFormat;
  final int requestTimeoutSeconds;

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

  SettingsModel copyWith({
    List<ApiProfile>? profiles,
    String? activeProfileId,
    String? responseFormat,
    bool clearResponseFormat = false,
    int? requestTimeoutSeconds,
  }) {
    return SettingsModel(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      responseFormat: clearResponseFormat
          ? null
          : responseFormat ?? this.responseFormat,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'activeProfileId': activeProfileId,
      'responseFormat': responseFormat,
      'requestTimeoutSeconds': requestTimeoutSeconds,
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
}
