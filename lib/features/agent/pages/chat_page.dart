import 'package:flutter/material.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/agent_repository.dart';
import '../../customers/customer_pages.dart';
import '../widgets/message_assistance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/copilot.dart';
import '../../../data/models/message.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/agent_providers.dart';
import '../providers/copilot_provider.dart';
import '../providers/agent_utils.dart';
import '../widgets/message_bubble.dart';
import '../widgets/copilot_panel.dart';
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
  bool _isNearBottom = true;
  String? _replyingTo;
  bool _mentionMenu = false;
  String? _pendingQuickRun, _pendingQuickDraft, _firstMessageId;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onComposerChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentSelectedId = ref.read(agentAppProvider).selectedId;
      if (currentSelectedId != widget.conversationId) {
        ref
            .read(agentAppProvider.notifier)
            .selectConversation(widget.conversationId);
      } else {
        // 会话已选中且消息已在内存中：直接定位到最新消息。
        _scrollToBottom(animated: false);
      }
    });
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _messageController.clear();
      _replyingTo = null;
      _isSending = false;
      _showEmojiPicker = false;
      _pendingQuickRun = null;
      _pendingQuickDraft = null;
      _firstMessageId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(agentAppProvider.notifier)
              .selectConversation(widget.conversationId);
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    if (mounted) {
      setState(() {
        _mentionMenu = RegExp(r'^\s*@(?:a(?:g(?:e(?:n(?:t)?)?)?)?)?$',
                caseSensitive: false)
            .hasMatch(_messageController.text);
      });
    }
  }

  void _insertAgent([String? command]) {
    final current = _messageController.text;
    final question =
        copilotQuestion(current).replaceFirst(RegExp(r'^@\w*\s*'), '');
    _messageController.text = '@agent ${command ?? question}';
    _messageController.selection =
        TextSelection.collapsed(offset: _messageController.text.length);
    setState(() => _mentionMenu = command == null);
    _focusNode.requestFocus();
  }

  Future<void> _quickReply(String text) async {
    final id = widget.conversationId;
    final draft = _messageController.text;
    if (ref.read(copilotProvider(id)).snapshot?.enabled != true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先启用 AI 助手，以便转换为客户语言')));
      return;
    }
    final ok = await ref.read(copilotProvider(id).notifier).ask(
        '将以下中文快捷回复结合当前上下文转换为客户使用的语言，使用 show_reply_options，只给一个选项；staffText 提供完整中文译文，不添加未经确认的承诺。\n$text',
        sourceMessageId: _latestMessageId(ref.read(agentAppProvider).messages),
        purpose: 'quick_reply');
    if (!mounted || widget.conversationId != id || !ok) return;
    final runId = ref.read(copilotProvider(id).notifier).lastRequestedRunId;
    if (runId != null) {
      _pendingQuickRun = runId;
      _pendingQuickDraft = draft;
      _fillQuickReply(ref.read(copilotProvider(id)));
    }
  }

  void _fillQuickReply(CopilotState state) {
    final run =
        state.snapshot?.runs.where((r) => r.id == _pendingQuickRun).firstOrNull;
    if (run?.completed != true) return;
    final reply = run!.events
        .where((e) => e.card?.kind == 'replies')
        .lastOrNull
        ?.card
        ?.options
        .firstOrNull;
    if (reply != null && _messageController.text == _pendingQuickDraft) {
      _adoptReply(reply, run.sourceMessageId);
    }
    _pendingQuickRun = null;
    _pendingQuickDraft = null;
  }

  Future<void> _intakeLink() async {
    final id = widget.conversationId;
    try {
      final link = await ref.read(customerRepositoryProvider).createIntake(id);
      if (!mounted || id != widget.conversationId) return;
      _messageController.text =
          'Please complete your basic information and upload any reports you have: $link';
      _messageController.selection =
          TextSelection.collapsed(offset: _messageController.text.length);
      _focusNode.requestFocus();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  String? _latestMessageId(List<ChatMessage> messages) => messages
      .where((message) =>
          message.conversationId == widget.conversationId &&
          !message.isSystem &&
          !message.id.startsWith('optimistic:'))
      .lastOrNull
      ?.id;

  void _adoptReply(CopilotReply reply, String? sourceId) {
    if (ref.read(agentAppProvider).selectedId != widget.conversationId) {
      return;
    }
    setState(() {
      _replyingTo = null;
    });
    _messageController.text = reply.customerText;
    _messageController.selection =
        TextSelection.collapsed(offset: reply.customerText.length);
    _focusNode.requestFocus();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _isNearBottom = position.pixels >= position.maxScrollExtent - 60;
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _sendMessage() async {
    final conversationId = widget.conversationId;
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (ref.read(agentAppProvider).selectedId != widget.conversationId) return;
    if (isCopilotMention(text)) {
      setState(() {
        _isSending = true;
      });
      final success = await ref
          .read(copilotProvider(widget.conversationId).notifier)
          .ask(text,
              sourceMessageId:
                  _latestMessageId(ref.read(agentAppProvider).messages));
      if (!mounted || widget.conversationId != conversationId) return;
      if (success && _messageController.text.trim() == text) {
        _messageController.clear();
      }
      setState(() => _isSending = false);
      return;
    }
    if (!ref.read(agentAppProvider).selectedCanSend) return;
    ref.read(agentAppProvider.notifier).sendTextMessage(text);
    _messageController.clear();
    setState(() {
      _replyingTo = null;
    });

    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final conversationId = widget.conversationId;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null &&
        mounted &&
        widget.conversationId == conversationId &&
        ref.read(agentAppProvider).selectedId == conversationId) {
      setState(() => _isSending = true);
      final url =
          await ref.read(agentAppProvider.notifier).uploadImage(image.path);
      if (!mounted) return;
      if (widget.conversationId != conversationId ||
          ref.read(agentAppProvider).selectedId != conversationId) {
        setState(() => _isSending = false);
        return;
      }
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
          Navigator.pop(context);
          _quickReply(text);
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
    final copilot = ref.watch(copilotProvider(widget.conversationId));
    final conversation = appState.selected;
    final messages = appState.messages
        .where((m) => m.conversationId == widget.conversationId)
        .toList();
    final firstId =
        messages.where((m) => !m.id.startsWith('optimistic:')).firstOrNull?.id;
    if (_firstMessageId != firstId) {
      _firstMessageId = firstId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(copilotProvider(widget.conversationId).notifier)
              .setMessageRange(firstId);
        }
      });
    }
    ref.listen<CopilotState>(copilotProvider(widget.conversationId),
        (previous, next) {
      _fillQuickReply(next);
      if (_isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom(animated: false);
        });
      }
    });
    final colorScheme = Theme.of(context).colorScheme;
    final presenceState = appState.selectedPresenceState;
    final displayName = visitorDisplayName(conversation);
    final draft = appState.selectedDraft;
    final isVisitorTyping = draft.isNotEmpty;
    final canSend = appState.selectedCanSend;

    if (conversation == null || conversation.id != widget.conversationId) {
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

    ref.listen<List<ChatMessage>>(
      agentAppProvider.select((s) => s.messages),
      (previous, next) {
        if (next.isEmpty) return;
        if (previous == null || previous.isEmpty) {
          // 首次加载：直接定位到最新消息。
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom(animated: false));
        } else if (_isNearBottom && next.length != previous.length) {
          // 有新消息且用户还在底部：跟随滚动到底部。
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom(animated: true));
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
                    Row(children: [
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
                      const SizedBox(width: 8),
                      Flexible(
                          child: CopilotPresence(
                              conversationId: widget.conversationId)),
                    ]),
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
                case 'customer':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CustomerDetailPage(
                              conversationId: widget.conversationId)));
                  break;
                case 'summary':
                  ref.read(copilotProvider(widget.conversationId).notifier).ask(
                      summaryPrompt,
                      sourceMessageId: _latestMessageId(messages),
                      purpose: 'summary');
                  break;
                case 'intake':
                  _intakeLink();
                  break;
                case 'transfer':
                  _showTransferDialog();
                  break;
                case 'end':
                  _showEndDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'customer', child: Text('客户资料')),
              const PopupMenuItem(value: 'summary', child: Text('汇总资料')),
              const PopupMenuItem(value: 'intake', child: Text('填写资料链接')),
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
          if (copilot.error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Expanded(
                      child: Text(copilot.error!,
                          style: TextStyle(
                              fontSize: 12, color: colorScheme.error))),
                  TextButton(
                      onPressed: () => ref
                          .read(copilotProvider(widget.conversationId).notifier)
                          .refresh(),
                      child: const Text('重试')),
                ])),
          Expanded(
              child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final runs = copilot.snapshot?.runs
                                .where((r) => r.sourceMessageId == message.id)
                                .toList() ??
                            <CopilotRun>[];
                        final next = index + 1 < messages.length
                            ? messages[index + 1]
                            : null;
                        final anchor = runs.isNotEmpty ||
                            message.senderType == MessageSenderType.visitor &&
                                next?.senderType != MessageSenderType.visitor;
                        return Column(
                            key: ValueKey(message.id),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MessageBubble(
                                  message: message,
                                  showAvatar: index == 0 ||
                                      messages[index - 1].senderUserId !=
                                          message.senderUserId ||
                                      messages[index - 1].senderType !=
                                          message.senderType,
                                  conversation: conversation,
                                  isTranslating: appState.translatingMessageIds
                                      .contains(message.id),
                                  onReply: () => setState(() {
                                        _replyingTo = message.id;
                                        _focusNode.requestFocus();
                                      }),
                                  onTranslate: () async {
                                    try {
                                      await ref
                                          .read(agentRepositoryProvider)
                                          .translateMessage(
                                              widget.conversationId,
                                              message.id);
                                      if (mounted) {
                                        ref
                                            .read(copilotProvider(
                                                    widget.conversationId)
                                                .notifier)
                                            .refresh();
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content:
                                                    Text(error.toString())));
                                      }
                                    }
                                  }),
                              MessageAssistance(message: message),
                              if (anchor)
                                CopilotPanel(
                                    key: ValueKey('assistant-${message.id}'),
                                    conversationId: widget.conversationId,
                                    sourceMessageId: message.id,
                                    onChoose: _adoptReply),
                            ]);
                      }))),
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
    final askingAgent = isCopilotMention(_messageController.text);
    final canSubmit = (canSend || askingAgent) &&
        !_isSending &&
        (askingAgent
            ? copilotQuestion(_messageController.text).isNotEmpty
            : _messageController.text.trim().isNotEmpty);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 5, 10, 8),
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_mentionMenu)
            Wrap(spacing: 8, children: [
              ActionChip(
                  label: const Text('翻译'),
                  onPressed: () => _insertAgent('请把客户最新消息翻译成中文')),
              ActionChip(
                  label: const Text('回复建议'),
                  onPressed: () => _insertAgent(replyPrompt)),
              ActionChip(
                  label: const Text('分析'),
                  onPressed: () => _insertAgent('简洁分析客户诉求，给我下一步建议，不重复对话内容')),
            ]),
          TextField(
            controller: _messageController,
            focusNode: _focusNode,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontSize: 14, height: 1.5),
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: canSend ? '输入消息或 @agent 求助' : '可输入 @agent 内部求助',
              isDense: true,
              filled: false,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onSubmitted: canSubmit ? (_) => _sendMessage() : null,
          ),
          Row(children: [
            IconButton(
                tooltip: '@agent',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.alternate_email, size: 20),
                onPressed: () => _insertAgent()),
            Expanded(
                child: askingAgent
                    ? Text('@agent · 仅客服可见',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 10, color: colorScheme.primary))
                    : const SizedBox()),
            IconButton(
              tooltip: '图片',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.image_outlined, size: 20),
              onPressed:
                  canSend && !askingAgent && !_isSending ? _pickImage : null,
            ),
            IconButton(
              tooltip: '表情',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                  _showEmojiPicker
                      ? Icons.keyboard
                      : Icons.emoji_emotions_outlined,
                  size: 20),
              onPressed: () => setState(() {
                _showEmojiPicker = !_showEmojiPicker;
                if (_showEmojiPicker) {
                  FocusScope.of(context).unfocus();
                } else {
                  _focusNode.requestFocus();
                }
              }),
            ),
            IconButton(
              tooltip: '常用语',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.quickreply_outlined, size: 20),
              onPressed: canSend && !askingAgent ? _showQuickReplies : null,
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: askingAgent ? '向内部助手提问' : '发送给客户',
              style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6))),
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 19),
              onPressed: canSubmit ? _sendMessage : null,
            ),
          ]),
        ]),
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
