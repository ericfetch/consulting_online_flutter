class AppConstants {
  AppConstants._();

  static const String appName = '在线客服';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://consulting.sanain.com',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://consulting.sanain.com',
  );

  static const int connectTimeout = 15000;
  static const int receiveTimeout = 30000;
  static const int wsReconnectDelay = 2000;
  static const int heartbeatInterval = 20000;
  static const int presenceClockInterval = 10000;
  static const int messageTimeout = 45000;
  static const int presenceStaleMs = 180000;

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String cookieKey = 'session_cookie';
  static const String quickRepliesKey = 'quick_replies';

  static const int pageSize = 50;
  static const int maxMessageLength = 2000;
  static const int typingTimeout = 3000;
}
