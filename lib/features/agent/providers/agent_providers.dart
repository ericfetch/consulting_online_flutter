import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';
import '../../../data/models/transfer_candidate.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/agent_repository.dart';
import '../../auth/providers/auth_providers.dart';
import 'agent_utils.dart';

class AgentAppState {
  final bool connected;
  final ConversationBucket queueMode;
  final List<Conversation> conversations;
  final String? selectedId;
  final List<ChatMessage> messages;
  final List<HistoryItem> history;
  final Map<String, ChatMessage> latestUnreadMessages;
  final Map<String, int> unreadCounts;
  final Map<String, String> drafts;
  final Map<String, PresenceInfo> presence;
  final String? error;
  final DateTime presenceClock;
  final Set<String> translatingMessageIds;
  final List<String> quickReplies;
  final AgentUser? settings;

  const AgentAppState({
    this.connected = false,
    this.queueMode = ConversationBucket.serving,
    this.conversations = const [],
    this.selectedId,
    this.messages = const [],
    this.history = const [],
    this.latestUnreadMessages = const {},
    this.unreadCounts = const {},
    this.drafts = const {},
    this.presence = const {},
    this.error,
    required this.presenceClock,
    this.translatingMessageIds = const {},
    this.quickReplies = const [
      '您好，我是在线客服，可以先了解一下您的需求吗？',
      '这个活动现在可以预约，我帮您看一下名额。',
      '方便留个手机号吗？我让客服尽快联系您。',
      '您现在主要关注价格、效果，还是交付周期？',
      '我发您一张说明图，您看完我再帮您确认方案。',
    ],
    this.settings,
  });

  List<Conversation> get assignedConversations {
    final currentSettings = settings;
    if (currentSettings == null) return const [];
    return conversations.where((item) {
      if (currentSettings.role == UserRole.admin) {
        return true;
      }
      if (item.assigneeId == currentSettings.id) {
        return true;
      }
      if (currentSettings.ledGroupIds.isNotEmpty &&
          item.groupId != null &&
          currentSettings.ledGroupIds.contains(item.groupId)) {
        return true;
      }
      return false;
    }).toList();
  }

