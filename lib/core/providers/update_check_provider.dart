import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/update_check_service.dart';
import '../version/app_version.dart';

enum UpdateCheckStatus { idle, checking, upToDate, updateAvailable, failed }

class UpdateCheckState {
  const UpdateCheckState({
    required this.status,
    required this.currentVersion,
    this.latestVersion,
    this.releaseUrl = AppVersion.latestReleaseUrl,
  });

  const UpdateCheckState.initial()
    : status = UpdateCheckStatus.idle,
      currentVersion = AppVersion.current,
      latestVersion = null,
      releaseUrl = AppVersion.latestReleaseUrl;

  final UpdateCheckStatus status;
  final String currentVersion;
  final String? latestVersion;
  final String releaseUrl;

  bool get hasUpdate => status == UpdateCheckStatus.updateAvailable;
}

final updateCheckServiceProvider = Provider<UpdateCheckService>(
  (ref) => UpdateCheckService(),
);

final updateCheckProvider =
    StateNotifierProvider<UpdateCheckController, UpdateCheckState>((ref) {
      return UpdateCheckController(ref.watch(updateCheckServiceProvider));
    });

class UpdateCheckController extends StateNotifier<UpdateCheckState> {
  UpdateCheckController(this._service)
    : super(const UpdateCheckState.initial()) {
    unawaited(check());
  }

  final UpdateCheckService _service;

  Future<void> check() async {
    if (state.status == UpdateCheckStatus.checking) {
      return;
    }

    state = const UpdateCheckState(
      status: UpdateCheckStatus.checking,
      currentVersion: AppVersion.current,
    );

    try {
      final info = await _service.checkLatestRelease();
      state = UpdateCheckState(
        status: info.hasUpdate
            ? UpdateCheckStatus.updateAvailable
            : UpdateCheckStatus.upToDate,
        currentVersion: info.currentVersion,
        latestVersion: info.latestVersion,
        releaseUrl: info.releaseUrl,
      );
    } catch (_) {
      state = const UpdateCheckState(
        status: UpdateCheckStatus.failed,
        currentVersion: AppVersion.current,
      );
    }
  }
}
