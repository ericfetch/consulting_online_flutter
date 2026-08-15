enum UserRole { admin, agent }

enum AgentStatus { online, busy, offline }

class AgentUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarUrl;
  final String? autoGreeting;
  final bool autoTranslate;
  final AgentStatus agentStatus;
  final String? themeMode;
  final List<String> ledGroupIds;
  final List<VisibleSite> visibleSites;

  const AgentUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl = '',
    this.autoGreeting,
    this.autoTranslate = false,
    this.agentStatus = AgentStatus.offline,
    this.themeMode,
    this.ledGroupIds = const [],
    this.visibleSites = const [],
  });

  bool get isAdmin => role == UserRole.admin;

  factory AgentUser.fromJson(Map<String, dynamic> json) {
    return AgentUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: _parseRole(json['role']),
      avatarUrl: json['avatarUrl'] as String? ?? '',
      autoGreeting: json['autoGreeting'] as String?,
      autoTranslate: json['autoTranslate'] as bool? ?? false,
      agentStatus: _parseAgentStatus(json['agentStatus']),
      themeMode: json['themeMode'] as String?,
      ledGroupIds:
          (json['ledGroupIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      visibleSites:
          (json['visibleSites'] as List<dynamic>?)
              ?.map((e) => VisibleSite.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role == UserRole.admin ? 'ADMIN' : 'AGENT',
      'avatarUrl': avatarUrl,
      'autoGreeting': autoGreeting,
      'autoTranslate': autoTranslate,
      'agentStatus': _agentStatusToJson(agentStatus),
      'themeMode': themeMode,
      'ledGroupIds': ledGroupIds,
      'visibleSites': visibleSites.map((e) => e.toJson()).toList(),
    };
  }

  AgentUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    String? autoGreeting,
    bool? autoTranslate,
    AgentStatus? agentStatus,
    String? themeMode,
    List<String>? ledGroupIds,
    List<VisibleSite>? visibleSites,
  }) {
    return AgentUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      autoGreeting: autoGreeting ?? this.autoGreeting,
      autoTranslate: autoTranslate ?? this.autoTranslate,
      agentStatus: agentStatus ?? this.agentStatus,
      themeMode: themeMode ?? this.themeMode,
      ledGroupIds: ledGroupIds ?? this.ledGroupIds,
      visibleSites: visibleSites ?? this.visibleSites,
    );
  }

  static UserRole _parseRole(dynamic value) {
    if (value == null) return UserRole.agent;
    final str = value.toString().toUpperCase();
    if (str == 'ADMIN') return UserRole.admin;
    return UserRole.agent;
  }

  static AgentStatus _parseAgentStatus(dynamic value) {
    if (value == null) return AgentStatus.offline;
    final str = value.toString().toUpperCase();
    switch (str) {
      case 'ONLINE':
        return AgentStatus.online;
      case 'BUSY':
        return AgentStatus.busy;
      case 'OFFLINE':
      default:
        return AgentStatus.offline;
    }
  }

  static String _agentStatusToJson(AgentStatus status) {
    switch (status) {
      case AgentStatus.online:
        return 'ONLINE';
      case AgentStatus.busy:
        return 'BUSY';
      case AgentStatus.offline:
        return 'OFFLINE';
    }
  }
}

class VisibleSite {
  final String id;
  final String name;
  final String companyName;
  final String domain;

  const VisibleSite({
    required this.id,
    required this.name,
    this.companyName = '',
    this.domain = '',
  });

  bool get enabled => true;

  factory VisibleSite.fromJson(Map<String, dynamic> json) {
    return VisibleSite(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'companyName': companyName, 'domain': domain};
  }
}