  Conversation? get selected {
    if (selectedId == null) return null;
    for (final item in assignedConversations) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  PresenceInfo? get selectedPresence =>
      selectedId != null ? presence[selectedId] : null;

  VisitorPresence? get selectedPresenceState {
    final s = selected;
    if (s == null) return null;
    final p = selectedPresence;
    return effectivePresenceState(s, p, presenceClock);
  }

  String get selectedDraft =>
      selectedId != null ? (drafts[selectedId] ?? '') : '';

  bool get selectedHasLlm => selected?.llmEnabled ?? false;

  bool get selectedCanSend {
    final s = selected;
    if (s == null) return false;
    return canSendFreeformMessage(s, presenceClock);
  }

  String get selectedLanguage =>
      normalizeLanguageCode(selected?.visitorLanguage);

  Map<ConversationBucket, int> get bucketCounts {
    final counts = {
      ConversationBucket.serving: 0,
      ConversationBucket.browsing: 0,
      ConversationBucket.left: 0
    };
    for (final conv in assignedConversations) {
      final p = presence[conv.id];
      final state = effectivePresenceState(conv, p, presenceClock);
      final bucket = conversationBucket(state, conv);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return counts;
  }

  List<Conversation> get servingConversations {
    return assignedConversations.where((item) {
      final p = presence[item.id];
      final state = effectivePresenceState(item, p, presenceClock);
      return conversationBucket(state, item) == ConversationBucket.serving;
    }).toList();
  }

  List<Conversation> get visibleConversations {
    return assignedConversations.where((item) {
      final p = presence[item.id];
      final state = effectivePresenceState(item, p, presenceClock);
      return conversationBucket(state, item) == queueMode;
    }).toList();
  }

  String get workspaceSiteLabel =>
      workspaceSiteName(settings?.visibleSites, assignedConversations);

  AgentAppState copyWith({
    bool? connected,
    ConversationBucket? queueMode,
    List<Conversation>? conversations,
    String? selectedId,
    bool clearSelected = false,
    List<ChatMessage>? messages,
    List<HistoryItem>? history,
    Map<String, ChatMessage>? latestUnreadMessages,
    Map<String, int>? unreadCounts,
    Map<String, String>? drafts,
    Map<String, PresenceInfo>? presence,
    String? error,
    bool clearError = false,
    DateTime? presenceClock,
    Set<String>? translatingMessageIds,
    List<String>? quickReplies,
    AgentUser? settings,
  }) {
    return AgentAppState(
      connected: connected ?? this.connected,
      queueMode: queueMode ?? this.queueMode,
      conversations: conversations ?? this.conversations,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
      messages: messages ?? this.messages,
      history: history ?? this.history,
      latestUnreadMessages: latestUnreadMessages ?? this.latestUnreadMessages,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      drafts: drafts ?? this.drafts,
      presence: presence ?? this.presence,
      error: clearError ? null : (error ?? this.error),
      presenceClock: presenceClock ?? this.presenceClock,
      translatingMessageIds:
          translatingMessageIds ?? this.translatingMessageIds,
      quickReplies: quickReplies ?? this.quickReplies,
      settings: settings ?? this.settings,
    );
  }
}

class AgentAppNotifier extends StateNotifier<AgentAppState> {
  final AgentRepository _repo;
  final WsClient _ws;
  final Ref _ref;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _wsStatusSubscription;
  Timer? _presenceClockTimer;
  final Set<String> _knownConversationIds = {};
  final Map<String, Timer> _messageTimeouts = {};

  AgentAppNotifier(this._repo, this._ws, this._ref)
      : super(AgentAppState(presenceClock: DateTime.now())) {
    _init();
  }

  void _init() async {
    _wsSubscription = _ws.events.listen(_handleWsEvent);
    _wsStatusSubscription = _ws.statusStream.listen(_handleWsStatus);

    final prefs = await SharedPreferences.getInstance();
    final storedReplies = prefs.getStringList(AppConstants.quickRepliesKey);
    if (storedReplies != null) {
      state = state.copyWith(quickReplies: storedReplies);
    }

    try {
      final settings = await _repo.getSettings();
      _applySettings(settings);
    } catch (_) {}

    _ws.connect();

    _presenceClockTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.presenceClockInterval),
      (_) {
        state = state.copyWith(presenceClock: DateTime.now());
      },
    );
  }

  void _handleWsStatus(WsConnectionStatus status) {
    state = state.copyWith(connected: status == WsConnectionStatus.connected);
  }

  void _applySettings(AgentUser next) {
    state = state.copyWith(settings: next);
    _ref.read(authProvider.notifier).updateUser(next);
  }

