import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';
import '../../../data/models/user.dart';

enum ConversationBucket { serving, browsing, left }

class PresenceInfo {
  final VisitorPresence state;
  final DateTime? at;

  const PresenceInfo({required this.state, this.at});
}

String visitorDisplayName(Conversation? conversation) {
  if (conversation == null) return '';
  if (conversation.channel == ConversationChannel.whatsapp) {
    final phonePart = conversation.visitorPhone.isNotEmpty
        ? conversation.visitorPhone
        : conversation.visitorExternalId.replaceFirst('whatsapp:', '+');
    return conversation.visitorName.isNotEmpty
        ? conversation.visitorName
        : (phonePart.isNotEmpty ? phonePart : 'WhatsApp 用户');
  }
  return conversation.visitorIp.isNotEmpty
      ? conversation.visitorIp
      : (conversation.visitorExternalId.isNotEmpty
          ? conversation.visitorExternalId
          : (conversation.visitorName.isNotEmpty
              ? conversation.visitorName
              : '访客'));
}

String visitorLocationDisplay(Conversation? conversation) {
  if (conversation == null) return '';
  if (conversation.channel == ConversationChannel.whatsapp) {
    return conversation.visitorPhone.isNotEmpty
        ? conversation.visitorPhone
        : conversation.visitorExternalId.replaceFirst('whatsapp:', '+');
  }
  return conversation.visitorIpLocation.isNotEmpty
      ? conversation.visitorIpLocation
      : '地域未定位';
}

String visitorPresenceLine(Conversation conversation, VisitorPresence? state) {
  if (conversation.channel == ConversationChannel.whatsapp) {
    final phone = conversation.visitorPhone.isNotEmpty
        ? conversation.visitorPhone
        : '手机号未记录';
    return 'WhatsApp · $phone';
  }
  final status = presenceLabel(state).isNotEmpty
      ? presenceLabel(state)
      : conversation.status;
  final location = conversation.visitorIpLocation;
  return location.isNotEmpty ? '$status · $location' : status;
}

String siteDisplayName(VisibleSite site) {
  return site.companyName.isNotEmpty ? site.companyName : site.name;
}

String workspaceSiteName(
    List<VisibleSite>? sites, List<Conversation> conversations) {
  final visibleSites =
      (sites ?? []).where((s) => siteDisplayName(s).isNotEmpty).toList();
  if (visibleSites.length == 1) return siteDisplayName(visibleSites[0]);
  if (visibleSites.length > 1)
    return '${siteDisplayName(visibleSites[0])} 等 ${visibleSites.length} 个站点';

  final names = conversations
      .map((c) => c.companyName.isNotEmpty ? c.companyName : c.siteName)
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();
  if (names.length == 1) return names[0];
  if (names.length > 1) return '${names[0]} 等 ${names.length} 个站点';
  return '';
}

String previewMessage(ChatMessage message) {
  final mediaType = messageMediaType(message);
  if (mediaType == 'video') return '[视频]';
  if (mediaType == 'sticker') return '[贴纸]';
  if (mediaType == 'image') return '[图片]';
  return message.body;
}

String formatConversationTime(DateTime value) {
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    return DateFormat('HH:mm').format(value);
  }
  return DateFormat('M/d').format(value);
}

bool isImageMessage(ChatMessage message) {
  return messageMediaType(message) != null;
}

String? messageMediaType(ChatMessage message) {
  if (message.metadata?.whatsappMedia?.type != null)
    return message.metadata!.whatsappMedia!.type;
  if (message.metadata?.attachments.isNotEmpty == true)
    return message.metadata!.attachments.first.type;
  final imageMatches = RegExp(
          r'(https?:\/\/\S+\.(?:png|jpe?g|gif|webp)(?:\?\S*)?|\/(?:api\/)?uploads\/\S+\.(?:png|jpe?g|gif|webp))',
          caseSensitive: false)
      .allMatches(message.body);
  if (imageMatches.isNotEmpty) return 'image';
  return null;
}

String visitorListPreview(Conversation conversation, VisitorPresence? state,
    ChatMessage? latestUnread, String? draft) {
  if (draft != null && draft.isNotEmpty) return '正在输入：$draft';
  if (latestUnread != null) return previewMessage(latestUnread);
  if (state == VisitorPresence.browsing && conversation.landingUrl.isNotEmpty)
    return '正在浏览：${conversation.landingUrl}';
  if (conversation.channel == ConversationChannel.whatsapp)
    return 'WhatsApp 对话';
  return conversation.landingUrl.isNotEmpty
      ? '当前页面：${conversation.landingUrl}'
      : (conversation.campaign.isNotEmpty ? conversation.campaign : '未记录页面');
}

VisitorPresence effectivePresenceState(
    Conversation conversation, PresenceInfo? current, DateTime now) {
  if (conversation.channel == ConversationChannel.whatsapp) {
    return conversation.status == 'RESOLVED'
        ? VisitorPresence.siteClosed
        : VisitorPresence.active;
  }
  final state = current?.state ?? conversation.visitorPresence;
  final at = current?.at ?? conversation.visitorPresenceAt;
  if (state != VisitorPresence.siteClosed && _isPresenceStale(at, now)) {
    return VisitorPresence.siteClosed;
  }
  return state;
}

String channelLabel(ConversationChannel channel) {
  return channel == ConversationChannel.whatsapp ? 'WhatsApp' : '网页客服';
}

bool canSendFreeformMessage(Conversation conversation, DateTime now) {
  if (conversation.channel != ConversationChannel.whatsapp) return true;
  final expiresAt =
      conversation.whatsappWindowExpiresAt?.millisecondsSinceEpoch ?? 0;
  return expiresAt > now.millisecondsSinceEpoch;
}

