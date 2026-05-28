import 'package:dio/dio.dart';

import '../version/app_version.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.hasUpdate,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final bool hasUpdate;
}

class UpdateCheckService {
  UpdateCheckService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'MintImage update checker',
              },
            ),
          );

  final Dio _dio;

  Future<UpdateInfo> checkLatestRelease() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/${AppVersion.repository}/releases/latest',
    );
    final data = response.data ?? const <String, dynamic>{};
    final latestVersion = switch (data['tag_name']) {
      String value when value.trim().isNotEmpty => value.trim(),
      _ => AppVersion.current,
    };
    final releaseUrl = switch (data['html_url']) {
      String value when value.trim().isNotEmpty => value.trim(),
      _ => AppVersion.latestReleaseUrl,
    };

    return UpdateInfo(
      currentVersion: AppVersion.current,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      hasUpdate: _compareVersions(latestVersion, AppVersion.current) > 0,
    );
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var i = 0; i < length; i += 1) {
      final leftPart = i < leftParts.length ? leftParts[i] : 0;
      final rightPart = i < rightParts.length ? rightParts[i] : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }

    return 0;
  }

  List<int> _versionParts(String version) {
    final normalized = version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    final matches = RegExp(r'\d+').allMatches(normalized);
    return [
      for (final match in matches) int.tryParse(match.group(0) ?? '0') ?? 0,
    ];
  }
}
