import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/notifications/foreground_service.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  // 初始化移动端系统通知（不阻塞启动）。
  NotificationService.instance.init();
  // 初始化前台服务保活配置（登录后才真正启动服务）。
  ForegroundService.instance.init();
  runApp(
    const ProviderScope(
      child: ConsultingOnlineApp(),
    ),
  );
}