  void _handleWsEvent(RealtimeEvent event) {
    if (event.type == 'auth:failed') {
      _ref.read(authProvider.notifier).logout();
      return;
    }

    if (event.type == 'agent:ready' &&
        event.payload?['conversations'] != null) {
      if (event.payload?['user'] != null) {
        final user =
            AgentUser.fromJson(event.payload!['user'] as Map<String, dynamic>);
        _applySettings(user);
      }
      final conversationsList =
          (event.payload!['conversations'] as List<dynamic>)
              .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
              .toList();
      _knownConversationIds.clear();
      for (final c in conversationsList) {
        _knownConversationIds.add(c.id);
      }
      final newPresence = <String, PresenceInfo>{};
      for (final c in conversationsList) {
        newPresence[c.id] =
            PresenceInfo(state: c.visitorPresence, at: c.visitorPresenceAt);
      }
      state = state.copyWith(
        conversations: sortConversations(conversationsList),
        presence: newPresence,
        clearError: true,
      );
      return;
    }

    if (event.type == 'conversation:updated' &&
        event.payload?['conversation'] != null) {
      final conversation = Conversation.fromJson(
          event.payload!['conversation'] as Map<String, dynamic>);
      final isNew = !_knownConversationIds.contains(conversation.id);
      _knownConversationIds.add(conversation.id);
      _upsertConversation(conversation);
      final newPresence = Map<String, PresenceInfo>.from(state.presence);
      newPresence[conversation.id] = PresenceInfo(
          state: conversation.visitorPresence,
          at: conversation.visitorPresenceAt);
      state = state.copyWith(presence: newPresence);
      if (isNew) {
        // TODO: play notification sound
      }
      if (event.payload?['history'] != null &&
          conversation.id == state.selectedId) {
        final historyList = (event.payload!['history'] as List<dynamic>)
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(history: historyList);
      }
      return;
    }

    if (event.type == 'message:new' &&
        event.payload?['conversation'] != null &&
        event.payload?['message'] != null) {
      final conversation = Conversation.fromJson(
          event.payload!['conversation'] as Map<String, dynamic>);
      final message = ChatMessage.fromJson(
          event.payload!['message'] as Map<String, dynamic>);
      _knownConversationIds.add(conversation.id);
      _upsertConversation(conversation);

      final newDrafts = Map<String, String>.from(state.drafts);
      newDrafts[conversation.id] = '';
      state = state.copyWith(drafts: newDrafts);

      if (message.senderType == MessageSenderType.visitor) {
        if (conversation.llmEnabled &&
            (state.settings?.autoTranslate ?? false) &&
            !isImageMessage(message)) {
          _markMessageTranslating(message.id);
        }
        final newLatestUnread =
            Map<String, ChatMessage>.from(state.latestUnreadMessages);
        newLatestUnread[conversation.id] = message;
        Map<String, int> newUnread;
        // 后台时坐席没有在看任何会话，来消息一律弹通知；前台只看非当前会话。
        final isBackground = WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed;
        debugPrint(
            '[notify] visitor msg conv=${conversation.id} selected=${state.selectedId} bg=$isBackground');
        if (conversation.id != state.selectedId || isBackground) {
          newUnread = Map<String, int>.from(state.unreadCounts);
          newUnread[conversation.id] = (newUnread[conversation.id] ?? 0) + 1;
          // 非当前会话（或 app 在后台）的新消息：弹系统级通知。
          final visitorTitle = conversation.visitorName.isNotEmpty
              ? conversation.visitorName
              : '访客';
          final visitorIp = conversation.visitorIp;
          NotificationService.instance.showMessageNotification(
            title: visitorIp.isNotEmpty
                ? '$visitorTitle · $visitorIp'
                : visitorTitle,
            body: message.displayContent,
          );
        } else {
          newUnread = state.unreadCounts;
          _clearUnread(conversation.id);
        }
        state = state.copyWith(
          latestUnreadMessages: newLatestUnread,
          unreadCounts: newUnread,
        );
      }

      if (message.conversationId == state.selectedId) {
        final newMessages =
            replaceOptimisticMessage(state.messages, message, event.requestId);
        state = state.copyWith(messages: newMessages);
        _cancelMessageTimeout(event.requestId);
      }
      return;
    }

    if (event.type == 'error' && event.requestId != null) {
      final errorPayload = event.payload;
      final errorMessage = errorPayload?['message'] as String? ?? '发送失败';
      final newMessages = markOptimisticMessageFailed(
          state.messages, event.requestId!, errorMessage);
      state = state.copyWith(messages: newMessages, error: errorMessage);
      _cancelMessageTimeout(event.requestId);
      return;
    }

    if (event.type == 'visitor:typing' &&
        event.payload?['conversation'] != null) {
      final convId = (event.payload!['conversation']
          as Map<String, dynamic>)['id'] as String?;
      if (convId != null) {
        final isTyping = event.payload!['isTyping'] as bool? ?? false;
        final draft = event.payload!['draft'] as String? ?? '';
        final newDrafts = Map<String, String>.from(state.drafts);
        newDrafts[convId] = isTyping ? draft : '';
        state = state.copyWith(drafts: newDrafts);
      }
      return;
    }

    if (event.type == 'visitor:presence' &&
        event.payload?['conversation'] != null &&
        event.payload?['state'] != null) {
      final convId = (event.payload!['conversation']
          as Map<String, dynamic>)['id'] as String?;
      final presenceState = event.payload!['state'] as String;
      final atStr = event.payload!['at'] as String?;
      if (convId != null) {
        final newPresence = Map<String, PresenceInfo>.from(state.presence);
        VisitorPresence parsedState;
        switch (presenceState.toLowerCase()) {
          case 'active':
            parsedState = VisitorPresence.active;
            break;
          case 'away':
            parsedState = VisitorPresence.away;
            break;
          case 'widget_closed':
            parsedState = VisitorPresence.widgetClosed;
            break;
          case 'site_closed':
            parsedState = VisitorPresence.siteClosed;
            break;
          case 'browsing':
          default:
            parsedState = VisitorPresence.browsing;
        }
        final at = atStr != null ? DateTime.tryParse(atStr) : DateTime.now();
        newPresence[convId] =
            PresenceInfo(state: parsedState, at: at ?? DateTime.now());
        state = state.copyWith(presence: newPresence);
      }
      return;
    }

    if (event.type == 'message:metadata_updated' &&
        event.payload?['message'] != null) {
      final updated = ChatMessage.fromJson(
          event.payload!['message'] as Map<String, dynamic>);
      if (event.payload?['conversation'] != null) {
        final conv = Conversation.fromJson(
            event.payload!['conversation'] as Map<String, dynamic>);
        _upsertConversation(conv);
      }
      final newMessages = state.messages
          .map((m) =>
              m.id == updated.id ? m.copyWith(metadata: updated.metadata) : m)
          .toList();
      final newTranslating = Set<String>.from(state.translatingMessageIds)
        ..remove(updated.id);
      state = state.copyWith(
          messages: newMessages, translatingMessageIds: newTranslating);
      return;
    }

    if (event.type == 'message:updated' && event.payload?['message'] != null) {
      final updated = ChatMessage.fromJson(
          event.payload!['message'] as Map<String, dynamic>);
      if (event.payload?['conversation'] != null) {
        final conv = Conversation.fromJson(
            event.payload!['conversation'] as Map<String, dynamic>);
        _upsertConversation(conv);
      }
      final newMessages = upsertMessage(state.messages, updated);
      state = state.copyWith(messages: newMessages);
      return;
    }

    if (event.type == 'message:translation_status' &&
        event.payload?['messageId'] != null) {
      final messageId = event.payload!['messageId'] as String;
      final status = event.payload!['status'] as String?;
      if (status == 'translating') {
        _markMessageTranslating(messageId);
      } else {
        final newTranslating = Set<String>.from(state.translatingMessageIds)
          ..remove(messageId);
        state = state.copyWith(translatingMessageIds: newTranslating);
      }
    }
  }

