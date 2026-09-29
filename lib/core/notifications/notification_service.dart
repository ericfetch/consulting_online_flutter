import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// 移动端系统级通知服务（新消息提醒）。
///
/// 通过单例在 app 启动时初始化，访客发来新消息时弹出系统通知。
/// 仅在移动端生效，web 上直接跳过。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 新消息提示音播放器，独立于系统通知渠道，MIUI 等机型静音通知渠道也能响。
  final AudioPlayer _soundPlayer = AudioPlayer();

  /// 提示音使用「通知」音量流，跟随通知音量而非媒体音量。
  static final AudioContext _alertContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  Future<void>? _initFuture;
  int _nextId = 0;

  /// 初始化插件并申请通知权限。幂等，多次调用共享同一次初始化。
  Future<void> init() {
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    if (kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _plugin.initialize(settings: initSettings);
    await requestPermissions();
  }

  /// Android 13+ 与 iOS 的通知运行时权限申请。
  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 弹出一条系统级新消息通知。
  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    await _playAlertSound();

    const androidDetails = AndroidNotificationDetails(
      'new_messages_v2',
      '新消息',
      channelDescription: '访客发来的新消息',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      ticker: '新消息',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// 新消息提示音 + 震动。独立于系统通知渠道，保证在 MIUI 等机型上也能提醒。
  Future<void> _playAlertSound() async {
    try {
      await _soundPlayer.stop();
      await _soundPlayer.play(
        AssetSource('sounds/notification.wav'),
        ctx: _alertContext,
      );
    } catch (_) {
      // 声音播放失败不影响通知展示。
    }
    try {
      await Vibration.vibrate(duration: 300, amplitude: 255);
    } catch (_) {
      // 震动失败不影响通知展示。
    }
  }
}
