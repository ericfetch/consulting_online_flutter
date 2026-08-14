import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/agent_providers.dart';
import '../providers/agent_utils.dart';
import '../widgets/message_bubble.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/visitor_panel.dart';
import '../widgets/quick_replies_sheet.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmojiPicker = false;
  bool _isSending = false;
  String? _replyingTo;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSelectedId = ref.read(agentAppProvider).selectedId;
      if (currentSelectedId != widget.conversationId) {
        ref
            .read(agentAppProvider.notifier)
            .selectConversation(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {}

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    ref.read(agentAppProvider.notifier).sendTextMessage(text);
    setState(() {
      _replyingTo = null;
      _isSending = false;
    });

    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isSending = true);
      final url =
          await ref.read(agentAppProvider.notifier).uploadImage(image.path);
      if (url != null) {
        ref.read(agentAppProvider.notifier).sendImageMessage(url);
      }
      setState(() => _isSending = false);
    }
  }

  void _showQuickReplies() {
    final quickReplies = ref.read(agentAppProvider).quickReplies;
    showModalBottomSheet(
      context: context,
      builder: (context) => QuickRepliesSheet(
        quickReplies: quickReplies,
        onSelected: (text) {
          _messageController.text = text;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
          Navigator.pop(context);
          _focusNode.requestFocus();
        },
      ),
    );
  }

  void _showTransferDialog() {
    final conversation = ref.read(agentAppProvider).selected;
    if (conversation == null) return;

    showDialog(
      context: context,
      builder: (context) => _TransferDialog(conversation: conversation),
    );
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束会话'),
        content: const Text('确定要结束这个会话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(agentAppProvider.notifier).resolveConversation();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('结束'),
          ),
        ],
      ),
    );
  }

  void _toggleVisitorPanel() {
    final appState = ref.read(agentAppProvider);
    final conversation = appState.selected;
    if (conversation == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => VisitorPanel(
        conversation: conversation,
        presenceState: appState.selectedPresenceState,
      ),
    );
  }

  String _getPresenceStatus(VisitorPresence? state) {
    if (state == null) return 'offline';
    switch (state) {
      case VisitorPresence.active:
      case VisitorPresence.away:
        return 'online';
      case VisitorPresence.browsing:
        return 'busy';
      case VisitorPresence.widgetClosed:
      case VisitorPresence.siteClosed:
        return 'offline';
    }
  }

  bool _isActive(VisitorPresence? state) {
    return state == VisitorPresence.active || state == VisitorPresence.away;
  }

  Widget _buildVisitorAvatar(Conversation conversation, String displayName,
      VisitorPresence? presenceState) {
    if (conversation.visitorAvatarUrl.isNotEmpty) {
      return UserAvatar(
        name: displayName,
        imageUrl: conversation.visitorAvatarUrl,
        size: 36,
        showStatus: true,
        status: _getPresenceStatus(presenceState),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          conversation.visitorInitial,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(agentAppProvider);
    final conversation = appState.selected;
    final messages = appState.messages;
    final colorScheme = Theme.of(context).colorScheme;
    final presenceState = appState.selectedPresenceState;
    final displayName = visitorDisplayName(conversation);
    final draft = appState.selectedDraft;
    final isVisitorTyping = draft.isNotEmpty;
    final canSend = appState.selectedCanSend;

    if (conversation == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '会话不存在',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final isActive = _isActive(presenceState);

    ref.listen<String?>(
      agentAppProvider.select((s) => s.error),
      (previous, next) {
        if (next != null && next.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          ref.read(agentAppProvider.notifier).setError(null);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: InkWell(
          onTap: _toggleVisitorPanel,
          child: Row(
            children: [
              _buildVisitorAvatar(conversation, displayName, presenceState),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isVisitorTyping
                          ? '正在输入...'
                          : isActive
                              ? '在线'
                              : '离线',
                      style: TextStyle(
                        fontSize: 12,
                        color: isVisitorTyping
                            ? AppTheme.infoColor
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: _toggleVisitorPanel,
            tooltip: '访客信息',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'transfer':
                  _showTransferDialog();
                  break;
                case 'end':
                  _showEndDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'transfer',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz),
                  title: Text('转接会话'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'end',
                child: ListTile(
                  leading: Icon(Icons.close, color: Colors.red),
                  title: Text('结束会话', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !appState.connected
                ? const Center(child: LoadingIndicator())
                : GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final showAvatar = index == messages.length - 1 ||
                            messages[index + 1].senderUserId !=
                                message.senderUserId ||
                            messages[index + 1].senderType !=
                                message.senderType;
                        final isTranslating =
                            appState.translatingMessageIds.contains(message.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: MessageBubble(
                            message: message,
                            showAvatar: showAvatar,
                            conversation: conversation,
                            isTranslating: isTranslating,
                            onReply: () {
                              setState(() {
                                _replyingTo = message.id;
                                _focusNode.requestFocus();
                              });
                            },
                            onTranslate: () {
                              ref
                                  .read(agentAppProvider.notifier)
                                  .translateMessage(message.id, message.body);
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_replyingTo != null) _buildReplyPreview(messages),
          if (!canSend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WhatsApp 24 小时客服窗口已关闭',
                      style: TextStyle(fontSize: 12, color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          _buildInputArea(canSend),
          if (_showEmojiPicker)
            EmojiPicker(
              onEmojiSelected: (emoji) {
                _messageController.text += emoji;
                _messageController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _messageController.text.length),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(List<ChatMessage> messages) {
    ChatMessage? replyMsg;
    for (final m in messages) {
      if (m.id == _replyingTo) {
        replyMsg = m;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyMsg?.senderName ?? '回复',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  replyMsg?.displayContent ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool canSend) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _showEmojiPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                  if (_showEmojiPicker) {
                    FocusScope.of(context).unfocus();
                  } else {
                    _focusNode.requestFocus();
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(
                Icons.image_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: _pickImage,
            ),
            IconButton(
              icon: Icon(
                Icons.quickreply_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: _showQuickReplies,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                enabled: canSend,
                decoration: InputDecoration(
                  hintText: canSend ? '输入消息...' : '无法发送消息',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: canSend ? (_) => _sendMessage() : null,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: canSend ? colorScheme.primary : colorScheme.outline,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: (canSend && !_isSending) ? _sendMessage : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferDialog extends ConsumerStatefulWidget {
  final Conversation conversation;

  const _TransferDialog({required this.conversation});

  @override
  ConsumerState<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<_TransferDialog> {
  String? _selectedAgentId;

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(
      transferCandidatesProvider(widget.conversation.id),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('转接会话'),
      content: SizedBox(
        width: double.maxFinite,
        child: candidatesAsync.when(
          data: (agents) {
            if (agents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 48,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '没有可转接的坐席',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return RadioListTile<String>(
                  value: agent.id,
                  groupValue: _selectedAgentId,
                  onChanged: (value) {
                    setState(() => _selectedAgentId = value);
                  },
                  title: Row(
                    children: [
                      UserAvatar(name: agent.name, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agent.name),
                            if (agent.groupName.isNotEmpty)
                              Text(
                                agent.groupName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: LoadingIndicator()),
          error: (_, __) => Center(
            child: Text('加载失败', style: TextStyle(color: colorScheme.error)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedAgentId == null
              ? null
              : () {
                  ref.read(agentAppProvider.notifier).transferConversation(
                        _selectedAgentId!,
                      );
                  Navigator.pop(context);
                },
          child: const Text('转接'),
        ),
      ],
    );
  }
}