  void _markMessageTranslating(String messageId) {
    final newTranslating = Set<String>.from(state.translatingMessageIds)
      ..add(messageId);
    state = state.copyWith(translatingMessageIds: newTranslating);
    Timer(const Duration(seconds: 60), () {
      final updated = Set<String>.from(state.translatingMessageIds)
        ..remove(messageId);
      if (mounted) {
        state = state.copyWith(translatingMessageIds: updated);
      }
    });
  }

  void _upsertConversation(Conversation conversation) {
    final existing =
        state.conversations.where((c) => c.id == conversation.id).toList();
    List<Conversation> updated;
    if (existing.isNotEmpty) {
      updated = state.conversations
          .map((c) => c.id == conversation.id ? conversation : c)
          .toList();
    } else {
      updated = [conversation, ...state.conversations];
    }
    updated = sortConversations(updated);
    String? newSelectedId = state.selectedId;
    if (newSelectedId == null &&
        conversation.assigneeId == state.settings?.id) {
      newSelectedId = conversation.id;
    }
    state = state.copyWith(conversations: updated, selectedId: newSelectedId);
  }

  void selectConversation(String? id) {
    state =
        state.copyWith(selectedId: id, messages: const [], history: const []);
    if (id != null) {
      _clearUnread(id);
      _loadMessages(id);
      _loadHistory(id);
    }
  }

  void _clearUnread(String id) {
    final newUnread = Map<String, int>.from(state.unreadCounts);
    newUnread.remove(id);
    final newLatestUnread =
        Map<String, ChatMessage>.from(state.latestUnreadMessages);
    newLatestUnread.remove(id);
    state = state.copyWith(
        unreadCounts: newUnread, latestUnreadMessages: newLatestUnread);
  }

