import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Web 平台的 WebSocket 实现。
WebSocketChannel createWsChannel(Uri uri, {Map<String, dynamic>? headers}) =>
    HtmlWebSocketChannel.connect(uri.toString());
