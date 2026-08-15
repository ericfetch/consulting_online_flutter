enum VisitorPresence { browsing, active, away, widgetClosed, siteClosed }

enum ConversationChannel { web, whatsapp }

class ReferralContext {
  final String code;
  final String? partnerName;
  final String? company;
  final DateTime? capturedAt;
  final String? landingUrl;

  const ReferralContext({
    required this.code,
    this.partnerName,
    this.company,
    this.capturedAt,
    this.landingUrl,
  });

  factory ReferralContext.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ReferralContext(code: '');
    }
    return ReferralContext(
      code: json['code'] as String? ?? '',
      partnerName: json['partnerName'] as String?,
      company: json['company'] as String?,
      capturedAt: _parseDateTime(json['capturedAt']),
      landingUrl: json['landingUrl'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class Conversation {
  final String id;
  final String status;
  final ConversationChannel channel;
  final DateTime? whatsappWindowExpiresAt;
  final String? assigneeId;
  final String? assigneeName;
  final String? groupId;
  final String siteName;
  final String companyName;
  final bool llmEnabled;
  final String visitorName;
  final String visitorExternalId;
  final String visitorPhone;
  final String visitorIp;
  final String visitorIpLocation;
  final String visitorUserAgent;
  final String visitorAvatarUrl;
  final List<String> defaultVisitorAvatars;
  final String landingUrl;
  final String referrer;
  final String campaign;
  final ReferralContext? referral;
  final Map<String, dynamic>? formData;
  final String visitorLanguage;
  final String visitorLanguageSource;
  final VisitorPresence visitorPresence;
  final DateTime? visitorPresenceAt;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.status,
    this.channel = ConversationChannel.web,
    this.whatsappWindowExpiresAt,
    this.assigneeId,
    this.assigneeName,
    this.groupId,
    this.siteName = '',
    this.companyName = '',
    this.llmEnabled = false,
    this.visitorName = '',
    this.visitorExternalId = '',
    this.visitorPhone = '',
    this.visitorIp = '',
    this.visitorIpLocation = '',
    this.visitorUserAgent = '',
    this.visitorAvatarUrl = '',
    this.defaultVisitorAvatars = const [],
    this.landingUrl = '',
    this.referrer = '',
    this.campaign = '',
    this.referral,
    this.formData,
    this.visitorLanguage = '',
    this.visitorLanguageSource = '',
    this.visitorPresence = VisitorPresence.browsing,
    this.visitorPresenceAt,
    required this.lastMessageAt,
    required this.createdAt,
  });

  bool get isResolved => status == 'RESOLVED';

  String get visitorInitial {
    if (visitorName.isNotEmpty) return visitorName[0].toUpperCase();
    if (visitorPhone.isNotEmpty) return visitorPhone[visitorPhone.length - 1];
    if (visitorIp.isNotEmpty) return visitorIp.split('.').last;
    return '?';
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      channel: _parseChannel(json['channel']),
      whatsappWindowExpiresAt: _parseDateTime(json['whatsappWindowExpiresAt']),
      assigneeId: json['assigneeId'] as String?,
      assigneeName: json['assigneeName'] as String?,
      groupId: json['groupId'] as String?,
      siteName: json['siteName'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      llmEnabled: json['llmEnabled'] as bool? ?? false,
      visitorName: json['visitorName'] as String? ?? '',
      visitorExternalId: json['visitorExternalId'] as String? ?? '',
      visitorPhone: json['visitorPhone'] as String? ?? '',
      visitorIp: json['visitorIp'] as String? ?? '',
      visitorIpLocation: json['visitorIpLocation'] as String? ?? '',
      visitorUserAgent: json['visitorUserAgent'] as String? ?? '',
      visitorAvatarUrl: json['visitorAvatarUrl'] as String? ?? '',
      defaultVisitorAvatars:
          (json['defaultVisitorAvatars'] as List<dynamic>?)?.cast<String>() ??
              const [],
      landingUrl: json['landingUrl'] as String? ?? '',
      referrer: json['referrer'] as String? ?? '',
      campaign: json['campaign'] as String? ?? '',
      referral: json['referral'] != null
          ? ReferralContext.fromJson(json['referral'] as Map<String, dynamic>)
          : null,
      formData: json['formData'] as Map<String, dynamic>?,
      visitorLanguage: json['visitorLanguage'] as String? ?? '',
      visitorLanguageSource: json['visitorLanguageSource'] as String? ?? '',
      visitorPresence: _parsePresence(json['visitorPresence']),
      visitorPresenceAt: _parseDateTime(json['visitorPresenceAt']),
      lastMessageAt: _parseDateTime(json['lastMessageAt']) ?? DateTime.now(),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'channel': channel == ConversationChannel.whatsapp ? 'WHATSAPP' : 'WEB',
      'whatsappWindowExpiresAt': whatsappWindowExpiresAt?.toIso8601String(),
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'groupId': groupId,
      'siteName': siteName,
      'companyName': companyName,
      'llmEnabled': llmEnabled,
      'visitorName': visitorName,
      'visitorExternalId': visitorExternalId,
      'visitorPhone': visitorPhone,
      'visitorIp': visitorIp,
      'visitorIpLocation': visitorIpLocation,
      'visitorUserAgent': visitorUserAgent,
      'visitorAvatarUrl': visitorAvatarUrl,
      'defaultVisitorAvatars': defaultVisitorAvatars,
      'landingUrl': landingUrl,
      'referrer': referrer,
      'campaign': campaign,
      'referral': referral != null
          ? {
              'code': referral!.code,
              if (referral!.partnerName != null)
                'partnerName': referral!.partnerName,
              if (referral!.company != null) 'company': referral!.company,
              if (referral!.capturedAt != null)
                'capturedAt': referral!.capturedAt!.toIso8601String(),
              if (referral!.landingUrl != null)
                'landingUrl': referral!.landingUrl,
            }
          : null,
      'formData': formData,
      'visitorLanguage': visitorLanguage,
      'visitorLanguageSource': visitorLanguageSource,
      'visitorPresence': _presenceToJson(visitorPresence),
      'visitorPresenceAt': visitorPresenceAt?.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Conversation copyWith({
    String? id,
    String? status,
    ConversationChannel? channel,
    DateTime? whatsappWindowExpiresAt,
    String? assigneeId,
    String? assigneeName,
    String? groupId,
    String? siteName,
    String? companyName,
    bool? llmEnabled,
    String? visitorName,
    String? visitorExternalId,
    String? visitorPhone,
    String? visitorIp,
    String? visitorIpLocation,
    String? visitorUserAgent,
    String? visitorAvatarUrl,
    List<String>? defaultVisitorAvatars,
    String? landingUrl,
    String? referrer,
    String? campaign,
    ReferralContext? referral,
    Map<String, dynamic>? formData,
    String? visitorLanguage,
    String? visitorLanguageSource,
    VisitorPresence? visitorPresence,
    DateTime? visitorPresenceAt,
    DateTime? lastMessageAt,
    DateTime? createdAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      whatsappWindowExpiresAt:
          whatsappWindowExpiresAt ?? this.whatsappWindowExpiresAt,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      groupId: groupId ?? this.groupId,
      siteName: siteName ?? this.siteName,
      companyName: companyName ?? this.companyName,
      llmEnabled: llmEnabled ?? this.llmEnabled,
      visitorName: visitorName ?? this.visitorName,
      visitorExternalId: visitorExternalId ?? this.visitorExternalId,
      visitorPhone: visitorPhone ?? this.visitorPhone,
      visitorIp: visitorIp ?? this.visitorIp,
      visitorIpLocation: visitorIpLocation ?? this.visitorIpLocation,
      visitorUserAgent: visitorUserAgent ?? this.visitorUserAgent,
      visitorAvatarUrl: visitorAvatarUrl ?? this.visitorAvatarUrl,
      defaultVisitorAvatars:
          defaultVisitorAvatars ?? this.defaultVisitorAvatars,
      landingUrl: landingUrl ?? this.landingUrl,
      referrer: referrer ?? this.referrer,
      campaign: campaign ?? this.campaign,
      referral: referral ?? this.referral,
      formData: formData ?? this.formData,
      visitorLanguage: visitorLanguage ?? this.visitorLanguage,
      visitorLanguageSource:
          visitorLanguageSource ?? this.visitorLanguageSource,
      visitorPresence: visitorPresence ?? this.visitorPresence,
      visitorPresenceAt: visitorPresenceAt ?? this.visitorPresenceAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static ConversationChannel _parseChannel(dynamic value) {
    if (value == null) return ConversationChannel.web;
    final str = value.toString().toUpperCase();
    if (str == 'WHATSAPP') return ConversationChannel.whatsapp;
    return ConversationChannel.web;
  }

  static VisitorPresence _parsePresence(dynamic value) {
    if (value == null) return VisitorPresence.browsing;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'active':
        return VisitorPresence.active;
      case 'away':
        return VisitorPresence.away;
      case 'widget_closed':
        return VisitorPresence.widgetClosed;
      case 'site_closed':
        return VisitorPresence.siteClosed;
      case 'browsing':
      default:
        return VisitorPresence.browsing;
    }
  }

  static String _presenceToJson(VisitorPresence presence) {
    switch (presence) {
      case VisitorPresence.active:
        return 'active';
      case VisitorPresence.away:
        return 'away';
      case VisitorPresence.widgetClosed:
        return 'widget_closed';
      case VisitorPresence.siteClosed:
        return 'site_closed';
      case VisitorPresence.browsing:
        return 'browsing';
    }
  }
}
