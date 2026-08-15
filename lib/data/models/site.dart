enum LlmProvider { openai, claude }

class LlmConfig {
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool enabled;
  final LlmProvider provider;
  final bool intentAnalysis;

  const LlmConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.enabled = false,
    this.provider = LlmProvider.openai,
    this.intentAnalysis = false,
  });

  factory LlmConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LlmConfig(
        apiKey: '',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
      );
    }
    return LlmConfig(
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
      model: json['model'] as String? ?? 'gpt-4o-mini',
      enabled: json['enabled'] as bool? ?? false,
      provider: json['provider'] == 'claude'
          ? LlmProvider.claude
          : LlmProvider.openai,
      intentAnalysis: json['intentAnalysis'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
      'enabled': enabled,
      'provider': provider == LlmProvider.claude ? 'claude' : 'openai',
      'intentAnalysis': intentAnalysis,
    };
  }

  LlmConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? enabled,
    LlmProvider? provider,
    bool? intentAnalysis,
  }) {
    return LlmConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      intentAnalysis: intentAnalysis ?? this.intentAnalysis,
    );
  }
}

class WhatsappConfig {
  final bool enabled;
  final String phoneNumberId;
  final String? businessAccountId;
  final String? displayPhoneNumber;
  final String accessToken;
  final String appSecret;
  final String verifyToken;
  final String apiVersion;

  const WhatsappConfig({
    this.enabled = false,
    this.phoneNumberId = '',
    this.businessAccountId,
    this.displayPhoneNumber,
    this.accessToken = '',
    this.appSecret = '',
    this.verifyToken = '',
    this.apiVersion = 'v26.0',
  });

  factory WhatsappConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WhatsappConfig();
    return WhatsappConfig(
      enabled: json['enabled'] as bool? ?? false,
      phoneNumberId: json['phoneNumberId'] as String? ?? '',
      businessAccountId: json['businessAccountId'] as String?,
      displayPhoneNumber: json['displayPhoneNumber'] as String?,
      accessToken: json['accessToken'] as String? ?? '',
      appSecret: json['appSecret'] as String? ?? '',
      verifyToken: json['verifyToken'] as String? ?? '',
      apiVersion: json['apiVersion'] as String? ?? 'v26.0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'phoneNumberId': phoneNumberId,
      'businessAccountId': businessAccountId,
      'displayPhoneNumber': displayPhoneNumber,
      'accessToken': accessToken,
      'appSecret': appSecret,
      'verifyToken': verifyToken,
      'apiVersion': apiVersion,
    };
  }
}

class Site {
  final String id;
  final String name;
  final String companyName;
  final String domain;
  final String widgetToken;
  final List<String> defaultVisitorAvatars;
  final LlmConfig? llmConfig;
  final WhatsappConfig? whatsappConfig;
  final bool enabled;
  final DateTime? createdAt;

  const Site({
    required this.id,
    required this.name,
    this.companyName = '',
    this.domain = '',
    this.widgetToken = '',
    this.defaultVisitorAvatars = const [],
    this.llmConfig,
    this.whatsappConfig,
    this.enabled = true,
    this.createdAt,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      widgetToken: json['widgetToken'] as String? ?? '',
      defaultVisitorAvatars:
          (json['defaultVisitorAvatars'] as List<dynamic>?)?.cast<String>() ??
          [],
      llmConfig: json['llmConfig'] != null
          ? LlmConfig.fromJson(json['llmConfig'] as Map<String, dynamic>)
          : null,
      whatsappConfig: json['whatsappConfig'] != null
          ? WhatsappConfig.fromJson(
              json['whatsappConfig'] as Map<String, dynamic>,
            )
          : null,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}
