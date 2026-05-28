import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/providers/app_providers.dart';
import 'core/services/background_generation_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/request_log_service.dart';
import 'features/logs/log_viewer_app.dart';

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.contains('--log-window')) {
    final requestLogService = await RequestLogService.load();
    runApp(
      ProviderScope(
        overrides: [
          requestLogServiceProvider.overrideWithValue(requestLogService),
        ],
        child: const LogViewerApp(),
      ),
    );
    return;
  }

  runApp(const _AppStartupShell());
}

class _AppStartupShell extends StatefulWidget {
  const _AppStartupShell();

  @override
  State<_AppStartupShell> createState() => _AppStartupShellState();
}

class _AppStartupShellState extends State<_AppStartupShell> {
  late final Future<_AppStartupData> _startupFuture = _load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppStartupData>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _MainApp(data: snapshot.requireData);
        }

        if (snapshot.hasError) {
          return _StartupError(error: snapshot.error);
        }

        return const _StartupSplash();
      },
    );
  }

  Future<_AppStartupData> _load() async {
    final bootstrapFuture = AppBootstrap.load();
    final requestLogFuture = RequestLogService.load(reset: true);

    final bootstrap = await bootstrapFuture;
    final requestLogService = await requestLogFuture;

    unawaited(notificationService.initialize());
    unawaited(backgroundGenerationService.initialize());

    return _AppStartupData(
      bootstrap: bootstrap,
      requestLogService: requestLogService,
    );
  }
}

class _MainApp extends StatelessWidget {
  const _MainApp({required this.data});

  final _AppStartupData data;

  @override
  Widget build(BuildContext context) {
    final bootstrap = data.bootstrap;
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          bootstrap.sharedPreferences,
        ),
        appDatabaseProvider.overrideWithValue(bootstrap.database),
        imageRecordDaoProvider.overrideWithValue(bootstrap.imageRecordDao),
        initialSettingsModelProvider.overrideWithValue(
          bootstrap.initialSettings,
        ),
        initialImageRecordsProvider.overrideWithValue(bootstrap.initialRecords),
        requestLogServiceProvider.overrideWithValue(data.requestLogService),
      ],
      child: const GptImageApp(),
    );
  }
}

class _AppStartupData {
  const _AppStartupData({
    required this.bootstrap,
    required this.requestLogService,
  });

  final AppBootstrap bootstrap;
  final RequestLogService requestLogService;
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF8FAFF),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFF8FAFF),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'MintImage 启动失败\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0B1C30),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
