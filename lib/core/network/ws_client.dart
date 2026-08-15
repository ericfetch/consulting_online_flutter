import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'ws_channel_factory_io.dart'
    if (dart.library.js_interop) 'ws_channel_factory_web.dart';
import '../constants/app_constants.dart';

enum WsConnectionStatus { disconnected, connecting, connected, reconnecting }

class RealtimeEvent {
  final String type;
  final Map<String, dynamic>? payload;
  final String? requestId;

  RealtimeEvent({required this.type, this.payload, this.requestId});

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      type: json['type'] as String? ?? 'unknown',
      payload: json['payload'] as Map<String, dynamic>?,
      requestId: json['requestId'] as String?,
    );
  }
}

String generateRequestId() {
  final random = Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomPart = random.nextInt(1000000).toString().padLeft(6, '0');
  return '$timestamp-$randomPart';
}

class WsClient {
  WebSocketChannel? _channel;
  WsConnectionStatus _status = WsConnectionStatus.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _sessionCookie;

  /// 标记「主动断开」（退出登录 / 鉴权失败）：
  /// 此时 `_onDone`/`_onError` 不再自动重连，避免用失效 cookie 反复重连造成死循环。
  bool _manuallyClosed = false;

  final _eventController = StreamController<RealtimeEvent>.broadcast();
  final _statusController = StreamController<WsConnectionStatus>.broadcast();

  Stream<RealtimeEvent> get events => _eventController.stream;
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;
  WsConnectionStatus get status => _status;

  void connect({String? cookie}) {
    if (_status == WsConnectionStatus.connected ||
        _status == WsConnectionStatus.connecting) {
      return;
    }

    _manuallyClosed = false;
    if (cookie != null) {
      _sessionCookie = cookie;
    }
    _updateStatus(WsConnectionStatus.connecting);

    try {
      final uri = Uri.parse('${AppConstants.wsUrl}/ws');

      Map<String, dynamic>? headers;
      if (_sessionCookie != null) {
        headers = {'Cookie': _sessionCookie};
      }
      _channel = createWsChannel(uri, headers: headers);

      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);
      _onOpen();
    } catch (e) {
      _onError(e);
    }
  }

  void _onOpen() {
    _updateStatus(WsConnectionStatus.connected);
    _reconnectAttempts = 0;
    _startHeartbeat();
    send('agent:init', {});
  }

  void _onMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final event = RealtimeEvent.fromJson(json);

      if (event.type == 'message:new') {
        debugPrint('[ws] recv message:new at ${DateTime.now().toIso8601String()}');
      }

      if (event.type == 'auth:failed') {
        // 鉴权失败：停止重连并取消定时器，避免失效 cookie 反复重连。
        _manuallyClosed = true;
        _reconnectTimer?.cancel();
        _heartbeatTimer?.cancel();
        _updateStatus(WsConnectionStatus.disconnected);
      }

      _eventController.add(event);
    } catch (e) {
      debugPrint('Failed to parse WebSocket message: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[ws] error at ${DateTime.now().toIso8601String()}: $error');
    _updateStatus(WsConnectionStatus.disconnected);
    if (!_manuallyClosed) {
      _scheduleReconnect();
    }
  }

  void _onDone() {
    debugPrint('[ws] done at ${DateTime.now().toIso8601String()}');
    _heartbeatTimer?.cancel();
    _updateStatus(WsConnectionStatus.disconnected);
    if (!_manuallyClosed) {
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.heartbeatInterval),
      (_) {
        if (_status == WsConnectionStatus.connected) {
          debugPrint('[ws] heartbeat at ${DateTime.now().toIso8601String()}');
          send('agent:heartbeat', {});
        }
      },
    );
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    _updateStatus(WsConnectionStatus.reconnecting);
    _reconnectAttempts++;

    final delay = AppConstants.wsReconnectDelay;
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      connect();
    });
  }

  void _updateStatus(WsConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  void setCookie(String? cookie) {
    _sessionCookie = cookie;
  }

  bool send(String type, Map<String, dynamic> payload, {String? requestId}) {
    if (_channel == null || _status != WsConnectionStatus.connected) {
      connect();
      return false;
    }

    final message = jsonEncode({
      'type': type,
      'payload': payload,
      if (requestId != null) 'requestId': requestId,
    });
    _channel?.sink.add(message);
    return true;
  }

  bool sendMessage(
    String conversationId,
    String body, {
    Map<String, dynamic>? metadata,
    String? requestId,
  }) {
    return send(
        'message:send',
        {
          'conversationId': conversationId,
          'body': body,
          if (metadata != null) 'metadata': metadata,
        },
        requestId: requestId);
  }

  bool updateConversation(String conversationId, Map<String, dynamic> updates) {
    return send('conversation:update', {'conversationId': conversationId, ...updates});
  }

  void disconnect() {
    _manuallyClosed = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateStatus(WsConnectionStatus.disconnected);
    _reconnectAttempts = 0;
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _statusController.close();
  }
}

final wsClientProvider = Provider<WsClient>((ref) {
  final client = WsClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final wsConnectionStatusProvider = StreamProvider<WsConnectionStatus>((ref) {
  final client = ref.watch(wsClientProvider);
  return client.statusStream;
});
