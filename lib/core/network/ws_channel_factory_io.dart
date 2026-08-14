import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 原生平台（Android/iOS/桌面）的 WebSocket 实现。
WebSocketChannel createWsChannel(Uri uri, {Map<String, dynamic>? headers}) =>
    IOWebSocketChannel.connect(uri, headers: headers);