String deliveryStatusLabel(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.pending:
      return '发送中';
    case DeliveryStatus.accepted:
      return '已接受';
    case DeliveryStatus.sent:
      return '已发送';
    case DeliveryStatus.delivered:
      return '已送达';
    case DeliveryStatus.read:
      return '已读';
    case DeliveryStatus.failed:
      return '发送失败';
  }
}

bool _isPresenceStale(DateTime? at, DateTime now) {
  if (at == null) return true;
  return now.difference(at).inMilliseconds > AppConstants.presenceStaleMs;
}

ConversationBucket conversationBucket(
    VisitorPresence state, Conversation conversation) {
  if (state == VisitorPresence.siteClosed ||
      state == VisitorPresence.widgetClosed ||
      conversation.status == 'RESOLVED') {
    return ConversationBucket.left;
  }
  if (state == VisitorPresence.browsing) return ConversationBucket.browsing;
  return ConversationBucket.serving;
}

String bucketLabel(ConversationBucket bucket) {
  switch (bucket) {
    case ConversationBucket.serving:
      return '接待中';
    case ConversationBucket.browsing:
      return '浏览中';
    case ConversationBucket.left:
      return '已离开';
  }
}

String bucketColor(ConversationBucket bucket) {
  switch (bucket) {
    case ConversationBucket.serving:
      return 'teal';
    case ConversationBucket.browsing:
      return 'blue';
    case ConversationBucket.left:
      return 'gray';
  }
}

String presenceLabel(VisitorPresence? state) {
  if (state == null) return '';
  switch (state) {
    case VisitorPresence.browsing:
      return '用户未打开客服系统，正在浏览网页';
    case VisitorPresence.active:
      return '接待中';
    case VisitorPresence.away:
      return '接待中';
    case VisitorPresence.widgetClosed:
      return '已离开';
    case VisitorPresence.siteClosed:
      return '访客关闭网站';
  }
}

String normalizeLanguageCode(String? value) {
  final normalized = (value ?? '').trim().toLowerCase().replaceAll('_', '-');
  if (normalized.isEmpty) return '';
  return normalized.split('-')[0];
}

List<ChatMessage> upsertMessage(
    List<ChatMessage> messages, ChatMessage message) {
  final exists = messages.any((m) => m.id == message.id);
  final List<ChatMessage> next;
  if (exists) {
    next = messages
        .map((m) => m.id == message.id ? _mergeMessage(m, message) : m)
        .toList();
  } else {
    next = [...messages, message];
  }
  next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return next;
}

ChatMessage _mergeMessage(ChatMessage existing, ChatMessage updated) {
  return existing.copyWith(
    id: updated.id,
    conversationId: updated.conversationId,
    senderType: updated.senderType,
    senderUserId: updated.senderUserId ?? existing.senderUserId,
    senderUserName: updated.senderUserName ?? existing.senderUserName,
    senderAvatarUrl: updated.senderAvatarUrl.isNotEmpty
        ? updated.senderAvatarUrl
        : existing.senderAvatarUrl,
    body: updated.body,
    externalId: updated.externalId ?? existing.externalId,
    deliveryStatus: updated.deliveryStatus ?? existing.deliveryStatus,
    deliveryUpdatedAt: updated.deliveryUpdatedAt ?? existing.deliveryUpdatedAt,
    clientRequestId: updated.clientRequestId ?? existing.clientRequestId,
    clientError: updated.clientError ?? existing.clientError,
    metadata: updated.metadata ?? existing.metadata,
    createdAt: updated.createdAt,
  );
}

List<ChatMessage> replaceOptimisticMessage(
    List<ChatMessage> messages, ChatMessage message, String? requestId) {
  int optimisticIndex = -1;
  for (var i = 0; i < messages.length; i++) {
    final item = messages[i];
    if (item.clientRequestId != null) {
      if (item.clientRequestId == requestId) {
        optimisticIndex = i;
        break;
      }
      if (requestId == null &&
          message.senderType == MessageSenderType.agent &&
          item.conversationId == message.conversationId &&
          item.body == message.body) {
        optimisticIndex = i;
        break;
      }
    }
  }

  if (optimisticIndex < 0) {
    return upsertMessage(messages, message);
  }

  final next = <ChatMessage>[];
  for (var i = 0; i < messages.length; i++) {
    if (i != optimisticIndex && messages[i].id != message.id) {
      next.add(messages[i]);
    }
  }
  next.add(message);
  next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return next;
}

List<ChatMessage> markOptimisticMessageFailed(
    List<ChatMessage> messages, String requestId, String error) {
  return messages.map((m) {
    if (m.clientRequestId == requestId) {
      return m.copyWith(
        deliveryStatus: DeliveryStatus.failed,
        deliveryUpdatedAt: DateTime.now(),
        clientError: error,
      );
    }
    return m;
  }).toList();
}

List<ChatMessage> markOptimisticMessageTimedOut(
    List<ChatMessage> messages, String requestId) {
  return messages.map((m) {
    if (m.clientRequestId == requestId &&
        m.deliveryStatus == DeliveryStatus.pending) {
      return m.copyWith(
        deliveryStatus: DeliveryStatus.failed,
        deliveryUpdatedAt: DateTime.now(),
        clientError: '发送超时，请检查连接后重试',
      );
    }
    return m;
  }).toList();
}

List<Conversation> sortConversations(List<Conversation> conversations) {
  final sorted = List<Conversation>.from(conversations);
  sorted.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  return sorted;
}
