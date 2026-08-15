enum MessageSenderType { visitor, agent, system }

enum DeliveryStatus { pending, accepted, sent, delivered, read, failed }

class MessageAttachment {
  final String type;
  final String url;
  final String? mimeType;

  const MessageAttachment(
      {required this.type, required this.url, this.mimeType});

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      type: json['type'] as String? ?? 'image',
      url: json['url'] as String? ?? '',
      mimeType: json['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }
}

class MessageTranslation {
  final String detectedLanguage;
  final String text;

  const MessageTranslation(
      {required this.detectedLanguage, required this.text});

  factory MessageTranslation.fromJson(Map<String, dynamic> json) {
    return MessageTranslation(
      detectedLanguage: json['detectedLanguage'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

class MessageIntent {
  final String label;
  final double confidence;

  const MessageIntent({required this.label, required this.confidence});

  factory MessageIntent.fromJson(Map<String, dynamic> json) {
    return MessageIntent(
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AgentTranslation {
  final String targetLanguage;
  final String translatedText;

  const AgentTranslation(
      {required this.targetLanguage, required this.translatedText});

  factory AgentTranslation.fromJson(Map<String, dynamic> json) {
    return AgentTranslation(
      targetLanguage: json['targetLanguage'] as String? ?? '',
      translatedText: json['translatedText'] as String? ?? '',
    );
  }
}

class MessageWhatsapp {
  final String? error;

  const MessageWhatsapp({this.error});

  factory MessageWhatsapp.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MessageWhatsapp();
    return MessageWhatsapp(
      error: json['error'] as String?,
    );
  }
}

class MessageWhatsappMedia {
  final String? id;
  final String? type;
  final bool pending;
  final String? mimeType;
  final String? sha256;
  final bool animated;
  final String? error;

  const MessageWhatsappMedia({
    this.id,
    this.type,
    this.pending = false,
    this.mimeType,
    this.sha256,
    this.animated = false,
    this.error,
  });

  factory MessageWhatsappMedia.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MessageWhatsappMedia();
    return MessageWhatsappMedia(
      id: json['id'] as String?,
      type: json['type'] as String?,
      pending: json['pending'] as bool? ?? false,
      mimeType: json['mimeType'] as String?,
      sha256: json['sha256'] as String?,
      animated: json['animated'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

class MessageMetadata {
  final String? kind;
  final List<MessageAttachment> attachments;
  final Map<String, dynamic>? formData;
  final DateTime? submittedAt;
  final MessageTranslation? translation;
  final MessageIntent? intent;
  final AgentTranslation? agentTranslation;
  final String? originalText;
  final MessageWhatsapp? whatsapp;
  final MessageWhatsappMedia? whatsappMedia;

  const MessageMetadata({
    this.kind,
    this.attachments = const [],
    this.formData,
    this.submittedAt,
    this.translation,
    this.intent,
    this.agentTranslation,
    this.originalText,
    this.whatsapp,
    this.whatsappMedia,
  });

  factory MessageMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MessageMetadata();
    return MessageMetadata(
      kind: json['kind'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map(
                  (e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      formData: json['formData'] as Map<String, dynamic>?,
      submittedAt: _parseDateTime(json['submittedAt']),
      translation: json['translation'] != null
          ? MessageTranslation.fromJson(
              json['translation'] as Map<String, dynamic>)
          : null,
      intent: json['intent'] != null
          ? MessageIntent.fromJson(json['intent'] as Map<String, dynamic>)
          : null,
      agentTranslation: json['agentTranslation'] != null
          ? AgentTranslation.fromJson(
              json['agentTranslation'] as Map<String, dynamic>)
          : null,
      originalText: json['originalText'] as String?,
      whatsapp: json['whatsapp'] != null
          ? MessageWhatsapp.fromJson(json['whatsapp'] as Map<String, dynamic>)
          : null,
      whatsappMedia: json['whatsappMedia'] != null
          ? MessageWhatsappMedia.fromJson(
              json['whatsappMedia'] as Map<String, dynamic>)
          : null,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final MessageSenderType senderType;
  final String? senderUserId;
  final String? senderUserName;
  final String senderAvatarUrl;
  final String body;
  final String? externalId;
  final DeliveryStatus? deliveryStatus;
  final DateTime? deliveryUpdatedAt;
  final String? clientRequestId;
  final String? clientError;
  final MessageMetadata? metadata;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    this.senderUserId,
    this.senderUserName,
    this.senderAvatarUrl = '',
    required this.body,
    this.externalId,
    this.deliveryStatus,
    this.deliveryUpdatedAt,
    this.clientRequestId,
    this.clientError,
    this.metadata,
    required this.createdAt,
  });

  bool get isMe => senderType == MessageSenderType.agent;
  bool get isSystem => senderType == MessageSenderType.system;
  bool get isFromVisitor => senderType == MessageSenderType.visitor;
  bool get isFromAgent => senderType == MessageSenderType.agent;
  bool get isImage =>
      metadata?.attachments.any((a) => a.type == 'image') ?? false;
  bool get isVideo =>
      metadata?.attachments.any((a) => a.type == 'video') ?? false;
  bool get isSticker =>
      metadata?.attachments.any((a) => a.type == 'sticker') ?? false;
  bool get isPending => deliveryStatus == DeliveryStatus.pending;
  bool get isFailed => deliveryStatus == DeliveryStatus.failed;
  List<String> get imageUrls =>
      metadata?.attachments
          .where((a) => a.type == 'image')
          .map((a) => a.url)
          .toList() ??
      const [];
  String get senderName =>
      senderUserName ?? (isMe ? '我' : (isSystem ? '系统' : '访客'));
  String? get translatedContent =>
      metadata?.agentTranslation?.translatedText ?? metadata?.translation?.text;
  String get displayContent {
    if (isImage && imageUrls.isNotEmpty) return '[图片]';
    if (isVideo) return '[视频]';
    if (isSticker) return '[贴纸]';
    return body;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderType: _parseSenderType(json['senderType']),
      senderUserId: json['senderUserId'] as String?,
      senderUserName: json['senderUserName'] as String?,
      senderAvatarUrl: json['senderAvatarUrl'] as String? ?? '',
      body: json['body'] as String? ?? '',
      externalId: json['externalId'] as String?,
      deliveryStatus: _parseDeliveryStatus(json['deliveryStatus']),
      deliveryUpdatedAt: _parseDateTime(json['deliveryUpdatedAt']),
      clientRequestId: json['clientRequestId'] as String?,
      clientError: json['clientError'] as String?,
      metadata:
          MessageMetadata.fromJson(json['metadata'] as Map<String, dynamic>?),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderType': _senderTypeToJson(senderType),
      'senderUserId': senderUserId,
      'senderUserName': senderUserName,
      'senderAvatarUrl': senderAvatarUrl,
      'body': body,
      'externalId': externalId,
      'deliveryStatus': deliveryStatus != null
          ? _deliveryStatusToJson(deliveryStatus!)
          : null,
      'deliveryUpdatedAt': deliveryUpdatedAt?.toIso8601String(),
      'clientRequestId': clientRequestId,
      'clientError': clientError,
      'metadata': metadata != null ? _metadataToJson(metadata!) : null,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _metadataToJson(MessageMetadata meta) {
    return {
      if (meta.kind != null) 'kind': meta.kind,
      if (meta.attachments.isNotEmpty)
        'attachments': meta.attachments.map((a) => a.toJson()).toList(),
      if (meta.formData != null) 'formData': meta.formData,
      if (meta.submittedAt != null)
        'submittedAt': meta.submittedAt!.toIso8601String(),
      if (meta.translation != null)
        'translation': {
          'detectedLanguage': meta.translation!.detectedLanguage,
          'text': meta.translation!.text
        },
      if (meta.intent != null)
        'intent': {
          'label': meta.intent!.label,
          'confidence': meta.intent!.confidence
        },
      if (meta.agentTranslation != null)
        'agentTranslation': {
          'targetLanguage': meta.agentTranslation!.targetLanguage,
          'translatedText': meta.agentTranslation!.translatedText
        },
      if (meta.originalText != null) 'originalText': meta.originalText,
      if (meta.whatsapp != null) 'whatsapp': {'error': meta.whatsapp!.error},
      if (meta.whatsappMedia != null)
        'whatsappMedia': {
          'id': meta.whatsappMedia!.id,
          'type': meta.whatsappMedia!.type,
          'pending': meta.whatsappMedia!.pending,
          'mimeType': meta.whatsappMedia!.mimeType,
          'sha256': meta.whatsappMedia!.sha256,
          'animated': meta.whatsappMedia!.animated,
          'error': meta.whatsappMedia!.error,
        },
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    MessageSenderType? senderType,
    String? senderUserId,
    String? senderUserName,
    String? senderAvatarUrl,
    String? body,
    String? externalId,
    DeliveryStatus? deliveryStatus,
    DateTime? deliveryUpdatedAt,
    String? clientRequestId,
    String? clientError,
    MessageMetadata? metadata,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderType: senderType ?? this.senderType,
      senderUserId: senderUserId ?? this.senderUserId,
      senderUserName: senderUserName ?? this.senderUserName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      body: body ?? this.body,
      externalId: externalId ?? this.externalId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryUpdatedAt: deliveryUpdatedAt ?? this.deliveryUpdatedAt,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      clientError: clientError ?? this.clientError,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static MessageSenderType _parseSenderType(dynamic value) {
    if (value == null) return MessageSenderType.system;
    final str = value.toString().toUpperCase();
    switch (str) {
      case 'VISITOR':
        return MessageSenderType.visitor;
      case 'AGENT':
        return MessageSenderType.agent;
      case 'SYSTEM':
      default:
        return MessageSenderType.system;
    }
  }

  static String _senderTypeToJson(MessageSenderType type) {
    switch (type) {
      case MessageSenderType.visitor:
        return 'VISITOR';
      case MessageSenderType.agent:
        return 'AGENT';
      case MessageSenderType.system:
        return 'SYSTEM';
    }
  }

  static DeliveryStatus? _parseDeliveryStatus(dynamic value) {
    if (value == null) return null;
    final str = value.toString().toUpperCase();
    switch (str) {
      case 'PENDING':
        return DeliveryStatus.pending;
      case 'ACCEPTED':
        return DeliveryStatus.accepted;
      case 'SENT':
        return DeliveryStatus.sent;
      case 'DELIVERED':
        return DeliveryStatus.delivered;
      case 'READ':
        return DeliveryStatus.read;
      case 'FAILED':
        return DeliveryStatus.failed;
      default:
        return null;
    }
  }

  static String _deliveryStatusToJson(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return 'PENDING';
      case DeliveryStatus.accepted:
        return 'ACCEPTED';
      case DeliveryStatus.sent:
        return 'SENT';
      case DeliveryStatus.delivered:
        return 'DELIVERED';
      case DeliveryStatus.read:
        return 'READ';
      case DeliveryStatus.failed:
        return 'FAILED';
    }
  }
}
