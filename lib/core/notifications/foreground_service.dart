import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 前台服务保活（仅 Android 有效）。
///
/// 没有系统推送的情况下，安卓靠前台服务把进程提升为「前台优先级」，
/// 让 WebSocket 在 app 切到后台后仍然保持连接，从而能即时弹出新消息通知。
/// 常驻一条「在线接单」通知，坐席随时知道自己在接单中。
///
/// iOS 无前台服务，切后台即挂起，此服务在 iOS 上为空操作。
class ForegroundService {
  ForegroundService._();

  static final ForegroundService instance = ForegroundService._();

  bool _initialized = false;

  /// 初始化前台服务配置。幂等，多次调用只生效一次。
  void init() {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: '在线接单',
        channelDescription: '保持后台在线，及时接收访客新消息',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 无需后台定时任务，仅用于保活。
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// 启动前台服务（登录后调用）。已在运行则跳过。
  Future<void> start() async {
    if (kIsWeb) return;
    init();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      notificationTitle: '在线客服',
      notificationText: '正在接单中，保持后台在线',
    );
  }

  /// 停止前台服务（退出登录时调用）。
  Future<void> stop() async {
    if (kIsWeb) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
