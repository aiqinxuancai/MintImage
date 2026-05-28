import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/image_record.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'mint_image_generation';
  static const String _channelName = 'MintImage 生成结果';
  static const String _channelDescription = '生成任务完成后的本地通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsRequested = false;

  Future<void> initialize({bool requestPermissions = false}) async {
    if (_initialized) {
      if (requestPermissions) {
        await _requestPermissions();
      }
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      _initialized = true;
      return;
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_bg_service_small'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      }
    } catch (_) {
      return;
    }

    _initialized = true;

    if (requestPermissions) {
      await _requestPermissions();
    }
  }

  Future<void> showResult(ImageRecord record) async {
    if (record.status == ImageRecordStatus.cancelled) {
      return;
    }

    if (!_initialized) {
      await initialize(requestPermissions: true);
    } else {
      await _requestPermissions();
    }

    if (!_initialized) {
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return;
    }

    try {
      final details = NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_bg_service_small',
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      );

      final title = record.status == ImageRecordStatus.done ? '生成完成' : '生成失败';
      final body = record.status == ImageRecordStatus.done
          ? '${_shorten(record.prompt)} · ${record.sizeLabel}'
          : _shorten(record.errorMessage ?? '请求失败，请稍后重试。');

      await _plugin.show(
        id: _notificationId(record.id),
        title: title,
        body: record.usedSingleImageFallback ? '$body · 已自动退化为单图' : body,
        notificationDetails: details,
        payload: record.id,
      );
    } catch (_) {}
  }

  int _notificationId(String recordId) {
    return recordId.hashCode & 0x7fffffff;
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) {
      return;
    }

    try {
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (Platform.isMacOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      _permissionsRequested = true;
    } catch (_) {}
  }

  String _shorten(String text, {int maxLength = 72}) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 3)}...';
  }
}

final notificationService = NotificationService.instance;
