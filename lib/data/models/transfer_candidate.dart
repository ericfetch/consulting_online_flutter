import 'conversation.dart';
import 'message.dart';

class TransferCandidate {
  final String id;
  final String name;
  final String email;
  final String? groupId;
  final String groupName;

  const TransferCandidate({
    required this.id,
    required this.name,
    required this.email,
    this.groupId,
    this.groupName = '',
  });

  factory TransferCandidate.fromJson(Map<String, dynamic> json) {
    return TransferCandidate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      groupId: json['groupId'] as String?,
      groupName: json['groupName'] as String? ?? '',
    );
  }
}

class HistoryItem {
  final Conversation conversation;
  final List<ChatMessage> messages;

  const HistoryItem({required this.conversation, this.messages = const []});

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      conversation: Conversation.fromJson(json['conversation'] as Map<String, dynamic>? ?? {}),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
