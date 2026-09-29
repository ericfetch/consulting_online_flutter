enum AssignmentRule { average, sequential, conversionRate }

class DashboardTrendPoint {
  final String date;
  final int conversations;
  final int messages;
  final int visitors;
  final int conversions;
  final int consultations;

  const DashboardTrendPoint({
    required this.date,
    this.conversations = 0,
    this.messages = 0,
    this.visitors = 0,
    this.conversions = 0,
    this.consultations = 0,
  });

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) {
    return DashboardTrendPoint(
      date: json['date'] as String? ?? '',
      conversations: json['conversations'] as int? ?? 0,
      messages: json['messages'] as int? ?? 0,
      visitors: json['visitors'] as int? ?? 0,
      conversions: json['conversions'] as int? ?? 0,
      consultations: json['consultations'] as int? ?? 0,
    );
  }
}

class DashboardStats {
  final int agents;
  final int onlineNow;
  final int consultingNow;
  final int conversationsToday;
  final int messagesToday;
  final int visitorsToday;
  final int conversionsToday;
  final double conversionRate;
  final List<DashboardTrendPoint> trend;
  final int activeConversationsToday,
      summarizedCustomers,
      summarizedCustomersToday,
      webConsultingNow,
      whatsappConsultingNow;
  final DateTime? generatedAt;
  final List<AdminUser> agentRoster;

  const DashboardStats({
    this.agents = 0,
    this.onlineNow = 0,
    this.consultingNow = 0,
    this.conversationsToday = 0,
    this.messagesToday = 0,
    this.visitorsToday = 0,
    this.conversionsToday = 0,
    this.conversionRate = 0,
    this.trend = const [],
    this.activeConversationsToday = 0,
    this.summarizedCustomers = 0,
    this.summarizedCustomersToday = 0,
    this.webConsultingNow = 0,
    this.whatsappConsultingNow = 0,
    this.generatedAt,
    this.agentRoster = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final trend = (json['trend'] as List<dynamic>? ?? [])
        .map((e) => DashboardTrendPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return DashboardStats(
      agents: json['agents'] as int? ?? 0,
      onlineNow: json['onlineNow'] as int? ?? 0,
      consultingNow: json['consultingNow'] as int? ?? 0,
      conversationsToday: json['conversationsToday'] as int? ?? 0,
      messagesToday: json['messagesToday'] as int? ?? 0,
      visitorsToday: json['visitorsToday'] as int? ?? 0,
      conversionsToday: json['conversionsToday'] as int? ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0,
      trend: trend,
      activeConversationsToday: json['activeConversationsToday'] as int? ?? 0,
      summarizedCustomers: json['summarizedCustomers'] as int? ?? 0,
      summarizedCustomersToday: json['summarizedCustomersToday'] as int? ?? 0,
      webConsultingNow: json['webConsultingNow'] as int? ?? 0,
      whatsappConsultingNow: json['whatsappConsultingNow'] as int? ?? 0,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
      agentRoster: (json['agentRoster'] as List? ?? [])
          .map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String? groupId;
  final String? avatarUrl;
  final String agentStatus;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'AGENT',
    this.status = 'ACTIVE',
    this.groupId,
    this.avatarUrl,
    this.agentStatus = 'OFFLINE',
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'AGENT',
      status: json['status'] as String? ?? 'ACTIVE',
      groupId: json['groupId'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      agentStatus: json['agentStatus'] as String? ?? 'OFFLINE',
    );
  }
}

class AgentGroup {
  final String id;
  final String name;
  final String? leaderId;
  final String? leaderName;
  final String description;
  final AssignmentRule assignmentRule;
  final int memberCount;

  const AgentGroup({
    required this.id,
    required this.name,
    this.leaderId,
    this.leaderName,
    this.description = '',
    this.assignmentRule = AssignmentRule.average,
    this.memberCount = 0,
  });

  factory AgentGroup.fromJson(Map<String, dynamic> json) {
    return AgentGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      leaderId: json['leaderId'] as String?,
      leaderName: json['leaderName'] as String?,
      description: json['description'] as String? ?? '',
      assignmentRule: _parseRule(json['assignmentRule'] as String?),
      memberCount: (json['members'] as List?)?.length ?? 0,
    );
  }

  String get assignmentRuleLabel {
    switch (assignmentRule) {
      case AssignmentRule.average:
        return '平均分配';
      case AssignmentRule.sequential:
        return '顺序分配';
      case AssignmentRule.conversionRate:
        return '按转化率';
    }
  }

  static AssignmentRule _parseRule(String? rule) {
    switch (rule) {
      case 'SEQUENTIAL':
        return AssignmentRule.sequential;
      case 'CONVERSION_RATE':
        return AssignmentRule.conversionRate;
      default:
        return AssignmentRule.average;
    }
  }
}