  Future<void> _loadMessages(String id) async {
    try {
      final msgs = await _repo.getMessages(id);
      if (state.selectedId == id) {
        msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = state.copyWith(messages: msgs);
      }
    } catch (_) {
      if (state.selectedId == id) {
        state = state.copyWith(messages: const []);
      }
    }
  }

  Future<void> _loadHistory(String id) async {
    try {
      final hist = await _repo.getHistory(id);
      if (state.selectedId == id) {
        state = state.copyWith(history: hist);
      }
    } catch (_) {
      if (state.selectedId == id) {
        state = state.copyWith(history: const []);
      }
    }
  }

  void setQueueMode(ConversationBucket mode) {
    state = state.copyWith(queueMode: mode);
  }

  void sendAgentMessage(String body, {Map<String, dynamic>? metadata}) {
    final selectedId = state.selectedId;
    final currentSettings = state.settings;
    if (selectedId == null || currentSettings == null) return;

    final requestId = generateRequestId();
    final now = DateTime.now();
    final optimistic = ChatMessage(
      id: 'optimistic:$requestId',
      conversationId: selectedId,
      senderType: MessageSenderType.agent,
      senderUserId: currentSettings.id,
      senderUserName:
          currentSettings.name.isNotEmpty ? currentSettings.name : '客服',
      senderAvatarUrl: currentSettings.avatarUrl,
      body: body,
      metadata: metadata != null ? MessageMetadata.fromJson(metadata) : null,
      deliveryStatus: DeliveryStatus.pending,
      deliveryUpdatedAt: now,
      clientRequestId: requestId,
      createdAt: now,
    );

    final newMessages = upsertMessage(state.messages, optimistic);
    state = state.copyWith(messages: newMessages);

    final sent = _ws.sendMessage(selectedId, body,
        metadata: metadata, requestId: requestId);
    if (!sent) {
      final failedMessages =
          markOptimisticMessageFailed(state.messages, requestId, '实时连接未就绪');
      state = state.copyWith(messages: failedMessages, error: '实时连接未就绪，正在重连');
      return;
    }

    _messageTimeouts[requestId] =
        Timer(const Duration(milliseconds: AppConstants.messageTimeout), () {
      if (mounted) {
        final timedOutMessages =
            markOptimisticMessageTimedOut(state.messages, requestId);
        state = state.copyWith(messages: timedOutMessages);
      }
      _messageTimeouts.remove(requestId);
    });
  }

  void _cancelMessageTimeout(String? requestId) {
    if (requestId == null) return;
    _messageTimeouts[requestId]?.cancel();
    _messageTimeouts.remove(requestId);
  }

  void sendTextMessage(String body, {Map<String, dynamic>? metadata}) {
    if (!state.selectedCanSend) {
      state = state.copyWith(error: 'WhatsApp 24 小时客服窗口已关闭，只能发送已审核模板消息');
      return;
    }
    sendAgentMessage(body, metadata: metadata);
  }

  void sendImageMessage(String url) {
    sendAgentMessage(url, metadata: {
      'attachments': [
        {'type': 'image', 'url': url}
      ]
    });
  }

  void setError(String? error) {
    state = state.copyWith(error: error, clearError: error == null);
  }

