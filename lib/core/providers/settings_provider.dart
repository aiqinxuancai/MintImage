import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/generation_request.dart';
import '../models/settings_model.dart';
import 'app_providers.dart';

const _settingsStorageKey = 'settings_model_v1';
const _uuid = Uuid();

final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsModel>((ref) {
      return SettingsController(
        ref.watch(sharedPreferencesProvider),
        ref.watch(initialSettingsModelProvider),
      );
    });

class SettingsController extends StateNotifier<SettingsModel> {
  SettingsController(this._sharedPreferences, SettingsModel initialState)
    : super(initialState);

  final SharedPreferences _sharedPreferences;

  static SettingsModel loadFromPreferences(
    SharedPreferences sharedPreferences,
  ) {
    final raw = sharedPreferences.getString(_settingsStorageKey);
    if (raw == null || raw.isEmpty) {
      return SettingsModel.initial();
    }

    try {
      return SettingsModel.decode(raw);
    } catch (_) {
      return SettingsModel.initial();
    }
  }

  Future<ApiProfile> addProfile({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    ImageGenerationApiMode apiMode = ImageGenerationApiMode.images,
  }) async {
    final nextIndex = state.profiles.length + 1;
    final profile = ApiProfile(
      id: _uuid.v4(),
      name: name ?? '配置 $nextIndex',
      baseUrl: baseUrl ?? 'https://api.openai.com',
      apiKey: apiKey ?? '',
      model: model ?? apiMode.defaultModel,
      apiMode: apiMode,
    );
    state = state.copyWith(
      profiles: [...state.profiles, profile],
      activeProfileId: state.activeProfileId,
    );
    await _persist();
    return profile;
  }

  Future<void> updateProfile(ApiProfile profile) async {
    final profiles = [
      for (final item in state.profiles)
        if (item.id == profile.id) profile else item,
    ];
    state = state.copyWith(profiles: profiles);
    await _persist();
  }

  Future<void> deleteProfile(String id) async {
    if (state.profiles.length <= 1) {
      return;
    }

    final profiles = state.profiles
        .where((profile) => profile.id != id)
        .toList();
    final activeProfileId = state.activeProfileId == id
        ? profiles.first.id
        : state.activeProfileId;

    state = state.copyWith(
      profiles: profiles,
      activeProfileId: activeProfileId,
    );
    await _persist();
  }

  Future<void> setActiveProfile(String id) async {
    if (!state.profiles.any((profile) => profile.id == id)) {
      return;
    }
    state = state.copyWith(activeProfileId: id);
    await _persist();
  }

  Future<PromptOptimizationProfile> addPromptOptimizationProfile({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    PromptOptimizationProtocol protocol =
        PromptOptimizationProtocol.openAiResponses,
  }) async {
    final nextIndex = state.promptOptimizationProfiles.length + 1;
    final profile = PromptOptimizationProfile(
      id: _uuid.v4(),
      name: name ?? '优化配置 $nextIndex',
      baseUrl: baseUrl ?? protocol.defaultBaseUrl,
      apiKey: apiKey ?? '',
      model: model ?? protocol.defaultModel,
      protocol: protocol,
    );
    state = state.copyWith(
      promptOptimizationProfiles: [
        ...state.promptOptimizationProfiles,
        profile,
      ],
      activePromptOptimizationProfileId:
          state.activePromptOptimizationProfileId ?? profile.id,
    );
    await _persist();
    return profile;
  }

  Future<void> updatePromptOptimizationProfile(
    PromptOptimizationProfile profile,
  ) async {
    final profiles = [
      for (final item in state.promptOptimizationProfiles)
        if (item.id == profile.id) profile else item,
    ];
    state = state.copyWith(promptOptimizationProfiles: profiles);
    await _persist();
  }

  Future<void> deletePromptOptimizationProfile(String id) async {
    final profiles = state.promptOptimizationProfiles
        .where((profile) => profile.id != id)
        .toList();
    final activeProfileId = state.activePromptOptimizationProfileId == id
        ? profiles.isEmpty
              ? null
              : profiles.first.id
        : state.activePromptOptimizationProfileId;

    state = state.copyWith(
      promptOptimizationProfiles: profiles,
      activePromptOptimizationProfileId: activeProfileId,
      clearActivePromptOptimizationProfileId: activeProfileId == null,
    );
    await _persist();
  }

  Future<void> setActivePromptOptimizationProfile(String id) async {
    if (!state.promptOptimizationProfiles.any((profile) => profile.id == id)) {
      return;
    }
    state = state.copyWith(activePromptOptimizationProfileId: id);
    await _persist();
  }

  Future<void> setRequestTimeoutSeconds(int seconds) async {
    if (seconds <= 0) {
      return;
    }

    state = state.copyWith(requestTimeoutSeconds: seconds);
    await _persist();
  }

  Future<void> updateLastGenerationOptions({
    required SizePreset sizePreset,
    required int customWidth,
    required int customHeight,
    required ImageQuality quality,
    required ImageOutputFormat outputFormat,
  }) async {
    state = state.copyWith(
      lastSizePreset: sizePreset,
      lastCustomWidth: customWidth,
      lastCustomHeight: customHeight,
      lastQuality: quality,
      lastOutputFormat: outputFormat,
    );
    await _persist();
  }

  Future<void> _persist() async {
    await _sharedPreferences.setString(_settingsStorageKey, state.encode());
  }
}
