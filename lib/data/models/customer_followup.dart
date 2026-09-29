import 'dart:math';

const followupStages = {
  'WAIT_NOTIFY': '待通知',
  'MATCHING': '待匹配医生',
  'CONFIRMING': '待确认可接',
  'WAIT_PAYMENT': '待支付在线问诊费用',
  'WAIT_BOOKING': '待预约在线问诊',
  'WAIT_CONSULTATION': '待问诊',
  'WAIT_FOLLOWUP': '待回访',
  'WAIT_CHINA': '待来华就医',
  'WAIT_ENTRY': '待入境',
  'WAIT_TREATMENT': '待治疗',
  'WAIT_SETTLEMENT': '待结算',
  'COMPLETED': '已完结',
};
const notificationStatuses = {
  'PENDING': '等待处理',
  'PREPARING': '准备 PDF…',
  'SENDING': '通知中…',
  'SENT': '已通知',
  'FAILED': '通知失败',
  'UNCERTAIN': '结果未确认',
};

String followupRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class FollowupOwner {
  final String id, name;
  const FollowupOwner({required this.id, required this.name});
  factory FollowupOwner.fromJson(Map<String, dynamic> json) => FollowupOwner(
      id: json['id'] as String, name: json['name'] as String? ?? '客服');
}

class FollowupNotification {
  final String id, status, detail, actorName;
  final bool supplement;
  final DateTime? createdAt, expiresAt, revokedAt;
  FollowupNotification.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        status = json['status'] as String,
        detail = json['detail'] as String? ?? '',
        actorName = json['actorName'] as String? ?? '',
        supplement = json['supplement'] == true,
        createdAt = DateTime.tryParse(json['createdAt'] ?? ''),
        expiresAt = DateTime.tryParse(json['expiresAt'] ?? ''),
        revokedAt = DateTime.tryParse(json['revokedAt'] ?? '');
  bool get active => const ['PENDING', 'PREPARING', 'SENDING'].contains(status);
  bool get canRevoke =>
      !active &&
      revokedAt == null &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());
  String get label => notificationStatuses[status] ?? status;
}

class CustomerFollowupData {
  final String stage;
  final int version, total, page;
  final FollowupOwner? owner;
  final bool notifyEnabled;
  final DateTime? followedUpAt, notifiedAt;
  final List<Map<String, dynamic>> events;
  final List<FollowupNotification> notifications;
  CustomerFollowupData.fromJson(Map<String, dynamic> json)
      : stage = json['stage'] as String,
        version = (json['version'] as num).toInt(),
        total = (json['total'] as num?)?.toInt() ?? 0,
        page = (json['page'] as num?)?.toInt() ?? 1,
        owner = json['owner'] is Map
            ? FollowupOwner.fromJson(Map<String, dynamic>.from(json['owner']))
            : null,
        notifyEnabled = json['notifyEnabled'] == true,
        followedUpAt = DateTime.tryParse(json['followedUpAt'] ?? ''),
        notifiedAt = DateTime.tryParse(json['notifiedAt'] ?? ''),
        events = (json['events'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        notifications = (json['notifications'] as List? ?? [])
            .map((e) =>
                FollowupNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
  FollowupNotification? get activeNotification {
    for (final item in notifications) {
      if (item.active) return item;
    }
    return null;
  }

  FollowupNotification? get latest =>
      notifications.isEmpty ? null : notifications.first;
}
