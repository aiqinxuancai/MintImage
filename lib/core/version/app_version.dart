class AppVersion {
  const AppVersion._();

  static const current = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'v1.0.0',
  );

  static const repository = 'aiqinxuancai/MintImage';
  static const repositoryUrl = 'https://github.com/$repository';
  static const latestReleaseUrl = '$repositoryUrl/releases/latest';
}