  Future<void> updateStatus(AgentStatus newStatus) async {
    try {
      final updated = await _repo.updateSettings({
        'agentStatus': newStatus == AgentStatus.online
            ? 'ONLINE'
            : newStatus == AgentStatus.busy
                ? 'BUSY'
                : 'OFFLINE',
      });
      _applySettings(updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    try {
      final updated = await _repo.updateSettings(data);
      _applySettings(updated);
      final newConversations = state.conversations.map((c) {
        if (c.assigneeId == updated.id) {
          return c.copyWith(assigneeName: updated.name);
        }
        return c;
      }).toList();
      final newMessages = state.messages.map((m) {
        if (m.senderUserId == updated.id) {
          return m.copyWith(
              senderUserName: updated.name, senderAvatarUrl: updated.avatarUrl);
        }
        return m;
      }).toList();
      state = state.copyWith(
          conversations: newConversations,
          messages: newMessages,
          clearError: true);
      _refreshRealtime();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> switchVisitorLanguage(String language) async {
    final selectedId = state.selectedId;
    if (selectedId == null) return;
    final normalized = normalizeLanguageCode(language);
    final newConversations = state.conversations.map((c) {
      if (c.id == selectedId) {
        return c.copyWith(
            visitorLanguage: normalized, visitorLanguageSource: 'manual');
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: newConversations);
    try {
      final updated = await _repo
          .updateConversation(selectedId, {'visitorLanguage': normalized});
      _upsertConversation(updated);
      state = state.copyWith(clearError: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      _refreshRealtime();
    }
  }

  void resolveConversation() {
    final selected = state.selected;
    if (selected == null || selected.status == 'RESOLVED') return;
    _ws.updateConversation(selected.id, {'status': 'RESOLVED'});
  }

  void transferConversation(String agentId) {
    final selectedId = state.selectedId;
    if (selectedId == null) return;
    _ws.updateConversation(selectedId, {'assigneeId': agentId});
  }

  void _refreshRealtime() {
    if (_ws.status == WsConnectionStatus.connected) {
      _ws.send('agent:init', {});
    } else {
      _ws.connect();
    }
  }

  void saveQuickReplies(List<String> replies) async {
    final filtered = replies
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .take(30)
        .toList();
    state = state.copyWith(quickReplies: filtered);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(AppConstants.quickRepliesKey, filtered);
  }

  Future<String?> uploadImage(String filePath) async {
    try {
      return await _repo.uploadFile(filePath);
    } catch (e) {
      state = state.copyWith(error: '图片上传失败');
      return null;
    }
  }

  Future<void> translateMessage(String messageId, String body) async {
    final selectedId = state.selectedId;
    if (selectedId == null) return;
    _markMessageTranslating(messageId);
    try {
      final translated = await _repo.translate(selectedId, body);
      if (translated != null) {
        final newMessages = state.messages.map((m) {
          if (m.id == messageId) {
            return m.copyWith(
              metadata: MessageMetadata(
                kind: m.metadata?.kind,
                attachments: m.metadata?.attachments ?? const [],
                formData: m.metadata?.formData,
                submittedAt: m.metadata?.submittedAt,
                translation: m.metadata?.translation,
                intent: m.metadata?.intent,
                agentTranslation: AgentTranslation(
                  targetLanguage: state.selectedLanguage,
                  translatedText: translated,
                ),
                originalText: m.metadata?.originalText ?? body,
                whatsapp: m.metadata?.whatsapp,
                whatsappMedia: m.metadata?.whatsappMedia,
              ),
            );
          }
          return m;
        }).toList();
        final newTranslating = Set<String>.from(state.translatingMessageIds)
          ..remove(messageId);
        state = state.copyWith(
            messages: newMessages, translatingMessageIds: newTranslating);
      }
    } catch (e) {
      final newTranslating = Set<String>.from(state.translatingMessageIds)
        ..remove(messageId);
      state =
          state.copyWith(error: '翻译失败', translatingMessageIds: newTranslating);
    }
  }

  void loadSettings() async {
    try {
      final settings = await _repo.getSettings();
      _applySettings(settings);
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsStatusSubscription?.cancel();
    _presenceClockTimer?.cancel();
    for (final timer in _messageTimeouts.values) {
      timer.cancel();
    }
    _messageTimeouts.clear();
    super.dispose();
  }
}

final agentAppProvider =
    StateNotifierProvider<AgentAppNotifier, AgentAppState>((ref) {
  final repo = ref.watch(agentRepositoryProvider);
  final ws = ref.watch(wsClientProvider);
  return AgentAppNotifier(repo, ws, ref);
});

final transferCandidatesProvider =
    FutureProvider.family<List<TransferCandidate>, String>(
        (ref, conversationId) async {
  final repo = ref.watch(agentRepositoryProvider);
  return repo.getTransferCandidates(conversationId);
});
